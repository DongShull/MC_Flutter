import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../state/detail_controller.dart';

/// 分集列表（media_episode：名称 / 简介 / 播出日 / 时长 / 评分 / still 缩略图）。
/// 点击分集 = 播放导航意图，不自己播视频（跳 player 路由，见 DetailPage）。
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
    return Column(
      children: [
        for (final e in episodes)
          InkWell(
            onTap: () => onEpisodeTap(e),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // still 缩略图
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: e.stillUrl != null
                        ? CachedNetworkImage(
                            imageUrl: e.stillUrl!,
                            width: 110,
                            height: 62,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _stillFallback(context),
                          )
                        : _stillFallback(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '第 ${e.episodeNumber} 集',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Colors.white54),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.name,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (e.played)
                              const Icon(Icons.check_circle_outline,
                                  size: 16, color: Colors.green),
                          ],
                        ),
                        if (e.airDate != null || e.runtimeMinutes != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (e.airDate != null) e.airDate!,
                              if (e.runtimeMinutes != null && e.runtimeMinutes! > 0)
                                '${e.runtimeMinutes} 分钟',
                            ].join(' · '),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: Colors.white38),
                          ),
                        ],
                        if (e.overview != null && e.overview!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            e.overview!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white60),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (e.rating != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 14, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                e.rating!.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _stillFallback(BuildContext context) => Container(
        width: 110,
        height: 62,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.tv_outlined, size: 22),
      );
}
