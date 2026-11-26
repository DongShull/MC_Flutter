import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/detail_controller.dart';

/// 在播档期横幅（对齐 iOS / Android `AirSchedule`）。
class AirSchedule extends StatelessWidget {
  const AirSchedule({super.key, required this.schedule});

  final AirScheduleBanner schedule;

  @override
  Widget build(BuildContext context) {
    final text = schedule.text;
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: McTokens.pagePadding,
        vertical: 6,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: McTokens.line, width: 1),
        ),
        child: Row(
          children: [
            const Icon(McIcons.clockFill, size: 15, color: McTokens.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.caption.copyWith(color: McTokens.text).tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
