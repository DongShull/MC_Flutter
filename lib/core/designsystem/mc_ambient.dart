import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../image/image_urls.dart';
import 'mc_icons.dart';
import 'theme.dart';

/// 剧照动态取色引擎（1:1 复刻 iOS `ImmersiveHero.swift` 的 `ImmersiveHeroAmbientColor` 与 `HeroEdgeColor`）：
/// - `dominant(url)`：按 `饱和度² × (亮度 + 0.25)` 单位圆加权求色相，亮度锁定 `0.44`，用于轮播页上半截氛围底；
/// - `bottomEdge(url)`：取底部 `8%` 条带的平均色，亮度封顶 `0.34`，用于详情页整页 Apple Music 式铺底。
/// 结果常驻内存 LRU 缓存，同一张图绝不二次计算。
class McAmbientColor {
  McAmbientColor._();

  static final Map<String, Color> _dominantCache = {};
  static final Map<String, Color> _edgeCache = {};

  /// 灰黑剧照兜底色（冷银灰，与银玻璃强调色同族）。
  static final Color fallback =
      const HSVColor.fromAHSV(1, 220, 0.14, 0.30).toColor();

  static Future<Color?> dominant(String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final resolved = McImageUrls.resolve(rawUrl, widthPx: 320);
    if (resolved.isEmpty) return null;
    final hit = _dominantCache[resolved];
    if (hit != null) return hit;

    final bytes = await _loadRgbaBytes(resolved, targetWidth: 24, targetHeight: 24);
    if (bytes == null) return null;

    var x = 0.0, y = 0.0, satSum = 0.0, weightSum = 0.0;
    for (var i = 0; i + 3 < bytes.length; i += 4) {
      final r = bytes[i] / 255.0;
      final g = bytes[i + 1] / 255.0;
      final b = bytes[i + 2] / 255.0;
      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      final delta = maxC - minC;
      if (maxC <= 0.12 || delta <= 0.04) continue;
      final s = delta / maxC;
      double hue;
      if (maxC == r) {
        hue = (g - b) / delta;
      } else if (maxC == g) {
        hue = 2.0 + (b - r) / delta;
      } else {
        hue = 4.0 + (r - g) / delta;
      }
      hue /= 6.0;
      if (hue < 0) hue += 1.0;
      final w = s * s * (maxC + 0.25);
      x += math.cos(hue * 2 * math.pi) * w;
      y += math.sin(hue * 2 * math.pi) * w;
      satSum += s * w;
      weightSum += w;
    }

    final Color result;
    if (weightSum <= 2.0) {
      result = fallback;
    } else {
      var hue = math.atan2(y, x) / (2 * math.pi);
      if (hue < 0) hue += 1.0;
      final meanSat = (satSum / weightSum * 1.1).clamp(0.28, 0.72);
      result = HSVColor.fromAHSV(1, hue * 360.0, meanSat, 0.42).toColor();
    }
    if (_dominantCache.length > 256) _dominantCache.clear();
    _dominantCache[resolved] = result;
    return result;
  }

  static Future<Color?> bottomEdge(String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final resolved = McImageUrls.resolve(rawUrl, widthPx: 320);
    if (resolved.isEmpty) return null;
    final hit = _edgeCache[resolved];
    if (hit != null) return hit;

    final bytes = await _loadRgbaBytes(resolved, targetWidth: 24, targetHeight: 24);
    if (bytes == null) return null;

    // 取底部 3 行（24×3 像素）均值
    const startRow = 21;
    var rSum = 0.0, gSum = 0.0, bSum = 0.0, count = 0;
    for (var row = startRow; row < 24; row++) {
      for (var col = 0; col < 24; col++) {
        final idx = (row * 24 + col) * 4;
        if (idx + 3 >= bytes.length) break;
        rSum += bytes[idx] / 255.0;
        gSum += bytes[idx + 1] / 255.0;
        bSum += bytes[idx + 2] / 255.0;
        count++;
      }
    }
    if (count == 0) return null;
    final avg = Color.fromARGB(
      255,
      ((rSum / count) * 255).round().clamp(0, 255),
      ((gSum / count) * 255).round().clamp(0, 255),
      ((bSum / count) * 255).round().clamp(0, 255),
    );
    final hsv = HSVColor.fromColor(avg);
    final clamped = HSVColor.fromAHSV(
      1,
      hsv.hue,
      (hsv.saturation * 1.1).clamp(0.0, 1.0),
      math.min(0.32, hsv.value),
    ).toColor();
    if (_edgeCache.length > 256) _edgeCache.clear();
    _edgeCache[resolved] = clamped;
    return clamped;
  }

