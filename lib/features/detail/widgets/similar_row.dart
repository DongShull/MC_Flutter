import 'package:flutter/material.dart';

import '../../../core/designsystem/poster_card.dart';
import '../state/detail_controller.dart';

/// 横滚海报行：系列一行 / 相似推荐一行。
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final e = entries[i];
              return McPosterCard(
                title: e.title,
                posterUrl: e.posterUrl,
                width: 104,
                radius: 10,
                onTap: () => onTap(e),
              );
            },
          ),
        ),
      ],
    );
  }
}
