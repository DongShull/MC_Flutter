import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';

/// 缺集区间提示（连续分集号之间有空洞时列出缺集区间）。
List<String> missingRanges(List<EpisodeEntry> episodes) {
  final numbers = episodes
      .map((e) => e.episodeNumber)
      .where((n) => n > 0)
      .toList()
    ..sort();
  if (numbers.length < 2) return const [];
  final ranges = <String>[];
  for (var i = 1; i < numbers.length; i++) {
    final gapStart = numbers[i - 1] + 1;
    final gapEnd = numbers[i] - 1;
    if (gapEnd >= gapStart) {
      ranges.add(
        gapStart == gapEnd ? '缺 $gapStart 集' : '缺 $gapStart-$gapEnd 集',
      );
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        6,
        McTokens.pagePadding,
        4,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x1AF5C451),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x40F5C451), width: 1),
        ),
        child: Row(
          children: [
            const Icon(McIcons.alert1, size: 15, color: McTokens.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ranges.join('、'),
                style: McText.caption
                    .copyWith(color: McTokens.warning)
                    .tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
