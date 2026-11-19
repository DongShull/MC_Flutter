import 'models.dart';

/// 活动页的派生口径 —— 逐条对齐网页 lib/job-attention.ts / lib/task-activity.ts /
/// lib/download-attention.ts（Android ActivityDerive.kt 的 Flutter 对应物）。
/// **只此一处**：总览的分区行与顶部摘要行都读这里的函数。

/// 算「进行中」的任务状态（网页 ACTIVE_FEED_JOB_STATUSES）。
const activeFeedJobStatuses = {'queued', 'running', 'retry_wait', 'cancelling', 'waiting'};

/// 网页 HISTORY_JOB_STATUSES。
const _historyJobStatuses = {'succeeded', 'cancelled'};

/// 用户忽略过的失败任务不再出现（后端 dismissed_at）。
bool jobIsDismissed(JobView job) => job.dismissedAt != null;

/// 网页 jobNeedsAttention：失败且没被忽略。
bool jobNeedsAttention(JobView job) => job.status == 'failed' && !jobIsDismissed(job);

/// 网页 jobIsHistorical：已结束 = succeeded/cancelled，或失败但已被忽略。
bool jobIsHistorical(JobView job) =>
    _historyJobStatuses.contains(job.status) || (job.status == 'failed' && jobIsDismissed(job));

/// 网页 downloadTaskNeedsAttention：external 种子一律不算需要处理。
bool downloadTaskNeedsAttention(DownloadTask task, JobView? linkedIngestJob) {
  if (task.source == 'external') return false;
  return task.canReplace ||
      task.state == 'error' ||
      task.state == 'missing' ||
      (task.landingError != null && task.landingError!.isNotEmpty) ||
      task.contentMissingLabel() != null ||
      (linkedIngestJob != null && jobNeedsAttention(linkedIngestJob));
}

/// 网页 ingestJobsByHash：library.ingest 任务挂的下载资源 → info_hash。
Map<String, JobView> ingestJobsByHash(List<JobView> jobs) {
  final linked = <String, JobView>{};
  for (final job in jobs) {
    if (job.jobType != 'library.ingest') continue;
    for (final resource in job.resources) {
      final key = resource.resourceId.toLowerCase();
      if (resource.resourceType == 'download' && !linked.containsKey(key)) {
        linked[key] = job;
      }
    }
  }
  return linked;
}

/// 已串进下载生命周期的入库任务 id（既不重复渲染，也不重复计数）。
Set<String> linkedIngestJobIds(List<DownloadTask> tasks, Map<String, JobView> ingestJobs) =>
    tasks.map((t) => ingestJobs[t.infoHash.toLowerCase()]?.id).whereType<String>().toSet();

/// 网页 ingestOwnsTaskState：整包下完或入库受阻时，入库轴接管卡片主状态。
bool ingestOwnsTaskState(DownloadTask task, JobView? ingestJob) {
  if (ingestJob == null || ingestJob.status == 'cancelled') return false;
  if (jobNeedsAttention(ingestJob)) return true;
  return task.state == 'completed';
}

/// 网页 isSystemCancelled：系统取消的任务不给「重新执行」。
bool jobIsSystemCancelled(JobView job) =>
    job.status == 'cancelled' && (job.cancelRequestedBy?.startsWith('system:') ?? false);

/// 任务类型的展示名（内置类型本地文案；插件任务用服务端给的 job_type_label）。
String jobTypeLabel(JobView job) => _localJobTypeLabel(job.jobType) ?? job.jobTypeLabel ?? job.jobType;

String? _localJobTypeLabel(String jobType) => switch (jobType) {
      'subtitle.generate' => '生成 AI 字幕',
      'library.scan' => '扫描媒体库',
      'library.metadata.refresh' => '刷新媒体库元数据',
      'media.metadata.refresh' => '刷新条目元数据',
      'library.chapter_images' => '生成章节',
      'library.skip_segments' || 'media.skip_segments' => '识别片头片尾',
      'reels.clips' => '预切片段',
      'library.organize' => '整理媒体库文件',
      'library.transfer' => '转移媒体库条目',
      'library.ingest' => '自动整理入库',
      _ => null,
    };

