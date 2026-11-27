import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../state/mc_api.dart';
import '../state/models.dart';

/// 库类型图标（统一使用 McIcons 字体图标）。
IconData libraryKindIcon(String kind) => switch (kind) {
      'movie' => McIcons.movie,
      'tv' => McIcons.tv,
      'video' => McIcons.film,
      'photo' => McIcons.imageAdd,
      _ => McIcons.mediaLibraryFill,
    };

String libraryKindLabel(String kind) => switch (kind) {
      'movie' => '电影',
      'tv' => '剧集',
      'video' => '其他视频',
      'photo' => '照片',
      _ => kind,
    };

/// 扫描阶段 → 状态词（对齐 Web SCAN_PHASE_LABELS & iOS ScanPhase）。
String scanPhaseLabel(String? phase) => switch (phase ?? 'ingesting') {
      'walking' => '正在盘点文件',
      'ingesting' => '正在扫描',
      'probing' => '正在补探画质与音轨',
      'assets' => '正在补齐海报与剧照',
      'reidentifying' => '正在重新识别条目',
      'organizing' => '正在整理文件名',
      _ => '扫描中',
    };

String scanPhaseHint(String? phase) => switch (phase ?? 'ingesting') {
      'walking' => '清点目录中的文件',
      'ingesting' => '识别并登记新文件',
      'probing' => '读取视频分辨率与音轨',
      'assets' => '补齐海报与分集剧照',
      'reidentifying' => '重走识别链',
      'organizing' => '按规范路径重命名归位',
      _ => '',
    };

/// S01E02 形式的集号。
String episodeCode(int season, int episode) =>
    'S${mcPad2(season)}E${mcPad2(episode)}';

/// 「最近添加」的季集摘要。
String? formatRecentAddition(LibraryRecentAddition a) {
  if (a.episodeCount == 0 || a.seasonCount == 0) return null;
  if (a.seasonCount > 1) return '新增${a.seasonCount}季 · ${a.episodeCount}集';
  final season = a.seasonNumber;
  if (season == null) return null;
  if (a.completeSeason) {
    return '${season == 0 ? '特别篇' : '第$season季'} · 全${a.episodeCount}集';
  }
  final start = a.firstEpisodeNumber;
  final end = a.lastEpisodeNumber;
  if (start == null || end == null) {
    return 'S${mcPad2(season)} · 新增${a.episodeCount}集';
  }
  return start == end
      ? 'S${mcPad2(season)}E${mcPad2(start)}'
      : 'S${mcPad2(season)}E${mcPad2(start)}–${mcPad2(end)}';
}

/// 剧集库存概况（对齐 iOS `formatInventorySummary`）。
String formatInventorySummary(LibraryInventorySummaryView summary) {
  final String episodes;
  if (summary.allEpisodesOwned) {
    episodes = '全 ${summary.episodeCount} 集';
  } else if (summary.seasonNumber != null && summary.totalEpisodeCount != null) {
    episodes = '${summary.episodeCount}/${summary.totalEpisodeCount} 集';
  } else {
    episodes = '${summary.episodeCount} 集';
  }
  if (summary.seasonNumber != null) {
    final s = summary.seasonNumber!;
    return '${s == 0 ? '特别篇' : '第 $s 季'} · $episodes';
  }
  final seasons = summary.allSeasonsOwned
      ? '全 ${summary.seasonCount} 季'
      : '${summary.seasonCount} 季';
  return '$seasons · $episodes';
}

/// 收藏层级说明：整剧与电影不解释。
String? favoriteLevelLabel(String kind, int? season, int? episode) {
  if (kind != 'tv' || season == null) return null;
  if (episode != null) return '收藏了 S${mcPad2(season)}E${mcPad2(episode)}';
  return season == 0 ? '收藏了特别篇' : '收藏了第 $season 季';
}

/// 长按海报的信息行：最近添加的季集范围、入库时间、收藏层级。
List<String> posterInfoLines(LibraryItemView item, {bool favorite = false}) {
  if (favorite) {
    final level = favoriteLevelLabel(
      item.kind,
      item.favoriteSeasonNumber,
      item.favoriteEpisodeNumber,
    );
    return [if (level != null) level];
  }
  final recent = item.kind == 'tv' && item.recentAddition != null
      ? formatRecentAddition(item.recentAddition!)
      : null;
  return [
    if (recent != null) recent,
    if (item.addedAt != null) '${mcFromNowIso(item.addedAt)}入库',
  ];
}

