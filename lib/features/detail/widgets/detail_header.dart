import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';

/// 头部：backdrop 模糊底 + poster + 标题 / 年份 / 元信息行 + 评分 + tagline
/// （对齐 ItemDetailScreen.kt 的头部区）。
class DetailHeader extends StatelessWidget {
  const DetailHeader({super.key, required this.entry, this.onBack});

  final DetailEntry entry;
  final VoidCallback? onBack;

  String get _metaLine {
    final parts = <String>[
      if (entry.year != null) entry.year.toString(),
      if (entry.runtimeMinutes != null && entry.runtimeMinutes! > 0)
        entry.runtimeMinutes! >= 60
            ? '${entry.runtimeMinutes! ~/ 60}h${(entry.runtimeMinutes! % 60).toString().padLeft(2, '0')}'
            : '${entry.runtimeMinutes} 分钟',
      if (entry.resolution != null && entry.resolution!.isNotEmpty) entry.resolution!,
      if (entry.hdr) 'HDR',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      children: [
        // backdrop 模糊底
        if (entry.backdropUrl != null)
          Positioned.fill(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: CachedNetworkImage(
                  imageUrl: entry.backdropUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  McColors.bgDark.withValues(alpha: 0.45),
                  McColors.bgDark.withValues(alpha: 0.92),
                  McColors.bgDark,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BackButton(onPressed: onBack),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // poster
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: entry.posterUrl != null
                          ? CachedNetworkImage(
                              imageUrl: entry.posterUrl!,
                              width: 120,
                              height: 180,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 120,
                                height: 180,
                                color: McColors.surfaceDark,
                              ),
                            )
                          : Container(
                              width: 120,
                              height: 180,
                              color: McColors.surfaceDark,
                              child: const Icon(Icons.movie_outlined, size: 40),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_metaLine.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              _metaLine,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                          if (entry.officialRating != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.white38),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.officialRating!,
                                style: textTheme.labelSmall,
                              ),
                            ),
                          ],
                          if (entry.rating != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  entry.rating!.toStringAsFixed(1),
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                          if (entry.tagline != null &&
                              entry.tagline!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              entry.tagline!,
                              style: textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white60),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
