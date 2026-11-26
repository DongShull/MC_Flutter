import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../state/models.dart';
import '../state/offline_state.dart';

/// 下载中单元行（1:1 对齐 Kotlin DownloadingRow）：
/// 海报 + 片名 + 季集 · 档位 + 状态文本 + 速度 + 4dp 进度条；长按弹毛玻璃菜单。
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
    final done = unit.status == OfflineUnitStatus.done;
    return McPressable(
      onTap: () => _showMenu(context),
      onLongPress: () => _showMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(McTokens.radiusSm),
              child: SizedBox(
                width: 60,
                height: 90,
                child: poster ??
                    const ColoredBox(
                      color: McTokens.posterPlaceholder,
                      child: Icon(McIcons.movie, color: McTokens.textFaint),
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.ui.semibold,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (unit.seasonEpisode != null) unit.seasonEpisode!,
                      unit.profileLabel,
                    ].join(' · '),
                    style: McText.caption.muted,
                  ),
                  if (!done) ...[
                    const SizedBox(height: 2),
                    Text(
                      "${unit.status.text()}${unit.status == OfflineUnitStatus.running ? ' · ${mcFormatSpeed(unit.speedBps)}' : ''}",
                      style: McText.caption.muted,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: unit.progress <= 0 ? null : unit.progress,
                        minHeight: 4,
                        color: McTokens.accentStrong,
                        backgroundColor: McTokens.surfaceInset,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 2),
                    Text(
                      '已下载',
                      style: McText.caption.copyWith(color: McTokens.ok),
                    ),
                  ],
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
    showMcSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: unit.title,
          margin: EdgeInsets.zero,
          children: [
            McInsetRow(
              icon: McIcons.arrowUpCircle,
              title: '优先下载',
              onTap: () {
                Navigator.of(sheetContext).pop();
                onPrioritize();
              },
            ),
            McInsetRow(
              icon: unit.status == OfflineUnitStatus.running
                  ? McIcons.pause
                  : McIcons.play2Fill,
              title:
                  unit.status == OfflineUnitStatus.running ? '暂停' : '继续',
              onTap: () {
                Navigator.of(sheetContext).pop();
                onPauseResume();
              },
            ),
            McInsetRow(
              icon: McIcons.close2,
              title: '取消下载',
              destructive: true,
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
    const reserve = OfflineController.reserveBytes;
    final availGb = ((info.availableBytes - reserve) / (1024 * 1024 * 1024))
        .toStringAsFixed(1);
    final totalGb = ((info.totalBytes - reserve) / (1024 * 1024 * 1024))
        .toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                McIcons.databaseFill,
                size: 17,
                color: McTokens.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                '可用 $availGb GB / 共 $totalGb GB',
                style: McText.caption.muted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: info.usedRatio.clamp(0.0, 1.0),
              minHeight: 5,
              color: McTokens.accentStrong,
              backgroundColor: McTokens.surfaceInset,
            ),
          ),
        ],
      ),
    );
  }
}