/// 媒体库库存汇总行（对齐 iOS/Web 页脚库存摘要）。
String libraryStatsSummary(List<LibraryView>? libraries) {
  if (libraries == null) return '正在汇总媒体库统计…';
  if (libraries.isEmpty) return '还没有媒体库，创建后会在这里显示库存统计';
  var movie = 0, tv = 0, video = 0, photo = 0, size = 0;
  for (final l in libraries) {
    switch (l.kind) {
      case 'movie':
        movie += l.stats.itemCount;
      case 'tv':
        tv += l.stats.itemCount;
      case 'video':
        video += l.stats.itemCount;
      case 'photo':
        photo += l.stats.itemCount;
    }
    size += l.stats.totalSizeBytes;
  }
  final videoPart = video > 0 ? ' · $video 个其他视频' : '';
  final photoPart = photo > 0 ? ' · $photo 张照片' : '';
  return '${libraries.length} 个媒体库 · $movie 部电影 · $tv 部剧集$videoPart$photoPart'
      ' · ${mcFormatBytes(size)}';
}

/// 解码 `data:image/...;base64,xxxx` 微缩模糊图（轻量 LRU 缓存）。
final Map<String, Uint8List?> _blurCache = {};

Uint8List? decodePosterBlur(String? raw) {
  if (raw == null || !raw.startsWith('data:')) return null;
  if (_blurCache.containsKey(raw)) return _blurCache[raw];
  final comma = raw.indexOf(',');
  if (comma < 0 || comma + 1 >= raw.length) return null;
  try {
    final bytes = base64Decode(raw.substring(comma + 1));
    if (_blurCache.length > 240) _blurCache.clear();
    _blurCache[raw] = bytes;
    return bytes;
  } catch (_) {
    _blurCache[raw] = null;
    return null;
  }
}

/// 「回到上次浏览的位置」持久化记录（对齐 iOS `LibraryWallRecall`）。
abstract final class LibraryWallRecall {
  static const _prefsKey = 'movieclaw.library.wall-recall';
  static const int minOffset = 24;
  static const int maxAgeSec = 14 * 86400;

  static Future<int?> read({
    required String scope,
    required String view,
  }) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final entry = map[scope];
      if (entry is! Map) return null;
      if (entry['view']?.toString() != view) return null;
      final offset = (entry['offset'] as num?)?.toInt() ?? 0;
      if (offset < minOffset) return null;
      final at = (entry['at'] as num?)?.toDouble() ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
      if (now - at > maxAgeSec) return null;
      return offset;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write({
    required String scope,
    required String view,
    required int offset,
  }) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_prefsKey);
      final map = raw != null && raw.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : <String, dynamic>{};
      map[scope] = {
        'view': view,
        'offset': offset,
        'at': DateTime.now().millisecondsSinceEpoch / 1000.0,
      };
      await sp.setString(_prefsKey, jsonEncode(map));
    } catch (_) {}
  }
}

/// 底部浮出「回到上次位置」银玻璃胶囊（对齐 iOS `WallRecallPill`）。
class WallRecallPill extends StatelessWidget {
  const WallRecallPill({
    super.key,
    required this.onJump,
    required this.onDismiss,
  });

