
import 'package:flutter/material.dart';

import '../../../core/models/format.dart';
import '../state/models.dart';
import '../state/offline_state.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 下载中单元行（1:1 对齐 Kotlin DownloadingRow）：
/// 海报 + 片名 + 季集 · 档位 + 状态文本 + 速度 + 4dp 进度条；长按弹菜单。
class DownloadingRow extends StatelessWidget {
  const DownloadingRow({
    super.key,
    required this.unit,
    required this.onPauseResume,
    required this.onCancel,
    required this.onPrioritize,
    this.onDelete,
    this.poster,
  });

  final DownloadUnit unit;
  final VoidCallback onPauseResume;
  final VoidCallback onCancel;
  final VoidCallback onPrioritize;
  final VoidCallback? onDelete;
  final Widget? poster;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = unit.status == OfflineUnitStatus.done;
    return InkWell(
      onLongPress: () => _showMenu(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 60,
                height: 90,
                child: poster ??
                    ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: const Icon(McIcons.movie),
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(unit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    [
                      if (unit.seasonEpisode != null) unit.seasonEpisode!,
                      unit.profileLabel,
                    ].join(' · '),
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  if (!done) ...[
                    Text(
                      "${unit.status.text()}${unit.status == OfflineUnitStatus.running ? ' · ${mcFormatSpeed(unit.speedBps)}' : ''}",
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: unit.progress <= 0 ? null : unit.progress,
                        minHeight: 4,
                      ),
                    ),
                  ] else
                    Text('已下载',
                        style: TextStyle(fontSize: 12, color: scheme.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    if (unit.status == OfflineUnitStatus.done) {
      onDelete?.call();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.low_priority),
              title: const Text('优先下载'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onPrioritize();
              },
            ),
            ListTile(
              leading: Icon(unit.status == OfflineUnitStatus.running
                  ? McIcons.pause
                  : McIcons.play2Fill),
              title:
                  Text(unit.status == OfflineUnitStatus.running ? '暂停' : '继续'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onPauseResume();
              },
            ),
            ListTile(
              leading: const Icon(McIcons.close2),
              title: const Text('取消下载'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onCancel();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 容量条（对齐 StorageCard）：可用 / 总量（扣掉 2GB 预留）。
class StorageCard extends StatelessWidget {
  const StorageCard({super.key, required this.info});

  final StorageInfo info;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const reserve = OfflineController.reserveBytes;
    final availGb =
        ((info.availableBytes - reserve) / (1024 * 1024 * 1024)).toStringAsFixed(1);
    final totalGb =
        ((info.totalBytes - reserve) / (1024 * 1024 * 1024)).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(McIcons.databaseFill, size: 18),
              const SizedBox(width: 8),
              Text(
                '可用 $availGb GB / 共 $totalGb GB',
                style:
                    TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: info.usedRatio.clamp(0.0, 1.0),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
