import '../../../core/models/format.dart';
import 'models.dart';

/// 活动页的派生口径 —— 1:1 对齐 iOS `TaskCenterLogic.swift` & Web `job-attention.ts` / `task-activity.ts`。
/// **只此一处**：总览的分区行、二级页与顶部摘要行都读这里的函数。

/// 需要用户判断的 Job 状态（含 `blocked` 与 `failed`）。
const attentionJobStatuses = {'blocked', 'failed'};

/// 算「进行中」的任务状态（网页 ACTIVE_FEED_JOB_STATUSES）。
const activeFeedJobStatuses = {
  'queued',
  'running',
  'retry_wait',
  'cancelling',
  'waiting',
};

/// 网页 HISTORY_JOB_STATUSES。
const _historyJobStatuses = {'succeeded', 'cancelled'};

/// 有自动来源的任务类型：忽略时可连来源一起静音（当前为字幕自动生成）。
const autoRecreatedJobTypes = <String, String>{
  'subtitle.generate': '这集不再自动生成字幕',
};

/// Job 错误动作里 App 能执行的类型。
const supportedErrorActions = <String>{
  'retry_job',
  'open_settings',
  'inspect_logs',
  'update_runtime',
  'handoff_agent',
};

/// 用户忽略过的失败任务不再出现（后端 dismissed_at）。
bool jobIsDismissed(JobView job) => job.dismissedAt != null;

/// 需要用户处理的 Job：blocked / failed 且没被忽略。
bool jobNeedsAttention(JobView job) =>
    attentionJobStatuses.contains(job.status) && !jobIsDismissed(job);

/// 已结束的 Job：succeeded/cancelled，或失败但已被忽略。
bool jobIsHistorical(JobView job) =>
    _historyJobStatuses.contains(job.status) ||
    (job.status == 'failed' && jobIsDismissed(job));

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

/// 只有进入救援窗口且仍能定位下载器任务时，才提供「立即换种」。
bool shouldOfferInlineReplacement(DownloadTask task) =>
    task.canReplace && task.downloaderId != null;

/// 是否为洗版任务。
bool isUpgradeTask(DownloadTask task) =>
    task.subscriptions.firstOrNull?.purpose == 'upgrade';

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
Set<String> linkedIngestJobIds(
  List<DownloadTask> tasks,
  Map<String, JobView> ingestJobs,
) =>
    tasks
        .map((t) => ingestJobs[t.infoHash.toLowerCase()]?.id)
        .whereType<String>()
        .toSet();

/// 网页 ingestOwnsTaskState：整包下完或入库受阻时，入库轴接管卡片主状态。
bool ingestOwnsTaskState(DownloadTask task, JobView? ingestJob) {
  if (ingestJob == null || ingestJob.status == 'cancelled') return false;
  if (jobNeedsAttention(ingestJob)) return true;
  return task.state == 'completed';
}

/// 系统取消的任务（`system:` 前缀）不给「重新执行」。
bool jobIsSystemCancelled(JobView job) =>
    job.status == 'cancelled' &&
    (job.cancelRequestedBy?.startsWith('system:') ?? false);

/// 任务类型的展示名（内置类型本地文案；插件任务用服务端给的 job_type_label）。
String jobTypeLabel(JobView job) =>
    _localJobTypeLabel(job.jobType) ??
    ((job.jobTypeLabel?.isNotEmpty ?? false) ? job.jobTypeLabel! : job.jobType);

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

/// 阶段展示词。
String jobPhaseLabel(String phase) => switch (phase) {
      'queued' => '排队中',
      'preparing' => '准备中',
      'ocr' => '字幕识别 (OCR)',
      'syncing' => '时间轴同步',
      'glossary' => '提取术语表',
      'translating' => 'AI 翻译中',
      'validating' => '质量校验',
      'compressing' => '压缩处理',
      'writing' => '写入文件',
      'refreshing' => '刷新元数据',
      'walking' => '扫描目录',
      'ingesting' => '整理入库',
      'probing' => '探测媒体信息',
      'assets' => '下载海报与素材',
      'analyzing' => '分析音视频',
      'organizing' => '整理文件',
      'transferring' => '搬运文件',
      'identifying' => '识别作品',
      'waiting_library' => '等待媒体库空闲',
      'waiting_stable' => '等待文件稳定',
      'finalizing' => '收尾归档',
      'retry_wait' => '等待重试',
      'blocked' => '已阻塞',
      'completed' => '已完成',
      'cancelled' => '已取消',
      _ => phase,
    };

const _languageLabels = <String, String>{
  'chs': '简体中文',
  'cht': '繁体中文',
  'eng': '英语',
  'jpn': '日语',
  'kor': '韩语',
  'fre': '法语',
  'ger': '德语',
  'spa': '西班牙语',
  'ita': '意大利语',
  'por': '葡萄牙语',
  'rus': '俄语',
  'tha': '泰语',
};

/// 字幕目标语言展示（「简体中文 + 英语（双语）」）。
String? subtitleLanguageLabel(JobView job) {
  if (job.jobType != 'subtitle.generate') return null;
  final target = job.detailString('target_language');
  if (target == null) return null;
  final primary = _languageLabels[target] ?? target;
  final secondary = job.detailString('secondary_language');
  if (secondary == null) return primary;
  return '$primary + ${_languageLabels[secondary] ?? secondary}（双语）';
}

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

