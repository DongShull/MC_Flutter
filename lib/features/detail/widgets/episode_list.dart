import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';

/// 分集列表（对齐 iOS `EpisodeRow`：16:9 剧照缩略图 + 集号标题 + 时长/评分 + 单集简介）。
/// 点击分集触发起播导航意图；缺文件条目自动降暗并提示。
class EpisodeList extends StatelessWidget {
  const EpisodeList({
    super.key,
    required this.episodes,
    required this.onEpisodeTap,
  });

  final List<EpisodeEntry> episodes;
  final void Function(EpisodeEntry episode) onEpisodeTap;

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
          ),
        ],
      ],
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.episode, required this.onTap});

  final EpisodeEntry episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final totalMs = (episode.runtimeMinutes ?? 0) * 60000;
    final progress = (episode.resumeMs > 0 && totalMs > 0)
        ? (episode.resumeMs / totalMs).clamp(0.02, 1.0)
        : null;
    final epPrefix =
        'E${episode.episodeNumber.toString().padLeft(2, '0')}';

    final metaParts = <String>[
      if (episode.airDate != null && episode.airDate!.isNotEmpty)
        episode.airDate!,
      if (episode.runtimeMinutes != null && episode.runtimeMinutes! > 0)
        '${episode.runtimeMinutes} 分钟',
    ];

    return Opacity(
      opacity: episode.owned ? 1.0 : 0.48,
      child: McFocusRing(
        borderRadius: 12,
        child: McPressable(
          onTap: onTap,
          scaleDown: 0.985,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
              vertical: 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 16:9 剧照卡（锁比模糊铺底 + 1px 描边 + 播放微标 + 已看绿勾 + 贴底银白进度条）
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
                        episode.name.isEmpty
                            ? epPrefix
                            : '$epPrefix · ${episode.name}',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
