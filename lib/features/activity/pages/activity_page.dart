import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';

import '../state/activity_derive.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../widgets/watch_stats_panel.dart';

/// 活动中心（对齐 iOS ActivityView.dashboard 总览结构）：
/// 单页分区列表——摘要行 → 需要处理 → 正在播放 → 下载中 → 进行中 →
/// 最近播放 → 观看统计 → 最近完成。分区头「● 标题 数量 …… 查看全部」，
/// 行是「一眼能看懂的摘要」，完整操作收进行内按钮。
class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  bool _showAllFinished = false;

  ActivityController get _controller =>
      ref.read(activityControllerProvider.notifier);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(activityControllerProvider);
    final activity = deriveTaskActivity(snapshot.downloads, snapshot.jobs);
    final form = McFormWatch.of(context);
    final windowClass = mcWindowClassOf(form);
    final playback = snapshot.playback;
    final watching = playback?.sessions.length ?? 0;
    final historyTotal = activity.historyJobs.length;
    final downloading = playback?.downloads.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('活动中心'),
        actions: [
          McFocusRing(
            borderRadius: 24,
            child: IconButton(
              icon: const Icon(McIcons.refreshS),
              onPressed: () => _guard(_controller.refresh),
            ),
          ),
        ],
      ),
      body: snapshot.loading
          ? const McLoadingView()
          : RefreshIndicator(
              onRefresh: () => _guard(_controller.refresh),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: windowClass == McWindowClass.compact
                        ? double.infinity
                        : 720,
                  ),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // 摘要行：N 项需要处理 · M 台设备在播放 · ……；空态「一切正常」。
                      _SummaryLine(
                        attention: activity.attentionTotal,
                        watching: watching,
                        downloading: downloading,
                        active: activity.activeTotal,
                      ),
                      if (snapshot.error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: _WarningBanner(message: snapshot.error!),
                        ),
                      if (activity.attentionTotal > 0)
                        _Section(
                          header: _SectionHeader(
                            title: '需要处理',
                            count: activity.attentionTotal,
                            tint: _kDanger,
                            trailing: _hasFailed(activity)
                                ? ('全部清除', () => _guard(_controller.dismissAllJobs))
                                : null,
                          ),
                          rows: [
                            for (final group in activity.attentionGroups)
                              _ActiveDownloadRow(
                                group: group,
                                onDelete: group.tasks.length == 1 &&
                                        group.tasks.first.downloaderId != null
                                    ? () => _guard(() => _controller
                                        .deleteDownloadTask(group.tasks.first))
                                    : null,
                              ),
                            for (final job in activity.attentionJobs)
                              _ActiveJobRow(
                                job: job,
                                onCancel: () =>
                                    _guard(() => _controller.cancelJob(job.id)),
                                onDismiss: () =>
                                    _guard(() => _controller.dismissJob(job.id)),
                              ),
                          ],
                        ),
                      if (playback != null && playback.sessions.isNotEmpty)
                        _Section(
                          header: _SectionHeader(
                            title: '正在播放',
                            count: playback.sessions.length,
                            tint: _kSuccess,
                          ),
                          rows: [
                            for (final session in playback.sessions)
                              _SessionRow(
                                session: session,
                                onEnd: () => _guard(() => _controller
                                    .endPlaybackSession(session.deviceId)),
                              ),
                          ],
                        ),
                      if (playback != null && playback.downloads.isNotEmpty)
                        _Section(
                          header: _SectionHeader(
                            title: '下载中',
                            count: playback.downloads.length,
                          ),
                          rows: [
                            for (final download in playback.downloads)
                              _FileDownloadRow(download: download),
                          ],
                        ),
                      if (activity.activeTotal > 0)
                        _Section(
                          header: _SectionHeader(
                            title: '进行中',
                            count: activity.activeTotal,
                          ),
                          rows: [
                            for (final group in activity.activeGroups)
                              _ActiveDownloadRow(
                                group: group,
                                onDelete: group.tasks.length == 1 &&
                                        group.tasks.first.downloaderId != null
                                    ? () => _guard(() => _controller
                                        .deleteDownloadTask(group.tasks.first))
                                    : null,
                              ),
                            for (final job in activity.activeJobs)
                              _ActiveJobRow(
                                job: job,
                                onCancel: job.status == 'queued' ||
                                        job.status == 'running' ||
                                        job.status == 'retry_wait'
                                    ? () =>
                                        _guard(() => _controller.cancelJob(job.id))
                                    : null,
                              ),
                          ],
                        ),
                      if (!snapshot.historyForbidden &&
                          snapshot.history != null &&
                          snapshot.history!.entries.isNotEmpty)
                        _Section(
                          header: const _SectionHeader(title: '最近播放'),
                          rows: [
                            for (final entry
                                in snapshot.history!.entries.take(6))
                              _RecentPlayRow(entry: entry),
                          ],
                        ),
                      if (!snapshot.statsForbidden &&
                          snapshot.watchStats != null)
                        _Section(
                          header: const _SectionHeader(title: '观看统计'),
                          child: WatchStatsPanel(
                            stats: snapshot.watchStats!,
                            days: snapshot.watchStatsDays,
                            memberId: snapshot.watchStatsMemberId,
                            onDaysChanged: (d) =>
                                _guard(() => _controller.setWatchStatsDays(d)),
                            onMemberSelected: (id) =>
                                _guard(() => _controller.setWatchStatsMember(id)),
                          ),
                        ),
                      if (activity.historyJobs.isNotEmpty)
                        _Section(
                          header: _SectionHeader(
                            title: '最近完成',
                            count: activity.historyJobs.length,
                            trailing: _showAllFinished
                                ? null
                                : (
                                    '查看全部 $historyTotal',
                                    () => setState(
                                        () => _showAllFinished = true),
                                  ),
                          ),
                          rows: [
                            for (final job in _showAllFinished
                                ? activity.historyJobs
                                : activity.historyJobs.take(5))
                              _FinishedJobRow(
                                job: job,
                                onUndismiss: job.status == 'failed' &&
                                        jobIsDismissed(job)
                                    ? () =>
                                        _guard(() => _controller.undismissJob(job.id))
                                    : null,
                                onRetry: job.status == 'cancelled' &&
                                        !jobIsDismissed(job)
                                    ? () =>
                                        _guard(() => _controller.retryJob(job.id))
                                    : null,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  bool _hasFailed(TaskActivity activity) =>
      activity.attentionJobs.any((j) => j.status == 'failed');
}

// iOS 分区配色（与 ActivityDashboardRows.swift 的 Theme.danger/success/info 对应）。
const Color _kDanger = Color(0xFFE5615B);
const Color _kSuccess = Color(0xFF5CB86A);
const Color _kInfo = Color(0xFF5B8DEF);
const Color _kFaint = Color(0xFF98989E);

/// 相对时间：刚刚 / N 分钟前 / N 小时前 / N 天前 / 日期。
String _relative(String? iso) {
  final t = DateTime.tryParse(iso ?? '')?.toLocal();
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  final mins = d.inMinutes;
  final hours = d.inHours;
  final days = d.inDays;
  if (mins < 1) return '刚刚';
  if (mins < 60) return '$mins 分钟前';
  if (hours < 24) return '$hours 小时前';
  if (days < 7) return '$days 天前';
  return t.toString().substring(0, 10);
}

// ---------- 摘要行 ----------

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.attention,
    required this.watching,
    required this.downloading,
    required this.active,
  });

  final int attention;
  final int watching;
  final int downloading;
  final int active;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: _kFaint);
    final strong = base?.copyWith(color: _kDanger, fontWeight: FontWeight.w600);
    final spans = <TextSpan>[];
    void add(String text, [TextStyle? style]) {
      if (spans.isNotEmpty) spans.add(const TextSpan(text: ' · '));
      spans.add(TextSpan(text: text, style: style));
    }

    if (attention > 0) add('$attention 项需要处理', strong);
    if (watching > 0) add('$watching 台设备在播放');
    if (downloading > 0) add('$downloading 个下载');
    if (active > 0) add('$active 个任务进行中');
    if (spans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text('一切正常 · 现在没有人在看', style: base),
      );
    }
    if (watching == 0) add('现在没有人在看');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text.rich(TextSpan(children: spans, style: base)),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kDanger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(McIcons.alertFill, color: _kDanger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _kDanger),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- 分区骨架 ----------

