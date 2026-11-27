import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/player/player_page_args.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import 'library_shared.dart';

/// 瀑布流密度（图床浏览与照片库共用，对齐 iOS `GalleryDensity`）。
enum GalleryDensity {
  compact('compact', '紧凑', 150, 3, 3),
  standard('standard', '标准', 230, 2, 6),
  loose('loose', '宽松', 340, 1, 10);

  const GalleryDensity(
    this.value,
    this.label,
    this.column,
    this.minColumns,
    this.gap,
  );

  final String value;
  final String label;
  final double column;
  final int minColumns;
  final double gap;

  static const double minAspect = 0.5;
  static const double maxAspect = 2.0;

  static GalleryDensity fromValue(String? raw) => values.firstWhere(
        (e) => e.value == raw,
        orElse: () => GalleryDensity.standard,
      );

  static double clampAspect(double raw) {
    final v = raw > 0 ? raw : 1.0;
    return v.clamp(minAspect, maxAspect);
  }

  /// 按当前容器宽度估算瓦片请求像素宽（用于命中缩略图缓存）。
  int tileImageWidth(double screenWidth, double dpr) {
    final width = math.max(200.0, screenWidth - 32);
    final cols = math.max(minColumns, ((width + gap) / (column + gap)).floor());
    final colW = (width - gap * (cols - 1)) / cols;
    return McImageUrls.snap((colW * dpr).round());
  }

  /// 最短列瀑布流排版（Pinterest 原版算法 + 稀疏行等高兜底）。
  ({List<Rect> frames, double height}) layout(
    List<double> aspects,
    double width,
  ) {
    if (aspects.isEmpty || width <= 0) {
      return (frames: const [], height: 0);
    }
    final cols = math.max(minColumns, ((width + gap) / (column + gap)).floor());
    if (aspects.length < cols) {
      return _sparseRow(aspects, width);
    }
    final colWidth = (width - gap * (cols - 1)) / cols;
    final heights = List<double>.filled(cols, 0);
    final frames = <Rect>[];
    for (final raw in aspects) {
      final h = colWidth / clampAspect(raw);
      var target = 0;
      for (var i = 1; i < cols; i++) {
        if (heights[i] < heights[target] - 0.5) target = i;
      }
      frames.add(
        Rect.fromLTWH(target * (colWidth + gap), heights[target], colWidth, h),
      );
      heights[target] += h + gap;
    }
    final maxH = heights.reduce(math.max);
    return (frames: frames, height: math.max(0, maxH - gap));
  }

  ({List<Rect> frames, double height}) _sparseRow(
    List<double> aspects,
    double width,
  ) {
    final ratios = aspects.map(clampAspect).toList();
    final sum = ratios.fold<double>(0, (a, b) => a + b);
    final fit = (width - gap * (ratios.length - 1)) / math.max(sum, 0.01);
    final h = math.min(column * 1.2, fit);
    var x = 0.0;
    final frames = <Rect>[];
    for (final ratio in ratios) {
      final w = ratio * h;
      frames.add(Rect.fromLTWH(x, 0, w, h));
      x += w + gap;
    }
    return (frames: frames, height: h);
  }
}

/// 瀑布流横切带子（用于 SliverList / ListView 懒渲染大墙）。
class MasonryPlaced {
  const MasonryPlaced({required this.index, required this.rect});
  final int index;
  final Rect rect;
}

class MasonryBand {
  const MasonryBand({
    required this.id,
    required this.height,
    required this.tiles,
  });
  final int id;
  final double height;
  final List<MasonryPlaced> tiles;