/// 网页 jobFeedIdentity：结构化参数 / 书名号里的片名优先。
String? jobFeedIdentity(JobView job) {
  final structured = job.progress.messageParams['title']?.toString();
  final quoted =
      RegExp('《([^》]+)》').firstMatch(job.progress.message)?.group(1);
  final title = (structured != null && structured.isNotEmpty)
      ? structured
      : (quoted ??
          job.detailString('media_title') ??
          job.detailString('title') ??
          job.subject);
  if (title == null || title.isEmpty) return null;
  if (title.startsWith('《') || title.startsWith('「')) return title;
  if (job.jobType == 'library.scan') return '「$title」';
  if (job.jobType == 'library.ingest' ||
      job.jobType == 'subtitle.generate' ||
      job.jobType.contains('metadata.refresh')) {
    return '《$title》';
  }
  return title;
}

/// 卡片进度条下的处理量。
String? cardProgressAmount(JobView job) {
  final current = job.progress.current;
  final total = job.progress.total;
  if (current == null || total == null) return null;
  if (job.jobType == 'library.ingest') {
    return '${mcFormatBytes(current)} / ${mcFormatBytes(total)}';
  }
  return switch (job.jobType) {
    'subtitle.generate' => '$current / $total 段',
    'library.scan' || 'library.organize' => '$current / $total 个文件',
    'library.transfer' => '$current / $total 个路径',
    'media.metadata.refresh' => '$current / $total 张图片',
    'library.metadata.refresh' => '$current / $total 个条目',
    _ => '$current / $total',
  };
}

/// 任务卡片页脚发起方。
String cardOriginLabel(JobView job) {
  final origin = switch (job.origin) {
    'cli' => 'CLI',
    'agent' => 'AI 助手',
    'scheduler' || 'system' => '系统',
    _ => '网页',
  };
  final actor = job.actorName;
  return (actor != null && actor.isNotEmpty) ? '$origin · $actor' : origin;
}

/// 历史任务标题：身份 + 动作 + 结果。
String historicalJobTitle(JobView job) {
  final identity = jobFeedIdentity(job);
  final action = _completedJobActions[job.jobType];
  final result = switch (job.status) {
    'cancelled' => '已取消',
    'failed' => '未完成',
    _ => '完成',
  };
  if (identity != null && action != null) return '$identity$action$result';
  return '${identity ?? jobTypeLabel(job)}$result';
}