  static Future<List<int>?> _loadRgbaBytes(
    String url, {
    required int targetWidth,
    required int targetHeight,
  }) async {
    final completer = Completer<ui.Image?>();
    final provider = ResizeImage(
      CachedNetworkImageProvider(url, headers: mcImageHeaders()),
      width: targetWidth,
      height: targetHeight,
      allowUpscaling: false,
    );
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (_, __) {
        if (!completer.isCompleted) completer.complete(null);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    final img = await completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        stream.removeListener(listener);
        return null;
      },
    );
    if (img == null) return null;
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data?.buffer.asUint8List();
  }
}

/// 轮播页顶部向下渐隐的氛围底（对齐 iOS `ImmersiveHeroAmbient`：换张 1.2s 交叉淡入，深滚渐退）。
class McAmbientTopGlow extends StatelessWidget {
  const McAmbientTopGlow({
    super.key,
    required this.tint,
    this.scrollOffset = 0,
  });

  final Color? tint;
  final double scrollOffset;

  @override
  Widget build(BuildContext context) {
    final fade = (1.0 - math.max(0.0, scrollOffset) / 900.0).clamp(0.30, 1.0);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: McTokens.bg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 900),
            child: tint == null
                ? const SizedBox.expand(key: ValueKey('none'))
                : Opacity(
                    key: ValueKey(tint!.toARGB32()),
                    opacity: fade,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            tint!.withValues(alpha: 0.82),
                            tint!.withValues(alpha: 0.46),
                            tint!.withValues(alpha: 0.14),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.40, 0.72, 1.0],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 轮播指示器（对齐 iOS `ImmersiveHeroIndicator`：当前格为 `26×5dp` 按停留时长线性填满的长胶囊，其余为 `5×5dp` 圆点）。
class McHeroIndicator extends StatelessWidget {
  const McHeroIndicator({
    super.key,
    required this.count,
    required this.index,
    required this.fill,
    this.onSelect,
  });

