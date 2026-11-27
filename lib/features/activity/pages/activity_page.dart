import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../routes.dart';
import '../state/activity_derive.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../widgets/activity_cards.dart';
import '../widgets/watch_stats_panel.dart';

/// 活动总览页（Tab 4，1:1 对齐 iOS `ActivityView.swift`）：
/// - 按紧急度自上而下排列：
///   `● 需要处理`（完整卡片）→ `● 正在播放` → `● 正在下载` → `进行中（含刷流）` →
///   `最近播放` → `观看统计` → `最近完成`；
/// - 各个长列表/分析区通过分组标题「查看全部 ›」直达 5 个专用二级页。
class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  static const _activePreviewLimit = 5;
  static const _recentPlaysLimit = 3;
  static const _recentFinishedLimit = 3;

  ActivityController get _controller =>
      ref.read(activityControllerProvider.notifier);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) McToast.error(e.toString());
    }
  }

  bool _hasFailed(TaskActivity activity) =>
      activity.attentionJobs.any((j) => j.status == 'failed');

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(activityControllerProvider);
    final activity = deriveTaskActivity(snapshot.downloads, snapshot.jobs);
    final form = McFormWatch.of(context);
    final wide = mcWindowClassOf(form) != McWindowClass.compact;
    final playback = snapshot.playback;
    final watching =
        (playback?.sessions.length ?? 0) + (playback?.hiddenSessionCount ?? 0);
    final downloading =
        (playback?.downloads.length ?? 0) + (playback?.hiddenDownloadCount ?? 0);
    final hasSourceWarning = snapshot.downloadsError != null ||
        snapshot.downloadSources.any((s) => s.status != 'active');

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top + 56,
        color: McTokens.accentStrong,
        backgroundColor: McTokens.surfaceSolid,
        onRefresh: () => _guard(_controller.refresh),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            McSliverTopBar(
              title: '活动',
              actions: [
                McFocusRing(
                  borderRadius: 22,
                  child: McGlassIconButton(
                    icon: McIcons.refreshS,
                    tooltip: '刷新状态',
                    onTap: () => _guard(_controller.refresh),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              onSearch: () => context.push('/search'),
            ),
            if (snapshot.loading && playback == null && snapshot.jobs.isEmpty)
              SliverToBoxAdapter(
                child: _ActivityLoadingSkeleton(wide: wide),
              )
            else
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: wide ? 780 : double.infinity,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: 120 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SummaryLine(
                            attention: activity.attentionTotal,
                            watching: watching,
                            downloading: downloading,
                            active: activity.activeTotal,
                          ),
                          if (snapshot.error != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                McTokens.pagePadding,
                                8,
                                McTokens.pagePadding,
                                0,
                              ),
                              child: ActivityWarningBanner(
                                message: snapshot.error!,
                              ),
                            ),
                          if (hasSourceWarning)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                McTokens.pagePadding,
                                8,
                                McTokens.pagePadding,
                                0,
                              ),
                              child: TaskSourceWarningBanner(
                                sources: snapshot.downloadSources,
                                downloadsError: snapshot.downloadsError,
                              ),
                            ),

                          // 1. 需要处理（保留完整卡片：支持换种/重试/AI诊断/删除/忽略）
                          if (activity.attentionTotal > 0) ...[
                            const SizedBox(height: 22),
                            McSectionHeader(
                              title: '需要处理',
                              leadingDotColor: McTokens.danger,
                              countLabel: '${activity.attentionTotal}',
                              trailingText:
                                  _hasFailed(activity) ? '全部忽略' : null,
                              onTap: _hasFailed(activity)
                                  ? () => _guard(() async {
                                        final n =
                                            await _controller.dismissAllJobs();
                                        McToast.success(
                                          n == 0
                                              ? '没有可忽略的失败任务'
                                              : '已忽略 $n 个失败任务',
                                        );
                                      })
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            for (final group in activity.attentionGroups)
                              DownloadGroupCard(
                                group: group,
                                ingestJobs: activity.ingestJobs,
                                onReplace: (t) => _guard(
                                  () => _controller.replaceDownloadTask(t),
                                ),
                                onDelete: (t, delFiles) => _guard(
                                  () => _controller.deleteDownloadTask(
                                    t,
                                    deleteFiles: delFiles,
                                  ),
                                ),
                              ),
                            for (final job in activity.attentionJobs)
                              JobCard(
                                job: job,
                                onCancel: activeFeedJobStatuses.contains(job.status)
                                    ? () => _guard(
                                          () => _controller.cancelJob(job.id),
                                        )
                                    : null,
                                onRetry: () => _guard(
                                  () => _controller.retryJob(job.id),
                                ),
                                onDismiss: (mute) => _controller.dismissJob(
                                  job.id,
                                  muteSource: mute,
                                ),
                                onUndismiss: () => _guard(
                                  () => _controller.undismissJob(job.id),
                                ),
                              ),
                          ],

                          // 2. 正在播放（含真实 delivery / 结束播放 / 注销设备 / 范围切换脚注）
                          if (playback != null &&
                              (playback.sessions.isNotEmpty ||
                                  playback.hiddenSessionCount > 0)) ...[
                            _DashboardSection(
                              title: '正在播放',
                              dotColor: McTokens.ok,
                              count: watching,
                              rows: [
                                for (final session in playback.sessions)
                                  ActivityPlaybackSessionRow(
                                    session: session,
                                    onEnd: () => _controller.endPlaybackSession(
                                      session.deviceId,
                                    ),
                                    onRevoke: () =>
                                        _controller.revokePlaybackDevice(
                                      session.deviceId,
                                    ),
                                  ),
                              ],
                              footer: ActivityScopeFooter(
                                hiddenCount: playback.hiddenSessionCount,
                                scope: snapshot.scope,
                                hiddenText:
                                    '另有 ${playback.hiddenSessionCount} 台设备在播放范围外内容',
                                onToggleScope: (next) =>
                                    _guard(() => _controller.setScope(next)),
                              ),
                            ),
                          ],

                          // 3. 正在下载（整文件离线缓存 + 范围切换脚注）
                          if (playback != null &&
                              (playback.downloads.isNotEmpty ||
                                  playback.hiddenDownloadCount > 0)) ...[
                            _DashboardSection(
                              title: '正在下载',
                              dotColor: McTokens.info,
                              count: downloading,
                              rows: [
                                for (final download in playback.downloads)
                                  ActivityFileDownloadRow(
                                    download: download,
                                    onRevoke: () =>
                                        _controller.revokePlaybackDevice(
                                      download.deviceId,
                                    ),
                                  ),
                              ],
                              footer: ActivityScopeFooter(
                                hiddenCount: playback.hiddenDownloadCount,
                                scope: snapshot.scope,
                                hiddenText:
                                    '另有 ${playback.hiddenDownloadCount} 个范围外文件正在下载',
                                onToggleScope: (next) =>
                                    _guard(() => _controller.setScope(next)),
                              ),
                            ),
                          ],

                          // 4. 进行中（含刷流摘要行，点「查看全部 ›」进 /activity/active）
                          if (activity.activeTotal > 0 ||
                              activity.boostTasks.isNotEmpty)
                            _DashboardSection(
                              title: '进行中',
                              dotColor: McTokens.info,
                              count: activity.activeTotal > 0
                                  ? activity.activeTotal
                                  : null,
                              trailingText:
                                  activity.activeTotal > 0 ? '查看全部 ›' : null,
                              onTrailingTap: activity.activeTotal > 0
                                  ? () => context.push(routeActivityActive)
                                  : null,
                              rows: [
                                ..._buildActivePreviewRows(context, activity),
                                if (activity.boostTasks.isNotEmpty)
                                  ActivityBoostSummaryRow(
                                    tasks: activity.boostTasks,
                                    pool: snapshot.boostPool,
                                    onTap: () =>
                                        context.push(routeActivityBoost),
                                  ),
                              ],
                            ),

                          // 5. 最近播放（点「查看全部 ›」进 /activity/plays）
                          if (!snapshot.historyForbidden &&
                              snapshot.history != null &&
                              snapshot.history!.entries.isNotEmpty)
                            _DashboardSection(
                              title: '最近播放',
                              trailingText: '查看全部 ›',
                              onTrailingTap: () =>
                                  context.push(routeActivityPlays),
                              rows: [
                                for (final entry in snapshot.history!.entries
                                    .take(_recentPlaysLimit))
                                  ActivityRecentPlayRow(entry: entry),
                              ],
                            ),

                          // 6. 观看统计（7 天紧凑摘要卡，点卡或「查看全部 ›」进 /activity/stats）
                          if (!snapshot.statsForbidden &&
                              snapshot.watchStats != null)
                            _DashboardSection(
                              title: '观看统计',
                              trailingText: '查看全部 ›',
                              onTrailingTap: () =>
                                  context.push(routeActivityStats),
                              customChild: ActivityWeeklyWatchCard(
                                stats: snapshot.watchStats!,
                                onTap: () => context.push(routeActivityStats),
                              ),
                            ),

                          // 7. 最近完成（点「查看全部 N ›」进 /activity/finished）
                          if (activity.historyJobs.isNotEmpty)
                            _DashboardSection(
                              title: '最近完成',
                              count: activity.historyTotal,
                              trailingText: '查看全部 ${activity.historyTotal} ›',
                              onTrailingTap: () =>
                                  context.push(routeActivityFinished),
                              rows: [
                                for (final job in activity.historyJobs
                                    .take(_recentFinishedLimit))
                                  _FinishedJobPreviewRow(
                                    job: job,
                                    onTap: () =>
                                        context.push(routeActivityFinished),
                                    onUndismiss: job.status == 'failed' &&
                                            jobIsDismissed(job)
                                        ? () => _guard(
                                              () => _controller
                                                  .undismissJob(job.id),
                                            )
                                        : null,
                                    // 修复：仅对非系统取消的已取消任务提供重试！
                                    onRetry: job.status == 'cancelled' &&
                                            !jobIsSystemCancelled(job)
                                        ? () => _guard(
                                              () => _controller.retryJob(job.id),
                                            )
                                        : null,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActivePreviewRows(
    BuildContext context,
    TaskActivity activity,
  ) {
    final rows = <Widget>[];
    for (final group in activity.activeGroups) {
      if (rows.length >= _activePreviewLimit) break;
      rows.add(
        _ActiveDownloadPreviewRow(
          group: group,
          ingestJobs: activity.ingestJobs,
          onTap: () => context.push(routeActivityActive),
        ),
      );
    }
    for (final job in activity.activeJobs) {
      if (rows.length >= _activePreviewLimit) break;
      rows.add(
        _ActiveJobPreviewRow(
          job: job,
          onTap: () => context.push(routeActivityActive),
          onCancel: job.status != 'cancelling'
              ? () => _guard(() => _controller.cancelJob(job.id))
              : null,
        ),
      );
    }
    return rows;
  }
}

class _ActivityLoadingSkeleton extends StatelessWidget {
  const _ActivityLoadingSkeleton({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 780 : double.infinity),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            McTokens.pagePadding,
            10,
            McTokens.pagePadding,
            120 + MediaQuery.paddingOf(context).bottom,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              McShimmerBox(width: 210, height: 18, radius: 6),
              SizedBox(height: 24),
              McShimmerBox(width: 96, height: 16, radius: 6),
              SizedBox(height: 10),
              McShimmerBox(height: 132, radius: McTokens.cardRadius),
              SizedBox(height: 22),
              McShimmerBox(width: 112, height: 16, radius: 6),
              SizedBox(height: 10),
              McShimmerBox(height: 112, radius: McTokens.cardRadius),
              SizedBox(height: 22),
              McShimmerBox(width: 100, height: 16, radius: 6),
              SizedBox(height: 10),
              McShimmerBox(height: 148, radius: McTokens.cardRadius),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final base = McText.caption.muted.tabular;
    final strong = McText.caption
        .copyWith(color: McTokens.danger, fontWeight: FontWeight.w600)
        .tabular;
    final spans = <TextSpan>[];
    void add(String text, [TextStyle? style]) {
      if (spans.isNotEmpty) {
        spans.add(TextSpan(text: ' · ', style: McText.caption.faint));
      }
      spans.add(TextSpan(text: text, style: style));
    }

    if (attention > 0) add('$attention 项需要处理', strong);
    if (watching > 0) add('$watching 台设备在播放');
    if (downloading > 0) add('$downloading 个下载进行中');
    if (active > 0) add('$active 个任务进行中');
    if (spans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          McTokens.pagePadding,
          4,
          McTokens.pagePadding,
          4,
        ),
        child: Text('一切正常 · 当前无人在看', style: base),
      );
    }
    if (watching == 0) add('当前无人在看');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        4,
        McTokens.pagePadding,
        4,
      ),
      child: Text.rich(TextSpan(children: spans, style: base)),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    this.dotColor,
    this.count,
    this.trailingText,
    this.onTrailingTap,
    this.rows = const [],
    this.customChild,
    this.footer,
  });

  final String title;
  final Color? dotColor;
  final int? count;
  final String? trailingText;
  final VoidCallback? onTrailingTap;
  final List<Widget> rows;
  final Widget? customChild;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        McSectionHeader(
          title: title,
          leadingDotColor: dotColor,
          countLabel: count?.toString(),
          trailingText: trailingText,
          onTap: onTrailingTap,
        ),
        const SizedBox(height: 10),
        if (customChild != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
            decoration: BoxDecoration(
              color: McTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(McTokens.cardRadius),
              border: Border.all(color: McTokens.line, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: customChild,
          )
        else if (rows.isNotEmpty)
          McInsetGroup(children: rows),
        if (footer != null) footer!,
      ],
    );
  }
}

