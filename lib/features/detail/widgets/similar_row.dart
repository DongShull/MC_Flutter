import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';

/// 详情页同系列 / 相似推荐海报横滑行（统一 `McSectionHeader` + `McPosterCard` 12dp 圆角）。
class SimilarRow extends StatelessWidget {
  const SimilarRow({
    super.key,
    required this.title,
    required this.entries,
    required this.onTap,
  });

  final String title;
  final List<DetailEntry> entries;
  final ValueChanged<DetailEntry> onTap;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        McSectionHeader(title: title),
        const SizedBox(height: 12),
        SizedBox(
          height: 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
            ),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final e = entries[i];
              return McPosterCard(
                title: e.title,
                subtitle: e.year?.toString(),
                posterUrl: e.posterUrl,
                rating: e.rating,
                width: 112,
                onTap: () => onTap(e),
              );
            },
          ),
        ),
      ],
    );
  }
}