/// 分区头：「● 标题 数量 …… 查看全部 ›」；圆点只给需要处理（红）与正在播放（绿）。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.count,
    this.tint,
    this.trailing,
  });

  final String title;
  final int? count;
  final Color? tint;
  final (String, VoidCallback)? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          if (tint != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(title, style: theme.textTheme.titleSmall),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text('$count',
                style: theme.textTheme.bodySmall?.copyWith(color: _kFaint)),
          ],
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: trailing!.$2,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    Text(trailing!.$1,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: _kFaint)),
                    const Icon(McIcons.chevronRight,
                        size: 14, color: _kFaint),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// iOS insetGrouped 分区：圆角卡片包住所有行，行间细分割线。
class _Section extends StatelessWidget {
  const _Section({required this.header, this.rows = const [], this.child});

  final _SectionHeader header;
  final List<Widget> rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
        height: 1,
        thickness: 0.5,
        indent: 16,
        color: Theme.of(context).dividerColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: child ??
                Column(
                  children: [
                    for (final (i, row) in rows.indexed) ...[
                      if (i > 0) divider,
                      row,
                    ],
                  ],
                ),
          ),
        ),
      ],
    );
  }
}

// ---------- 行 ----------

/// 正在播放一行：海报 · 标题 / 成员·设备 / 进度条 + 结束按钮。
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onEnd});

  final ActivePlaybackSession session;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = session.media;
    final poster = McImageUrls.build(media.posterUrl, widthPx: 96);
    final progress = (session.positionMs != null &&
            session.durationMs != null &&
            session.durationMs! > 0)
        ? session.positionMs! / session.durationMs!
        : null;
    final who =
        session.memberName.isNotEmpty ? session.memberName : session.client;
    final epLabel = mcEpisodeLabel(media.seasonNumber, media.episodeNumber);
    final episode = media.seasonNumber > 0 ? ' $epLabel' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Poster(url: poster, width: 48, height: 70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (media.title.isEmpty ? '未知内容' : media.title) + episode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (who.isNotEmpty) who,
                    if (session.deviceName.isNotEmpty) session.deviceName,
                    session.paused ? '已暂停' : '正在播放',
                    if (session.rateBytesPerSecond != null &&
                        session.rateBytesPerSecond! > 0)
                      mcFormatSpeed(session.rateBytesPerSecond!),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: _kFaint),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress?.clamp(0.0, 1.0),
                    minHeight: 3,
                    color: session.paused ? _kFaint : _kInfo,
                    backgroundColor: _kFaint.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onEnd,
            style: TextButton.styleFrom(
              foregroundColor: _kDanger,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('结束'),
          ),
        ],
      ),
    );
  }
}

