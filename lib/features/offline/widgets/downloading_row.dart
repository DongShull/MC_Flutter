import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../state/models.dart';
import '../state/offline_packager.dart';
import '../state/offline_state.dart';

/// 离线条目海报微缩图（优先读取 `OfflineImages` 本地缓存文件，无网时也能完整显示，在线缺失再回落网络图）。
class OfflineArtworkImage extends StatelessWidget {
  const OfflineArtworkImage({
    super.key,
    this.rawUrl,
    this.widthPx = 240,
    this.fit = BoxFit.cover,
    this.placeholderIcon = McIcons.movie,
  });

  final String? rawUrl;
  final int widthPx;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final fullUrl = McImageUrls.build(rawUrl, widthPx: widthPx) ?? rawUrl;
    final localFile = OfflineImages.shared.localFileFor(fullUrl) ??
        OfflineImages.shared.localFileFor(rawUrl);
    if (localFile != null) {
      return Image.file(
        localFile,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (fullUrl != null && fullUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: fullUrl,
        httpHeaders: mcImageHeaders(),
        fit: fit,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => ColoredBox(
        color: McTokens.posterPlaceholder,
        child: Center(
          child: Icon(placeholderIcon, color: McTokens.textFaint, size: 22),
        ),
      );
}

/// 下载中单元行（对齐 iOS OfflineDownloadingStorageRow）：
/// 本地/缓存海报 + 片名 + 季集 · 档位 + 状态文本（排队位置/转码排队/速度/百分比）+ 进度条；长按/点按弹菜单。
class DownloadingRow extends StatelessWidget {
  const DownloadingRow({
    super.key,
    required this.unit,
    required this.onPauseResume,
    required this.onCancel,
    required this.onPrioritize,
    this.onDelete,
    this.poster,
    this.queueAhead = 0,
    this.waitingForWifi = false,
    this.canPrioritize = true,
  });

  final DownloadUnit unit;
  final VoidCallback onPauseResume;
  final VoidCallback onCancel;
  final VoidCallback onPrioritize;
  final VoidCallback? onDelete;
  final Widget? poster;
  final int queueAhead;
  final bool waitingForWifi;
  final bool canPrioritize;

  @override
  Widget build(BuildContext context) {
    final done = unit.status == OfflineUnitStatus.done;
    final tint = unit.needsAttention ? McTokens.warning : McTokens.accentStrong;
    final statusText = unit.status.text(
      ahead: queueAhead,
      waitingForWifi: waitingForWifi,
      transcodeWait: unit.transcodeWait,
      progress: unit.progressFraction,
      receivedBytes: unit.receivedBytes,
      expectedBytes: unit.effectiveTotalBytes,
      error: unit.error,
      retryable: unit.retryable,
      damaged: unit.damaged,
    );
    final showSpeed = unit.status == OfflineUnitStatus.running &&
        !waitingForWifi &&
        unit.speedBps > 0;
    final artUrl = unit.posterUrl ?? unit.stillUrl ?? unit.backdropUrl;

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
                    OfflineArtworkImage(
                      rawUrl: artUrl,
                      widthPx: 160,
                      placeholderIcon:
                          unit.kind == 'tv' ? McIcons.tv : McIcons.movie,
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
                      if (unit.displaySeasonEpisode != null)
                        unit.displaySeasonEpisode!,
                      unit.profileLabel,
                    ].join(' · '),
                    style: McText.caption.muted,
                  ),
                  if (!done) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.caption.copyWith(color: tint),
                          ),
                        ),
                        if (showSpeed) ...[
                          const SizedBox(width: 6),
                          Text(
                            mcFormatSpeed(unit.speedBps),
                            style: McText.caption.muted.tabular,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (unit.status == OfflineUnitStatus.preparing ||
                                (unit.status == OfflineUnitStatus.running &&
                                    unit.progressFraction <= 0))
                            ? null
                            : unit.progressFraction,
                        minHeight: 4,
                        color: tint,
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
          header: unit.displaySeasonEpisode != null
              ? '${unit.title} · ${unit.displaySeasonEpisode}'
              : unit.title,
          margin: EdgeInsets.zero,
          children: [
            if (canPrioritize)
              McInsetRow(
                icon: McIcons.arrowUpCircle,
                title: '优先下载',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onPrioritize();
                },
              ),
            if (!unit.waitingForTranscode &&
                unit.status != OfflineUnitStatus.preparing)
              McInsetRow(
                icon: unit.status == OfflineUnitStatus.running
                    ? McIcons.pause
                    : McIcons.play2Fill,
                title: unit.status == OfflineUnitStatus.running
                    ? '暂停'
                    : (unit.status == OfflineUnitStatus.failed ? '重试' : '继续'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onPauseResume();
                },
              ),
            McInsetRow(
              icon: McIcons.close,
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
        .clamp(0.0, double.infinity)
        .toStringAsFixed(1);
    final totalGb = ((info.totalBytes - reserve) / (1024 * 1024 * 1024))
        .clamp(0.0, double.infinity)
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