  static List<MasonryBand> slice(
    List<Rect> frames,
    double totalHeight, {
    double bandHeight = 420,
    int idBase = 0,
  }) {
    if (totalHeight <= 0 || frames.isEmpty) return const [];
    final count = math.max(1, (totalHeight / bandHeight).ceil());
    final buckets = List<List<MasonryPlaced>>.generate(count, (_) => []);
    for (var i = 0; i < frames.length; i++) {
      final f = frames[i];
      final first = (f.top / bandHeight).floor().clamp(0, count - 1);
      final last =
          (math.max(f.top, f.bottom - 0.5) / bandHeight).floor().clamp(0, count - 1);
      for (var b = first; b <= last; b++) {
        buckets[b].add(
          MasonryPlaced(
            index: i,
            rect: f.translate(0, -b * bandHeight),
          ),
        );
      }
    }
    return [
      for (var b = 0; b < count; b++)
        MasonryBand(
          id: idBase + b,
          height: math.min(bandHeight, totalHeight - b * bandHeight),
          tiles: buckets[b],
        ),
    ];
  }
}

/// 一条带子的绝对定位渲染（出界裁切，多带子无缝拼接）。
class MasonryBandView extends StatelessWidget {
  const MasonryBandView({
    super.key,
    required this.band,
    required this.tileBuilder,
  });

  final MasonryBand band;
  final Widget Function(MasonryPlaced placed) tileBuilder;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: band.height,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final placed in band.tiles)
              Positioned(
                left: placed.rect.left,
                top: placed.rect.top,
                width: placed.rect.width,
                height: placed.rect.height,
                child: tileBuilder(placed),
              ),
          ],
        ),
      ),
    );
  }
}

/// 本机图床 / 照片墙偏好（SharedPreferences 持久化，对齐 iOS `GalleryPrefs`）。
class GalleryPrefs extends ChangeNotifier {
  GalleryPrefs._() {
    _hydrate();
  }

  static final GalleryPrefs instance = GalleryPrefs._();

  static const _modeKey = 'movieclaw.library.gallery-mode';
  static const _libraryModesKey = 'movieclaw.library.gallery-modes';
  static const _groupedKey = 'movieclaw.library.gallery-grouped';
  static const _densityKey = 'movieclaw.photo-wall.density';

  bool _galleryMode = false;
  Map<String, bool> _libraryModes = {};
  bool _grouped = true;
  GalleryDensity _density = GalleryDensity.standard;
  bool _hydrated = false;

  bool get grouped => _grouped;
  GalleryDensity get density => _density;
  bool get hydrated => _hydrated;

  bool galleryModeFor({int? libraryId}) {
    if (libraryId == null) return _galleryMode;
    return _libraryModes['$libraryId'] ?? false;
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _galleryMode = prefs.getBool(_modeKey) ?? false;
      _grouped = prefs.getBool(_groupedKey) ?? true;
      _density = GalleryDensity.fromValue(prefs.getString(_densityKey));
      final rawModes = prefs.getString(_libraryModesKey);
      if (rawModes != null && rawModes.isNotEmpty) {
        final decoded = jsonDecode(rawModes);
        if (decoded is Map) {
          _libraryModes = {
            for (final e in decoded.entries)
              e.key.toString(): e.value == true,
          };
        }
      }
      _hydrated = true;
      notifyListeners();
    } catch (_) {
      _hydrated = true;
    }
  }

  Future<void> setGalleryMode(bool enabled, {int? libraryId}) async {
    if (libraryId == null) {
      _galleryMode = enabled;
    } else {
      _libraryModes = {..._libraryModes, '$libraryId': enabled};
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (libraryId == null) {
        await prefs.setBool(_modeKey, enabled);
      } else {
        await prefs.setString(_libraryModesKey, jsonEncode(_libraryModes));
      }
    } catch (_) {}
  }

  Future<void> setGrouped(bool value) async {
    if (_grouped == value) return;
    _grouped = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_groupedKey, value);
    } catch (_) {}
  }

  Future<void> setDensity(GalleryDensity value) async {
    if (_density == value) return;
    _density = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_densityKey, value.value);
    } catch (_) {}
  }
}

