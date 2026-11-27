import 'dart:async';

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
import '../../../core/navigation/external_media_link.dart';
import '../state/activity_api.dart';
import '../state/activity_derive.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../widgets/activity_cards.dart';
import '../widgets/watch_stats_panel.dart';

/// 活动二级页公共外壳：纯黑背景 + 浮动返回顶栏 + 宽屏可读宽度居中。
class _SubpageScaffold extends StatelessWidget {
  const _SubpageScaffold({
    required this.title,
    this.subtitle,
    this.trailing = const [],
    required this.child,
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;
  final Widget child;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home?tab=activity');
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = McFormWatch.of(context);
    final wide = mcWindowClassOf(form) != McWindowClass.compact;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: wide ? 820 : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.only(top: topPad + 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                        child: Text(
                          subtitle!,
                          style: McText.caption.muted,
                        ),
                      ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: McFloatingDetailBar(
              onBack: () => _back(context),
              title: title,
              titleVisible: true,
              trailing: trailing,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 子页 1 & 2：进行中任务 / 已结束历史 ──

class ActivityTasksPage extends ConsumerStatefulWidget {
  const ActivityTasksPage({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<ActivityTasksPage> createState() => _ActivityTasksPageState();
}

class _ActivityTasksPageState extends ConsumerState<ActivityTasksPage> {
  final Set<String> _collapsedDays = <String>{};

  ActivityController get _ctrl =>
      ref.read(activityControllerProvider.notifier);

  Future<void> _guard(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (mounted) McToast.error(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(activityControllerProvider);
    final activity = deriveTaskActivity(snapshot.downloads, snapshot.jobs);

    return _SubpageScaffold(
      title: widget.active ? '进行中' : '已结束',
      trailing: [
        McGlassIconButton(
          icon: McIcons.refreshS,
          tooltip: '刷新',
          onTap: () => _guard(_ctrl.refresh),
        ),
      ],
      child: RefreshIndicator(
        color: McTokens.accentStrong,
        backgroundColor: McTokens.surfaceSolid,
        onRefresh: () => _guard(_ctrl.refresh),
        child: widget.active
            ? _buildActiveList(snapshot, activity)
            : _buildHistoryList(activity),
      ),
    );
  }

  Widget _buildActiveList(ActivitySnapshot snapshot, TaskActivity activity) {
    final hasWarning = snapshot.downloadsError != null ||
        snapshot.downloadSources.any((s) => s.status != 'active');
    if (activity.activeTotal == 0 && !hasWarning) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          McEmptyView(
            icon: McIcons.task2,
            title: '当前没有进行中的任务',
            text: '下载器任务、自动入库、媒体库扫描与字幕生成会实时出现在这里。',
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 6, bottom: 48),
      children: [
        if (hasWarning)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TaskSourceWarningBanner(
              sources: snapshot.downloadSources,
              downloadsError: snapshot.downloadsError,
            ),
          ),
        for (final group in activity.activeGroups)
          DownloadGroupCard(
            group: group,
            ingestJobs: activity.ingestJobs,
            onReplace: (t) => _guard(() => _ctrl.replaceDownloadTask(t)),
            onDelete: (t, delFiles) => _guard(
              () => _ctrl.deleteDownloadTask(t, deleteFiles: delFiles),
            ),
          ),
        for (final job in activity.activeJobs)
          JobCard(
            job: job,
            onCancel: job.status != 'cancelling'
                ? () => _guard(() => _ctrl.cancelJob(job.id))
                : null,
            onRetry: () => _guard(() => _ctrl.retryJob(job.id)),
          ),
      ],
    );
  }

  Widget _buildHistoryList(TaskActivity activity) {
    final groups = groupHistoricalJobs(activity.historyJobs);
    if (groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          McEmptyView(
            icon: McIcons.history1,
            title: '还没有已结束的任务',
            text: '已完成、已取消或已忽略的后台任务会按天归档在这里。',
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
      children: [
        for (final group in groups) _buildDayGroup(group),
      ],
    );
  }

  Widget _buildDayGroup(JobDayGroup group) {
    final open = !_collapsedDays.contains(group.key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        McPressable(
          onTap: () {
            setState(() {
              if (open) {
                _collapsedDays.add(group.key);
              } else {
                _collapsedDays.remove(group.key);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Text(
                  group.label,
                  style: McText.sub.copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${group.jobs.length} 项', style: McText.caption.faint.tabular),
                const Spacer(),
                Text(open ? '收起' : '展开', style: McText.caption.faint),
                const SizedBox(width: 4),
                Icon(
                  open ? McIcons.arrowDownS : McIcons.arrowRightS,
                  size: 14,
                  color: McTokens.textFaint,
                ),
              ],
            ),
          ),
        ),
        if (open)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: McTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: McTokens.line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < group.jobs.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: McTokens.line),
                  _buildHistoricalRow(group.jobs[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHistoricalRow(JobView job) {
    final dismissed = job.status == 'failed' && jobIsDismissed(job);
    final canRetry = job.status == 'cancelled' && !jobIsSystemCancelled(job);
    final ingest = ingestHistoryDetail(job);
    final partial = succeededWithProblems(job);
    final iconColor = job.status == 'succeeded'
        ? (partial ? McTokens.warning : McTokens.ok)
        : McTokens.textFaint;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              job.status == 'succeeded'
                  ? McIcons.checkCircleFill
                  : McIcons.closeCircle,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  historicalJobTitle(job),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: McText.sub.copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${activityClock(job.finishedAt ?? job.createdAt)}  ${ingest?.summary ?? historicalJobSummary(job)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.muted.tabular,
                ),
                if (ingest != null) IngestHistoryFiles(detail: ingest),
              ],
            ),
          ),
          if (dismissed) ...[
            const SizedBox(width: 8),
            McChip(
              label: '撤销忽略',
              compact: true,
              onTap: () => _guard(() => _ctrl.undismissJob(job.id)),
            ),
          ] else if (canRetry) ...[
            const SizedBox(width: 8),
            McChip(
              label: '重试',
              compact: true,
              onTap: () => _guard(() => _ctrl.retryJob(job.id)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 子页 3：刷流做种（ActivityBoostPage） ──

class ActivityBoostPage extends ConsumerStatefulWidget {
  const ActivityBoostPage({super.key});

  @override
  ConsumerState<ActivityBoostPage> createState() => _ActivityBoostPageState();
}

class _ActivityBoostPageState extends ConsumerState<ActivityBoostPage> {
  static const _pageSize = 20;
  int _visibleCount = _pageSize;
  bool _cleaning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityControllerProvider.notifier).loadBoostPool();
    });
  }

  Future<void> _prepareAndConfirmCleanup() async {
    if (_cleaning) return;
    BoostPoolView pool;
    try {
      pool = await ref.read(activityApiProvider).boostPoolShow();
    } catch (e) {
      if (mounted) McToast.error(e.toString());
      return;
    }
    if (!mounted) return;

    var count = 0;
    var bytes = 0;
    var protectedCount = 0;
    var protectedBytes = 0;
    String? protectedUntil;
    final enabledNames = <String>[];
    for (final s in pool.sites) {
      count += s.taskCount;
      bytes += s.sizeBytes;
      protectedCount += s.protectedCount;
      protectedBytes += s.protectedBytes;
      if (s.protectedUntil != null &&
          s.protectedUntil!.compareTo(protectedUntil ?? '') > 0) {
        protectedUntil = s.protectedUntil;
      }
      if (s.boostEnabled) enabledNames.add(s.siteName);
    }

    final lines = <String>[
      '将清理 $count 个刷流种子（共 ${mcFormatBytes(bytes)}）并连带删除数据文件。',
      if (enabledNames.isNotEmpty)
        '以下站点仍在开启刷流，本次将一并关闭以避免重新拉取：${enabledNames.join('、')}。',
      if (protectedCount > 0)
        '其中 $protectedCount 个种子（${mcFormatBytes(protectedBytes)}）仍在站点 H&R 保留期内'
            '${formatBoostDeadline(protectedUntil) != null ? '（最晚 ${formatBoostDeadline(protectedUntil)} 到期）' : ''}。'
            '默认会先标记并在到期后自动删除；若选择「立即全部删除」将绕过保护，可能触发站点 H&R 警告。',
    ];

    final choice = await showMcSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              count > 0 ? '清理 $count 个刷流种子' : '清理刷流种子',
              style: McText.title,
            ),
            const SizedBox(height: 10),
            Text(lines.join('\n\n'), style: McText.sub.muted),
            const SizedBox(height: 18),
            McActionPill(
              label: enabledNames.isEmpty
                  ? (protectedCount > 0 ? '安全清理（保留期到期自动删）' : '立即清理')
                  : '关闭刷流并安全清理',
              primary: true,
              height: 44,
              onTap: () => Navigator.of(ctx).pop('safe'),
            ),
            if (protectedCount > 0) ...[
              const SizedBox(height: 10),
              McActionPill(
                label: '立即全部删除（含保留期内，可能触发 H&R）',
                primary: false,
                tone: McGlassTone.danger,
                height: 44,
                onTap: () => Navigator.of(ctx).pop('force'),
              ),
            ],
            const SizedBox(height: 10),
            McActionPill(
              label: '取消',
              primary: false,
              height: 42,
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;
    setState(() => _cleaning = true);
    try {
      final result = await ref
          .read(activityControllerProvider.notifier)
          .cleanupBoostPool(force: choice == 'force');
      if (mounted) McToast.success(formatBoostCleanupSummary(result));
    } catch (e) {
      if (mounted) McToast.error(e.toString());
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(activityControllerProvider);
    final activity = deriveTaskActivity(snapshot.downloads, snapshot.jobs);
    final tasks = activity.boostTasks;
    final totals = ActivityBoostTotals(tasks);
    final sites = ActivityBoostSites(tasks, snapshot.boostPool);
    final sorted = ActivityBoostTotals.sorted(tasks);

    return _SubpageScaffold(
      title: '刷流做种',
      trailing: [
        if (snapshot.supportsBoostCleanup && tasks.isNotEmpty)
          McActionPill(
            label: _cleaning ? '清理中…' : '清理',
            primary: false,
            tone: McGlassTone.danger,
            height: 34,
            busy: _cleaning,
            onTap: _cleaning ? null : _prepareAndConfirmCleanup,
          ),
      ],
      child: RefreshIndicator(
        color: McTokens.accentStrong,
        backgroundColor: McTokens.surfaceSolid,
        onRefresh: () async {
          await ref.read(activityControllerProvider.notifier).refresh();
          await ref.read(activityControllerProvider.notifier).loadBoostPool();
        },
        child: tasks.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  McEmptyView(
                    icon: McIcons.fileSeedFill,
                    title: '当前没有在池刷流种子',
                    text: '开启 PT 站点刷流后，正在做种与下载的刷流任务会汇总展示在这里。',
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 48),
                children: [
                  McInsetGroup(
                    header: '共 ${totals.count} 个种子',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '↑ ${mcFormatSpeed(totals.upSpeed)}',
                                    style: McText.titleSm
                                        .copyWith(color: McTokens.ok)
                                        .tabular,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '↓ ${mcFormatSpeed(totals.downSpeed)}',
                                    style: McText.titleSm
                                        .copyWith(color: McTokens.info)
                                        .tabular,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '累计上传 ${mcFormatBytes(totals.uploaded)}',
                                    style: McText.caption.muted.tabular,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '累计下载 ${mcFormatBytes(totals.downloaded)}',
                                    style: McText.caption.muted.tabular,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (sites.sites.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    McInsetGroup(
                      header: '按站点分布',
                      footer: sites.count(BoostSiteMode.off) > 0
                          ? '已关闭刷流的站点不会自动删种，可点右上角「清理」回收磁盘空间。'
                          : null,
                      children: [
                        for (final site in sites.sites) _buildSiteRow(site),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  McInsetGroup(
                    header: '按实时上传速度排序',
                    children: [
                      for (final task in sorted.take(_visibleCount))
                        _buildBoostTaskRow(
                          task,
                          sites.taskStates[task.infoHash.toLowerCase()],
                        ),
                      if (sorted.length > _visibleCount)
                        McPressable(
                          onTap: () => setState(
                            () => _visibleCount += _pageSize,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                '再显示 ${(sorted.length - _visibleCount).clamp(0, _pageSize)} 个（共 ${sorted.length} 个）',
                                style: McText.sub.copyWith(color: McTokens.info),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSiteRow(ActivityBoostSiteGroup site) {
    final totals = ActivityBoostTotals(site.tasks);
    final size = site.tasks.fold<int>(0, (s, t) => s + (t.sizeBytes ?? 0));
    final (label, color) = switch (site.mode) {
      BoostSiteMode.running => ('运行中', McTokens.ok),
      BoostSiteMode.paused => ('已暂停', McTokens.warning),
      BoostSiteMode.off => ('已关闭', McTokens.textFaint),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  site.name,
                  style: McText.sub.copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${site.tasks.length} 个种子 · ${mcFormatBytes(size)} · ↑ ${mcFormatSpeed(totals.upSpeed)}',
                  style: McText.caption.muted.tabular,
                ),
                if ((site.pool?.scheduledCount ?? 0) > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${site.pool!.scheduledCount} 个已预约到期自动清理',
                    style: McText.micro.copyWith(color: McTokens.warning),
                  ),
                ],
              ],
            ),
          ),
          Text(
            label,
            style: McText.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoostTaskRow(DownloadTask task, BoostPoolTaskView? poolState) {
    final upSpeed = task.upspeedBytes ?? 0;
    final downloading = task.state == 'downloading';
    final pct = task.progress != null ? (task.progress! * 100).floor() : null;
    final name = (task.name?.isNotEmpty ?? false) ? task.name! : task.infoHash;
    String? cleanupNote;
    if (poolState != null && poolState.cleanupScheduled) {
      final dl = formatBoostDeadline(poolState.protectedUntil);
      cleanupNote = dl != null ? '已预约清理 · $dl 后自动删除' : '已预约清理 · 下一轮巡检自动删除';
    }

    return McPressable(
      onTap: (task.pageUrl?.isNotEmpty ?? false)
          ? () => ExternalMediaLink.open(task.pageUrl!)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: McText.sub.copyWith(color: McTokens.text),
                  ),
                ),
                if (upSpeed > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '↑ ${mcFormatSpeed(upSpeed)}',
                    style: McText.caption
                        .copyWith(
                          color: McTokens.ok,
                          fontWeight: FontWeight.w600,
                        )
                        .tabular,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              [
                if (task.siteName != null && task.siteName!.isNotEmpty)
                  task.siteName!,
                if (task.sizeBytes != null) mcFormatBytes(task.sizeBytes!),
                if ((task.uploadedBytes ?? 0) > 0)
                  '已上传 ${mcFormatBytes(task.uploadedBytes!)}',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.caption.muted.tabular,
            ),
            if (downloading && pct != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ActivityProgressBar(
                      progress: pct / 100.0,
                      color: McTokens.info,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$pct%', style: McText.micro.faint.tabular),
                  if ((task.dlspeedBytes ?? 0) > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '↓ ${mcFormatSpeed(task.dlspeedBytes!)}',
                      style: McText.micro.faint.tabular,
                    ),
                  ],
                ],
              ),
            ],
            if (cleanupNote != null) ...[
              const SizedBox(height: 4),
              Text(
                cleanupNote,
                style: McText.micro.copyWith(color: McTokens.warning),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 子页 4：播放历史（WatchHistoryPage，游标分页 + 成员/范围筛选 + 按天分组） ──

class WatchHistoryPage extends ConsumerStatefulWidget {
  const WatchHistoryPage({super.key});

  @override
  ConsumerState<WatchHistoryPage> createState() => _WatchHistoryPageState();
}

class _WatchHistoryPageState extends ConsumerState<WatchHistoryPage> {
  static const _pageSize = 30;
  final ScrollController _scroll = ScrollController();

  List<PlaybackLogEntry> _entries = const [];
  int _hiddenCount = 0;
  int? _cursor;
  bool _hasMore = false;
  bool _loading = true;
  String? _error;
  int? _memberId;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityControllerProvider.notifier).loadMembers();
      _reload();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading || _cursor == null) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 280) {
      unawaited(_load(before: _cursor));
    }
  }

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _entries = const [];
      _hiddenCount = 0;
      _cursor = null;
      _hasMore = false;
      _error = null;
    });
    await _load(before: null);
  }

  Future<void> _load({required int? before}) async {
    final gen = _generation;
    setState(() => _loading = true);
    final scope = ref.read(activityControllerProvider).scope;
    try {
      final page = await ref.read(activityApiProvider).playbackHistory(
            limit: _pageSize,
            before: before,
            memberId: _memberId,
            scope: scope,
          );
      if (!mounted || gen != _generation) return;
      final existingIds = _entries.map((e) => e.id).toSet();
      final nextEntries = before == null
          ? page.entries
          : [
              ..._entries,
              ...page.entries.where((e) => !existingIds.contains(e.id)),
            ];
      setState(() {
        _entries = nextEntries;
        _hiddenCount =
            before == null ? page.hiddenCount : _hiddenCount + page.hiddenCount;
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _memberLabel(List<ActivityMemberOption> members) {
    if (_memberId == null) return '全部成员';
    if (_memberId == 0) return '超级管理员';
    for (final m in members) {
      if (m.id == _memberId) return m.displayName;
    }
    return '成员 #$_memberId';
  }

  List<({String key, String label, List<PlaybackLogEntry> items})> _groupEntries() {
    final out = <({String key, String label, List<PlaybackLogEntry> items})>[];
    for (final entry in _entries) {
      final dt = DateTime.tryParse(entry.startedAt)?.toLocal();
      final key = dt != null ? activityDayKey(dt) : entry.startedAt;
      if (out.isNotEmpty && out.last.key == key) {
        out.last.items.add(entry);
      } else {
        out.add((
          key: key,
          label: activityHistoryDayLabel(entry.startedAt, isoDate: true),
          items: [entry],
        ));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(activityControllerProvider);
    final scope = snap.scope;
    final members = snap.members;
    final subtitle =
        '${_memberLabel(members)} · ${scope == 'all' ? '全部范围' : '我的浏览范围'}';
    final groups = _groupEntries();

    return _SubpageScaffold(
      title: '最近播放',
      subtitle: subtitle,
      trailing: [
        PopupMenuButton<String>(
          tooltip: '筛选条件',
          onSelected: (v) async {
            if (v == 'scope:visible' || v == 'scope:all') {
              await ref
                  .read(activityControllerProvider.notifier)
                  .setScope(v.substring(6));
              await _reload();
            } else if (v.startsWith('member:')) {
              final id = int.tryParse(v.substring(7));
              setState(() => _memberId = (id == null || id < 0) ? null : id);
              await _reload();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              enabled: false,
              child: Text('按成员筛选', style: McText.micro),
            ),
            PopupMenuItem(
              value: 'member:-1',
              child: Text('全部成员${_memberId == null ? ' ✓' : ''}'),
            ),
            PopupMenuItem(
              value: 'member:0',
              child: Text('超级管理员${_memberId == 0 ? ' ✓' : ''}'),
            ),
            for (final m in members)
              PopupMenuItem(
                value: 'member:${m.id}',
                child: Text('${m.displayName}${_memberId == m.id ? ' ✓' : ''}'),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              enabled: false,
              child: Text('浏览范围', style: McText.micro),
            ),
            PopupMenuItem(
              value: 'scope:visible',
              child: Text('我的浏览范围${scope != 'all' ? ' ✓' : ''}'),
            ),
            PopupMenuItem(
              value: 'scope:all',
              child: Text('全部（含范围外）${scope == 'all' ? ' ✓' : ''}'),
            ),
          ],
          child: McLiquidGlass(
            radius: McTokens.pillRadius,
            withShadow: false,
            padding: const EdgeInsets.all(8),
            child: Icon(
              McIcons.filterS,
              size: 16,
              color: (_memberId != null || scope == 'all')
                  ? McTokens.info
                  : McTokens.text,
            ),
          ),
        ),
      ],
      child: RefreshIndicator(
        color: McTokens.accentStrong,
        backgroundColor: McTokens.surfaceSolid,
        onRefresh: _reload,
        child: _error != null && _entries.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  ActivityWarningBanner(
                    message: _error!,
                    actionLabel: '重试',
                    onAction: _reload,
                  ),
                ],
              )
            : _loading && _entries.isEmpty
                ? const McLoadingView()
                : _entries.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 120),
                          McEmptyView(
                            icon: McIcons.history1,
                            title: _hiddenCount > 0
                                ? '记录均在当前浏览范围外'
                                : '暂无播放记录',
                            text: _hiddenCount > 0
                                ? '共有 $_hiddenCount 条范围外播放记录，切换到「全部」即可查看。'
                                : '成员开始播放媒体后，按场次记录会出现在这里。',
                            actionLabel: _hiddenCount > 0
                                ? '显示全部'
                                : (_memberId != null ? '查看全部成员' : null),
                            onRetry: _hiddenCount > 0
                                ? () async {
                                    await ref
                                        .read(activityControllerProvider.notifier)
                                        .setScope('all');
                                    await _reload();
                                  }
                                : (_memberId != null
                                    ? () {
                                        setState(() => _memberId = null);
                                        _reload();
                                      }
                                    : null),
                          ),
                        ],
                      )
                    : ListView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 6, bottom: 48),
                        children: [
                          for (final g in groups) ...[
                            McInsetGroup(
                              header: '${g.label}（共 ${g.items.length} 次）',
                              children: [
                                for (final entry in g.items)
                                  _buildHistoryEntryRow(entry),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_hiddenCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ActivityScopeFooter(
                                hiddenCount: _hiddenCount,
                                scope: scope,
                                hiddenText: '另有 $_hiddenCount 条范围外播放记录未显示',
                                onToggleScope: (next) async {
                                  await ref
                                      .read(activityControllerProvider.notifier)
                                      .setScope(next);
                                  await _reload();
                                },
                              ),
                            ),
                          if (_hasMore)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: McActionPill(
                                label: _loading ? '正在加载更早记录…' : '加载更多',
                                primary: false,
                                busy: _loading,
                                height: 42,
                                onTap: _loading || _cursor == null
                                    ? null
                                    : () => _load(before: _cursor),
                              ),
                            )
                          else if (_entries.length >= _pageSize)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  '已经到最早的记录了',
                                  style: McText.caption.faint,
                                ),
                              ),
                            ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildHistoryEntryRow(PlaybackLogEntry entry) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: SizedBox(
            width: 38,
            child: Text(
              activityClock(entry.startedAt),
              style: McText.caption.faint.tabular,
            ),
          ),
        ),
        Expanded(child: ActivityRecentPlayRow(entry: entry)),
      ],
    );
  }
}

// ── 子页 5：观看统计详情页（WatchStatsPage） ──

class WatchStatsPage extends ConsumerStatefulWidget {
  const WatchStatsPage({super.key});

  @override
  ConsumerState<WatchStatsPage> createState() => _WatchStatsPageState();
}

class _WatchStatsPageState extends ConsumerState<WatchStatsPage> {
  int _days = 30;
  int? _memberId;
  PlaybackWatchStatsView? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityControllerProvider.notifier).loadMembers();
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final scope = ref.read(activityControllerProvider).scope;
    try {
      final res = await ref.read(activityApiProvider).playbackWatchStats(
            days: _days,
            memberId: _memberId,
            scope: scope,
          );
      if (!mounted) return;
      setState(() {
        _stats = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _memberLabel(List<ActivityMemberOption> members) {
    if (_memberId == null) return '全部成员';
    if (_memberId == 0) return '超级管理员';
    for (final m in members) {
      if (m.id == _memberId) return m.displayName;
    }
    return '成员 #$_memberId';
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(activityControllerProvider);
    final scope = snap.scope;
    final members = snap.members;
    final subtitle =
        '最近 $_days 天 · ${_memberLabel(members)} · ${scope == 'all' ? '全部范围' : '我的浏览范围'}';

    return _SubpageScaffold(
      title: '观看统计',
      subtitle: subtitle,
      trailing: [
        McGlassIconButton(
          icon: McIcons.refreshS,
          tooltip: '刷新统计',
          onTap: _load,
        ),
      ],
      child: RefreshIndicator(
        color: McTokens.accentStrong,
        backgroundColor: McTokens.surfaceSolid,
        onRefresh: _load,
        child: _loading && _stats == null
            ? const McLoadingView()
            : _error != null && _stats == null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      ActivityWarningBanner(
                        message: _error!,
                        actionLabel: '重试',
                        onAction: _load,
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 48),
                    child: WatchStatsPanel(
                      stats: _stats ?? const PlaybackWatchStatsView(),
                      days: _days,
                      memberId: _memberId,
                      members: members,
                      scope: scope,
                      onDaysChanged: (d) async {
                        setState(() => _days = d);
                        await _load();
                      },
                      onMemberSelected: (id) async {
                        setState(() => _memberId = id);
                        await _load();
                      },
                      onScopeChanged: (next) async {
                        await ref
                            .read(activityControllerProvider.notifier)
                            .setScope(next);
                        await _load();
                      },
                    ),
                  ),
      ),
    );
  }
}
