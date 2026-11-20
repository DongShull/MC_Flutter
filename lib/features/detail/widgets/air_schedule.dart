import 'package:flutter/material.dart';

import '../state/detail_controller.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 在播档期横幅（对齐 AirSchedule.kt：只有「每周 x · 时间 · 下集 / 下次播出」时显示）。
class AirSchedule extends StatelessWidget {
  const AirSchedule({super.key, required this.schedule});

  final AirScheduleBanner schedule;

  @override
  Widget build(BuildContext context) {
    final text = schedule.text;
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(McIcons.clockFill, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
