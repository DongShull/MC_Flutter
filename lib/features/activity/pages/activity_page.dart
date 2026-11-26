import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../state/activity_derive.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../widgets/watch_stats_panel.dart';

/// 活动页（Tab 4，1:1 对齐 iOS `ActivityView.swift` & 参考图 `scene-3.zh.jpg`）：
/// - 纯黑无界画布 + 左上 `30sp Bold`「活动」大标题 + 右侧玻璃刷新圆钮与搜索圆钮；
/// - 紧随标题下的一行实时状态摘要（如 `4 台设备在播放 · 1 个下载进行中`）；
/// - 按紧急度自上而下排列 `McInsetGroup` 圆角卡片组：
///   `● 需要处理`（红点）→ `● 正在播放`（绿点）→ `● 正在下载`（蓝点）→ `进行中` → `最近播放` → `观看统计` → `最近完成`。
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
    final watching = playback?.sessions.length ?? 0;
    final historyTotal = activity.historyJobs.length;
    final downloading = playback?.downloads.length ?? 0;

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
              const SliverFillRemaining(
                hasScrollBody: false,
                child: McLoadingView(),
              )
            else
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: wide ? 760 : double.infinity,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 120),
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
                              child: _WarningBanner(message: snapshot.error!),
                            ),
                          if (activity.attentionTotal > 0)
                            _DashboardSection(
                              title: '需要处理',
                              dotColor: McTokens.danger,
                              count: activity.attentionTotal,
                              trailingText: _hasFailed(activity)
                                  ? '全部清除'
                                  : null,
                              onTrailingTap: _hasFailed(activity)
                                  ? () => _guard(_controller.dismissAllJobs)
                                  : null,
                              rows: [
                                for (final group in activity.attentionGroups)
                                  _ActiveDownloadRow(
                                    group: group,
                                    onReplace:
                                        group.tasks.length == 1 &&
                                            group.tasks.first.downloaderId !=
                                                null
                                        ? () => _guard(
                                            () => _controller
                                                .replaceDownloadTask(
                                                  group.tasks.first,
                                                ),
                                          )
                                        : null,
                                    onDelete:
                                        group.tasks.length == 1 &&
                                            group.tasks.first.downloaderId !=
                                                null
                                        ? () => _guard(
                                            () => _controller
                                                .deleteDownloadTask(
                                                  group.tasks.first,
                                                ),
                                          )
                                        : null,
                                  ),
                                for (final job in activity.attentionJobs)
                                  _ActiveJobRow(
                                    job: job,
                                    onAskAi: () async {
                                      final sid = await _controller
                                          .handoffJobToAi(job);
                                      if (!context.mounted) return;
                                      if (sid != null && sid.isNotEmpty) {
                                        context.push('/agent/session/$sid');
                                      } else {
                                        context.push('/agent/new');
                                      }
                                    },
                                    onCancel: () => _guard(
                                      () => _controller.cancelJob(job.id),
                                    ),
                                    onDismiss: () => _guard(
                                      () => _controller.dismissJob(job.id),
                                    ),
                                  ),
                              ],
                            ),
                          if (playback != null && playback.sessions.isNotEmpty)
                            _DashboardSection(
                              title: '正在播放',
                              dotColor: McTokens.ok,
                              count: playback.sessions.length,
                              rows: [
                                for (final session in playback.sessions)
                                  _SessionRow(
                                    session: session,
                                    onEnd: () => _guard(
                                      () => _controller.endPlaybackSession(
                                        session.deviceId,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          if (playback != null && playback.downloads.isNotEmpty)
                            _DashboardSection(
                              title: '正在下载',
                              dotColor: McTokens.info,
                              count: playback.downloads.length,
                              rows: [
                                for (final download in playback.downloads)
                                  _FileDownloadRow(download: download),
                              ],
                            ),
                          if (activity.activeTotal > 0)
                            _DashboardSection(
                              title: '进行中',
                              dotColor: McTokens.info,
                              count: activity.activeTotal,
                              rows: [
                                for (final group in activity.activeGroups)
                                  _ActiveDownloadRow(
                                    group: group,
                                    onDelete:
                                        group.tasks.length == 1 &&
                                            group.tasks.first.downloaderId !=
                                                null
                                        ? () => _guard(
                                            () => _controller
                                                .deleteDownloadTask(
                                                  group.tasks.first,
                                                ),
                                          )
                                        : null,
                                  ),
                                for (final job in activity.activeJobs)
                                  _ActiveJobRow(
                                    job: job,
                                    onCancel:
                                        job.status == 'queued' ||
                                            job.status == 'running' ||
                                            job.status == 'retry_wait'
                                        ? () => _guard(
                                            () => _controller.cancelJob(job.id),
                                          )
                                        : null,
                                  ),
                              ],
                            ),
                          if (!snapshot.historyForbidden &&
                              snapshot.history != null &&
                              snapshot.history!.entries.isNotEmpty)
                            _DashboardSection(
                              title: '最近播放',
                              rows: [
                                for (final entry
                                    in snapshot.history!.entries.take(6))
                                  _RecentPlayRow(entry: entry),
                              ],
                            ),
                          if (!snapshot.statsForbidden &&
                              snapshot.watchStats != null)
                            _DashboardSection(
                              title: '观看统计',
                              customChild: WatchStatsPanel(
                                stats: snapshot.watchStats!,
                                days: snapshot.watchStatsDays,
                                memberId: snapshot.watchStatsMemberId,
                                onDaysChanged: (d) => _guard(
                                  () => _controller.setWatchStatsDays(d),
                                ),
                                onMemberSelected: (id) => _guard(
                                  () => _controller.setWatchStatsMember(id),
                                ),
                              ),
                            ),
                          if (activity.historyJobs.isNotEmpty)
                            _DashboardSection(
                              title: '最近完成',
                              count: activity.historyJobs.length,
                              trailingText: _showAllFinished
                                  ? null
                                  : '查看全部 $historyTotal',
                              onTrailingTap: _showAllFinished
                                  ? null
                                  : () => setState(
                                      () => _showAllFinished = true,
                                    ),
                              rows: [
                                for (final job in _showAllFinished
                                    ? activity.historyJobs
                                    : activity.historyJobs.take(5))
                                  _FinishedJobRow(
                                    job: job,
                                    onUndismiss:
                                        job.status == 'failed' &&
                                            jobIsDismissed(job)
                                        ? () => _guard(
                                            () => _controller.undismissJob(
                                              job.id,
                                            ),
                                          )
                                        : null,
                                    onRetry:
                                        job.status == 'cancelled' &&
                                            !jobIsDismissed(job)
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
}

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
    if (active > 0) add('$active 个后台任务');
    if (spans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          McTokens.pagePadding,
          4,
          McTokens.pagePadding,
          4,
        ),
        child: Text('一切正常 · 当前无活动会话', style: base),
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

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x1FFF6B6B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x4DFF6B6B), width: 1),
      ),
      child: Row(
        children: [
          const Icon(McIcons.alert1, color: McTokens.danger, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: McText.caption.copyWith(color: McTokens.danger),
            ),
          ),
        ],
      ),
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
  });

  final String title;
  final Color? dotColor;
  final int? count;
  final String? trailingText;
  final VoidCallback? onTrailingTap;
  final List<Widget> rows;
  final Widget? customChild;

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
        else
          McInsetGroup(children: rows),
      ],
    );
  }
}

