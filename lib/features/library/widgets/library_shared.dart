import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../state/models.dart';

// 媒体库模块共用的小工具与小组件（逐条对齐鸿蒙 library/LibraryShared.ets）：
// 类型图标、扫描阶段、季集摘要、首页统计、海报格、进度环、分区头、空态。

/// 库类型图标（鸿蒙 LibraryKindMeta.symbol）。
IconData libraryKindIcon(String kind) => switch (kind) {
      'movie' => Icons.movie_outlined,
      'tv' => Icons.tv_outlined,
      'video' => Icons.videocam_outlined,
      'photo' => Icons.image_outlined,
      _ => Icons.layers_outlined,
    };

/// 扫描阶段 → 状态词（Web SCAN_PHASE_LABELS）：阶段变了文案跟着变，免得 100% 配「扫描中」像卡死。
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
String episodeCode(int season, int episode) => 'S${mcPad2(season)}E${mcPad2(episode)}';

/// 「最近添加」的季集摘要（Web formatRecentAddition）：连续区间保留精确集号，零散或跨季改为计数。
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
  if (start == null || end == null) return 'S${mcPad2(season)} · 新增${a.episodeCount}集';
  return start == end
      ? 'S${mcPad2(season)}E${mcPad2(start)}'
      : 'S${mcPad2(season)}E${mcPad2(start)}–${mcPad2(end)}';
}

/// 收藏层级说明（Web favoriteLevelLabel）：整剧与电影不解释。
String? favoriteLevelLabel(String kind, int? season, int? episode) {
  if (kind != 'tv' || season == null) return null;
  if (episode != null) return '收藏了 S${mcPad2(season)}E${mcPad2(episode)}';
  return season == 0 ? '收藏了特别篇' : '收藏了第 $season 季';
}

/// 长按海报的信息行：最近添加的季集范围、入库时间、收藏层级。
List<String> posterInfoLines(LibraryItemView item, {bool favorite = false}) {
  if (favorite) {
    final level =
        favoriteLevelLabel(item.kind, item.favoriteSeasonNumber, item.favoriteEpisodeNumber);
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

/// 媒体库首页摘要（Web libraryStatsSummary）：只聚合库列表随带的统计快照。
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
      ' · 共占用 ${mcFormatBytes(size)} 存储空间';
}

/// 带登录头的网络图（失败/无图落回占位底 + 图标）。
class LibraryNetImage extends StatelessWidget {
  const LibraryNetImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.movie_outlined,
  });

  final String url;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: McTokens.surfaceRaised,
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

/// 按框比例铺图（鸿蒙 LibraryArtwork）：框比例锁死、同一行等高；主图真实比例与框不一致时，
/// 同一张图放大模糊铺底、中央按真实比例完整显示，而不是裁掉或撑变形。
class LibraryArtwork extends StatelessWidget {
  const LibraryArtwork({
    super.key,
    required this.url,
    this.imageAspect,
    this.frameAspect = McTokens.posterAspect,
    this.fallbackText,
    this.placeholderIcon = Icons.movie_outlined,
  });

  final String url;
  final double? imageAspect;
  final double frameAspect;
  final String? fallbackText;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    final ia = imageAspect;
    if (url.isEmpty && fallbackText != null) {
      child = Container(
        color: McTokens.surfaceRaised,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Text(
          fallbackText!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0x40FFFFFF),
          ),
        ),
      );
    } else if (ia != null && ia > 0 && (ia - frameAspect).abs() > 0.05) {
      child = Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.45,
            child: Transform.scale(
              scale: 1.25,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: LibraryNetImage(url: url, placeholderIcon: placeholderIcon),
              ),
            ),
          ),
          const ColoredBox(color: Color(0x40000000)),
          Center(
            child: AspectRatio(
              aspectRatio: ia,
              child: LibraryNetImage(
                  url: url, fit: BoxFit.contain, placeholderIcon: placeholderIcon),
            ),
          ),
        ],
      );
    } else {
      child = LibraryNetImage(url: url, placeholderIcon: placeholderIcon);
    }
    return AspectRatio(aspectRatio: frameAspect, child: ClipRect(child: child));
  }
}

/// 媒体库海报格（鸿蒙 LibraryPosterCell 首页用到的子集）：海报 + 片名 + 年份 + 左上角标。
class LibraryPosterCell extends StatelessWidget {
  const LibraryPosterCell({
    super.key,
    required this.title,
    this.year,
    required this.url,
    this.imageAspect,
    this.frameAspect = McTokens.posterAspect,
    this.cornerLabel,
    this.placeholderIcon = Icons.movie_outlined,
  });

  final String title;
  final int? year;
  final String url;
  final double? imageAspect;
  final double frameAspect;
  final String? cornerLabel;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(McTokens.posterRadius),
                border: Border.all(color: McTokens.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(McTokens.posterRadius),
                child: LibraryArtwork(
                  url: url,
                  imageAspect: imageAspect,
                  frameAspect: frameAspect,
                  placeholderIcon: placeholderIcon,
                ),
              ),
            ),
            if (cornerLabel != null)
              Positioned(
                left: 7,
                top: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    cornerLabel!,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xE6FFFFFF)),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: McTokens.text),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            year == null ? ' ' : '$year',
            maxLines: 1,
            style: const TextStyle(fontSize: 12, color: McTokens.textMuted),
          ),
        ),
      ],
    );
  }
}

/// 首页 / 详情页的分区头：标题 + 右侧入口文字 + 可选尾部组件（⋯ 菜单）。
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600, color: McTokens.text),
            ),
          ),
          if (trailingText != null && trailingText!.isNotEmpty && onTrailing != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTrailing,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(trailingText!,
                    style: const TextStyle(fontSize: 15, color: McTokens.textFaint)),
              ),
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 扫描 / 整理 / 元数据刷新共用的进度环（已处理/总数；没有分母时转圈）。
class LibraryProgressRing extends StatelessWidget {
  const LibraryProgressRing({super.key, this.processed, this.total, this.size = 72});

  final int? processed;
  final int? total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = processed, t = total;
    final fraction = p == null || t == null || t <= 0 ? null : (p / t).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: fraction == null
          ? Center(
              child: SizedBox(
                width: size * 0.55,
                height: size * 0.55,
                child: const CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: size * 0.07,
                    color: Colors.white,
                    backgroundColor: const Color(0x33FFFFFF),
                  ),
                ),
                Text(
                  '${(fraction * 100).round()}%',
                  style: TextStyle(
                      fontSize: size * 0.2, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
    );
  }
}

/// 次级玻璃按钮（鸿蒙 GlassButtonModifier(Secondary) + accentStrong 文字）。
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
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      foregroundColor: color,
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}

/// 空态（鸿蒙 EmptyState）：图标 + 标题 + 说明 + 可选动作。
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({
    super.key,
    this.icon = Icons.movie_outlined,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Icon(icon, size: 44, color: McTokens.textFaint),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, color: McTokens.text)),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.45, color: McTokens.textMuted)),
          ],
          if (actionTitle != null && onAction != null) ...[
            const SizedBox(height: 16),
            LibraryGlassTextButton(label: actionTitle!, onTap: onAction),
          ],
        ],
      ),
    );
  }
}
