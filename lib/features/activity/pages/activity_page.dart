import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/state_views.dart';

import '../state/activity_derive.dart';
import '../state/controllers.dart';
import '../widgets/activity_cards.dart';
import '../widgets/watch_stats_panel.dart';

/// 活动中心页（对齐 ActivityScreen.kt 与设计文档 04 §6）：
/// 观看视角（正在播放 / 整文件下载 / 观看统计 / 最近播放）与
/// 任务视角（需要处理 / 进行中 / 已结束按天分组），双视角用分段控件切换。
class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  bool _watchView = false;

  ActivityController get _controller => ref.read(activityControllerProvider.notifier);

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('活动中心'),
        actions: [
          // TV：刷新按钮 D-pad 聚焦环。
          McFocusRing(
            borderRadius: 24,
            child: IconButton(
              icon: const Icon(Icons.refresh),
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
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('观看'), icon: Icon(Icons.play_circle_outline)),
                        ButtonSegment(value: false, label: Text('任务'), icon: Icon(Icons.task_outlined)),
                      ],
                        selected: {_watchView},
                        onSelectionChanged: (v) => setState(() => _watchView = v.first),
                      ),
                    ),
                  if (snapshot.error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        snapshot.error!,
                        style: const TextStyle(color: Color(0xFFE5615B)),
                      ),
                    ),
                  ...(_watchView ? _buildWatchView(snapshot) : _buildTaskView(snapshot, activity)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ---------- 观看视角 ----------

  List<Widget> _buildWatchView(ActivitySnapshot snapshot) {
    final playback = snapshot.playback;
    final history = snapshot.history;
    return [
      SectionLabel(text: '正在播放 ${playback?.sessions.length ?? 0}'),
      if (playback == null || playback.sessions.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('现在没有设备在播放'),
        )
      else
        for (final session in playback.sessions)
          PlaybackSessionCard(
            session: session,
            onEnd: () => _guard(() => _controller.endPlaybackSession(session.deviceId)),
          ),
      SectionLabel(text: '设备下载 ${playback?.downloads.length ?? 0}'),
      if (playback == null || playback.downloads.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('没有进行中的设备下载'),
        )
      else
        for (final download in playback.downloads) FileDownloadCard(download: download),
      if (!snapshot.statsForbidden && snapshot.watchStats != null) ...[
        const SectionLabel(text: '观看统计'),
        WatchStatsPanel(
          stats: snapshot.watchStats!,
          days: snapshot.watchStatsDays,
          memberId: snapshot.watchStatsMemberId,
          onDaysChanged: (d) => _guard(() => _controller.setWatchStatsDays(d)),
          onMemberSelected: (id) => _guard(() => _controller.setWatchStatsMember(id)),
        ),
      ],
      if (!snapshot.historyForbidden && history != null && history.entries.isNotEmpty) ...[
        const SectionLabel(text: '最近播放'),
        for (final entry in history.entries) HistoryTile(entry: entry),
      ],
      const SizedBox(height: 24),
    ];
  }

  // ---------- 任务视角 ----------

  List<Widget> _buildTaskView(ActivitySnapshot snapshot, TaskActivity activity) {
    final historyGroups = groupHistoricalJobs(activity.historyJobs);
    return [
      ActivitySummaryBar(
        activity: activity,
        onDismissAll: () => _guard(_controller.dismissAllJobs),
      ),
      if (activity.attentionGroups.isEmpty && activity.attentionJobs.isEmpty)
        const SizedBox.shrink()
      else ...[
        SectionLabel(text: '需要处理 ${activity.attentionTotal}', danger: true),
        for (final group in activity.attentionGroups)
          DownloadGroupCard(
            group: group,
            ingestJobs: activity.ingestJobs,
            onReplace: (t) => _guard(() => _controller.replaceDownloadTask(t)),
            onDelete: (t) => _guard(() => _controller.deleteDownloadTask(t)),
          ),
        for (final job in activity.attentionJobs)
          JobCard(
            job: job,
            onCancel: () => _guard(() => _controller.cancelJob(job.id)),
            onDismiss: () => _guard(() => _controller.dismissJob(job.id)),
          ),
      ],
      if (activity.activeGroups.isNotEmpty || activity.activeJobs.isNotEmpty) ...[
        SectionLabel(text: '正在进行 ${activity.activeTotal}'),
        for (final group in activity.activeGroups)
          DownloadGroupCard(
            group: group,
            ingestJobs: activity.ingestJobs,
            onReplace: (t) => _guard(() => _controller.replaceDownloadTask(t)),
            onDelete: (t) => _guard(() => _controller.deleteDownloadTask(t)),
          ),
        for (final job in activity.activeJobs)
          JobCard(
            job: job,
            onCancel: job.status == 'queued' || job.status == 'running' || job.status == 'retry_wait'
                ? () => _guard(() => _controller.cancelJob(job.id))
                : null,
          ),
      ],
      if (historyGroups.isNotEmpty) ...[
        const SectionLabel(text: '已结束'),
        // Android 端：最近一天默认展开，更早的折叠。
        for (final (i, group) in historyGroups.indexed)
          _HistoryDayTile(
            group: group,
            initiallyExpanded: i == 0,
            onUndismiss: (id) => _guard(() => _controller.undismissJob(id)),
          ),
      ],
      const SizedBox(height: 24),
    ];
  }
}

/// 历史任务的一天：最近一天展开，其余折叠（对齐 ActivityScreen.kt 的历史区）。
class _HistoryDayTile extends StatelessWidget {
  const _HistoryDayTile({required this.group, required this.initiallyExpanded, this.onUndismiss});

  final JobDayGroup group;
  final bool initiallyExpanded;
  final Future<void> Function(String)? onUndismiss;

  @override
  Widget build(BuildContext context) {
    final hasIgnored = group.jobs.any((j) => jobIsDismissed(j));
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: Text('${group.label} · ${group.jobs.length} 项'),
          children: [
            for (final job in group.jobs)
              JobCard(
                job: job,
                historical: true,
                onUndismiss: jobIsDismissed(job) && onUndismiss != null
                    ? () => onUndismiss!(job.id)
                    : null,
              ),
            if (hasIgnored && onUndismiss != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '被忽略的失败任务仍在历史里，可在任务详情撤回忽略',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