/// 看图偏好弹出菜单（按作品分组 + 紧凑/标准/宽松密度）。
Future<void> showGalleryPrefsSheet(
  BuildContext context, {
  bool showsGrouping = true,
}) {
  return showMcSheet<void>(
    context: context,
    builder: (_) => AnimatedBuilder(
      animation: GalleryPrefs.instance,
      builder: (ctx, __) {
        final prefs = GalleryPrefs.instance;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text('图床显示设置', style: McText.titleSm),
              ),
              if (showsGrouping) ...[
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    SwitchListTile(
                      value: prefs.grouped,
                      onChanged: prefs.setGrouped,
                      title: const Text(
                        '按作品分组',
                        style: TextStyle(fontSize: 15, color: McTokens.text),
                      ),
                      subtitle: const Text(
                        '关闭后整库图片混排为一条沉浸瀑布流',
                        style: TextStyle(fontSize: 12, color: McTokens.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '瀑布流密度',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: McTokens.textMuted,
                  ),
                ),
              ),
              McInsetGroup(
                margin: EdgeInsets.zero,
                children: [
                  for (final d in GalleryDensity.values)
                    McInsetRow(
                      title: d.label,
                      subtitle: switch (d) {
                        GalleryDensity.compact => '多列紧凑预览',
                        GalleryDensity.standard => '默认均衡排版',
                        GalleryDensity.loose => '大图沉浸浏览',
                      },
                      trailing: prefs.density == d
                          ? const Icon(
                              Icons.check_rounded,
                              color: McTokens.accent,
                              size: 20,
                            )
                          : null,
                      onTap: () => prefs.setDensity(d),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

/* ────────────────────── 通用可缩放灯箱舞台 ────────────────────── */

class LightboxSlide {
  const LightboxSlide({
    required this.id,
    required this.title,
    required this.thumbUrl,
    required this.screenUrl,
    this.fullUrl,
    this.blurDataUri,
    this.aspect = 1.0,
  });

  final int id;
  final String title;
  final String thumbUrl;
  final String screenUrl;
  final String? fullUrl;
  final String? blurDataUri;
  final double aspect;
}

/// 通用全屏可缩放灯箱（图床与照片库共用：滑动翻页、双指/双击缩放、缩略条、放大超 1.01x 切原图）。
class McZoomableLightbox extends StatefulWidget {
  const McZoomableLightbox({
    super.key,
    required this.slides,
    required this.initialIndex,
    this.hasMore = false,
    this.onIndexChanged,
    this.onReachEnd,
    this.note,
    this.actionsBuilder,
    this.overlayBuilder,
  });

  final List<LightboxSlide> slides;
  final int initialIndex;
  final bool hasMore;
  final ValueChanged<int>? onIndexChanged;
  final VoidCallback? onReachEnd;
  final String? note;
  final List<Widget> Function(int index)? actionsBuilder;
  final Widget? Function(int index)? overlayBuilder;

  @override
  State<McZoomableLightbox> createState() => _McZoomableLightboxState();
}

class _McZoomableLightboxState extends State<McZoomableLightbox> {
  late final PageController _pageCtrl;
  late final ScrollController _thumbCtrl;
  late int _index;
  bool _chromeVisible = true;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(
      0,
      math.max(0, widget.slides.length - 1),
    );
    _pageCtrl = PageController(initialPage: _index);
    _thumbCtrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollThumbTo(_index));
  }

  @override
  void didUpdateWidget(covariant McZoomableLightbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.slides.length && widget.slides.isNotEmpty) {
      _index = widget.slides.length - 1;
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _thumbCtrl.dispose();
    super.dispose();
  }

  void _scrollThumbTo(int idx) {
    if (!_thumbCtrl.hasClients || widget.slides.isEmpty) return;
    final target = (idx * 52.0 - 120).clamp(
      0.0,
      _thumbCtrl.position.maxScrollExtent,
    );
    _thumbCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int next) {
    setState(() {
      _index = next;
      _isZoomed = false;
    });
    widget.onIndexChanged?.call(next);
    _scrollThumbTo(next);
    if (widget.hasMore && next >= widget.slides.length - 6) {
      widget.onReachEnd?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ),
      );
    }
    final current = widget.slides[_index.clamp(0, widget.slides.length - 1)];
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final overlay = widget.overlayBuilder?.call(_index);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主画布
          PageView.builder(
            controller: _pageCtrl,
            physics: _isZoomed
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: widget.slides.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (_, i) => _ZoomableSlidePage(
              slide: widget.slides[i],
              onSingleTap: () => setState(() => _chromeVisible = !_chromeVisible),
              onZoomChanged: (zoomed) {
                if (i == _index && _isZoomed != zoomed) {
                  setState(() => _isZoomed = zoomed);
                }
              },
            ),
          ),

          // 顶部操作栏
          AnimatedOpacity(
            opacity: _chromeVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: Container(
                padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.78),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    _LightboxIconButton(
                      icon: Icons.close_rounded,
                      tooltip: '关闭',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            current.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${_index + 1} / ${widget.slides.length}${widget.hasMore ? '+' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.actionsBuilder != null)
                      ...widget.actionsBuilder!(_index),
                  ],
                ),
              ),
            ),
          ),

          // 顶部进度条/提示
          if (widget.note != null && widget.note!.isNotEmpty)
            Positioned(
              top: topPad + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.note!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 可选浮层（如 EXIF 信息面板）
          if (overlay != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: (_chromeVisible ? 88 : 16) + bottomPad,
              child: overlay,
            ),

          // 底部缩略图条
          AnimatedOpacity(
            opacity: _chromeVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: EdgeInsets.fromLTRB(0, 12, 0, bottomPad + 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.82),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SizedBox(
                    height: 52,
                    child: ListView.separated(
                      controller: _thumbCtrl,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: widget.slides.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final s = widget.slides[i];
                        final active = i == _index;
                        return GestureDetector(
                          onTap: () => _pageCtrl.jumpToPage(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: active ? 48 : 42,
                            height: active ? 52 : 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: active
                                    ? McTokens.accent
                                    : Colors.white.withValues(alpha: 0.16),
                                width: active ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: s.thumbUrl.isEmpty
                                ? Container(color: McTokens.posterPlaceholder)
                                : CachedNetworkImage(
                                    imageUrl: s.thumbUrl,
                                    httpHeaders: mcImageHeaders(),
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        Container(color: McTokens.posterPlaceholder),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomableSlidePage extends StatefulWidget {
  const _ZoomableSlidePage({
    required this.slide,
    required this.onSingleTap,
    required this.onZoomChanged,
  });

  final LightboxSlide slide;
  final VoidCallback onSingleTap;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableSlidePage> createState() => _ZoomableSlidePageState();
}

class _ZoomableSlidePageState extends State<_ZoomableSlidePage> {
  final TransformationController _ctrl = TransformationController();
  bool _loadFull = false;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTransformChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _ctrl.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.01;
    widget.onZoomChanged(zoomed);
    if (zoomed && !_loadFull && (widget.slide.fullUrl?.isNotEmpty ?? false)) {
      setState(() => _loadFull = true);
    }
  }

  void _handleDoubleTap() {
    final scale = _ctrl.value.getMaxScaleOnAxis();
    if (scale > 1.05) {
      _ctrl.value = Matrix4.identity();
    } else {
      final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
      const zoom = 2.5;
      _ctrl.value = Matrix4.identity()
        ..translate(-pos.dx * (zoom - 1), -pos.dy * (zoom - 1))
        ..scale(zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.slide;
    final blurBytes = decodePosterBlur(s.blurDataUri);
    final headers = mcImageHeaders();

    return GestureDetector(
      onTap: widget.onSingleTap,
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _ctrl,
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // 第 0 级：微缩模糊图
              if (blurBytes != null)
                Image.memory(
                  blurBytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              // 第 1 级：墙面缓存缩略图铺底
              if (s.thumbUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: s.thumbUrl,
                  httpHeaders: headers,
                  fit: BoxFit.contain,
                  fadeInDuration: Duration.zero,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              // 第 2 级：屏宽适配高清图
              if (s.screenUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: s.screenUrl,
                  httpHeaders: headers,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 140),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              // 第 3 级：放大超 1.01x 时拉取完整原图
              if (_loadFull && (s.fullUrl?.isNotEmpty ?? false))
                CachedNetworkImage(
                  imageUrl: s.fullUrl!,
                  httpHeaders: headers,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 160),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LightboxIconButton extends StatelessWidget {
  const _LightboxIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.white,
    this.disabled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: disabled ? color.withValues(alpha: 0.35) : color,
          ),
        ),
      ),
    );
  }
}

/// 导出供 PhotoLightbox 使用的顶栏动作按钮。
Widget lightboxActionButton({
  required IconData icon,
  required String tooltip,
  required VoidCallback onTap,
  Color color = Colors.white,
  bool disabled = false,
}) =>
    _LightboxIconButton(
      icon: icon,
      tooltip: tooltip,
      onTap: onTap,
      color: color,
      disabled: disabled,
    );

/* ────────────────────── 图床瀑布流（LibraryGalleryWall） ────────────────────── */

class _GalleryEntry {
  const _GalleryEntry({required this.groupIndex, required this.imageIndex});
  final int groupIndex;
  final int imageIndex;
}

class _GalleryRow {
  const _GalleryRow.header(this.group, {required this.isFirst})
      : band = null,
        baseEntryIndex = 0;

  const _GalleryRow.band(this.band, {required this.baseEntryIndex})
      : group = null,
        isFirst = false;

  final LibraryGalleryGroupView? group;
  final bool isFirst;
  final MasonryBand? band;
  final int baseEntryIndex;
}

/// 影视库 / 合集 / 收藏共用图床瀑布流（对齐 iOS `LibraryGalleryWall`）。
class LibraryGalleryWall extends ConsumerStatefulWidget {
  const LibraryGalleryWall({
    super.key,
    required this.reloadKey,
    required this.fetch,
    this.startOffset = 0,
    this.onOpenItem,
    this.onFirstVisible,
  });

  static const int pageSize = 24;

  final Object reloadKey;
  final int startOffset;
  final Future<List<LibraryGalleryGroupView>> Function(int offset, int limit)
      fetch;
  final void Function(LibraryGalleryGroupView group)? onOpenItem;
  final void Function(int offset)? onFirstVisible;

  @override
  ConsumerState<LibraryGalleryWall> createState() => _LibraryGalleryWallState();
}

class _LibraryGalleryWallState extends ConsumerState<LibraryGalleryWall> {
  final List<LibraryGalleryGroupView> _groups = [];
  List<_GalleryEntry> _entries = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  int _start = 0;
  int _loaded = 0;
  int _gen = 0;

  // 灯箱状态共享通知器，便于灯箱翻页拉新页 & 收藏即时同步回墙面。
  final ValueNotifier<int> _feedVersion = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant LibraryGalleryWall oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey ||
        oldWidget.startOffset != widget.startOffset) {
      _reload();
    }
  }

  @override
  void dispose() {
    _feedVersion.dispose();
    super.dispose();
  }

  void _rebuildEntries() {
    final next = <_GalleryEntry>[];
    for (var g = 0; g < _groups.length; g++) {
      for (var i = 0; i < _groups[g].images.length; i++) {
        next.add(_GalleryEntry(groupIndex: g, imageIndex: i));
      }
    }
    _entries = next;
    _feedVersion.value++;
  }

  List<LibraryGalleryGroupView> _dedupe(List<LibraryGalleryGroupView> raw) {
    final seen = <int>{};
    return [
      for (final g in raw)
        if (g.images.isNotEmpty && seen.add(g.mediaItemId)) g,
    ];
  }

  Future<void> _reload() async {
    final g = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
      _start = widget.startOffset;
      _groups.clear();
      _entries = const [];
    });
    try {
      final page = await widget.fetch(
        widget.startOffset,
        LibraryGalleryWall.pageSize,
      );
      if (!mounted || g != _gen) return;
      _start = widget.startOffset;
      _loaded = widget.startOffset + page.length;
      _hasMore = page.length >= LibraryGalleryWall.pageSize;
      _groups
        ..clear()
        ..addAll(_dedupe(page));
      _rebuildEntries();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted || g != _gen) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    _loadingMore = true;
    final g = _gen;
    var attempts = 0;
    try {
      while (_hasMore && attempts < 5) {
        attempts++;
        final page = await widget.fetch(_loaded, LibraryGalleryWall.pageSize);
        if (!mounted || g != _gen) return;
        _loaded += page.length;
        _hasMore = page.length >= LibraryGalleryWall.pageSize;
        final before = _entries.length;
        final merged = _dedupe([..._groups, ...page]);
        _groups
          ..clear()
          ..addAll(merged);
        _rebuildEntries();
        if (mounted) setState(() {});
        if (_entries.length > before) break;
      }
    } catch (_) {
      if (mounted && g == _gen) setState(() => _hasMore = false);
    } finally {
      if (g == _gen) _loadingMore = false;
    }
  }

  Future<void> _toggleFavorite(int mediaItemId) async {
    final idx = _groups.indexWhere((g) => g.mediaItemId == mediaItemId);
    if (idx < 0) return;
    final nextFav = !_groups[idx].isFavorite;
    _patchFav(mediaItemId, nextFav);
    try {
      await ref.read(libraryApiProvider).setItemMark(
            mediaItemId,
            favorite: nextFav,
          );
    } catch (e) {
      _patchFav(mediaItemId, !nextFav);
      if (mounted) McToast.error('收藏失败：$e');
    }
  }

  void _patchFav(int mediaItemId, bool fav) {
    for (var i = 0; i < _groups.length; i++) {
      if (_groups[i].mediaItemId == mediaItemId) {
        _groups[i] = _groups[i].copyWith(isFavorite: fav);
      }
    }
    _feedVersion.value++;
    if (mounted) setState(() {});
  }

  String _groupTitle(LibraryGalleryGroupView g) =>
      g.year != null ? '${g.title} (${g.year})' : g.title;

  void _openLightbox(int entryIndex, int tileWidth) {
    final screenPx = McImageUrls.snap(
      (MediaQuery.of(context).size.width *
              MediaQuery.of(context).devicePixelRatio)
          .round(),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => ValueListenableBuilder<int>(
          valueListenable: _feedVersion,
          builder: (_, __, ___) {
            final slides = [
              for (var i = 0; i < _entries.length; i++)
                () {
                  final e = _entries[i];
                  final group = _groups[e.groupIndex];
                  final img = group.images[e.imageIndex];
                  return LightboxSlide(
                    id: i,
                    title: '${_groupTitle(group)} · ${img.label}',
                    thumbUrl: McImageUrls.resolve(img.url, widthPx: tileWidth),
                    screenUrl: McImageUrls.resolve(img.url, widthPx: screenPx),
                    aspect: img.aspect,
                  );
                }(),
            ];
            return McZoomableLightbox(
              slides: slides,
              initialIndex: entryIndex,
              hasMore: _hasMore,
              onReachEnd: _loadMore,
              actionsBuilder: (idx) {
                if (idx < 0 || idx >= _entries.length) return const [];
                final e = _entries[idx];
                final group = _groups[e.groupIndex];
                final img = group.images[e.imageIndex];
                return [
                  lightboxActionButton(
                    icon: Icons.play_arrow_rounded,
                    tooltip: img.tSeconds != null ? '从此处播放' : '播放',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      context.push(
                        '/player',
                        extra: PlayerPageArgs(
                          mediaItemId: group.mediaItemId,
                          seasonNumber: img.season,
                          episodeNumber: img.episode,
                          title: group.title,
                          isEpisode:
                              img.season != null && img.episode != null,
                          startPosition: img.tSeconds != null
                              ? Duration(
                                  milliseconds: (img.tSeconds! * 1000).round(),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  lightboxActionButton(
                    icon: group.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: group.isFavorite ? McTokens.danger : Colors.white,
                    tooltip: group.isFavorite ? '取消收藏' : '收藏',
                    onTap: () => _toggleFavorite(group.mediaItemId),
                  ),
                  lightboxActionButton(
                    icon: Icons.open_in_new_rounded,
                    tooltip: '前往作品详情',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      if (widget.onOpenItem != null) {
                        widget.onOpenItem!(group);
                      } else {
                        context.push(
                          '/detail/${group.libraryId}/${group.mediaItemId}',
                        );
                      }
                    },
                  ),
                ];
              },
            );
          },
        ),
      ),
    );
  }

  List<_GalleryRow> _buildRows(
    double width,
    GalleryDensity density,
    bool grouped,
  ) {
    if (width <= 0 || _entries.isEmpty) return const [];
    final rows = <_GalleryRow>[];
    if (grouped) {
      var base = 0;
      for (var g = 0; g < _groups.length; g++) {
        final group = _groups[g];
        rows.add(_GalleryRow.header(group, isFirst: g == 0));
        final laid = density.layout(
          group.images.map((im) => im.aspect).toList(),
          width,
        );
        for (final band in MasonryBand.slice(laid.frames, laid.height)) {
          rows.add(_GalleryRow.band(band, baseEntryIndex: base));
        }
        base += group.images.length;
      }
    } else {
      final aspects = [
        for (final e in _entries)
          _groups[e.groupIndex].images[e.imageIndex].aspect,
      ];
      final laid = density.layout(aspects, width);
      for (final band in MasonryBand.slice(laid.frames, laid.height)) {
        rows.add(_GalleryRow.band(band, baseEntryIndex: 0));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: McErrorView(text: _error!, onRetry: _reload),
      );
    }
    if (_entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: McEmptyView(
          icon: McIcons.imageAdd,
          title: '暂无可浏览图片',
          text: '作品生成海报、剧照或章节图后会出现在这里',
        ),
      );
    }

    return AnimatedBuilder(
      animation: GalleryPrefs.instance,
      builder: (context, _) {
        final prefs = GalleryPrefs.instance;
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final screenW = MediaQuery.of(context).size.width;
        final tileW = prefs.density.tileImageWidth(screenW, dpr);

        return LayoutBuilder(
          builder: (context, box) {
            final rows = _buildRows(box.maxWidth, prefs.density, prefs.grouped);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var r = 0; r < rows.length; r++)
                  _buildRow(rows[r], r, rows.length, tileW),
                if (_hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: _loadMore,
                        child: const Text('加载更多图片'),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRow(_GalleryRow row, int rowIndex, int totalRows, int tileW) {
    if (rowIndex >= totalRows - 3 && _hasMore && !_loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
    }
    if (row.group != null) {
      final g = row.group!;
      final gIdx = _groups.indexOf(g);
      if (gIdx >= 0 && rowIndex == 0) {
        widget.onFirstVisible?.call(_start + gIdx);
      }
      return Padding(
        padding: EdgeInsets.only(top: row.isFirst ? 0 : 24, bottom: 10),
        child: InkWell(
          onTap: () {
            if (widget.onOpenItem != null) {
              widget.onOpenItem!(g);
            } else {
              context.push('/detail/${g.libraryId}/${g.mediaItemId}');
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _groupTitle(g),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: McTokens.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${g.images.length} 张',
                style: const TextStyle(
                  fontSize: 12,
                  color: McTokens.textFaint,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final band = row.band!;
    return MasonryBandView(
      band: band,
      tileBuilder: (placed) {
        final entryIndex = row.baseEntryIndex + placed.index;
        if (entryIndex < 0 || entryIndex >= _entries.length) {
          return const SizedBox.shrink();
        }
        final entry = _entries[entryIndex];
        final group = _groups[entry.groupIndex];
        final image = group.images[entry.imageIndex];
        return GestureDetector(
          onTap: () {
            widget.onFirstVisible?.call(_start + entry.groupIndex);
            _openLightbox(entryIndex, tileW);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                LibraryNetImage(
                  url: image.url,
                  widthPx: tileW,
                  placeholderIcon: McIcons.imageAdd,
                ),
                if (group.isFavorite)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: McTokens.danger,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
