import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../widgets/gallery_wall_view.dart';
import '../widgets/library_shared.dart';

/// 照片墙跳转请求（用于「回到上次位置」）。
class PhotoWallJump {
  PhotoWallJump(this.offset) : token = DateTime.now().microsecondsSinceEpoch;
  final int offset;
  final int token;
}

class _PhotoRow {
  const _PhotoRow.header({
    required this.month,
    required this.count,
    required this.isFirst,
  })  : band = null,
        itemIndices = const [];

  const _PhotoRow.band({
    required this.band,
    required this.itemIndices,
  })  : month = '',
        count = 0,
        isFirst = false;

  final String month;
  final int count;
  final bool isFirst;
  final MasonryBand? band;
  final List<int> itemIndices;
}

/// 图片库照片墙（对齐 iOS `PhotoWallView` + `PhotoLightbox`）。
///
/// 特性：
/// - 按 EXIF 拍摄月份 `YYYY-MM` 分组（`grouped: false` 时为整条瀑布流）；
/// - 墙顶月份跳转菜单（按年分节）+ 「加载更早」向上补页；
/// - 最短列瀑布流 + `posterBlur` 渐进占位 + 全景/长图角标 + 文件缺失置灰；
/// - 全屏 `PhotoLightbox`：三级渐进加载（缩略图 → 屏宽原图 → 放大超 1.01x 拉原图）、
///   按需拉取 EXIF 拍摄信息面板、下载原图并通过系统分享保存。
class PhotoWallView extends ConsumerStatefulWidget {
  const PhotoWallView({
    super.key,
    required this.libraryId,
    required this.reloadKey,
    required this.fetch,
    this.grouped = true,
    this.refreshToken = 0,
    this.jumpRequest,
    this.workingLabel,
    this.onFirstVisible,
  });

  static const int pageSize = 60;
  static const String unknownMonth = '未知';

  final int libraryId;
  final Object reloadKey;
  final Future<List<LibraryItemView>> Function(int offset, int limit) fetch;
  final bool grouped;
  final int refreshToken;
  final PhotoWallJump? jumpRequest;
  final String? Function(LibraryItemView item)? workingLabel;
  final void Function(int offset)? onFirstVisible;

  static String monthOf(LibraryItemView item) {
    final d = item.releaseDate;
    if (d == null || d.length < 7) return unknownMonth;
    return d.substring(0, 7);
  }

  static String formatMonth(String month) {
    if (month == unknownMonth) return '日期未知';
    final parts = month.split('-');
    if (parts.length < 2) return month;
    final m = int.tryParse(parts[1]);
    if (m == null) return month;
    return '${parts[0]} 年 $m 月';
  }

  static String shortMonth(String month) {
    if (month == unknownMonth) return '日期未知';
    final parts = month.split('-');
    if (parts.length < 2) return month;
    final m = int.tryParse(parts[1]);
    return m == null ? month : '$m 月';
  }

  @override
  ConsumerState<PhotoWallView> createState() => _PhotoWallViewState();
}