/// 正在播放会话精排行（对齐 `scene-3.zh.jpg`：圆角小海报 + 四行紧凑指标 + 左滑终止会话）。
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onEnd});

  final ActivePlaybackSession session;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    final media = session.media;
    final poster = McImageUrls.resolve(media.posterUrl, widthPx: 140);
    final posMs = session.positionMs ?? 0;
    final durMs = session.durationMs ?? 0;
    final progress = (posMs > 0 && durMs > 0)
        ? (posMs / durMs).clamp(0.0, 1.0)
        : null;
    final pct = progress != null ? '${(progress * 100).round()}%' : null;
    final who = session.memberName.isNotEmpty
        ? session.memberName
        : session.client;
    final epLabel = mcEpisodeLabel(media.seasonNumber, media.episodeNumber);
    final episode = media.seasonNumber > 0 ? ' · $epLabel' : '';
    final speed =
        (session.rateBytesPerSecond != null && session.rateBytesPerSecond! > 0)
        ? '↓ ${mcFormatSpeed(session.rateBytesPerSecond!)}'
        : null;

    return Dismissible(
      key: ValueKey('play-session-${session.deviceId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await onEnd();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: McTokens.danger,
        child: const Icon(McIcons.stopCircle, color: Colors.white, size: 20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PosterThumb(url: poster, width: 52, height: 76),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (media.title.isEmpty ? '未知内容' : media.title) +
                              episode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.sub
                              .copyWith(
                                color: McTokens.text,
                                fontWeight: FontWeight.w600,
                              )
                              .tabular,
                        ),
                      ),
                      const SizedBox(width: 8),
                      McPressable(
                        onTap: onEnd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1FFF6B6B),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0x40FF6B6B),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '结束',
                            style: McText.micro.copyWith(
                              color: McTokens.danger,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (who.isNotEmpty) who,
                      if (session.deviceName.isNotEmpty) session.deviceName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: session.paused
                              ? McTokens.surfaceInset
                              : const Color(0x1F4ADE80),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: session.paused
                                ? McTokens.line
                                : const Color(0x4D4ADE80),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          session.paused ? '已暂停' : '直连',
                          style: McText.micro.copyWith(
                            color: session.paused
                                ? McTokens.textMuted
                                : McTokens.ok,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        [
                          session.paused ? '❚❚ 暂停' : '▶ 播放中',
                          if (pct != null) pct,
                        ].join(' · '),
                        style: McText.caption.muted.tabular,
                      ),
                      const Spacer(),
                      if (speed != null)
                        Text(
                          speed,
                          style: McText.micro
                              .copyWith(
                                color: McTokens.info,
                                fontWeight: FontWeight.w500,
                              )
                              .tabular,
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      color: session.paused
                          ? McTokens.textFaint
                          : McTokens.accentStrong,
                      backgroundColor: const Color(0x26FFFFFF),
                    ),
                  ),
                  if (durMs > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mcFormatClock(posMs ~/ 1000),
                          style: McText.micro
                              .copyWith(
                                fontWeight: FontWeight.w400,
                                color: McTokens.textFaint,
                              )
                              .tabular,
                        ),
                        Text(
                          mcFormatClock(durMs ~/ 1000),
                          style: McText.micro
                              .copyWith(
                                fontWeight: FontWeight.w400,
                                color: McTokens.textFaint,
                              )
                              .tabular,
                        ),
                      ],
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
}