  final int count;
  final int index;
  final double fill;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          if (i == index)
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                width: 26,
                height: 5,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0x42FFFFFF)),
                    ),
                    FractionallySizedBox(
                      widthFactor: fill.clamp(0.0, 1.0),
                      heightFactor: 1.0,
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xF2FFFFFF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSelect == null ? null : () => onSelect!(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0x57FFFFFF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// 全出血沉浸式轮播 Hero（对齐 iOS `ImmersiveHeroBackdrop` + `ImmersiveHeroRotation`）：
/// - 剧照顶到物理状态栏，12 秒慢速推近（Ken Burns `1.0 → 1.08`）
/// - 下拉越界时以底边为锚点等比放大拉伸，上滑时 `0.38x` 视差下沉
/// - 顶部护栏压暗 + 下半部托字压暗 + 底边无接缝渐隐融入页面氛围底色
/// - 每张停留 `interval`，自动推进并实时更新 `McHeroIndicator` 填充条与主色回调
class McImmersiveHero extends StatefulWidget {
  const McImmersiveHero({
    super.key,
    required this.itemCount,
    required this.imageUrlOf,
    required this.foregroundBuilder,
    this.height = 490,
    this.scrollOffset = 0,
    this.interval = const Duration(seconds: 8),
    this.onAmbientColorChanged,
    this.onTapSlide,
  });

  final int itemCount;
  final String? Function(int index) imageUrlOf;
  final Widget Function(BuildContext context, int index) foregroundBuilder;
  final double height;
  final double scrollOffset;
  final Duration interval;
  final ValueChanged<Color?>? onAmbientColorChanged;
  final ValueChanged<int>? onTapSlide;

  @override
  State<McImmersiveHero> createState() => _McImmersiveHeroState();
}

class _McImmersiveHeroState extends State<McImmersiveHero>
    with SingleTickerProviderStateMixin {
  late final PageController _pageCtrl = PageController();
  late final AnimationController _fillCtrl = AnimationController(
    vsync: this,
    duration: widget.interval,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          mounted &&
          widget.itemCount > 1 &&
          _pageCtrl.hasClients) {
        final next = (_index + 1) % widget.itemCount;
        _pageCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeInOutCubic,
        );
      }
    });

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartCycle();
    _sampleCurrentColor();
  }

  @override
  void didUpdateWidget(covariant McImmersiveHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.itemCount && widget.itemCount > 0) {
      _index = 0;
    }
    if (oldWidget.itemCount != widget.itemCount) {
      _restartCycle();
      _sampleCurrentColor();
    }
  }

  @override
  void dispose() {
    _fillCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _restartCycle() {
    _fillCtrl.stop();
    _fillCtrl.value = 0;
    if (widget.itemCount > 1) {
      _fillCtrl.forward();
    }
  }

  Future<void> _sampleCurrentColor() async {
    if (widget.onAmbientColorChanged == null || widget.itemCount == 0) return;
    final i = _index.clamp(0, widget.itemCount - 1);
    final url = widget.imageUrlOf(i);
    final color = await McAmbientColor.dominant(url);
    if (mounted && _index == i) {
      widget.onAmbientColorChanged?.call(color);
    }
  }

  void _jumpTo(int i) {
    if (!_pageCtrl.hasClients) return;
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) return const SizedBox.shrink();

    // 下拉负位移 → 放大拉伸；上滑正位移 → 0.35x 视差
    final pull = math.max(0.0, -widget.scrollOffset);
    final pullScale = 1.0 + (pull / math.max(1.0, widget.height)).clamp(0.0, 0.45);
    final parallaxY = math.max(0.0, widget.scrollOffset) * 0.35;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification && n.dragDetails != null) {
                _fillCtrl.stop();
              } else if (n is ScrollEndNotification) {
                _restartCycle();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.itemCount,
              onPageChanged: (i) {
                setState(() => _index = i);
                _restartCycle();
                _sampleCurrentColor();
              },
              itemBuilder: (context, i) {
                final url = widget.imageUrlOf(i);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTapSlide == null
                      ? null
                      : () => widget.onTapSlide!(i),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 剧照层：下拉放大 + Ken Burns 慢推 + 视差 + 底部四段渐隐遮罩
                      Transform.scale(
                        scale: pullScale,
                        alignment: Alignment.bottomCenter,
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black,
                              Colors.black,
                              Color(0x99000000),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.56, 0.82, 1.0],
                          ).createShader(rect),
                          child: ClipRect(
                            child: Transform.translate(
                              offset: Offset(0, parallaxY),
                              child: _KenBurnsArtwork(
                                imageUrl: url,
                                active: i == _index,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 顶部护状态栏/大标题暗雾
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 120,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x88000000), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 前景内容（Logo/片名、状态行、主播放胶囊）
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 34,
                        child: widget.foregroundBuilder(context, i),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (widget.itemCount > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: AnimatedBuilder(
                  animation: _fillCtrl,
                  builder: (context, _) => McHeroIndicator(
                    count: widget.itemCount,
                    index: _index,
                    fill: _fillCtrl.value,
                    onSelect: _jumpTo,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KenBurnsArtwork extends StatelessWidget {
  const _KenBurnsArtwork({required this.imageUrl, required this.active});

  final String? imageUrl;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final resolved = McImageUrls.resolve(imageUrl, widthPx: 1280);
    final placeholder = Container(
      color: McTokens.posterPlaceholder,
      alignment: Alignment.center,
      child: const Icon(McIcons.film, size: 42, color: McTokens.textFaint),
    );
    return TweenAnimationBuilder<double>(
      key: ValueKey('${resolved}_$active'),
      tween: Tween<double>(begin: 1.0, end: active ? 1.08 : 1.0),
      duration: const Duration(seconds: 12),
      curve: Curves.linear,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (resolved.isEmpty)
            placeholder
          else
            CachedNetworkImage(
              imageUrl: resolved,
              httpHeaders: mcImageHeaders(),
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 260),
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => placeholder,
            ),
          // 下半部压暗托住白字
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, -0.25),
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x94000000)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
