import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../state/models.dart';

/// 库类型图标（统一使用 McIcons 字体图标）。
IconData libraryKindIcon(String kind) => switch (kind) {
      'movie' => McIcons.movie,
      'tv' => McIcons.tv,
      'video' => McIcons.film,
      'photo' => McIcons.imageAdd,
      _ => McIcons.mediaLibraryFill,
    };

/// 扫描阶段 → 状态词（对齐 Web SCAN_PHASE_LABELS）。
String scanPhaseLabel(String? phase) => switch (phase ?? 'ingesting') {
      'walking' => '正在盘点文件',
      'ingesting' => '正在扫描',
      'probing' => '正在补探画质与音轨',
      'assets' => '正在补齐海报与剧照',
      'reidentifying' => '正在重新识别条目',
      'organizing' => '正在整理文件名',
      _ => '扫描中',
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
  var movie = 0, tv = 0, video = 0, size = 0;
  for (final l in libraries) {
    switch (l.kind) {
      case 'movie':
        movie += l.stats.itemCount;
      case 'tv':
        tv += l.stats.itemCount;
      case 'video':
        video += l.stats.itemCount;
    }
    size += l.stats.totalSizeBytes;
  }
  final videoPart = video > 0 ? ' · $video 个其他视频' : '';
  return '${libraries.length} 个媒体库 · $movie 部电影 · $tv 部剧集$videoPart'
      ' · ${mcFormatBytes(size)}';
}

/// 带登录头的网络图（失败/无图落回银玻璃中性占位底）。
class LibraryNetImage extends StatelessWidget {
  const LibraryNetImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderIcon = McIcons.film,
  });

  final String url;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: McTokens.posterPlaceholder,
      alignment: Alignment.center,
      child: Icon(placeholderIcon, size: 28, color: McTokens.textFaint),
    );
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
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