/// 状态的展示词。
String jobStatusLabel(String status) => switch (status) {
      'queued' => '排队中',
      'running' => '进行中',
      'retry_wait' => '等待重试',
      'cancelling' => '正在取消',
      'waiting' => '等待前置任务',
      'blocked' => '需要处理',
      'succeeded' => '已完成',
      'failed' => '未完成',
      'cancelled' => '已取消',
      _ => status,
    };

/// 进行中的动作词。
String activeJobStatus(JobView job) {
  if (job.status != 'running') return jobStatusLabel(job.status);
  return switch (job.jobType) {
    'subtitle.generate' => '正在生成字幕',
    'library.scan' => '正在扫描',
    'library.metadata.refresh' => '正在刷新媒体库元数据',
    'media.metadata.refresh' => '正在刷新元数据',
    'library.chapter_images' => '正在生成章节',
    'library.skip_segments' || 'media.skip_segments' => '正在识别片头片尾',
    'reels.clips' => '正在预切片段',
    'library.organize' => '正在整理文件',
    'library.transfer' => '正在转移文件',
    'library.ingest' => '正在入库',
    _ => '正在处理',
  };
}

/// 已完成任务的动作名（网页 COMPLETED_JOB_ACTIONS）。
const _completedJobActions = {
  'subtitle.generate': '字幕生成',
  'library.scan': '扫描',
  'library.metadata.refresh': '元数据刷新',
  'media.metadata.refresh': '元数据刷新',
  'library.chapter_images': '章节生成',
  'library.skip_segments': '片头片尾识别',
  'media.skip_segments': '片头片尾识别',
  'reels.clips': '片段预切',
  'library.organize': '文件整理',
  'library.transfer': '文件转移',
  'library.ingest': '入库',
};

/// 网页 jobFeedIdentity：书名号里的片名优先。
String? _feedIdentity(JobView job) {
  final quoted = RegExp('《([^》]+)》').firstMatch(job.progress.message)?.group(1);
  final title = quoted ??
      job.detailString('media_title') ??
      job.detailString('title') ??
      job.subject;
  if (title == null) return null;
  if (title.startsWith('《') || title.startsWith('「')) return title;
  if (job.jobType == 'library.scan') return '「$title」';
  if (job.jobType == 'library.ingest' ||
      job.jobType == 'subtitle.generate' ||
      job.jobType.contains('metadata.refresh')) {
    return '《$title》';
  }
  return title;
}

/// 网页 historicalJobTitle：身份 + 动作 + 结果。
String historicalJobTitle(JobView job) {
  final identity = _feedIdentity(job);
  final action = _completedJobActions[job.jobType];
  // 忽略只是"不再提醒"，历史里如实写「未完成」。
  final result = switch (job.status) {
    'cancelled' => '已取消',
    'failed' => '未完成',
    _ => '完成',
  };
  if (identity != null && action != null) return '$identity$action$result';
  return '${identity ?? jobTypeLabel(job)}$result';
}

