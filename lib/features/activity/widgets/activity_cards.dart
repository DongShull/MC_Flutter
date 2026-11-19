import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/format.dart';

import '../state/activity_derive.dart';
import '../state/models.dart';

/// 活动页共用小部件：摘要行、分区标签、任务卡、下载组卡、播放会话卡等
/// （对齐 ActivityScreen.kt 的卡片体系，Android 用 Compose，这里用 Material）。

/// 一条进度条 + 可选的 current/total 文案。
class ActivityProgressBar extends StatelessWidget {
  const ActivityProgressBar({super.key, this.progress, this.label});

  final double? progress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress?.clamp(0.0, 1.0),
            minHeight: 4,
          ),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// 分区标签（需要处理 N / 正在进行 N / 已结束）。
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
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: danger ? const Color(0xFFE5615B) : null,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// 顶部摘要行（对齐 ActivityScreen.kt 的 summary line）。
class ActivitySummaryBar extends StatelessWidget {
  const ActivitySummaryBar({super.key, required this.activity, required this.onDismissAll});

  final TaskActivity activity;
  final Future<void> Function() onDismissAll;

  @override
  Widget build(BuildContext context) {
    final attention = activity.attentionTotal;
    final active = activity.activeTotal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            attention > 0 ? '需要处理 $attention 项 · 进行中 $active 项' : '一切正常，进行中 $active 项',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          if (attention > 0)
            TextButton(
              onPressed: onDismissAll,
              child: const Text('全部忽略'),
            ),
        ],
      ),
    );
  }
}

/// 下载组卡：海报缩略 + 标题 + 每个种子的状态行 + 需要处理时的操作
/// （重试/换种/删除，对齐 ActiveDownloadRow / DeviceDownloadRow / GroupCard）。
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
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: group.posterUrl != null
                      ? Image.network(group.posterUrl!, width: 44, height: 62, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                              width: 44, height: 62, child: ColoredBox(color: Color(0x22FFFFFF))),
                        )
                      : const SizedBox(
                          width: 44, height: 62, child: ColoredBox(color: Color(0x22FFFFFF))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall),
                      if (group.kind != null)
                        Text(
                          group.kind == 'tv' ? '剧集' : '电影',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final task in group.tasks) ...[
              const Divider(height: 16),
              Text(task.name ?? task.infoHash,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              ActivityProgressBar(
                progress: task.progress,
                label: _stateLabel(task, ingestJobs[task.infoHash.toLowerCase()]),
              ),
              if (task.landingError != null && task.landingError!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('落点核验失败：${task.landingError}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFFE5615B))),
                ),
              if (task.contentMissingLabel() != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('内容核验缺失 ${task.contentMissingLabel()}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFFE5615B))),
                ),
              Wrap(
                spacing: 8,
                children: [
                  if (task.canReplace)
                    TextButton(
                      onPressed: () => onReplace(task),
                      child: const Text('换种'),
                    ),
                  TextButton(
                    onPressed: () => onDelete(task),
                    child: const Text('删除任务'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 后台任务卡（对齐 JobCard / AttentionCard）。
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
    final subtitle = historical ? historicalJobSummary(job) : job.progress.message;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty) Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (!historical) ...[
              const SizedBox(height: 6),
              ActivityProgressBar(progress: job.progress.percent, label: activeJobStatus(job)),
            ],
          ],
        ),
        trailing: historical || onCancel == null
            ? null
            : IconButton(
                tooltip: '取消',
                icon: const Icon(Icons.close),
                onPressed: onCancel,
              ),
        isThreeLine: true,
        dense: true,
      ),
    );
  }
}

/// 一条正在播放的会话卡（对齐 PlaybackSessionCard）。
class PlaybackSessionCard extends StatelessWidget {
  const PlaybackSessionCard({super.key, required this.session, required this.onEnd});

  final ActivePlaybackSession session;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = session.media;
    final position = session.positionMs;
    final duration = session.durationMs;
    final progress = (position != null && duration != null && duration > 0)
        ? position / duration
        : null;
    final who = session.memberName.isNotEmpty ? session.memberName : session.client;
    final episode = media.seasonNumber > 0
        ? ' ${mcEpisodeLabel(media.seasonNumber, media.episodeNumber)}'
        : '';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: Text(media.title + episode, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (who.isNotEmpty) who,
                if (session.deviceName.isNotEmpty) session.deviceName,
                session.paused ? '已暂停' : '正在播放',
                if (session.rateBytesPerSecond != null && session.rateBytesPerSecond! > 0)
                  '${mcFormatBytes(session.rateBytesPerSecond!.round())}/s',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            ActivityProgressBar(progress: progress),
          ],
        ),
        trailing: TextButton(onPressed: onEnd, child: const Text('结束')),
        isThreeLine: true,
        dense: true,
      ),
    );
  }
}

/// 设备整文件下载卡（对齐 DeviceDownloadRow）。
class FileDownloadCard extends StatelessWidget {
  const FileDownloadCard({super.key, required this.download});

  final ActiveFileDownload download;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = download.media;
    final who = download.memberName.isNotEmpty ? download.memberName : download.deviceName;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.file_download_outlined),
        title: Text(media?.title ?? download.fileName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (who.isNotEmpty) who,
                mcFormatBytes(download.sizeBytes),
                if (download.rateBytesPerSecond != null && download.rateBytesPerSecond! > 0)
                  '${mcFormatBytes(download.rateBytesPerSecond!.round())}/s',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            ActivityProgressBar(
              progress: download.progressPercent == null ? null : download.progressPercent! / 100,
            ),
          ],
        ),
        isThreeLine: true,
        dense: true,
      ),
    );
  }
}

/// 一条历史播放行（最近播放流水，点标题跳详情深链）。
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
    return ListTile(
      dense: true,
      leading: Icon(entry.completed ? Icons.check_circle_outline : Icons.history,
          size: 20),
      title: Text(media.title + episode, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (entry.memberName.isNotEmpty) entry.memberName,
          mcFormatWatched(entry.watchedMs),
          if (entry.startedAt.isNotEmpty)
            DateTime.tryParse(entry.startedAt)?.toLocal().toString().substring(0, 16) ?? '',
        ].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: libraryId == null
          ? null
          : () => context.push('/detail/$libraryId/${media.mediaItemId}'),
    );
  }
}
