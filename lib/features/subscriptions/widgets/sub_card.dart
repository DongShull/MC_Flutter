import '../../../core/image/image_urls.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/adaptive.dart';
import '../state/models.dart';

/// 订阅卡片（对齐 SubCard 126×189：海报 + 状态小签 + 底部进度线 + 标题 + meta）。
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

    // TV 形态包焦点环；非 TV 原样返回 child，零开销。
    return McFocusRing(
      borderRadius: 10,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
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
                        borderRadius: BorderRadius.circular(10),
                        child: sub.media.posterUrl != null
                            ? CachedNetworkImage(
                                httpHeaders: mcImageHeaders(),
                                imageUrl:
                                    McImageUrls.resolve(sub.media.posterUrl),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    Container(color: Colors.white10),
                              )
                            : Container(color: Colors.white10),
                      ),
                    ),
                    // 状态小签：黑 38% 胶囊 + 色点 + 文字
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(label,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    // 底部进度线
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(10)),
                        child: LinearProgressIndicator(
                          value: doneRatio > 0 ? doneRatio : null,
                          minHeight: 3,
                          backgroundColor: Colors.black45,
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
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '$_meta · ${subscriptionProgressNote(sub)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10, color: Colors.white.withValues(alpha: 0.55)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