/// 历史任务摘要。
String historicalJobSummary(JobView job) {
  if (job.jobType == 'library.scan') {
    final identified = _num(job.progress.details, 'identified')?.toInt();
    final unidentified = _num(job.progress.details, 'unidentified')?.toInt();
    final parts = <String>[
      if (identified != null) '识别 $identified 个',
      if (unidentified != null) '待识别 $unidentified 个',
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

/// 卡片上的领域明细小标签（最多 4 个，alert 为琥珀色）。
class JobDetailItem {
  const JobDetailItem({required this.label, this.alert = false});

  final String label;
  final bool alert;
}

bool succeededWithProblems(JobView job) =>
    job.status == 'succeeded' && jobDetailItems(job).any((d) => d.alert);

List<JobDetailItem> jobDetailItems(JobView job) {
  final d = job.progress.details;
  final items = <JobDetailItem>[];
  int? intVal(String key) => _num(d, key)?.toInt();

  switch (job.jobType) {
    case 'subtitle.generate':
      final lang = subtitleLanguageLabel(job);
      if (lang != null) items.add(JobDetailItem(label: lang));
      final done = intVal('done_events');
      final total = intVal('total_events');
      if (done != null && total != null && total != 0) {
        items.add(JobDetailItem(label: '字幕 $done/$total 条'));
      }
      if (d['uses_ocr'] == true) {
        items.add(const JobDetailItem(label: 'PGS OCR'));
      }
      final par = intVal('parallelism');
      if (par != null && par > 1) {
        items.add(JobDetailItem(label: '$par 路并行'));
      }
      final limits = intVal('rate_limit_count');
      if (limits != null && limits != 0) {
        items.add(JobDetailItem(label: '限流重试 $limits 次', alert: true));
      }
      break;
    case 'library.scan':
      final idf = intVal('identified');
      if (idf != null && idf != 0) {
        items.add(JobDetailItem(label: '识别 $idf 个'));
      }
      final probed = intVal('probed');
      if (probed != null && probed != 0) {
        items.add(JobDetailItem(label: '探测 $probed 个'));
      }
      final unidf = intVal('unidentified');
      if (unidf != null && unidf != 0) {
        items.add(JobDetailItem(label: '待识别 $unidf 个', alert: true));
      }
      final missing = intVal('marked_missing');
      if (missing != null && missing != 0) {
        items.add(JobDetailItem(label: '缺失 $missing 个', alert: true));
      }
      final errs = _countVal(d, 'errors');
      if (errs != 0) {
        items.add(JobDetailItem(label: '$errs 处异常', alert: true));
      }
      break;
    case 'library.organize':
      final errs = _countVal(d, 'errors');
      if (errs != 0) {
        items.add(JobDetailItem(label: '$errs 处异常', alert: true));
      }
      break;
    case 'library.transfer':
      final moved = _num(d, 'bytes_moved');
      final totalBytes = _num(d, 'total_bytes');
      if (moved != null && moved != 0) {
        items.add(JobDetailItem(label: '已搬运 ${mcFormatBytes(moved)}'));
      } else if (totalBytes != null && totalBytes != 0) {
        items.add(JobDetailItem(label: '共 ${mcFormatBytes(totalBytes)}'));
      }
      if (d['cross_device'] == true) {
        items.add(const JobDetailItem(label: '跨盘复制'));
      }
      break;
    case 'library.ingest':
      final fn = _str(d, 'file_name');
      if (fn != null) items.add(JobDetailItem(label: fn));
      break;
    case 'library.metadata.refresh':
    case 'media.metadata.refresh':
      final failed = intVal('failed');
      if (failed != null && failed != 0) {
        items.add(JobDetailItem(label: '未完成 $failed 项', alert: true));
      }
      final images = d['images'] is Map
          ? Map<String, dynamic>.from(d['images'] as Map)
          : const <String, dynamic>{};
      int img(String k) => _num(images, k)?.toInt() ?? 0;
      if (img('failed') != 0) {
        items.add(JobDetailItem(label: '图片失败 ${img('failed')} 张', alert: true));
      }
      if (img('downloaded') != 0) {
        final sz = mcFormatBytes(_num(images, 'bytes') ?? 0);
        items.add(JobDetailItem(label: '下载图片 ${img('downloaded')} 张（$sz）'));
      }
      if (img('reused') != 0) {
        items.add(JobDetailItem(label: '沿用 ${img('reused')} 张'));
      }
      if (img('adopted') != 0) {
        items.add(JobDetailItem(label: '收纳 ${img('adopted')} 张'));
      }
      if (img('derived') != 0) {
        items.add(JobDetailItem(label: '派生 ${img('derived')} 张'));
      }
      if (img('grabbed') != 0) {
        items.add(JobDetailItem(label: '抓帧 ${img('grabbed')} 张'));
      }
      break;
    default:
      break;
  }
  return items.take(4).toList();
}

/// 字幕任务的 LLM Token 用量汇总（对齐 iOS `TaskCenter.UsageSummary`）。
class SubtitleUsageSummary {
  const SubtitleUsageSummary({
    required this.requests,
    required this.failedRequests,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.cacheReadTokens,
    required this.totalDurationMs,
    required this.maxDurationMs,
  });

  final int requests;
  final int failedRequests;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int cacheReadTokens;
  final double totalDurationMs;
  final double maxDurationMs;
}

SubtitleUsageSummary? subtitleUsageSummary(JobView job) {
  if (job.jobType != 'subtitle.generate') return null;
  int intVal(String k) => _num(job.usage, k)?.toInt() ?? 0;
  final summary = SubtitleUsageSummary(
    requests: intVal('request_count'),
    failedRequests: intVal('failed_request_count'),
    promptTokens: intVal('prompt_tokens'),
    completionTokens: intVal('completion_tokens'),
    totalTokens: intVal('total_tokens'),
    cacheReadTokens: intVal('cache_read_tokens'),
    totalDurationMs: (_num(job.usage, 'total_duration_ms') ?? 0).toDouble(),
    maxDurationMs: (_num(job.usage, 'max_duration_ms') ?? 0).toDouble(),
  );
  return (summary.requests > 0 ||
          summary.totalTokens > 0 ||
          summary.totalDurationMs > 0)
      ? summary
      : null;
}

String formatModelDuration(double ms) {
  if (ms <= 0) return '—';
  if (ms < 1000) return '${ms.round()} ms';
  return formatDurationSeconds((ms / 1000).roundToDouble());
}

String formatDurationSeconds(double seconds) {
  if (!seconds.isFinite || seconds <= 0) return '—';
  if (seconds < 60) return '${seconds.toInt()} 秒';
  if (seconds < 3600) return '${(seconds / 60).round()} 分钟';
  final h = seconds / 3600;
  return h == h.roundToDouble()
      ? '${h.toInt()} 小时'
      : '${h.toStringAsFixed(1)} 小时';
}

String formatInteger(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 入库历史明细（对齐 iOS `TaskCenter.IngestHistoryDetail`）。
class IngestHistoryDetail {
  const IngestHistoryDetail({
    required this.summary,
    this.context,
    this.fileGroups = const [],
  });

  final String summary;
  final String? context;
  final List<({String label, List<String> files})> fileGroups;
}

IngestHistoryDetail? ingestHistoryDetail(JobView job) {
  if (job.jobType != 'library.ingest') return null;
  final message = job.progress.message;
  final imported = stringList(job.progress.details, 'imported_files');
  final present = stringList(job.progress.details, 'already_present_files');
  final ready = _readyFilePaths(job.inputData['ready_files']);
  final noMove = RegExp('已全部在库|无需搬运|未复制').hasMatch(message);
  final ctxMatch =
      RegExp(r'入库到(?:订阅指定的)?[「“"]([^」”"]+)[」”"]').firstMatch(message);
  final ctx = ctxMatch != null ? '目标媒体库：${ctxMatch.group(1)}' : null;

  if (imported.isNotEmpty) {
    final ep = _episodeLabelFromFiles(imported);
    final summary = ep != null
        ? '新增入库 $ep（共 ${imported.length} 个文件）'
        : '新增入库 ${imported.length} 个文件';
    final groups = <({String label, List<String> files})>[
      (label: '本次新增', files: imported),
      if (present.isNotEmpty) (label: '已在库文件', files: present),
    ];
    return IngestHistoryDetail(summary: summary, context: ctx, fileGroups: groups);
  }
  if (noMove) {
    final existing = present.isEmpty ? ready : present;
    final ep = _episodeLabelFromFiles(existing);
    final inspected = ep != null
        ? '核验 $ep'
        : (existing.isEmpty ? '已核验' : '核验 ${existing.length} 个文件');
    return IngestHistoryDetail(
      summary: '$inspected · 已在库无需重复复制',
      context: ctx,
      fileGroups: existing.isEmpty
          ? const []
          : [(label: '已在库文件', files: existing)],
    );
  }
  final copyMatch = RegExp(r'复制\s*(\d+)\s*个文件').firstMatch(message);
  if (copyMatch != null && ready.isNotEmpty) {
    final copied = int.tryParse(copyMatch.group(1) ?? '') ?? 0;
    final ep = _episodeLabelFromFiles(ready);
    final inspected = ep ?? '${ready.length} 个文件';
    return IngestHistoryDetail(
      summary: '核验 $inspected · 复制 $copied 个文件',
      context: ctx,
      fileGroups: [(label: '核验文件', files: ready)],
    );
  }
  return IngestHistoryDetail(
    summary: message.isNotEmpty
        ? message
        : (job.status == 'cancelled' ? '任务已取消' : '任务已完成'),
    context: ctx,
    fileGroups: present.isEmpty ? const [] : [(label: '已在库文件', files: present)],
  );
}

List<String> stringList(Map<String, dynamic> map, String key) {
  final raw = map[key];
  if (raw is! List) return const [];
  final seen = <String>{};
  final out = <String>[];
  for (final item in raw) {
    if (item is String && item.isNotEmpty && seen.add(item)) {
      out.add(item);
    }
  }
  return out;
}

List<String> _readyFilePaths(Object? raw) {
  if (raw is! List) return const [];
  final seen = <String>{};
  final out = <String>[];
  for (final item in raw) {
    String? path;
    if (item is String) {
      path = item;
    } else if (item is Map && item['path'] is String) {
      path = item['path'] as String;
    }
    if (path != null && path.isNotEmpty && seen.add(path)) {
      out.add(path);
    }
  }
  return out;
}

String? _episodeLabelFromFiles(List<String> files) {
  final seasons = <int, Set<int>>{};
  final re = RegExp(r'S(\d{1,3})[\s._-]*E(\d{1,4})', caseSensitive: false);
  for (final file in files) {
    for (final m in re.allMatches(file)) {
      final s = int.tryParse(m.group(1) ?? '');
      final e = int.tryParse(m.group(2) ?? '');
      if (s != null && e != null) {
        seasons.putIfAbsent(s, () => <int>{}).add(e);
      }
    }
  }
  if (seasons.isEmpty) return null;
  final sortedSeasons = seasons.keys.toList()..sort();
  return sortedSeasons.map((season) {
    final eps = seasons[season]!.toList()..sort();
    final ranges = <(int, int)>[];
    for (final ep in eps) {
      if (ranges.isNotEmpty && ep == ranges.last.$2 + 1) {
        ranges[ranges.length - 1] = (ranges.last.$1, ep);
      } else {
        ranges.add((ep, ep));
      }
    }
    final text = ranges
        .map((r) => r.$1 == r.$2
            ? 'E${mcPad2(r.$1)}'
            : 'E${mcPad2(r.$1)}–E${mcPad2(r.$2)}')
        .join('、');
    return 'S${mcPad2(season)}$text';
  }).join(' · ');
}

/// 季集摘要（对齐 iOS `TaskCenter.EpisodeSummary`）。
class EpisodeSummary {
  const EpisodeSummary({
    required this.isMovie,
    required this.label,
    required this.fullLabel,
    required this.episodeCount,
    required this.seasons,
  });

  final bool isMovie;
  final String label;
  final String fullLabel;
  final int episodeCount;
  final List<({int season, List<int> episodes})> seasons;
}

EpisodeSummary? summarizeEpisodeUnits(List<DownloadTaskUnit> units) {
  if (units.isEmpty) return null;
  if (units.any((u) => u.seasonNumber == 0 && u.episodeNumber == 0)) {
    return const EpisodeSummary(
      isMovie: true,
      label: '正片',
      fullLabel: '正片',
      episodeCount: 0,
      seasons: [],
    );
  }
  final unique = <String>{};
  final sorted = <DownloadTaskUnit>[];
  for (final u in units) {
    if (unique.add('${u.seasonNumber}:${u.episodeNumber}')) {
      sorted.add(u);
    }
  }
  sorted.sort((a, b) {
    final c = a.seasonNumber.compareTo(b.seasonNumber);
    return c != 0 ? c : a.episodeNumber.compareTo(b.episodeNumber);
  });

  final seasons = <({int season, List<int> episodes})>[];
  for (final u in sorted) {
    if (seasons.isNotEmpty && seasons.last.season == u.seasonNumber) {
      seasons.last.episodes.add(u.episodeNumber);
    } else {
      seasons.add((season: u.seasonNumber, episodes: [u.episodeNumber]));
    }
  }

  final ranges = <({int season, int start, int end})>[];
  for (final s in seasons) {
    for (final ep in s.episodes) {
      if (ranges.isNotEmpty &&
          ranges.last.season == s.season &&
          ep == ranges.last.end + 1) {
        ranges[ranges.length - 1] = (
          season: s.season,
          start: ranges.last.start,
          end: ep,
        );
      } else {
        ranges.add((season: s.season, start: ep, end: ep));
      }
    }
  }

  String fmt(List<({int season, int start, int end})> list) {
    final grouped = <({int season, List<String> labels})>[];
    for (final r in list) {
      final lbl = r.start == r.end
          ? 'E${mcPad2(r.start)}'
          : 'E${mcPad2(r.start)}–E${mcPad2(r.end)}';
      if (grouped.isNotEmpty && grouped.last.season == r.season) {
        grouped.last.labels.add(lbl);
      } else {
        grouped.add((season: r.season, labels: [lbl]));
      }
    }
    return grouped
        .map((g) => 'S${mcPad2(g.season)}${g.labels.join('、')}')
        .join(' · ');
  }

  final full = fmt(ranges);
  if (ranges.length <= 3) {
    return EpisodeSummary(
      isMovie: false,
      label: full,
      fullLabel: full,
      episodeCount: sorted.length,
      seasons: seasons,
    );
  }
  final hidden =
      ranges.skip(2).fold<int>(0, (acc, r) => acc + (r.end - r.start + 1));
  return EpisodeSummary(
    isMovie: false,
    label: '${fmt(ranges.take(2).toList())} 等 $hidden 集',
    fullLabel: full,
    episodeCount: sorted.length,
    seasons: seasons,
  );
}

/// 下载来源展示词。
String downloadSourceLabel(DownloadTask task) => switch (task.source) {
      'subscription' => '订阅自动下载',
      'manual' => '手动选种',
      _ => '下载器任务',
    };

/// 下载状态展示词。
String downloadStateLabel(String state) => switch (state) {
      'downloading' => '下载中',
      'stalled' => '等待连接',
      'paused' => '已暂停',
      'queued' => '排队中',
      'checking' => '校验中',
      'completed' => '已完成',
      'error' => '下载出错',
      'missing' => '任务缺失',
      _ => '未知状态',
    };

/// 下载任务说明文字（原因优先，出路其次）。
String? downloadTaskNote(DownloadTask task, JobView? ingestJob) {
  final missing = task.contentMissingLabel();
  if (missing != null) {
    return '种子内容核验缺失 $missing，已退回重新选种';
  }
  if (ingestJob != null) {
    switch (ingestJob.status) {
      case 'succeeded':
        final sub = task.subscriptions.firstOrNull;
        final upgrade = sub?.purpose == 'upgrade';
        final total = sub?.units.length ?? 0;
        final done = sub?.units
                .where((u) => upgrade ? u.replaced : u.status == 'imported')
                .length ??
            0;
        if (total > 0 && done < total) {
          return upgrade
              ? '已替换 $done / $total 集，等待其余集下载完成'
              : '已入库 $done / $total 集，等待其余集下载完成';
        }
        return upgrade ? '已完成洗版替换，等待同步状态' : '已整理入库，等待同步状态';
      case 'cancelled':
        return '上一次自动入库已取消';
      case 'blocked':
      case 'failed':
        return (ingestJob.error?.message.isNotEmpty ?? false)
            ? ingestJob.error!.message
            : ingestJob.progress.message;
      default:
        return ingestJob.progress.message.isNotEmpty
            ? ingestJob.progress.message
            : null;
    }
  }
  if (task.landingError != null && task.landingError!.isNotEmpty) {
    return task.landingError;
  }
  if (task.state == 'error') {
    final reason = (task.errorMessage?.isNotEmpty ?? false)
        ? task.errorMessage!
        : '下载器报告错误';
    if (task.source == 'external') return '外部下载任务出错：$reason';
    if (task.rescueMessage != null && task.rescueMessage!.isNotEmpty) {
      return '$reason · ${task.rescueMessage}';
    }
    return reason;
  }
  if (task.rescueMessage != null && task.rescueMessage!.isNotEmpty) {
    return task.rescueMessage;
  }
  return switch (task.state) {
    'missing' => '在下载器里找不到该任务，可能已被手动移除',
    'completed' => '已下载完成，等待自动整理入库',
    'paused' => '下载已暂停',
    'queued' => '正在下载器队列中排队',
    'checking' => '正在校验文件完整性',
    'stalled' => '暂无可用做种连接',
    _ => null,
  };
}

/// 下载生命周期步骤（对齐 iOS `TaskCenter.lifecycleSteps`）。
enum LifecycleTone { done, current, waiting, attention, future }

class LifecycleStep {
  const LifecycleStep({
    required this.label,
    required this.detail,
    required this.tone,
  });

  final String label;
  final String detail;
  final LifecycleTone tone;
}

List<LifecycleStep> downloadLifecycleSteps(
  DownloadTask task,
  JobView? ingestJob,
) {
  final downloaded = task.state == 'completed';
  final dlAttention = task.state == 'error' || task.state == 'missing';
  final dlWaiting =
      const {'stalled', 'paused', 'queued', 'unknown'}.contains(task.state);
  final percent =
      task.progress != null ? (task.progress! * 100).floor() : null;
  final source = (task.downloaderName?.isNotEmpty ?? false)
      ? task.downloaderName!
      : '下载器';

  final LifecycleStep downloadStep;
  if (dlAttention) {
    downloadStep = LifecycleStep(
      label: downloadStateLabel(task.state),
      detail: task.state == 'missing' ? '等待重新关联或换种' : '需在下载器或通过换种处理',
      tone: LifecycleTone.attention,
    );
  } else if (downloaded) {
    downloadStep = LifecycleStep(
      label: '下载完成',
      detail: task.sizeBytes != null ? mcFormatBytes(task.sizeBytes!) : '文件就绪',
      tone: LifecycleTone.done,
    );
  } else {
    downloadStep = LifecycleStep(
      label: downloadStateLabel(task.state),
      detail: percent != null ? '$percent%' : '正在读取进度',
      tone: dlWaiting ? LifecycleTone.waiting : LifecycleTone.current,
    );
  }

  final sub = task.subscriptions.firstOrNull;
  final upgrade = sub?.purpose == 'upgrade';
  final totalUnits = sub?.units.length ?? 0;
  final doneUnits = sub?.units
          .where((u) => upgrade ? u.replaced : u.status == 'imported')
          .length ??
      0;
  final missing = task.contentMissingLabel();
  final fullyDelivered = totalUnits == 0 || doneUnits >= totalUnits;

  LifecycleStep? ingestStep;
  if (ingestJob != null && jobNeedsAttention(ingestJob)) {
    ingestStep = LifecycleStep(
      label: '入库需要处理',
      detail: (ingestJob.error?.message.isNotEmpty ?? false)
          ? ingestJob.error!.message
          : ingestJob.progress.message,
      tone: LifecycleTone.attention,
    );
  } else if (ingestJob != null &&
      ingestJob.status == 'failed' &&
      jobIsDismissed(ingestJob)) {
    ingestStep = const LifecycleStep(
      label: '入库失败（已忽略）',
      detail: '可在已结束记录里撤销忽略或重试',
      tone: LifecycleTone.waiting,
    );
  } else if (ingestJob != null && ingestJob.status == 'running') {
    ingestStep = LifecycleStep(
      label: '正在整理入库',
      detail: ingestJob.progress.message,
      tone: LifecycleTone.current,
    );
  } else if (ingestJob != null &&
      activeFeedJobStatuses.contains(ingestJob.status)) {
    ingestStep = LifecycleStep(
      label: jobStatusLabel(ingestJob.status),
      detail: ingestJob.progress.message,
      tone: LifecycleTone.waiting,
    );
  } else if (missing != null) {
    ingestStep = LifecycleStep(
      label: '内容不符',
      detail: '缺少 $missing',
      tone: LifecycleTone.attention,
    );
  } else if ((ingestJob?.status == 'succeeded' && !upgrade) || doneUnits > 0) {
    final done = downloaded && fullyDelivered;
    ingestStep = LifecycleStep(
      label: done
          ? (upgrade ? '洗版替换完成' : '入库完成')
          : (upgrade ? '部分替换' : '部分入库'),
      detail: done
          ? (upgrade ? '全部集已替换' : '全部已入库')
          : '${upgrade ? '已替换' : '已入库'} $doneUnits / $totalUnits 集',
      tone: done ? LifecycleTone.done : LifecycleTone.waiting,
    );
  } else if (ingestJob?.status == 'cancelled') {
    ingestStep = const LifecycleStep(
      label: '入库已取消',
      detail: '等待重新触发处理',
      tone: LifecycleTone.waiting,
    );
  } else if (task.landingError != null && task.landingError!.isNotEmpty) {
    ingestStep = const LifecycleStep(
      label: '无法入库',
      detail: '服务端看不到下载落盘文件',
      tone: LifecycleTone.attention,
    );
  }

  final tail = ingestStep != null
      ? [ingestStep]
      : _plannedSteps(
          task,
          downloaded: downloaded,
          upgrade: upgrade,
          keepOld: sub?.upgradeKeepOld == true,
        );

  return [
    LifecycleStep(label: '已投递', detail: source, tone: LifecycleTone.done),
    downloadStep,
    ...tail,
  ];
}

List<LifecycleStep> _plannedSteps(
  DownloadTask task, {
  required bool downloaded,
  required bool upgrade,
  required bool keepOld,
}) {
  final plan = task.plan;
  if (plan == null) {
    return [
      LifecycleStep(
        label: downloaded ? '等待入库' : '等待下载完成',
        detail: '下一步',
        tone: LifecycleTone.future,
      ),
    ];
  }
  if (plan.mode == 'downloader_default') {
    return const [
      LifecycleStep(
        label: '不会自动入库',
        detail: '落在下载器默认目录，未匹配自动入库规则',
        tone: LifecycleTone.attention,
      ),
    ];
  }
  final libText =
      (plan.libraryName?.isNotEmpty ?? false) ? '「${plan.libraryName}」' : '目标媒体库';
  final steps = <LifecycleStep>[];
  if (plan.mode == 'watch') {
    final action = switch (plan.strategy) {
      'hardlink' => '待硬链接',
      'copy' => '待复制',
      _ => '待整理',
    };
    steps.add(
      LifecycleStep(
        label: action,
        detail: plan.destPath != null ? '目标：${plan.destPath}' : '按规则搬运到目标目录',
        tone: LifecycleTone.future,
      ),
    );
  }
  if (!plan.entersLibrary) {
    steps.add(
      const LifecycleStep(
        label: '不直接写库',
        detail: '落自定义目录后由外部流转',
        tone: LifecycleTone.future,
      ),
    );
    return steps;
  }
  steps.add(
    LifecycleStep(
      label: '待扫描入库',
      detail: '入库并刮削至 $libText',
      tone: LifecycleTone.future,
    ),
  );
  if (upgrade) {
    steps.add(
      LifecycleStep(
        label: '待洗版替换',
        detail: '在 $libText 校验新版本并替换',
        tone: LifecycleTone.future,
      ),
    );
    steps.add(
      LifecycleStep(
        label: keepOld ? '保留旧版本' : '旧版本进回收站',
        detail: keepOld ? '按收藏家模式共存' : '保留期满后自动清理',
        tone: LifecycleTone.future,
      ),
    );
  }
  return steps;
}

/// 历史任务的一天（网页 HistoryDayGroup）：按结束那一刻所在自然日分组。
class JobDayGroup {
  const JobDayGroup({
    required this.key,
    required this.label,
    required this.jobs,
  });

  final String key;
  final String label;
  final List<JobView> jobs;
}

DateTime? _parseIso(String? iso) =>
    iso == null || iso.isEmpty ? null : DateTime.tryParse(iso)?.toLocal();

String activityDayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

String activityClock(String? iso) {
  final t = _parseIso(iso);
  if (t == null) return '—';
  return '${mcPad2(t.hour)}:${mcPad2(t.minute)}';
}

/// 历史日期分组标题：今天早些时候 / 昨天 / YYYY-MM-DD（或本年 M月D日）。
String activityHistoryDayLabel(String? iso, {bool isoDate = false}) {
  final t = _parseIso(iso);
  if (t == null) return iso ?? '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '今天早些时候';
  if (diff == 1) return '昨天';
  if (isoDate) return activityDayKey(t);
  return t.year == now.year
      ? '${t.month}月${t.day}日'
      : '${t.year}年${t.month}月${t.day}日';
}

/// 网页 groupHistoricalJobs：组内保持原顺序（接口已按更新时间倒序返回）。
List<JobDayGroup> groupHistoricalJobs(List<JobView> jobs) {
  final groups = <String, JobDayGroup>{};
  for (final job in jobs) {
    final stamp = _parseIso(job.finishedAt) ?? _parseIso(job.createdAt);
    if (stamp == null) continue;
    final key = activityDayKey(stamp);
    final existing = groups[key];
    if (existing != null) {
      groups[key] = JobDayGroup(
        key: key,
        label: existing.label,
        jobs: [...existing.jobs, job],
      );
    } else {
      groups[key] = JobDayGroup(
        key: key,
        label: activityHistoryDayLabel(job.finishedAt ?? job.createdAt),
        jobs: [job],
      );
    }
  }
  return groups.values.toList();
}

/// 一个下载分组（网页 DownloadTaskGroup）：只用媒体条目主键合并。
class DownloadGroup {
  const DownloadGroup({
    required this.key,
    this.mediaItemId,
    required this.title,
    this.kind,
    this.posterUrl,
    required this.tasks,
  });

  final String key;
  final int? mediaItemId;
  final String title;
  final String? kind;
  final String? posterUrl;
  final List<DownloadTask> tasks;
}

/// 网页 groupDownloadTasks：未识别资源独立卡片，不按相似标题合并。
List<DownloadGroup> groupDownloadTasks(List<DownloadTask> tasks) {
  final groups = <String, DownloadGroup>{};
  for (final task in tasks) {
    final key =
        task.mediaItemId != null ? 'media:${task.mediaItemId}' : 'task:${task.id}';
    final existing = groups[key];
    if (existing != null) {
      groups[key] = DownloadGroup(
        key: key,
        mediaItemId: existing.mediaItemId,
        title: existing.title,
        kind: existing.kind,
        posterUrl: existing.posterUrl ?? task.posterUrl,
        tasks: [...existing.tasks, task],
      );
      continue;
    }
    groups[key] = DownloadGroup(
      key: key,
      mediaItemId: task.mediaItemId,
      title: (task.mediaTitle?.isNotEmpty ?? false)
          ? task.mediaTitle!
          : ((task.name?.isNotEmpty ?? false) ? task.name! : task.infoHash),
      kind: task.mediaKind,
      posterUrl: task.posterUrl,
      tasks: [task],
    );
  }
  return groups.values.toList();
}

/// 网页 downloadGroupNeedsAttention：组里有一条需要处理，整组就是需要处理。
bool downloadGroupNeedsAttention(
  DownloadGroup group,
  Map<String, JobView> ingestJobs,
) =>
    group.tasks.any(
      (t) => downloadTaskNeedsAttention(t, ingestJobs[t.infoHash.toLowerCase()]),
    );

/// 活动总览的全部派生结果（网页 useTaskActivity 的返回）。
class TaskActivity {
  const TaskActivity({
    required this.ingestJobs,
    required this.attentionGroups,
    required this.activeGroups,
    required this.boostTasks,
    required this.attentionJobs,
    required this.activeJobs,
    required this.historyJobs,
  });

  final Map<String, JobView> ingestJobs;
  final List<DownloadGroup> attentionGroups;
  final List<DownloadGroup> activeGroups;
  final List<DownloadTask> boostTasks;
  final List<JobView> attentionJobs;
  final List<JobView> activeJobs;
  final List<JobView> historyJobs;

  int get attentionTotal => attentionGroups.length + attentionJobs.length;
  int get activeTotal => activeGroups.length + activeJobs.length;
  int get historyTotal => historyJobs.length;
}

/// 分流顺序照网页：先摘掉刷流（boost），再按是否需要处理分成两拨；
/// 入库任务若已串进某个种子，就不再单独出现。
TaskActivity deriveTaskActivity(List<DownloadTask> tasks, List<JobView> jobs) {
  final ingestJobs = ingestJobsByHash(jobs);
  final linked = linkedIngestJobIds(tasks, ingestJobs);
  final boostTasks = tasks.where((t) => t.source == 'boost').toList();
  final groups =
      groupDownloadTasks(tasks.where((t) => t.source != 'boost').toList());
  final standalone = jobs.where((j) => !linked.contains(j.id)).toList();
  return TaskActivity(
    ingestJobs: ingestJobs,
    attentionGroups:
        groups.where((g) => downloadGroupNeedsAttention(g, ingestJobs)).toList(),
    activeGroups: groups
        .where((g) => !downloadGroupNeedsAttention(g, ingestJobs))
        .toList(),
    boostTasks: boostTasks,
    attentionJobs: standalone.where(jobNeedsAttention).toList(),
    activeJobs: standalone
        .where((j) => activeFeedJobStatuses.contains(j.status))
        .toList(),
    historyJobs: standalone.where(jobIsHistorical).toList(),
  );
}

// ── 刷流做种汇总与按站状态（对齐 iOS ActivityBoostTotals / ActivityBoostSites） ──

class ActivityBoostTotals {
  ActivityBoostTotals(List<DownloadTask> tasks)
      : count = tasks.length,
        upSpeed = tasks.fold(0, (s, t) => s + (t.upspeedBytes ?? 0)),
        downSpeed = tasks.fold(0, (s, t) => s + (t.dlspeedBytes ?? 0)),
        uploaded = tasks.fold(0, (s, t) => s + (t.uploadedBytes ?? 0)),
        downloaded = tasks.fold(0, (s, t) => s + (t.completedBytes ?? 0));

  final int count;
  final int upSpeed;
  final int downSpeed;
  final int uploaded;
  final int downloaded;

  /// 按上行速度倒序（正在出力的浮在最前），同速按累计上传。
  static List<DownloadTask> sorted(List<DownloadTask> tasks) {
    final copy = List<DownloadTask>.from(tasks);
    copy.sort((a, b) {
      final u = (b.upspeedBytes ?? 0).compareTo(a.upspeedBytes ?? 0);
      if (u != 0) return u;
      return (b.uploadedBytes ?? 0).compareTo(a.uploadedBytes ?? 0);
    });
    return copy;
  }
}

enum BoostSiteMode { running, paused, off }

class ActivityBoostSiteGroup {
  const ActivityBoostSiteGroup({
    required this.siteId,
    required this.name,
    required this.mode,
    required this.tasks,
    this.pool,
  });

  final String siteId;
  final String name;
  final BoostSiteMode mode;
  final List<DownloadTask> tasks;
  final BoostPoolSiteView? pool;
}

class ActivityBoostSites {
  ActivityBoostSites(List<DownloadTask> tasks, BoostPoolView? pool) {
    final bySite = <String, List<DownloadTask>>{};
    for (final t in tasks) {
      bySite.putIfAbsent(t.siteId ?? '', () => []).add(t);
    }
    final poolSites = <String, BoostPoolSiteView>{
      for (final s in pool?.sites ?? const <BoostPoolSiteView>[]) s.siteId: s,
    };
    final built = <ActivityBoostSiteGroup>[];
    for (final entry in bySite.entries) {
      final siteId = entry.key;
      final list = entry.value;
      final info = poolSites[siteId];
      final BoostSiteMode mode;
      if (pool == null) {
        mode = BoostSiteMode.running;
      } else if (info != null && info.boostEnabled) {
        mode = info.boostPaused ? BoostSiteMode.paused : BoostSiteMode.running;
      } else {
        mode = BoostSiteMode.off;
      }
      final name = list.first.siteName ??
          info?.siteName ??
          (siteId.isEmpty ? '未知站点' : siteId);
      built.add(
        ActivityBoostSiteGroup(
          siteId: siteId,
          name: name,
          mode: mode,
          tasks: list,
          pool: info,
        ),
      );
    }
    built.sort((a, b) => b.tasks.length.compareTo(a.tasks.length));
    sites = built;
    taskStates = {
      for (final t in pool?.tasks ?? const <BoostPoolTaskView>[])
        t.infoHash.toLowerCase(): t,
    };
  }

  late final List<ActivityBoostSiteGroup> sites;
  late final Map<String, BoostPoolTaskView> taskStates;

  int count(BoostSiteMode mode) => sites
      .where((s) => s.mode == mode)
      .fold(0, (acc, s) => acc + s.tasks.length);

  int get scheduledCount =>
      taskStates.values.where((t) => t.cleanupScheduled).length;
}

String? formatBoostDeadline(String? raw) {
  final d = _parseIso(raw);
  if (d == null) return null;
  return '${d.month}月${d.day}日 ${mcPad2(d.hour)}:${mcPad2(d.minute)}';
}

String formatBoostCleanupSummary(BoostCleanupResult result) {
  final parts = <String>[];
  if (result.deletedCount > 0) {
    parts.add(
      '已删除 ${result.deletedCount} 个种子（释放 ${mcFormatBytes(result.deletedBytes)}）',
    );
  }
  if (result.scheduledCount > 0) {
    final dl = formatBoostDeadline(result.scheduledUntil);
    parts.add(
      dl != null
          ? '${result.scheduledCount} 个在保留期内，将于 $dl 后自动删除'
          : '${result.scheduledCount} 个已标记到期自动删除',
    );
  }
  if (result.failedCount > 0) {
    parts.add('${result.failedCount} 个暂未删成，稍后自动重试');
  }
  return parts.isEmpty ? '当前没有可清理的刷流种子' : parts.join('；');
}

/// 客户端 · 设备名（对齐 iOS `WatchFormat.deviceLabel`）。
String watchDeviceLabel(String client, String deviceName) {
  final name = client.startsWith('MovieClaw ')
      ? client.substring('MovieClaw '.length)
      : client;
  if (deviceName.isEmpty) return name.isEmpty ? '未知设备' : name;
  final repeats = deviceName
      .split(' · ')
      .any((seg) => seg == name || seg.startsWith('$name '));
  if (name.isEmpty || repeats) return deviceName;
  return '$name · $deviceName';
}

num? _num(Map<String, dynamic> map, String key) {
  final v = map[key];
  return v is num ? v : null;
}

String? _str(Map<String, dynamic> map, String key) {
  final v = map[key];
  return (v is String && v.isNotEmpty) ? v : null;
}

int _countVal(Map<String, dynamic> map, String key) {
  final v = map[key];
  if (v is List) return v.length;
  if (v is num) return v.toInt();
  return 0;
}
