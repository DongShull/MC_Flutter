import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../state/activity_derive.dart';
import '../state/models.dart';

/// 活动页复用小组件（统一银玻璃设计令牌）。
class ActivityProgressBar extends StatelessWidget {
  const ActivityProgressBar({super.key, this.progress, this.label});

  final double? progress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress?.clamp(0.0, 1.0),
            minHeight: 3,
            color: McTokens.accentStrong,
            backgroundColor: const Color(0x26FFFFFF),
          ),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label!, style: McText.caption.muted),
        ],
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.text, this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: McText.caption.copyWith(
          color: danger ? McTokens.danger : McTokens.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ActivitySummaryBar extends StatelessWidget {
  const ActivitySummaryBar({
    super.key,
    required this.activity,
    required this.onDismissAll,
  });

  final TaskActivity activity;
  final Future<void> Function() onDismissAll;

  @override
  Widget build(BuildContext context) {
    final attention = activity.attentionTotal;
    final active = activity.activeTotal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            attention > 0
                ? '需要处理 $attention 项 · 进行中 $active 项'
                : '一切正常 · 进行中 $active 项',
            style: McText.caption.muted.tabular,
          ),
          const Spacer(),
          if (attention > 0)
            McPressable(
              onTap: onDismissAll,
              child: Text(
                '全部忽略',
                style: McText.caption.copyWith(color: McTokens.accent),
              ),
            ),
        ],
      ),
    );
  }
}

class DownloadGroupCard extends StatelessWidget {
  const DownloadGroupCard({
    super.key,
    required this.group,
    required this.ingestJobs,
    required this.onReplace,
    required this.onDelete,
  });

  final DownloadGroup group;
  final Map<String, JobView> ingestJobs;
  final Future<void> Function(DownloadTask) onReplace;
  final Future<void> Function(DownloadTask) onDelete;

  String _stateLabel(DownloadTask task, JobView? ingestJob) {
    if (ingestJob != null && ingestOwnsTaskState(task, ingestJob)) {
      return ingestJob.status == 'failed' ? '入库失败' : activeJobStatus(ingestJob);
    }
    return switch (task.state) {
      'grabbing' => '寻找资源',
      'downloading' => '下载中',
      'completed' => '已下载',
      'error' => '下载出错',
      'missing' => '文件缺失',
      _ => task.state,
    };
  }

  @override
  Widget build(BuildContext context) {
    final resolved = McImageUrls.resolve(group.posterUrl, widthPx: 140);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: resolved.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: resolved,
                        httpHeaders: mcImageHeaders(),
                        width: 44,
                        height: 64,
                        fit: BoxFit.cover,
                      )
                    : const SizedBox(
                        width: 44,
                        height: 64,
                        child: ColoredBox(color: McTokens.posterPlaceholder),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: McText.titleSm,
                    ),
                    if (group.kind != null)
                      Text(
                        group.kind == 'tv' ? '剧集' : '电影',
                        style: McText.caption.muted,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final task in group.tasks) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: McTokens.line),
            ),
            Text(
              task.name ?? task.infoHash,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.caption,
            ),
            const SizedBox(height: 6),
            ActivityProgressBar(
              progress: task.progress,
              label: _stateLabel(task, ingestJobs[task.infoHash.toLowerCase()]),
            ),
            if (task.landingError != null && task.landingError!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '落点核验失败：${task.landingError}',
                  style: McText.caption.copyWith(color: McTokens.danger),
                ),
              ),
            if (task.contentMissingLabel() != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '内容核验缺失 ${task.contentMissingLabel()}',
                  style: McText.caption.copyWith(color: McTokens.danger),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (task.canReplace)
                  McActionPill(
                    label: '换种',
                    primary: false,
                    height: 34,
                    onTap: () => onReplace(task),
                  ),
                McActionPill(
                  label: '删除任务',
                  primary: false,
                  tone: McGlassTone.danger,
                  height: 34,
                  onTap: () => onDelete(task),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.job,
    this.historical = false,
    this.onCancel,
    this.onRetry,
    this.onDismiss,
    this.onUndismiss,
  });

  final JobView job;
  final bool historical;
  final Future<void> Function()? onCancel;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onDismiss;
  final Future<void> Function()? onUndismiss;

  @override
  Widget build(BuildContext context) {
    final title = historical ? historicalJobTitle(job) : jobTypeLabel(job);
    final subtitle =
        historical ? historicalJobSummary(job) : job.progress.message;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: McText.sub.copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                ],
                if (!historical) ...[
                  const SizedBox(height: 6),
                  ActivityProgressBar(
                    progress: job.progress.percent,
                    label: activeJobStatus(job),
                  ),
                ],
              ],
            ),
          ),
          if (!historical && onCancel != null)
            McGlassIconButton(
              icon: McIcons.close,
              size: 32,
              iconSize: 15,
              tooltip: '取消',
              onTap: onCancel,
            ),
        ],
      ),
    );
  }
}

