import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/models.dart';

/// 订阅卡片（对齐 SubCard 126×189：海报 + 状态胶囊 + 底部进度线 + 标题 + meta）。
class SubCard extends StatelessWidget {
  const SubCard({super.key, required this.sub, this.onTap});

  final SubscriptionView sub;
  final VoidCallback? onTap;

  String get _meta {
    if (sub.media.kind == 'movie') return '${sub.media.year ?? ''}';
    final seasons = sub.seasonCollection;
    if (seasons.isEmpty) {
      return sub.status == 'completed' ? '${sub.media.year ?? ''}' : '仅追新集';
    }
    final owned = sub.progress.imported;
    final total = sub.progress.total;
    final season = sub.selectedSeasons.isNotEmpty
        ? sub.selectedSeasons.last
        : seasons.last.seasonNumber;
    return '第 $season 季 · $owned/$total';
  }

  @override
  Widget build(BuildContext context) {
    final label = subscriptionStatusLabel(sub);
    final color = subscriptionStatusColor(sub);
    final p = sub.progress;
    final doneRatio =
        p.total > 0 ? (p.imported / p.total).clamp(0.0, 1.0) : 0.0;

    return McFocusRing(
      borderRadius: McTokens.posterRadius,
      child: McPressable(
        onTap: onTap,
        child: SizedBox(
          width: 126,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(McTokens.posterRadius),
                        child: sub.media.posterUrl != null
                            ? CachedNetworkImage(
                                httpHeaders: mcImageHeaders(),
                                imageUrl:
                                    McImageUrls.resolve(sub.media.posterUrl),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const ColoredBox(
                                  color: McTokens.posterPlaceholder,
                                ),
                              )
                            : const ColoredBox(
                                color: McTokens.posterPlaceholder,
                              ),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius:
                              BorderRadius.circular(McTokens.pillRadius),
                          border: Border.all(color: McTokens.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(label, style: McText.micro),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(McTokens.posterRadius),
                        ),
                        child: LinearProgressIndicator(
                          value: doneRatio > 0 ? doneRatio : null,
                          minHeight: 3,
                          backgroundColor: const Color(0x73000000),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sub.media.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.posterTitle,
              ),
              const SizedBox(height: 2),
              Text(
                '$_meta · ${subscriptionProgressNote(sub)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.micro.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
