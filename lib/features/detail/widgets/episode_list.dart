import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';

/// 分集列表（对齐并超越 iOS `EpisodeRow` + Web 分集菜单）：
/// 16:9 剧照缩略图 + 集号标题 + 时长/评分 + 单集简介 + 桌面右键/触屏长按/右侧 `⋯` 分集菜单
/// （支持单集标为已看/未看、单集离线缓存、单集 AI 生成字幕）。
class EpisodeList extends StatelessWidget {
  const EpisodeList({
    super.key,
    required this.episodes,
    required this.onEpisodeTap,
    this.onTogglePlayed,
    this.onDownloadEpisode,
    this.onSubtitleEpisode,
  });

  final List<EpisodeEntry> episodes;
  final void Function(EpisodeEntry episode) onEpisodeTap;
  final void Function(EpisodeEntry episode)? onTogglePlayed;
  final void Function(EpisodeEntry episode)? onDownloadEpisode;
  final void Function(EpisodeEntry episode)? onSubtitleEpisode;

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < episodes.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.only(
                left: McTokens.pagePadding + 144,
                right: McTokens.pagePadding,
              ),
              child: Divider(height: 1, color: McTokens.line),
            ),
          _EpisodeCard(
            episode: episodes[i],
            onTap: () => onEpisodeTap(episodes[i]),
            onTogglePlayed: onTogglePlayed == null
                ? null
                : () => onTogglePlayed!(episodes[i]),
            onDownload: onDownloadEpisode == null
                ? null
                : () => onDownloadEpisode!(episodes[i]),
            onSubtitle: onSubtitleEpisode == null
                ? null
                : () => onSubtitleEpisode!(episodes[i]),
          ),
        ],
      ],
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.onTap,
    this.onTogglePlayed,
    this.onDownload,
    this.onSubtitle,
  });

  final EpisodeEntry episode;
  final VoidCallback onTap;
  final VoidCallback? onTogglePlayed;
  final VoidCallback? onDownload;
  final VoidCallback? onSubtitle;

  List<McPosterMenuAction> _actions() => [
        if (episode.owned)
          McPosterMenuAction(
            icon: McIcons.play2Fill,
            label: '立即播放本集',
            onTap: onTap,
          ),
        if (onTogglePlayed != null)
          McPosterMenuAction(
            icon: episode.played
                ? McIcons.eyeClosedFill
                : McIcons.checkCircleFill,
            label: episode.played ? '标为未看' : '标为已看',
            onTap: onTogglePlayed!,
          ),
        if (episode.owned && onDownload != null)
          McPosterMenuAction(
            icon: McIcons.downloadCloudOut,
            label: '离线缓存本集',
            onTap: onDownload!,
          ),
        if (episode.owned && onSubtitle != null)
          McPosterMenuAction(
            icon: McIcons.closedCaptioning,
            label: 'AI 生成本集字幕…',
            onTap: onSubtitle!,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final totalMs = (episode.runtimeMinutes ?? 0) * 60000;
    final progress = (episode.resumeMs > 0 && totalMs > 0)
        ? (episode.resumeMs / totalMs).clamp(0.02, 1.0)
        : null;
    final epPrefix =
        'E${episode.episodeNumber.toString().padLeft(2, '0')}';
    final fullTitle =
        episode.name.isEmpty ? epPrefix : '$epPrefix · ${episode.name}';

    final metaParts = <String>[
      if (episode.airDate != null && episode.airDate!.isNotEmpty)
        episode.airDate!,
      if (episode.runtimeMinutes != null && episode.runtimeMinutes! > 0)
        '${episode.runtimeMinutes} 分钟',
    ];
    final actions = _actions();

    return Opacity(
      opacity: episode.owned ? 1.0 : 0.48,
      child: McFocusRing(
        borderRadius: 12,
        child: McPressable(
          onTap: onTap,
          scaleDown: 0.985,
          onSecondaryTapUp: actions.isEmpty
              ? null
              : (d) => showMcContextActions(
                    context: context,
                    title: fullTitle,
                    actions: actions,
                    globalPosition: d.globalPosition,
                  ),
          onLongPress: actions.isEmpty
              ? null
              : () => showMcContextActions(
                    context: context,
                    title: fullTitle,
                    actions: actions,
                  ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
              vertical: 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 132,
                  height: 74,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: McTokens.line, width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      McArtwork(
                        url: episode.stillUrl,
                        frameAspect: 16 / 9,
                        widthPx: 360,
                        placeholderIcon: McIcons.tv,
                      ),
                      if (episode.owned)
                        Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0x78000000),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0x42FFFFFF),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              McIcons.play2Fill,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (episode.played)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: McTokens.ok,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              McIcons.check,
                              size: 11,
                              color: McTokens.onAccent,
                            ),
                          ),
                        ),
                      if (progress != null)
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 2.5,
                              backgroundColor: const Color(0x47FFFFFF),
                              valueColor: const AlwaysStoppedAnimation(
                                McTokens.accentStrong,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: McText.sub
                            .copyWith(
                              color: McTokens.text,
                              fontWeight: FontWeight.w600,
                            )
                            .tabular,
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          if (!episode.owned)
                            Text(
                              '● 缺失文件',
                              style: McText.micro.copyWith(
                                color: McTokens.warning,
                              ),
                            ),
                          if (metaParts.isNotEmpty)
                            Text(
                              metaParts.join(' · '),
                              style: McText.caption.faint.tabular,
                            ),
                          if (episode.rating != null && episode.rating! > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  McIcons.star2Fill,
                                  size: 11,
                                  color: McTokens.warning,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  episode.rating!.toStringAsFixed(1),
                                  style: McText.caption.faint.tabular,
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (episode.overview != null &&
                          episode.overview!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          episode.overview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: McText.caption.muted,
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions.isNotEmpty)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => showMcContextActions(
                      context: context,
                      title: fullTitle,
                      actions: actions,
                      globalPosition: d.globalPosition,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(6, 2, 2, 6),
                      child: Icon(
                        McIcons.more,
                        size: 17,
                        color: McTokens.textFaint,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