/// 网页 historicalJobSummary。
String historicalJobSummary(JobView job) {
  if (job.jobType == 'library.scan') {
    final parts = <String>[
      if (job.detailString('identified') != null) '识别 ${job.detailString('identified')} 个',
      if (job.detailString('unidentified') != null) '待识别 ${job.detailString('unidentified')} 个',
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
  }
  if (job.status == 'failed' && jobIsDismissed(job)) {
    final msg = (job.error?.message.isNotEmpty ?? false)
        ? job.error!.message
        : job.progress.message;
    return msg.isNotEmpty ? msg : '任务失败，已被忽略';
  }
  if (job.progress.message.isNotEmpty) return job.progress.message;
  return job.status == 'cancelled' ? '任务已取消' : '任务已完成';
}

/// 历史任务的一天（网页 HistoryDayGroup）：按结束那一刻所在自然日分组。
class JobDayGroup {
  JobDayGroup({required this.key, required this.label, required this.jobs});

  final String key;
  final String label;
  final List<JobView> jobs;
}

DateTime? _parseIso(String? iso) =>
    iso == null || iso.isEmpty ? null : DateTime.tryParse(iso);

String _dayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

String _dayLabel(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  return '${t.month} 月 ${t.day} 日';
}

/// 网页 groupHistoricalJobs：组内保持原顺序（接口已按更新时间倒序返回）。
List<JobDayGroup> groupHistoricalJobs(List<JobView> jobs) {
  final groups = <String, JobDayGroup>{};
  for (final job in jobs) {
    final stamp = _parseIso(job.finishedAt) ?? _parseIso(job.createdAt);
    if (stamp == null) continue;
    final key = _dayKey(stamp);
    final existing = groups[key];
    if (existing != null) {
      groups[key] = JobDayGroup(key: key, label: existing.label, jobs: [...existing.jobs, job]);
    } else {
      groups[key] = JobDayGroup(key: key, label: _dayLabel(stamp), jobs: [job]);
    }
  }
  return groups.values.toList();
}

/// 一个下载分组（网页 DownloadTaskGroup）：只用媒体条目主键合并。
class DownloadGroup {
  DownloadGroup({
    required this.key,
    required this.title,
    this.kind,
    this.posterUrl,
    required this.tasks,
  });

  final String key;
  final String title;
  final String? kind;
  final String? posterUrl;
  final List<DownloadTask> tasks;
}

/// 网页 groupDownloadTasks：未识别资源独立卡片，不按相似标题合并。
List<DownloadGroup> groupDownloadTasks(List<DownloadTask> tasks) {
  final groups = <String, DownloadGroup>{};
  for (final task in tasks) {
    final key = task.mediaItemId != null ? 'media:${task.mediaItemId}' : 'task:${task.id}';
    final existing = groups[key];
    if (existing != null) {
      groups[key] = DownloadGroup(
        key: key,
        title: existing.title,
        kind: existing.kind,
        posterUrl: existing.posterUrl ?? task.posterUrl,
        tasks: [...existing.tasks, task],
      );
      continue;
    }
    groups[key] = DownloadGroup(
      key: key,
      title: task.mediaTitle ?? task.name ?? task.infoHash,
      kind: task.mediaKind,
      posterUrl: task.posterUrl,
      tasks: [task],
    );
  }
  return groups.values.toList();
}

/// 网页 downloadGroupNeedsAttention：组里有一条需要处理，整组就是需要处理。
bool downloadGroupNeedsAttention(DownloadGroup group, Map<String, JobView> ingestJobs) =>
    group.tasks.any((t) => downloadTaskNeedsAttention(t, ingestJobs[t.infoHash.toLowerCase()]));

/// 活动总览的全部派生结果（网页 useTaskActivity 的返回）。
class TaskActivity {
  TaskActivity({
    required this.ingestJobs,
    required this.attentionGroups,
    required this.activeGroups,
    required this.attentionJobs,
    required this.activeJobs,
    required this.historyJobs,
  });

  final Map<String, JobView> ingestJobs;
  final List<DownloadGroup> attentionGroups;
  final List<DownloadGroup> activeGroups;
  final List<JobView> attentionJobs;
  final List<JobView> activeJobs;
  final List<JobView> historyJobs;

  int get attentionTotal => attentionGroups.length + attentionJobs.length;
  int get activeTotal => activeGroups.length + activeJobs.length;
}

/// 分流顺序照网页：先摘掉刷流（boost），再按是否需要处理分成两拨；
/// 入库任务若已串进某个种子，就不再单独出现。
TaskActivity deriveTaskActivity(List<DownloadTask> tasks, List<JobView> jobs) {
  final ingestJobs = ingestJobsByHash(jobs);
  final linked = linkedIngestJobIds(tasks, ingestJobs);
  // 刷流常年大量在跑，计入会让数字失去意义，先行分流。
  final groups = groupDownloadTasks(tasks.where((t) => t.source != 'boost').toList());
  final standalone = jobs.where((j) => !linked.contains(j.id)).toList();
  return TaskActivity(
    ingestJobs: ingestJobs,
    attentionGroups:
        groups.where((g) => downloadGroupNeedsAttention(g, ingestJobs)).toList(),
    activeGroups:
        groups.where((g) => !downloadGroupNeedsAttention(g, ingestJobs)).toList(),
    attentionJobs: standalone.where(jobNeedsAttention).toList(),
    activeJobs: standalone.where((j) => activeFeedJobStatuses.contains(j.status)).toList(),
    historyJobs: standalone.where(jobIsHistorical).toList(),
  );
}