  final VoidCallback onJump;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return McLiquidGlass(
      radius: McTokens.pillRadius,
      tone: McGlassTone.strong,
      withShadow: true,
      padding: const EdgeInsets.only(left: 14, right: 6, top: 4, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onJump,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    McIcons.history1,
                    size: 15,
                    color: McTokens.accentStrong,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '回到上次位置',
                    style: McText.sub.semibold.copyWith(color: McTokens.text),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: '关闭提示',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            icon: const Icon(McIcons.close, size: 13, color: McTokens.textMuted),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// 带登录头的网络图（失败/无图落回银玻璃中性占位底，可选 blurDataUri 渐进铺底）。
class LibraryNetImage extends StatelessWidget {
  const LibraryNetImage({
    super.key,
    required this.url,
    this.widthPx,
    this.fit = BoxFit.cover,
    this.placeholderIcon = McIcons.film,
    this.blurDataUri,
  });

  final String? url;
  final int? widthPx;
  final BoxFit fit;
  final IconData placeholderIcon;
  final String? blurDataUri;

  @override
  Widget build(BuildContext context) {
    final blurBytes = decodePosterBlur(blurDataUri);
    final placeholder = blurBytes != null
        ? ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Transform.scale(
                scale: 1.08,
                child: Image.memory(
                  blurBytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          )
        : Container(
            color: McTokens.posterPlaceholder,
            alignment: Alignment.center,
            child: Icon(placeholderIcon, size: 28, color: McTokens.textFaint),
          );
    final raw = (url ?? '').trim();
    if (raw.isEmpty) return placeholder;
    final resolved = (raw.startsWith('http://') || raw.startsWith('https://'))
        ? raw
        : McImageUrls.resolve(raw, widthPx: widthPx);
    if (resolved.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: resolved,
      httpHeaders: mcImageHeaders(),
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

/// 按框比例铺图（直接委托 core `McArtwork`）。
class LibraryArtwork extends StatelessWidget {
  const LibraryArtwork({
    super.key,
    required this.url,
    this.imageAspect,
    this.frameAspect = McTokens.posterAspect,
    this.fallbackText,
    this.placeholderIcon = McIcons.film,
  });

  final String url;
  final double? imageAspect;
  final double frameAspect;
  final String? fallbackText;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    return McArtwork(
      url: url,
      imageAspect: imageAspect,
      frameAspect: frameAspect,
      fallbackText: fallbackText,
      placeholderIcon: placeholderIcon,
    );
  }
}

/// 3 张海报错开叠放的合集封面（对齐 iOS `LibraryCollectionCover`）。
class LibraryCollectionCover extends StatelessWidget {
  const LibraryCollectionCover({
    super.key,
    required this.covers,
    this.aspectRatio = McTokens.posterAspect,
    this.radius = 12,
  });

  final List<CollectionCover> covers;
  final double aspectRatio;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shown = covers.where((c) => c.url.isNotEmpty).take(3).toList();
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: McTokens.line),
        ),
        child: shown.isEmpty
            ? Center(
                child: Text('暂无封面', style: McText.caption.faint),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final step = w * 0.07;
                  final inset = h * 0.025;
                  final frontW = math.max(1.0, w - step * (shown.length - 1));
                  return Stack(
                    children: [
                      for (var i = shown.length - 1; i >= 0; i--)
                        Positioned(
                          left: step * i,
                          top: inset * i,
                          width: frontW,
                          height: math.max(1.0, h - inset * i * 2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(radius - 1),
                            child: ColorFiltered(
                              colorFilter: i == 0
                                  ? const ColorFilter.mode(
                                      Colors.transparent,
                                      BlendMode.dst,
                                    )
                                  : ColorFilter.mode(
                                      Colors.black.withValues(
                                        alpha: i == 1 ? 0.35 : 0.55,
                                      ),
                                      BlendMode.darken,
                                    ),
                              child: LibraryNetImage(
                                url: McImageUrls.resolve(
                                  shown[i].url,
                                  widthPx: 480,
                                ),
                                blurDataUri: shown[i].blur,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// 首页「按类型找电影 / 剧集」剧照渐变色块卡（对齐 iOS `GenreCardFace`）。
class GenreCardFace extends StatelessWidget {
  const GenreCardFace({
    super.key,
    required this.label,
    required this.count,
    required this.mediaKind,
    this.coverUrl,
    this.width = 186,
    this.onTap,
  });

  final String label;
  final int count;
  final String mediaKind;
  final String? coverUrl;
  final double width;
  final VoidCallback? onTap;

  static const _palettes = <(Color, Color)>[
    (Color(0xFF1F324E), Color(0xFF0E1624)),
    (Color(0xFF3A2444), Color(0xFF160E1D)),
    (Color(0xFF1C3A39), Color(0xFF0D1B1C)),
    (Color(0xFF422C1F), Color(0xFF1B120E)),
    (Color(0xFF28304A), Color(0xFF121623)),
    (Color(0xFF3E2232), Color(0xFF180D15)),
  ];

  @override
  Widget build(BuildContext context) {
    final height = width * 150 / 236;
    final palette = _palettes[label.hashCode.abs() % _palettes.length];
    final countText = mediaKind == 'tv' ? '$count 部剧集' : '$count 部电影';
    final resolved =
        coverUrl != null ? McImageUrls.resolve(coverUrl, widthPx: 480) : '';

    return McPressable(
      hoverScale: 1.03,
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [palette.$1, palette.$2],
          ),
          border: Border.all(color: const Color(0x1EFFFFFF), width: 0.7),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (resolved.isNotEmpty)
              CachedNetworkImage(
                imageUrl: resolved,
                httpHeaders: mcImageHeaders(),
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              )
            else
              Positioned(
                right: 12,
                top: 10,
                child: Icon(
                  mediaKind == 'tv' ? McIcons.tv : McIcons.film,
                  size: 38,
                  color: const Color(0x22FFFFFF),
                ),
              ),
            // 左下双层暗部文字保护，保留右上剧照通透感
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: [0.0, 0.55, 1.0],
                  colors: [
                    Color(0x9E000000),
                    Color(0x2E000000),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.85, 0.95),
                  radius: 1.15,
                  colors: [
                    Color(0x88000000),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.titleSm.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Color(0x52000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    countText,
                    maxLines: 1,
                    style: McText.micro.copyWith(
                      color: const Color(0xBAFFFFFF),
                    ).tabular,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 媒体库海报格（委托全站唯一 `McPosterCard`）。
class LibraryPosterCell extends StatelessWidget {
  const LibraryPosterCell({
    super.key,
    required this.title,
    this.year,
    required this.url,
    this.imageAspect,
    this.frameAspect = McTokens.posterAspect,
    this.cornerLabel,
    this.favorite = false,
    this.placeholderIcon = McIcons.film,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final int? year;
  final String url;
  final double? imageAspect;
  final double frameAspect;
  final String? cornerLabel;
  final bool favorite;
  final IconData placeholderIcon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return McPosterCard(
      title: title,
      posterUrl: url,
      width: null,
      aspect: frameAspect,
      imageAspect: imageAspect,
      subtitle: year == null ? null : '$year',
      badge: cornerLabel,
      favorite: favorite,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// 媒体库分区头（委托全站唯一 `McSectionHeader`）。
class LibrarySectionHeader extends StatelessWidget {
  const LibrarySectionHeader({
    super.key,
    required this.title,
    this.trailingText,
    this.onTrailing,
    this.trailing,
  });

  final String title;
  final String? trailingText;
  final VoidCallback? onTrailing;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return McSectionHeader(
      title: title,
      trailingText: trailingText?.replaceAll(RegExp(r'\s*›$'), ''),
      trailing: trailing,
      onTap: onTrailing,
    );
  }
}

/// 扫描 / 整理 / 元数据刷新共用的进度环。
class LibraryProgressRing extends StatelessWidget {
  const LibraryProgressRing({
    super.key,
    this.processed,
    this.total,
    this.size = 64,
  });

  final int? processed;
  final int? total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = processed, t = total;
    final fraction =
        p == null || t == null || t <= 0 ? null : (p / t).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: fraction == null
          ? Center(
              child: SizedBox(
                width: size * 0.52,
                height: size * 0.52,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: McTokens.accentStrong,
                ),
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: size * 0.065,
                    color: McTokens.accentStrong,
                    backgroundColor: const Color(0x2EFFFFFF),
                  ),
                ),
                Text(
                  '${(fraction * 100).round()}%',
                  style: McText.caption
                      .copyWith(
                        fontSize: size * 0.2,
                        fontWeight: FontWeight.w600,
                        color: McTokens.text,
                      )
                      .tabular,
                ),
              ],
            ),
    );
  }
}

/// 次级液态玻璃胶囊按钮。
class LibraryGlassTextButton extends StatelessWidget {
  const LibraryGlassTextButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = McTokens.accentStrong,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return McGlassButton(
      onTap: onTap,
      tone: McGlassTone.secondary,
      radius: McTokens.pillRadius,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      foregroundColor: color,
      child: Text(
        label,
        style: McText.ui.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// 空态（统一委托 `McEmptyView`）。
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({
    super.key,
    this.icon = McIcons.film,
    required this.title,
    this.message,
    this.actionTitle,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionTitle;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return McEmptyView(
      icon: icon,
      title: title,
      text: message ?? '',
      actionLabel: actionTitle,
      onRetry: onAction,
    );
  }
}

/// 合集外链分享弹层（对齐 iOS `LibraryShareSheet.swift`，支持 GET / POST / DELETE `/collections/{id}/share`）。
Future<void> showCollectionShareSheet(
  BuildContext context, {
  required LibraryApi api,
  required CollectionView collection,
}) {
  return showMcSheet<void>(
    context: context,
    maxWidth: 520,
    builder: (_) => _CollectionShareSheet(api: api, collection: collection),
  );
}

class _CollectionShareSheet extends StatefulWidget {
  const _CollectionShareSheet({required this.api, required this.collection});

  final LibraryApi api;
  final CollectionView collection;

  @override
  State<_CollectionShareSheet> createState() => _CollectionShareSheetState();
}

class _CollectionShareSheetState extends State<_CollectionShareSheet> {
  static const _expiryOptions = <(int, String)>[
    (1, '1 天'),
    (3, '3 天'),
    (7, '7 天'),
    (30, '30 天'),
  ];

  LibraryShareView? _share;
  bool _loading = true;
  bool _busy = false;
  int _days = 7;
  bool _passwordOn = false;
  final _pwCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  String _genPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final rnd = math.Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  String _fullUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = widget.api.client.baseUrl;
    if (base.isEmpty) return raw;
    return raw.startsWith('/') ? '$base$raw' : '$base/$raw';
  }

  Future<void> _loadCurrent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final existing =
          await widget.api.collectionShareGet(widget.collection.id);
      if (mounted) {
        setState(() {
          _share = existing;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _share = null;
          _loading = false;
        });
      }
    }
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await widget.api.collectionShareCreate(
        widget.collection.id,
        expiresInDays: _days,
        password: _passwordOn ? _pwCtrl.text.trim() : null,
      );
      if (mounted) {
        setState(() {
          _share = created;
          _busy = false;
        });
        McToast.success('已生成合集分享链接');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '生成失败：$e';
        });
      }
    }
  }

  Future<void> _revoke() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.collectionShareRevoke(widget.collection.id);
      if (mounted) {
        setState(() {
          _share = null;
          _busy = false;
        });
        McToast.success('已取消分享，原链接立即失效');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '取消分享失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.collection;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                child: LibraryCollectionCover(covers: c.covers, radius: 7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: McText.titleSm),
                    const SizedBox(height: 2),
                    Text(
                      '${c.itemCount} 部${c.ruleDriven ? ' · 会自动收录新片' : ''} · 拿到链接的人无需登录即可观看',
                      style: McText.caption.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const SizedBox(height: 120, child: McLoadingView())
          else if (_share != null) ...[
            Builder(
              builder: (_) {
                final s = _share!;
                final link = _fullUrl(s.url.isNotEmpty ? s.url : '/s/${s.slug}');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    McInsetGroup(
                      margin: EdgeInsets.zero,
                      children: [
                        McInsetRow(
                          icon: McIcons.link,
                          title: '分享链接',
                          subtitle: link,
                          trailing: McChip(
                            label: '复制',
                            compact: true,
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: link));
                              McToast.success('已复制分享链接');
                            },
                          ),
                        ),
                        if (s.password != null)
                          McInsetRow(
                            icon: McIcons.lock,
                            title: '访问密码',
                            subtitle: s.password,
                            trailing: McChip(
                              label: '复制',
                              compact: true,
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: s.password!),
                                );
                                McToast.success('已复制访问密码');
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${s.viewCount > 0 ? '已打开 ${s.viewCount} 次' : '尚未打开'}'
                      '${s.expiresAt.isNotEmpty ? ' · 到期 ${mcFromNowIso(s.expiresAt, empty: s.expiresAt)}' : ''}',
                      style: McText.caption.faint.tabular,
                    ),
                    const SizedBox(height: 16),
                    McActionPill(
                      label: s.password != null ? '复制链接与密码' : '复制分享链接',
                      icon: McIcons.copy,
                      primary: true,
                      expanded: true,
                      onTap: () {
                        final text = s.password != null
                            ? '${c.name}\n$link\n访问密码：${s.password}'
                            : '${c.name}\n$link';
                        Clipboard.setData(ClipboardData(text: text));
                        McToast.success(
                          s.password != null ? '已复制链接与密码' : '已复制分享链接',
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    McActionPill(
                      label: _busy ? '取消中…' : '取消分享',
                      icon: McIcons.trash2,
                      primary: false,
                      tone: McGlassTone.danger,
                      expanded: true,
                      busy: _busy,
                      onTap: _busy ? null : _revoke,
                    ),
                  ],
                );
              },
            ),
          ] else ...[
            Text('有效期', style: McText.caption.muted),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (d, label) in _expiryOptions)
                  McChip(
                    label: label,
                    selected: _days == d,
                    compact: true,
                    onTap: () => setState(() => _days = d),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  icon: McIcons.lock,
                  title: '访问密码保护',
                  trailing: Switch(
                    value: _passwordOn,
                    onChanged: (v) {
                      setState(() {
                        _passwordOn = v;
                        if (v && _pwCtrl.text.isEmpty) {
                          _pwCtrl.text = _genPassword();
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_passwordOn) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pwCtrl,
                      maxLength: 16,
                      style: McText.body,
                      decoration: const InputDecoration(
                        hintText: '访问密码',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  McChip(
                    label: '换一个',
                    icon: McIcons.refreshS,
                    compact: true,
                    onTap: () => setState(() => _pwCtrl.text = _genPassword()),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: McText.caption.copyWith(color: McTokens.danger),
              ),
            ],
            const SizedBox(height: 16),
            McActionPill(
              label: _busy ? '生成中…' : '生成分享链接',
              icon: McIcons.share,
              primary: true,
              expanded: true,
              busy: _busy,
              onTap: _busy ? null : _create,
            ),
          ],
        ],
      ),
    );
  }
}
