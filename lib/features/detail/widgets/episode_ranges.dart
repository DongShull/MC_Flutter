import 'package:flutter/material.dart';

import '../state/detail_controller.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 缺集区间提示（对齐 EpisodeRanges.kt：连续分集号之间有空洞时列出缺集区间）。
/// 返回形如 "缺 4-6" 的区间文案列表。
List<String> missingRanges(List<EpisodeEntry> episodes) {
  final numbers = episodes.map((e) => e.episodeNumber).where((n) => n > 0).toList()..sort();
  if (numbers.length < 2) return const [];
  final ranges = <String>[];
  for (var i = 1; i < numbers.length; i++) {
    final gapStart = numbers[i - 1] + 1;
    final gapEnd = numbers[i] - 1;
    if (gapEnd >= gapStart) {
      ranges.add(gapStart == gapEnd ? '缺 $gapStart 集' : '缺 $gapStart-$gapEnd 集');
    }
  }
  return ranges;
}

class EpisodeRanges extends StatelessWidget {
  const EpisodeRanges({super.key, required this.episodes});

  final List<EpisodeEntry> episodes;

  @override
  Widget build(BuildContext context) {
    final ranges = missingRanges(episodes);
    if (ranges.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(McIcons.alert,
              size: 16, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              ranges.join('、'),
              style: textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