class _ActiveDownloadPreviewRow extends StatelessWidget {
  const _ActiveDownloadPreviewRow({
    required this.group,
    required this.ingestJobs,
    required this.onTap,
  });

  final DownloadGroup group;
  final Map<String, JobView> ingestJobs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final task = group.tasks.first;
    final ingest = task.state == 'completed'
        ? ingestJobs[task.infoHash.toLowerCase()]
        : null;
    final percent = ingest != null
        ? ingest.progress.percent
        : (task.progress != null ? task.progress! * 100 : null);
    final statusParts = <String>[
      if (ingest != null)
        activeJobStatus(ingest)
      else
        downloadStateLabel(task.state),
      if (ingest != null && ingest.progress.message.isNotEmpty)
        ingest.progress.message
      else ...[
        if ((task.dlspeedBytes ?? 0) > 0) '↓ ${mcFormatSpeed(task.dlspeedBytes!)}',
        if ((task.etaSeconds ?? 0) > 0 && task.state == 'downloading')
          '剩 ${formatDurationSeconds(task.etaSeconds!.toDouble())}',
      ],
    ];
    final accent = ingest != null ? McTokens.ok : McTokens.info;

    return McPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              ingest != null
                  ? McIcons.inboxArchive
                  : (task.state == 'downloading'
                      ? McIcons.downloadCloudOut
                      : McIcons.clock),
              size: 19,
              color: accent,
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
                          style: McText.sub.copyWith(
                            color: McTokens.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (group.tasks.length > 1)
                        Text(
                          ' ${group.tasks.length} 个资源',
                          style: McText.caption.faint.tabular,
                        ),
                      if (percent != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${percent.floor().clamp(0, 100)}%',
                          style: McText.caption.muted.tabular,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted.tabular,
                  ),
                  if (percent != null) ...[
                    const SizedBox(height: 6),
                    ActivityProgressBar(
                      progress: percent / 100.0,
                      color: accent,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              McIcons.arrowRightS,
              size: 16,
              color: McTokens.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveJobPreviewRow extends StatelessWidget {
  const _ActiveJobPreviewRow({
    required this.job,
    required this.onTap,
    this.onCancel,
  });

  final JobView job;
  final VoidCallback onTap;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final pct = job.progress.percent;
    final subtitle = [
      activeJobStatus(job),
      if (job.progress.message.isNotEmpty) job.progress.message,
    ].join(' · ');

    return McPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(McIcons.setting1, size: 19, color: McTokens.info),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          jobFeedIdentity(job) ?? jobTypeLabel(job),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.sub.copyWith(
                            color: McTokens.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (pct != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${pct.round()}%',
                          style: McText.caption.muted.tabular,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                  if (pct != null) ...[
                    const SizedBox(height: 6),
                    ActivityProgressBar(
                      progress: pct / 100.0,
                      color: McTokens.info,
                    ),
                  ],
                ],
              ),
            ),
            if (onCancel != null) ...[
              const SizedBox(width: 8),
              McGlassIconButton(
                icon: McIcons.close,
                size: 30,
                iconSize: 14,
                tooltip: '取消任务',
                onTap: onCancel,
              ),
            ] else ...[
              const SizedBox(width: 6),
              const Icon(
                McIcons.arrowRightS,
                size: 16,
                color: McTokens.textFaint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinishedJobPreviewRow extends StatelessWidget {
  const _FinishedJobPreviewRow({
    required this.job,
    required this.onTap,
    this.onUndismiss,
    this.onRetry,
  });

  final JobView job;
  final VoidCallback onTap;
  final Future<void> Function()? onUndismiss;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final ok = job.status == 'succeeded';
    final ingest = ingestHistoryDetail(job);
    final summary = ingest?.summary ?? historicalJobSummary(job);

    return McPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(
              ok ? McIcons.checkCircleFill : McIcons.closeCircle,
              size: 18,
              color: ok ? McTokens.ok : McTokens.textFaint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    historicalJobTitle(job),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.sub.copyWith(
                      color: McTokens.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onUndismiss != null)
              McChip(label: '恢复', compact: true, onTap: onUndismiss)
            else if (onRetry != null)
              McChip(label: '重试', compact: true, onTap: onRetry)
            else
              Text(
                mcFromNowIso(job.finishedAt ?? job.createdAt, empty: ''),
                style: McText.micro.faint.tabular,
              ),
          ],
        ),
      ),
    );
  }
}