class _ActiveDownloadRow extends StatelessWidget {
  const _ActiveDownloadRow({
    required this.group,
    this.onReplace,
    this.onDelete,
  });

  final DownloadGroup group;
  final Future<void> Function()? onReplace;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final task = group.tasks.first;
    final percent = (task.progress ?? 0) * 100;
    final taskCount = group.tasks.length;
    final pct = percent.floor();
    final isError = task.state == 'error';
    final stateLine = switch (task.state) {
      'downloading' => '下载中',
      'paused' => '已暂停',
      'stalled' => '等待连接',
      'checking' => '校验中',
      'completed' => '已完成',
      'error' => task.errorMessage ?? '下载出错',
      _ => task.state,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            task.state == 'downloading'
                ? McIcons.downloadCloudOut
                : task.state == 'paused' || task.state == 'stalled'
                ? McIcons.pause
                : isError
                ? McIcons.alert1
                : McIcons.clock,
            size: 19,
            color: isError ? McTokens.danger : McTokens.info,
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
                    if (taskCount > 1)
                      Text(' $taskCount 项', style: McText.caption.faint.tabular),
                    const SizedBox(width: 8),
                    Text(
                      '$pct%',
                      style: McText.caption
                          .copyWith(
                            color: McTokens.textMuted,
                            fontWeight: FontWeight.w600,
                          )
                          .tabular,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  stateLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.copyWith(
                    color: isError ? McTokens.danger : McTokens.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: percent.clamp(0.0, 100.0) / 100,
                    minHeight: 3,
                    color: isError ? McTokens.danger : McTokens.info,
                    backgroundColor: const Color(0x26FFFFFF),
                  ),
                ),
              ],
            ),
          ),
          if (onReplace != null && isError) ...[
            const SizedBox(width: 8),
            McChip(
              label: '换源重抓',
              compact: true,
              onTap: onReplace,
            ),
          ],
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            McGlassIconButton(
              icon: McIcons.trash2,
              size: 32,
              iconSize: 15,
              iconColor: McTokens.danger,
              tooltip: '删除任务',
              onTap: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveJobRow extends StatelessWidget {
  const _ActiveJobRow({
    required this.job,
    this.onAskAi,
    this.onCancel,
    this.onDismiss,
  });

  final JobView job;
  final VoidCallback? onAskAi;
  final Future<void> Function()? onCancel;
  final Future<void> Function()? onDismiss;

  @override
  Widget build(BuildContext context) {
    final percent = job.progress.percent;
    final needsAttention = jobNeedsAttention(job);
    final pct = percent?.round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            needsAttention ? McIcons.alert1 : McIcons.setting1,
            size: 18,
            color: needsAttention ? McTokens.danger : McTokens.info,
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
                        style: McText.sub.copyWith(
                          color: McTokens.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (pct != null)
                      Text(
                        '$pct%',
                        style: McText.caption.muted.tabular,
                      ),
                  ],
                ),
                if (job.progress.message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    job.progress.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                ],
                if (!needsAttention && percent != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 100.0) / 100,
                      minHeight: 3,
                      color: McTokens.info,
                      backgroundColor: const Color(0x26FFFFFF),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onAskAi != null && needsAttention) ...[
            const SizedBox(width: 6),
            McChip(
              icon: McIcons.aiStarFill,
              label: 'AI 排查',
              compact: true,
              onTap: onAskAi,
            ),
          ],
          if (onCancel != null) ...[
            const SizedBox(width: 6),
            McGlassIconButton(
              icon: McIcons.close,
              size: 32,
              iconSize: 15,
              tooltip: '取消',
              onTap: onCancel,
            ),
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: 6),
            McGlassIconButton(
              icon: McIcons.eyeOff,
              size: 32,
              iconSize: 15,
              tooltip: '忽略',
              onTap: onDismiss,
            ),
          ],
        ],
      ),
    );
  }
}