/// 进行中的下载组一行：图标 · 标题（N 个资源）· 状态 · 进度。
class _ActiveDownloadRow extends StatelessWidget {
  const _ActiveDownloadRow({required this.group, this.onDelete});

  final DownloadGroup group;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = group.tasks.first;
    final percent = (task.progress ?? 0) * 100;
    final taskCount = group.tasks.length;
    final pct = percent.floor();
    final stateLine = switch (task.state) {
      'downloading' => '下载中',
      'paused' => '已暂停',
      'stalled' => '已停滞',
      'checking' => '校验中',
      'completed' => '下载完成',
      'error' => task.errorMessage ?? '出错',
      _ => task.state,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Icon(
              task.state == 'downloading'
                  ? McIcons.arrowDown
                  : task.state == 'paused' || task.state == 'stalled'
                      ? McIcons.pause
                      : McIcons.clockFill,
              size: 20,
              color: task.state == 'error' ? _kDanger : _kInfo,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (group.tasks.length > 1)
                      Text(
                        ' $taskCount 个资源',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: _kFaint),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '$pct%',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: _kFaint, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  stateLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: _kFaint),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: percent.clamp(0.0, 100.0) / 100,
                    minHeight: 3,
                    color: _kInfo,
                    backgroundColor: _kFaint.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: '删除',
              icon: const Icon(McIcons.trashFill, size: 18, color: _kDanger),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

/// 进行中的后台作业一行：齿轮 · 标题 · 状态 · 进度；尾随取消 / 忽略。
class _ActiveJobRow extends StatelessWidget {
  const _ActiveJobRow({required this.job, this.onCancel, this.onDismiss});

  final JobView job;
  final Future<void> Function()? onCancel;
  final Future<void> Function()? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = job.progress.percent;
    final needsAttention = jobNeedsAttention(job);
    final pct = percent?.round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Icon(
              needsAttention ? McIcons.alertCircleFill : McIcons.settingFill,
              size: 18,
              color: needsAttention ? _kDanger : _kInfo,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        jobTypeLabel(job),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (percent != null)
                      Text(
                        '$pct%',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: _kFaint, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                if (job.progress.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      job.progress.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: _kFaint),
                    ),
                  ),
                if (!needsAttention && percent != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 100.0) / 100,
                      minHeight: 3,
                      color: _kInfo,
                      backgroundColor: _kFaint.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onCancel != null)
            IconButton(
              tooltip: '取消',
              icon: const Icon(McIcons.close2, size: 18, color: _kFaint),
              onPressed: onCancel,
            ),
          if (onDismiss != null)
            IconButton(
              tooltip: '忽略',
              icon: const Icon(McIcons.eyeClosedFill, size: 18, color: _kFaint),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}

/// 设备整文件下载一行。
class _FileDownloadRow extends StatelessWidget {
  const _FileDownloadRow({required this.download});

  final ActiveFileDownload download;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = download.media;
    final who =
        download.memberName.isNotEmpty ? download.memberName : download.deviceName;
    final percent = download.progressPercent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SizedBox(
            width: 26,
            child: Icon(McIcons.downloadCloudOutFill,
                size: 20, color: _kInfo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media?.title ?? download.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (who.isNotEmpty) who,
                    mcFormatBytes(download.sizeBytes),
                    if (download.rateBytesPerSecond != null &&
                        download.rateBytesPerSecond! > 0)
                      mcFormatSpeed(download.rateBytesPerSecond!),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: _kFaint),
                ),
                if (percent != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 100.0) / 100,
                      minHeight: 3,
                      color: _kInfo,
                      backgroundColor: _kFaint.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 最近播放一行：小海报 · 标题 / 成员·年份 / 右列「看到哪 + 相对时间」。
class _RecentPlayRow extends StatelessWidget {
  const _RecentPlayRow({required this.entry});

  final PlaybackLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = entry.media;
    final poster = McImageUrls.build(media.posterUrl, widthPx: 96);
    final epLabel = mcEpisodeLabel(media.seasonNumber, media.episodeNumber);
    final episode = media.seasonNumber > 0 ? ' $epLabel' : '';
    final lid = media.libraryId;
    final mid = media.mediaItemId;
    final year = media.year;
    final right = entry.completed
        ? '看完'
        : entry.watchedMs > 0
            ? mcFormatWatched(entry.watchedMs)
            : '';
    final row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: lid == null
          ? null
          : () => context.push('/detail/$lid/$mid'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _Poster(url: poster, width: 34, height: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (media.title.isEmpty ? '已删除的条目' : media.title) + episode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (entry.memberName.isNotEmpty) entry.memberName,
                      if (year != null) '$year',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: _kFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (right.isNotEmpty)
                  Text(
                    right,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: entry.completed ? _kSuccess : _kFaint,
                        fontWeight: FontWeight.w600),
                  ),
                Text(
                  _relative(entry.startedAt),
                  style: theme.textTheme.bodySmall?.copyWith(color: _kFaint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return row;
  }
}

/// 最近完成一行：状态图标 · 标题 / 摘要 · 相对时间；撤销忽略 / 重新执行。
class _FinishedJobRow extends StatelessWidget {
  const _FinishedJobRow({required this.job, this.onUndismiss, this.onRetry});

  final JobView job;
  final Future<void> Function()? onUndismiss;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dismissed = job.status == 'failed' && jobIsDismissed(job);
    final (iconData, iconColor) = job.status == 'succeeded'
        ? (McIcons.checkCircle, _kSuccess)
        : dismissed
            ? (McIcons.eyeClosedFill, _kFaint)
            : (McIcons.closeCircle, _kFaint);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: 26,
              child: Icon(iconData, size: 20, color: iconColor)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  historicalJobTitle(job),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (historicalJobSummary(job).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      historicalJobSummary(job),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: _kFaint),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _relative(job.finishedAt ?? job.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(color: _kFaint),
          ),
          if (onUndismiss != null)
            IconButton(
              tooltip: '撤销忽略',
              icon: const Icon(McIcons.clockwise, size: 18, color: _kInfo),
              onPressed: onUndismiss,
            ),
          if (onRetry != null)
            IconButton(
              tooltip: '重新执行',
              icon: const Icon(McIcons.replay, size: 18, color: _kInfo),
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }
}

/// 海报占位（活动页统一小图）。
class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.width, required this.height});

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final has = url != null && url!.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: width,
        height: height,
        color: _kFaint.withValues(alpha: 0.2),
        child: has
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(McIcons.film, size: 18, color: _kFaint)),
              )
            : const Center(child: Icon(McIcons.film, size: 18, color: _kFaint)),
      ),
    );
  }
}