class _PhotoWallViewState extends ConsumerState<PhotoWallView> {
  final List<LibraryItemView> _items = [];
  List<LibraryIndexEntry> _monthIndex = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _loadingPrev = false;
  bool _hasMore = false;
  String? _error;
  int _start = 0;
  int _gen = 0;
  final ValueNotifier<int> _feedVersion = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PhotoWallView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey ||
        oldWidget.grouped != widget.grouped) {
      _reload();
    } else if (oldWidget.refreshToken != widget.refreshToken) {
      _refreshWindow();
    } else if (widget.jumpRequest != null &&
        widget.jumpRequest?.token != oldWidget.jumpRequest?.token) {
      _jumpTo(widget.jumpRequest!.offset);
    }
  }

  @override
  void dispose() {
    _feedVersion.dispose();
    super.dispose();
  }

  List<LibraryItemView> _dedupe(List<LibraryItemView> raw) {
    final seen = <int>{};
    return [for (final i in raw) if (seen.add(i.mediaItemId)) i];
  }

  Future<void> _reload() async {
    final g = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
      _start = 0;
      _items.clear();
    });
    try {
      final api = ref.read(libraryApiProvider);
      final page = await widget.fetch(0, PhotoWallView.pageSize);
      List<LibraryIndexEntry> months = const [];
      if (widget.grouped) {
        try {
          months = await api.libraryItemIndex(
            widget.libraryId,
            filterQuery: const {'sort': 'release_date'},
          );
        } catch (_) {}
      }
      if (!mounted || g != _gen) return;
      _start = 0;
      _hasMore = page.length >= PhotoWallView.pageSize;
      _monthIndex = months;
      _items
        ..clear()
        ..addAll(_dedupe(page));
      _feedVersion.value++;
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

  Future<void> _refreshWindow() async {
    if (_loading || _loadingMore) return;
    final g = _gen;
    final count = _items.length < PhotoWallView.pageSize
        ? PhotoWallView.pageSize
        : _items.length;
    final collected = <LibraryItemView>[];
    var offset = _start;
    try {
      while (offset < _start + count) {
        final page = await widget.fetch(offset, PhotoWallView.pageSize);
        collected.addAll(page);
        if (page.length < PhotoWallView.pageSize) break;
        offset += PhotoWallView.pageSize;
      }
      if (!mounted || g != _gen) return;
      _hasMore = collected.length >= count;
      _items
        ..clear()
        ..addAll(_dedupe(collected));
      _feedVersion.value++;
      setState(() {});
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    _loadingMore = true;
    final g = _gen;
    try {
      final page = await widget.fetch(
        _start + _items.length,
        PhotoWallView.pageSize,
      );
      if (!mounted || g != _gen) return;
      _hasMore = page.length >= PhotoWallView.pageSize;
      final merged = _dedupe([..._items, ...page]);
      _items
        ..clear()
        ..addAll(merged);
      _feedVersion.value++;
      setState(() {});
    } catch (_) {
      if (mounted && g == _gen) setState(() => _hasMore = false);
    } finally {
      if (g == _gen) _loadingMore = false;
    }
  }

  Future<void> _loadPrevious() async {
    if (_start <= 0 || _loadingPrev || _loading) return;
    setState(() => _loadingPrev = true);
    final g = _gen;
    final offset = (_start - PhotoWallView.pageSize).clamp(0, _start);
    try {
      final page = await widget.fetch(offset, _start - offset);
      if (!mounted || g != _gen) return;
      _start = offset;
      final merged = _dedupe([...page, ..._items]);
      _items
        ..clear()
        ..addAll(merged);
      _feedVersion.value++;
      setState(() => _loadingPrev = false);
    } catch (_) {
      if (mounted && g == _gen) setState(() => _loadingPrev = false);
    }
  }

  Future<void> _jumpTo(int offset) async {
    final g = ++_gen;
    setState(() => _loading = true);
    try {
      final page = await widget.fetch(offset, PhotoWallView.pageSize);
      if (!mounted || g != _gen) return;
      _start = offset;
      _hasMore = page.length >= PhotoWallView.pageSize;
      _items
        ..clear()
        ..addAll(_dedupe(page));
      _feedVersion.value++;
      setState(() => _loading = false);
      widget.onFirstVisible?.call(offset);
    } catch (e) {
      if (!mounted || g != _gen) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openMonthPicker() {
    // 按年分节
    final sections = <({String year, List<LibraryIndexEntry> entries})>[];
    for (final entry in _monthIndex) {
      final year = entry.initial == PhotoWallView.unknownMonth
          ? '日期未知'
          : '${entry.initial.substring(0, entry.initial.length.clamp(0, 4))} 年';
      if (sections.isNotEmpty && sections.last.year == year) {
        sections.last.entries.add(entry);
      } else {
        sections.add((year: year, entries: [entry]));
      }
    }
    showMcSheet<void>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text('按月份跳转', style: McText.titleSm),
          ),
          for (final sec in sections) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
              child: Text(
                sec.year,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: McTokens.textMuted,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in sec.entries)
                  McChip(
                    label: '${PhotoWallView.shortMonth(e.initial)} · ${e.count}',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _jumpTo(e.offset);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openLightbox(int index, int tileWidth) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PhotoLightboxPage(
          libraryId: widget.libraryId,
          items: _items,
          feedVersion: _feedVersion,
          initialIndex: index,
          tileWidth: tileWidth,
          hasMore: _hasMore,
          onLoadMore: _loadMore,
        ),
      ),
    );
  }

  List<_PhotoRow> _buildRows(double width, GalleryDensity density) {
    if (width <= 0 || _items.isEmpty) return const [];
    final buckets = <({String month, List<int> indices})>[];
    if (widget.grouped) {
      final pos = <String, int>{};
      for (var i = 0; i < _items.length; i++) {
        final m = PhotoWallView.monthOf(_items[i]);
        final idx = pos[m];
        if (idx != null) {
          buckets[idx].indices.add(i);
        } else {
          pos[m] = buckets.length;
          buckets.add((month: m, indices: [i]));
        }
      }
    } else {
      buckets.add((
        month: '',
        indices: [for (var i = 0; i < _items.length; i++) i],
      ));
    }

    final totals = <String, int>{
      for (final e in _monthIndex) e.initial: e.count,
    };
    final rows = <_PhotoRow>[];
    for (var b = 0; b < buckets.length; b++) {
      final bucket = buckets[b];
      if (bucket.month.isNotEmpty) {
        rows.add(
          _PhotoRow.header(
            month: bucket.month,
            count: totals[bucket.month] ?? bucket.indices.length,
            isFirst: b == 0,
          ),
        );
      }
      final aspects = [
        for (final idx in bucket.indices) _items[idx].primaryAspect,
      ];
      final laid = density.layout(aspects, width);
      for (final band in MasonryBand.slice(laid.frames, laid.height)) {
        rows.add(_PhotoRow.band(band: band, itemIndices: bucket.indices));
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
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: McEmptyView(
          icon: McIcons.imageAdd,
          title: '照片库暂无照片',
          text: '扫描照片目录后会按拍摄月份展示在这里',
        ),
      );
    }

    return AnimatedBuilder(
      animation: GalleryPrefs.instance,
      builder: (context, _) {
        final density = GalleryPrefs.instance.density;
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final tileW = density.tileImageWidth(
          MediaQuery.of(context).size.width,
          dpr,
        );
        final showsJump = widget.grouped && _monthIndex.length > 1;

        return LayoutBuilder(
          builder: (context, box) {
            final rows = _buildRows(box.maxWidth, density);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_start > 0 || showsJump)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        if (_start > 0)
                          McActionPill(
                            label: _loadingPrev ? '加载中…' : '加载更早',
                            icon: Icons.arrow_upward_rounded,
                            onTap: _loadingPrev ? null : _loadPrevious,
                          ),
                        const Spacer(),
                        if (showsJump)
                          McActionPill(
                            label: '按月份跳转',
                            icon: Icons.calendar_month_rounded,
                            onTap: _openMonthPicker,
                          ),
                      ],
                    ),
                  ),
                for (var r = 0; r < rows.length; r++)
                  _buildRow(rows[r], r, rows.length, tileW),
                if (_hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: _loadMore,
                        child: const Text('加载更多照片'),
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

  Widget _buildRow(_PhotoRow row, int rowIndex, int totalRows, int tileW) {
    if (rowIndex >= totalRows - 3 && _hasMore && !_loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
    }
    if (row.band == null) {
      return Padding(
        padding: EdgeInsets.only(top: row.isFirst ? 0 : 24, bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              PhotoWallView.formatMonth(row.month),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: McTokens.text,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${row.count} 张',
              style: const TextStyle(
                fontSize: 12,
                color: McTokens.textFaint,
              ),
            ),
          ],
        ),
      );
    }

    return MasonryBandView(
      band: row.band!,
      tileBuilder: (placed) {
        final idx = row.itemIndices[placed.index];
        final item = _items[idx];
        final dead = item.isDead;
        final working = widget.workingLabel?.call(item);
        final extreme = item.primaryAspect > GalleryDensity.maxAspect
            ? '全景'
            : (item.primaryAspect < GalleryDensity.minAspect ? '长图' : null);

        return GestureDetector(
          onTap: () {
            widget.onFirstVisible?.call(_start + idx);
            _openLightbox(idx, tileW);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: dead
                      ? const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 0.55, 0,
                        ])
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.dst,
                        ),
                  child: LibraryNetImage(
                    url: item.posterUrl,
                    widthPx: tileW,
                    blurDataUri: item.posterBlur,
                    placeholderIcon: McIcons.imageAdd,
                  ),
                ),
                if (extreme != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        extreme,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: McTokens.accent,
                        ),
                      ),
                    ),
                  ),
                if (working != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: const Color(0xEB070C14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: McTokens.info,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              working,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: McTokens.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (dead)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: const Color(0xD9070C14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      child: const Text(
                        '文件缺失',
                        style: TextStyle(
                          fontSize: 10,
                          color: McTokens.textMuted,
                        ),
                      ),
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

/* ────────────────────── 照片全屏灯箱（三级加载 + EXIF + 原图下载） ────────────────────── */

class _PhotoLightboxPage extends ConsumerStatefulWidget {
  const _PhotoLightboxPage({
    required this.libraryId,
    required this.items,
    required this.feedVersion,
    required this.initialIndex,
    required this.tileWidth,
    required this.hasMore,
    required this.onLoadMore,
  });

  final int libraryId;
  final List<LibraryItemView> items;
  final ValueNotifier<int> feedVersion;
  final int initialIndex;
  final int tileWidth;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  ConsumerState<_PhotoLightboxPage> createState() => _PhotoLightboxPageState();
}

class _PhotoLightboxPageState extends ConsumerState<_PhotoLightboxPage> {
  late int _index;
  bool _infoOpen = false;
  String? _downloadNote;
  final Map<int, Map<String, dynamic>> _details = {};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  Future<void> _ensureDetail(LibraryItemView item) async {
    if (_details.containsKey(item.mediaItemId)) return;
    try {
      final d = await ref.read(libraryApiProvider).libraryItemDetail(
            widget.libraryId,
            item.mediaItemId,
          );
      if (mounted) {
        setState(() => _details[item.mediaItemId] = d);
      }
    } catch (_) {}
  }

  Map<String, dynamic>? _primaryFile(LibraryItemView item) {
    final detail = _details[item.mediaItemId];
    if (detail == null) return null;
    final files = (detail['files'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    if (files.isEmpty) return null;
    return files.firstWhere(
      (f) => f['id'] == item.primaryFileId,
      orElse: () => files.first,
    );
  }

  Future<void> _downloadOriginal(LibraryItemView item) async {
    final fileId = item.primaryFileId;
    if (fileId == null || _downloadNote != null) return;
    setState(() => _downloadNote = '正在准备下载原图…');
    try {
      final url = McImageUrls.resolve(
        '/libraries/files/$fileId/original?download=1',
      );
      if (url.isEmpty) throw Exception('无法解析原图地址');
      final dio = Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          headers: mcImageHeaders(),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      final resp = await dio.get<List<int>>(url);
      final data = resp.data;
      if (data == null || data.isEmpty) throw Exception('原图响应为空');

      final file = _primaryFile(item);
      var name = file?['file_name']?.toString() ?? item.title;
      final cd = resp.headers.value('content-disposition');
      if (cd != null) {
        final match = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
        if (match != null && (match.group(1)?.isNotEmpty ?? false)) {
          name = Uri.decodeComponent(match.group(1)!);
        }
      }
      if (!name.contains('.')) name = '$name.jpg';

      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/movieclaw-originals');
      if (!await dir.exists()) await dir.create(recursive: true);
      final out = File('${dir.path}/$name');
      await out.writeAsBytes(data, flush: true);

      if (!mounted) return;
      setState(() => _downloadNote = null);
      await Share.shareXFiles([XFile(out.path)], text: item.title);
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloadNote = null);
      McToast.error('下载原图失败：$e');
    }
  }

  Widget _buildInfoPanel(LibraryItemView item) {
    final file = _primaryFile(item);
    final loaded = _details.containsKey(item.mediaItemId);
    final sizeBytes = file?['size_bytes'] is num
        ? (file!['size_bytes'] as num).toInt()
        : item.totalSizeBytes;
    final rows = <(String, String)>[
      ('文件名', file?['file_name']?.toString() ?? item.title),
      ('拍摄日期', item.releaseDate ?? '—'),
      (
        '尺寸',
        file?['resolution']?.toString() ??
            (item.resolutions.isNotEmpty ? item.resolutions.first : '—'),
      ),
      ('大小', mcFormatBytes(sizeBytes)),
      ('格式', file?['container']?.toString().toUpperCase() ?? '—'),
      ('路径', file?['file_path']?.toString() ?? '—'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '拍摄信息',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _infoOpen = false),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final (label, val) in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              val,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!loaded)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '正在加载完整文件信息…',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenPx = McImageUrls.snap(
      (MediaQuery.of(context).size.width *
              MediaQuery.of(context).devicePixelRatio)
          .round(),
    );

    return ValueListenableBuilder<int>(
      valueListenable: widget.feedVersion,
      builder: (_, __, ___) {
        final slides = [
          for (var i = 0; i < widget.items.length; i++)
            () {
              final item = widget.items[i];
              final origPath = item.primaryFileId != null
                  ? '/libraries/files/${item.primaryFileId}/original'
                  : null;
              return LightboxSlide(
                id: i,
                title: item.title,
                thumbUrl: McImageUrls.resolve(
                  item.posterUrl,
                  widthPx: widget.tileWidth,
                ),
                screenUrl: origPath != null
                    ? McImageUrls.resolve(origPath, widthPx: screenPx)
                    : McImageUrls.resolve(item.posterUrl, widthPx: screenPx),
                fullUrl: origPath != null ? McImageUrls.resolve(origPath) : null,
                blurDataUri: item.posterBlur,
                aspect: item.primaryAspect,
              );
            }(),
        ];

        return McZoomableLightbox(
          slides: slides,
          initialIndex: _index,
          hasMore: widget.hasMore,
          note: _downloadNote,
          onReachEnd: widget.onLoadMore,
          onIndexChanged: (next) {
            _index = next;
            if (_infoOpen && next >= 0 && next < widget.items.length) {
              _ensureDetail(widget.items[next]);
            }
          },
          actionsBuilder: (idx) {
            if (idx < 0 || idx >= widget.items.length) return const [];
            final item = widget.items[idx];
            return [
              if (item.primaryFileId != null)
                lightboxActionButton(
                  icon: Icons.download_rounded,
                  tooltip: '下载原图',
                  disabled: _downloadNote != null,
                  onTap: () => _downloadOriginal(item),
                ),
              lightboxActionButton(
                icon: _infoOpen
                    ? Icons.info_rounded
                    : Icons.info_outline_rounded,
                color: _infoOpen ? McTokens.accent : Colors.white,
                tooltip: '拍摄信息',
                onTap: () {
                  setState(() => _infoOpen = !_infoOpen);
                  if (_infoOpen) _ensureDetail(item);
                },
              ),
            ];
          },
          overlayBuilder: (idx) {
            if (!_infoOpen || idx < 0 || idx >= widget.items.length) {
              return null;
            }
            return _buildInfoPanel(widget.items[idx]);
          },
        );
      },
    );
  }
}