class _FileDownloadRow extends StatelessWidget {
  const _FileDownloadRow({required this.download});

  final ActiveFileDownload download;

  @override
  Widget build(BuildContext context) {
    final media = download.media;
    final who = download.memberName.isNotEmpty
        ? download.memberName
        : download.deviceName;
    final percent = download.progressPercent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            McIcons.downloadCloudOut,
            size: 19,
            color: McTokens.info,
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
                  style: McText.sub.copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (who.isNotEmpty) who,
                    mcFormatBytes(download.sizeBytes),
                    if (download.rateBytesPerSecond != null &&
                        download.rateBytesPerSecond! > 0)
                      '↓ ${mcFormatSpeed(download.rateBytesPerSecond!)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.caption.muted.tabular,
                ),
                if (percent != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 100.0) / 100,
                      minHeight: 3,
                      color: McTokens.info,
                      backgroundColor: const Color(0x26FFFFFF),
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

class _RecentPlayRow extends StatelessWidget {
  const _RecentPlayRow({required this.entry});

  final PlaybackLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final media = entry.media;
    final poster = McImageUrls.resolve(media.posterUrl, widthPx: 120);
    final epLabel = mcEpisodeLabel(media.seasonNumber, media.episodeNumber);
    final episode = media.seasonNumber > 0 ? ' · $epLabel' : '';
    final lid = media.libraryId;
    final mid = media.mediaItemId;
    final year = media.year;
    final right = entry.completed
        ? '已看完'
        : entry.watchedMs > 0
        ? mcFormatWatched(entry.watchedMs)
        : '';

    return McPressable(
      onTap: lid == null ? null : () => context.push('/detail/$lid/$mid'),
      scaleDown: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _PosterThumb(url: poster, width: 38, height: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (media.title.isEmpty ? '已移除条目' : media.title) + episode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.sub
                        .copyWith(
                          color: McTokens.text,
                          fontWeight: FontWeight.w600,
                        )
                        .tabular,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (entry.memberName.isNotEmpty) entry.memberName,
                      if (year != null) '$year',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted.tabular,
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
                    style: McText.caption
                        .copyWith(
                          color: entry.completed
                              ? McTokens.ok
                              : McTokens.textMuted,
                          fontWeight: FontWeight.w600,
                        )
                        .tabular,
                  ),
                Text(
                  _relative(entry.startedAt),
                  style: McText.micro
                      .copyWith(
                        fontWeight: FontWeight.w400,
                        color: McTokens.textFaint,
                      )
                      .tabular,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishedJobRow extends StatelessWidget {
  const _FinishedJobRow({required this.job, this.onUndismiss, this.onRetry});

  final JobView job;
  final Future<void> Function()? onUndismiss;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final dismissed = job.status == 'failed' && jobIsDismissed(job);
    final (iconData, iconColor) = job.status == 'succeeded'
        ? (McIcons.checkCircleFill, McTokens.ok)
        : dismissed
        ? (McIcons.eyeOff, McTokens.textFaint)
        : (McIcons.closeCircle, McTokens.textFaint);
    final summary = historicalJobSummary(job);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(iconData, size: 18, color: iconColor),
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
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _relative(job.finishedAt ?? job.createdAt),
            style: McText.caption.faint.tabular,
          ),
          if (onUndismiss != null) ...[
            const SizedBox(width: 6),
            McGlassIconButton(
              icon: McIcons.clockwise,
              size: 30,
              iconSize: 15,
              tooltip: '恢复显示',
              onTap: onUndismiss,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(width: 6),
            McGlassIconButton(
              icon: McIcons.replay,
              size: 30,
              iconSize: 15,
              tooltip: '重新执行',
              onTap: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

class _PosterThumb extends StatelessWidget {
  const _PosterThumb({
    required this.url,
    required this.width,
    required this.height,
  });

  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: McTokens.posterPlaceholder,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              httpHeaders: mcImageHeaders(),
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Center(
                child: Icon(McIcons.film, size: 16, color: McTokens.textFaint),
              ),
            )
          : const Center(
              child: Icon(McIcons.film, size: 16, color: McTokens.textFaint),
            ),
    );
  }
}