class PlaybackSessionCard extends StatelessWidget {
  const PlaybackSessionCard({
    super.key,
    required this.session,
    required this.onEnd,
  });

  final ActivePlaybackSession session;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    final media = session.media;
    final position = session.positionMs;
    final duration = session.durationMs;
    final progress = (position != null && duration != null && duration > 0)
        ? position / duration
        : null;
    final who = session.memberName.isNotEmpty
        ? session.memberName
        : session.client;
    final episode = media.seasonNumber > 0
        ? ' ${mcEpisodeLabel(media.seasonNumber, media.episodeNumber)}'
        : '';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      child: Row(
        children: [
          const Icon(McIcons.playCircle, color: McTokens.ok),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.title + episode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.sub.copyWith(color: McTokens.text),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (who.isNotEmpty) who,
                    if (session.deviceName.isNotEmpty) session.deviceName,
                    session.paused ? '已暂停' : '正在播放',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 6),
                ActivityProgressBar(progress: progress),
              ],
            ),
          ),
          const SizedBox(width: 8),
          McActionPill(
            label: '结束',
            primary: false,
            tone: McGlassTone.danger,
            height: 32,
            onTap: onEnd,
          ),
        ],
      ),
    );
  }
}

class FileDownloadCard extends StatelessWidget {
  const FileDownloadCard({super.key, required this.download});

  final ActiveFileDownload download;

  @override
  Widget build(BuildContext context) {
    final media = download.media;
    final who = download.memberName.isNotEmpty
        ? download.memberName
        : download.deviceName;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      child: Row(
        children: [
          const Icon(McIcons.downloadCloudOut, color: McTokens.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media?.title ?? download.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.sub.copyWith(color: McTokens.text),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (who.isNotEmpty) who,
                    mcFormatBytes(download.sizeBytes),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.muted.tabular,
                ),
                const SizedBox(height: 6),
                ActivityProgressBar(
                  progress: download.progressPercent == null
                      ? null
                      : download.progressPercent! / 100,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryTile extends StatelessWidget {
  const HistoryTile({super.key, required this.entry});

  final PlaybackLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final media = entry.media;
    final episode = media.seasonNumber > 0
        ? ' S${media.seasonNumber.toString().padLeft(2, '0')}E${media.episodeNumber.toString().padLeft(2, '0')}'
        : '';
    final libraryId = media.libraryId;
    return McInsetRow(
      icon: entry.completed ? McIcons.checkCircleFill : McIcons.history1,
      iconColor: entry.completed ? McTokens.ok : McTokens.textMuted,
      title: media.title + episode,
      subtitle: [
        if (entry.memberName.isNotEmpty) entry.memberName,
        mcFormatWatched(entry.watchedMs),
      ].where((s) => s.isNotEmpty).join(' · '),
      onTap: libraryId == null
          ? null
          : () => context.push('/detail/$libraryId/${media.mediaItemId}'),
    );
  }
}
