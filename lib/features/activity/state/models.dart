/// 活动域模型（1:1 对齐 iOS `Models.swift` + `ActivityStores.swift` + `NowPlayingRows.swift`）。
library;

import '../../../core/models/format.dart';

/// 任务进度（服务端 JobProgressView）。
class JobProgress {
  const JobProgress({
    this.mode = '',
    this.phase = '',
    this.message = '',
    this.messageKey,
    this.messageParams = const {},
    this.current,
    this.total,
    this.percent,
    this.phaseIndex,
    this.phaseCount,
    this.details = const {},
  });

  final String mode;
  final String phase;
  final String message;
  final String? messageKey;
  final Map<String, dynamic> messageParams;
  final int? current;
  final int? total;
  final double? percent;
  final int? phaseIndex;
  final int? phaseCount;

  /// 领域进度明细（历史行标题/摘要从这里取 media_title、identified 等键）。
  final Map<String, dynamic> details;

  factory JobProgress.fromJson(Map<String, dynamic> j) => JobProgress(
        mode: j['mode'] as String? ?? '',
        phase: j['phase'] as String? ?? '',
        message: j['message'] as String? ?? '',
        messageKey: j['message_key'] as String?,
        messageParams: _map(j['message_params']),
        current: (j['current'] as num?)?.toInt(),
        total: (j['total'] as num?)?.toInt(),
        percent: (j['percent'] as num?)?.toDouble(),
        phaseIndex: (j['phase_index'] as num?)?.toInt(),
        phaseCount: (j['phase_count'] as num?)?.toInt(),
        details: _map(j['details']),
      );
}

/// 任务错误动作（type 机器名 + label 服务端给 + target 设置分区）。
class JobErrorAction {
  const JobErrorAction({this.type = '', this.label = '', this.target});

  final String type;
  final String label;
  final String? target;

  factory JobErrorAction.fromJson(Map<String, dynamic> j) => JobErrorAction(
        type: j['type'] as String? ?? '',
        label: j['label'] as String? ?? '',
        target: j['target'] as String?,
      );
}

/// 任务错误：{code, message, actions}。
class JobErrorView {
  const JobErrorView({
    this.code = '',
    this.message = '',
    this.actions = const [],
  });

  final String code;
  final String message;
  final List<JobErrorAction> actions;

  factory JobErrorView.fromJson(Map<String, dynamic> j) => JobErrorView(
        code: j['code'] as String? ?? '',
        message: j['message'] as String? ?? '',
        actions: ((j['actions'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => JobErrorAction.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// 任务占用的资源；library.ingest 挂 download 资源时 resource_id = info_hash。
class JobResourceView {
  const JobResourceView({
    this.resourceType = '',
    this.resourceId = '',
    this.relation = '',
  });

  final String resourceType;
  final String resourceId;
  final String relation;

  factory JobResourceView.fromJson(Map<String, dynamic> j) => JobResourceView(
        resourceType: j['resource_type'] as String? ?? '',
        resourceId: j['resource_id'] as String? ?? '',
        relation: j['relation'] as String? ?? '',
      );
}

/// 后台任务（服务端 JobView）。
class JobView {
  const JobView({
    required this.id,
    this.jobType = '',
    this.jobTypeLabel,
    this.subject,
    this.providerRef,
    this.status = '',
    this.progress = const JobProgress(),
    this.error,
    this.usage = const {},
    this.resources = const [],
    this.inputData = const {},
    this.origin = '',
    this.actorKind,
    this.actorName,
    this.attempt = 1,
    this.maxAttempts = 1,
    this.startedAt,
    this.dismissedAt,
    this.cancelRequestedBy,
    this.finishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String jobType;
  final String? jobTypeLabel;
  final String? subject;
  final String? providerRef;
  final String status;
  final JobProgress progress;
  final JobErrorView? error;
  final Map<String, dynamic> usage;
  final List<JobResourceView> resources;
  final Map<String, dynamic> inputData;
  final String origin;
  final String? actorKind;
  final String? actorName;
  final int attempt;
  final int maxAttempts;
  final String? startedAt;

  /// 非空 = 被用户忽略，不再出现在「需要处理」。
  final String? dismissedAt;

  /// system: 前缀 = 系统取消（不给「重新执行」）。
  final String? cancelRequestedBy;
  final String? finishedAt;
  final String? createdAt;
  final String? updatedAt;

  factory JobView.fromJson(Map<String, dynamic> j) => JobView(
        id: j['id'] as String? ?? '',
        jobType: j['job_type'] as String? ?? '',
        jobTypeLabel: j['job_type_label'] as String?,
        subject: j['subject'] as String?,
        providerRef: j['provider_ref'] as String?,
        status: j['status'] as String? ?? '',
        progress: j['progress'] is Map
            ? JobProgress.fromJson(Map<String, dynamic>.from(j['progress'] as Map))
            : const JobProgress(),
        error: j['error'] is Map
            ? JobErrorView.fromJson(Map<String, dynamic>.from(j['error'] as Map))
            : null,
        usage: _map(j['usage']),
        resources: ((j['resources'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => JobResourceView.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        inputData: _map(j['input_data']),
        origin: j['origin'] as String? ?? '',
        actorKind: j['actor_kind'] as String?,
        actorName: j['actor_name'] as String?,
        attempt: (j['attempt'] as num?)?.toInt() ?? 1,
        maxAttempts: (j['max_attempts'] as num?)?.toInt() ?? 1,
        startedAt: j['started_at'] as String?,
        dismissedAt: j['dismissed_at'] as String?,
        cancelRequestedBy: j['cancel_requested_by'] as String?,
        finishedAt: j['finished_at'] as String?,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  String? detailString(String key) {
    final v = progress.details[key] ?? inputData[key];
    if (v == null || v is! String) return null;
    return v.isEmpty ? null : v;
  }
}

/// 订阅逐集覆盖（下载任务卡上的「覆盖 N 集 · 已入库 M」）。
class DownloadTaskUnit {
  const DownloadTaskUnit({
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.status = 'grabbed',
    this.replaced = false,
    this.contentMissing = false,
  });

  final int seasonNumber;
  final int episodeNumber;
  final String status;
  final bool replaced;
  final bool contentMissing;

  factory DownloadTaskUnit.fromJson(Map<String, dynamic> j) => DownloadTaskUnit(
        seasonNumber: (j['season_number'] as num?)?.toInt() ?? 0,
        episodeNumber: (j['episode_number'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'grabbed',
        replaced: j['replaced'] as bool? ?? false,
        contentMissing: j['content_missing'] as bool? ?? false,
      );
}

class DownloadTaskSubscription {
  const DownloadTaskSubscription({
    this.id = 0,
    this.mediaItemId = 0,
    this.mediaTitle = '',
    this.mediaKind = '',
    this.posterUrl,
    this.purpose = 'fill',
    this.upgradeKeepOld = false,
    this.units = const [],
  });

  final int id;
  final int mediaItemId;
  final String mediaTitle;
  final String mediaKind;
  final String? posterUrl;
  final String purpose;
  final bool upgradeKeepOld;
  final List<DownloadTaskUnit> units;

  factory DownloadTaskSubscription.fromJson(Map<String, dynamic> j) =>
      DownloadTaskSubscription(
        id: (j['id'] as num?)?.toInt() ?? 0,
        mediaItemId: (j['media_item_id'] as num?)?.toInt() ?? 0,
        mediaTitle: j['media_title'] as String? ?? '',
        mediaKind: j['media_kind'] as String? ?? '',
        posterUrl: j['poster_url'] as String?,
        purpose: j['purpose'] as String? ?? 'fill',
        upgradeKeepOld: j['upgrade_keep_old'] as bool? ?? false,
        units: ((j['units'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => DownloadTaskUnit.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// 下载完成后还没发生的落点计划（DownloadTaskPlanView）。
class DownloadTaskPlan {
  const DownloadTaskPlan({
    this.mode = '',
    this.strategy,
    this.libraryName,
    this.destPath,
    this.entersLibrary = true,
  });

  final String mode;
  final String? strategy;
  final String? libraryName;
  final String? destPath;
  final bool entersLibrary;

  factory DownloadTaskPlan.fromJson(Map<String, dynamic> j) => DownloadTaskPlan(
        mode: j['mode'] as String? ?? '',
        strategy: j['strategy'] as String?,
        libraryName: j['library_name'] as String?,
        destPath: j['dest_path'] as String?,
        entersLibrary: j['enters_library'] as bool? ?? true,
      );
}

/// 单台下载器的快照健康状态（DownloadTaskSourceView）。
class DownloadTaskSource {
  const DownloadTaskSource({
    this.id = 0,
    this.name = '',
    this.clientType = '',
    this.status = 'active',
    this.message,
    this.taskCount = 0,
  });

  final int id;
  final String name;
  final String clientType;
  final String status;
  final String? message;
  final int taskCount;

  factory DownloadTaskSource.fromJson(Map<String, dynamic> j) =>
      DownloadTaskSource(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        clientType: j['client_type'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        message: j['message'] as String?,
        taskCount: (j['task_count'] as num?)?.toInt() ?? 0,
      );
}

class DownloadTaskListView {
  const DownloadTaskListView({
    this.items = const [],
    this.sources = const [],
  });

  final List<DownloadTask> items;
  final List<DownloadTaskSource> sources;

  factory DownloadTaskListView.fromJson(Map<String, dynamic> j) =>
      DownloadTaskListView(
        items: ((j['items'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => DownloadTask.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        sources: ((j['sources'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => DownloadTaskSource.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// 下载器快照里的种子任务（DownloadTaskView）。
class DownloadTask {
  const DownloadTask({
    required this.id,
    this.infoHash = '',
    this.name,
    this.downloaderId,
    this.downloaderName,
    this.downloaderType,
    this.progress,
    this.sizeBytes,
    this.dlspeedBytes,
    this.upspeedBytes,
    this.uploadedBytes,
    this.completedBytes,
    this.etaSeconds,
    this.state = '',
    this.source = '',
    this.siteId,
    this.siteName,
    this.pageUrl,
    this.resolution,
    this.mediaSource,
    this.remux = false,
    this.mediaTitle,
    this.mediaKind,
    this.posterUrl,
    this.errorMessage,
    this.landingError,
    this.canReplace = false,
    this.rescueState,
    this.noProgressSeconds,
    this.replacementDueAt,
    this.rescueMessage,
    this.mediaItemId,
    this.plan,
    this.subscriptions = const [],
  });

  final String id;
  final String infoHash;
  final String? name;
  final int? downloaderId;
  final String? downloaderName;
  final String? downloaderType;

  /// 0..1；缺失为 null。
  final double? progress;
  final int? sizeBytes;
  final int? dlspeedBytes;
  final int? upspeedBytes;
  final int? uploadedBytes;
  final int? completedBytes;
  final int? etaSeconds;
  final String state;
  final String source;
  final String? siteId;
  final String? siteName;
  final String? pageUrl;
  final String? resolution;
  final String? mediaSource;
  final bool remux;
  final String? mediaTitle;
  final String? mediaKind;
  final String? posterUrl;
  final String? errorMessage;

  /// 下载完成但看不到文件（落点核验失败）。
  final String? landingError;
  final bool canReplace;
  final String? rescueState;
  final int? noProgressSeconds;
  final String? replacementDueAt;
  final String? rescueMessage;
  final int? mediaItemId;
  final DownloadTaskPlan? plan;
  final List<DownloadTaskSubscription> subscriptions;

  factory DownloadTask.fromJson(Map<String, dynamic> j) => DownloadTask(
        id: j['id'] as String? ?? j['info_hash'] as String? ?? '',
        infoHash: j['info_hash'] as String? ?? '',
        name: j['name'] as String?,
        downloaderId: (j['downloader_id'] as num?)?.toInt(),
        downloaderName: j['downloader_name'] as String?,
        downloaderType: j['downloader_type'] as String?,
        progress: (j['progress'] as num?)?.toDouble(),
        sizeBytes: (j['size_bytes'] as num?)?.toInt(),
        dlspeedBytes: (j['dlspeed_bytes'] as num?)?.toInt(),
        upspeedBytes: (j['upspeed_bytes'] as num?)?.toInt(),
        uploadedBytes: (j['uploaded_bytes'] as num?)?.toInt(),
        completedBytes: (j['completed_bytes'] as num?)?.toInt(),
        etaSeconds: (j['eta_seconds'] as num?)?.toInt(),
        state: j['state'] as String? ?? '',
        source: j['source'] as String? ?? '',
        siteId: j['site_id'] as String?,
        siteName: j['site_name'] as String?,
        pageUrl: j['page_url'] as String?,
        resolution: j['resolution'] as String?,
        mediaSource: j['media_source'] as String?,
        remux: j['remux'] as bool? ?? false,
        mediaTitle: j['media_title'] as String?,
        mediaKind: j['media_kind'] as String?,
        posterUrl: j['poster_url'] as String?,
        errorMessage: j['error_message'] as String?,
        landingError: j['landing_error'] as String?,
        canReplace: j['can_replace'] as bool? ?? false,
        rescueState: j['rescue_state'] as String?,
        noProgressSeconds: (j['no_progress_seconds'] as num?)?.toInt(),
        replacementDueAt: j['replacement_due_at'] as String?,
        rescueMessage: j['rescue_message'] as String?,
        mediaItemId: (j['media_item_id'] as num?)?.toInt(),
        plan: j['plan'] is Map
            ? DownloadTaskPlan.fromJson(Map<String, dynamic>.from(j['plan'] as Map))
            : null,
        subscriptions: ((j['subscriptions'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => DownloadTaskSubscription.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  /// 内容核验证明种子里没有这几集（形如 S01E05 / S01E05 等 3 集）。
  String? contentMissingLabel() {
    final units = subscriptions.firstOrNull?.units
            .where((u) => u.contentMissing)
            .toList() ??
        const <DownloadTaskUnit>[];
    if (units.isEmpty) return null;
    final first = units.first;
    final label = mcEpisodeLabel(first.seasonNumber, first.episodeNumber);
    return units.length == 1 ? label : '$label 等 ${units.length} 集';
  }

  /// 覆盖与入库进度（imported 或 replaced 算已入库）。
  (int, int)? unitSummary() {
    final units = subscriptions.firstOrNull?.units;
    if (units == null || units.isEmpty) return null;
    return (
      units.length,
      units.where((u) => u.status == 'imported' || u.replaced).length,
    );
  }
}

/// 刷流在池站点概况（BoostPoolSiteView）。
class BoostPoolSiteView {
  const BoostPoolSiteView({
    required this.siteId,
    required this.siteName,
    this.boostEnabled = false,
    this.boostPaused = false,
    this.taskCount = 0,
    this.sizeBytes = 0,
    this.deletableCount = 0,
    this.deletableBytes = 0,
    this.protectedCount = 0,
    this.protectedBytes = 0,
    this.protectedUntil,
    this.scheduledCount = 0,
  });

  final String siteId;
  final String siteName;
  final bool boostEnabled;
  final bool boostPaused;
  final int taskCount;
  final int sizeBytes;
  final int deletableCount;
  final int deletableBytes;
  final int protectedCount;
  final int protectedBytes;
  final String? protectedUntil;
  final int scheduledCount;

  factory BoostPoolSiteView.fromJson(Map<String, dynamic> j) =>
      BoostPoolSiteView(
        siteId: (j['site_id'] ?? '').toString(),
        siteName: (j['site_name'] ?? j['site_id'] ?? '').toString(),
        boostEnabled: j['boost_enabled'] == true,
        boostPaused: j['boost_paused'] == true,
        taskCount: (j['task_count'] as num?)?.toInt() ?? 0,
        sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
        deletableCount: (j['deletable_count'] as num?)?.toInt() ?? 0,
        deletableBytes: (j['deletable_bytes'] as num?)?.toInt() ?? 0,
        protectedCount: (j['protected_count'] as num?)?.toInt() ?? 0,
        protectedBytes: (j['protected_bytes'] as num?)?.toInt() ?? 0,
        protectedUntil: j['protected_until'] as String?,
        scheduledCount: (j['scheduled_count'] as num?)?.toInt() ?? 0,
      );
}

/// 刷流单种子清理状态（BoostPoolTaskView）。
class BoostPoolTaskView {
  const BoostPoolTaskView({
    required this.infoHash,
    this.siteId = '',
    this.protectedUntil,
    this.cleanupScheduled = false,
  });

  final String infoHash;
  final String siteId;
  final String? protectedUntil;
  final bool cleanupScheduled;

  factory BoostPoolTaskView.fromJson(Map<String, dynamic> j) =>
      BoostPoolTaskView(
        infoHash: (j['info_hash'] ?? '').toString(),
        siteId: (j['site_id'] ?? '').toString(),
        protectedUntil: j['protected_until'] as String?,
        cleanupScheduled: j['cleanup_scheduled'] == true,
      );
}

/// 刷流在池概况（BoostPoolView）。
class BoostPoolView {
  const BoostPoolView({
    this.sites = const [],
    this.tasks = const [],
  });

  final List<BoostPoolSiteView> sites;
  final List<BoostPoolTaskView> tasks;

  factory BoostPoolView.fromJson(Map<String, dynamic> j) => BoostPoolView(
        sites: ((j['sites'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => BoostPoolSiteView.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        tasks: ((j['tasks'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => BoostPoolTaskView.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// 刷流清理结果（BoostCleanupResult）。
class BoostCleanupResult {
  const BoostCleanupResult({
    this.deletedCount = 0,
    this.deletedBytes = 0,
    this.scheduledCount = 0,
    this.scheduledUntil,
    this.failedCount = 0,
    this.disabledSites = const [],
  });

  final int deletedCount;
  final int deletedBytes;
  final int scheduledCount;
  final String? scheduledUntil;
  final int failedCount;
  final List<String> disabledSites;

  factory BoostCleanupResult.fromJson(Map<String, dynamic> j) =>
      BoostCleanupResult(
        deletedCount: (j['deleted_count'] as num?)?.toInt() ?? 0,
        deletedBytes: (j['deleted_bytes'] as num?)?.toInt() ?? 0,
        scheduledCount: (j['scheduled_count'] as num?)?.toInt() ?? 0,
        scheduledUntil: j['scheduled_until'] as String?,
        failedCount: (j['failed_count'] as num?)?.toInt() ?? 0,
        disabledSites: ((j['disabled_sites'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// 活动页作品目标（正在播放 / 历史行共用的条目元信息）。
class MediaActivityTarget {
  const MediaActivityTarget({
    this.mediaItemId = 0,
    this.libraryId,
    this.browsable = true,
    this.kind = 'movie',
    this.title = '',
    this.year,
    this.posterUrl,
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.episodeTitle,
  });

  final int mediaItemId;
  final int? libraryId;
  final bool browsable;
  final String kind;
  final String title;
  final int? year;
  final String? posterUrl;
  final int seasonNumber;
  final int episodeNumber;
  final String? episodeTitle;

  factory MediaActivityTarget.fromJson(Map<String, dynamic> j) =>
      MediaActivityTarget(
        mediaItemId: (j['media_item_id'] as num?)?.toInt() ?? 0,
        libraryId: (j['library_id'] as num?)?.toInt(),
        browsable: j['browsable'] as bool? ?? true,
        kind: j['kind'] as String? ?? 'movie',
        title: j['title'] as String? ?? '',
        year: (j['year'] as num?)?.toInt(),
        posterUrl: j['poster_url'] as String?,
        seasonNumber: (j['season_number'] as num?)?.toInt() ?? 0,
        episodeNumber: (j['episode_number'] as num?)?.toInt() ?? 0,
        episodeTitle: j['episode_title'] as String?,
      );
}

/// 播放方式（PlaybackDeliveryView：直连 / 重封装 / 音频转码 / 硬件转码 / 软件转码 / 远程转码）。
class PlaybackDeliveryView {
  const PlaybackDeliveryView({
    this.mode = 'direct',
    this.executionKind,
    this.label = '',
    this.target,
    this.executor,
    this.reason,
  });

  final String mode;
  final String? executionKind;
  final String label;
  final String? target;
  final String? executor;
  final String? reason;

  factory PlaybackDeliveryView.fromJson(Map<String, dynamic> j) =>
      PlaybackDeliveryView(
        mode: j['mode'] as String? ?? 'direct',
        executionKind: j['execution_kind'] as String?,
        label: j['label'] as String? ?? '',
        target: j['target'] as String?,
        executor: j['executor'] as String?,
        reason: j['reason'] as String?,
      );
}

/// 一条正在进行的播放会话（观看视角「正在播放」卡）。
class ActivePlaybackSession {
  const ActivePlaybackSession({
    required this.deviceId,
    this.revocable = false,
    this.memberName = '',
    this.client = '',
    this.deviceName = '',
    this.clientVersion = '',
    this.media = const MediaActivityTarget(),
    this.positionMs,
    this.durationMs,
    this.progressPercent,
    this.paused = false,
    this.playMethod = 'local',
    this.rateBytesPerSecond,
    this.bytesSent,
    this.connections = 0,
    this.delivery,
    this.startedAt = '',
    this.lastReportAt = '',
  });

  final String deviceId;
  final bool revocable;
  final String memberName;
  final String client;
  final String deviceName;
  final String clientVersion;
  final MediaActivityTarget media;
  final int? positionMs;
  final int? durationMs;
  final int? progressPercent;
  final bool paused;

  /// local = 本机直连；remote = 网盘直链。
  final String playMethod;
  final double? rateBytesPerSecond;
  final int? bytesSent;
  final int connections;
  final PlaybackDeliveryView? delivery;
  final String startedAt;
  final String lastReportAt;

  factory ActivePlaybackSession.fromJson(Map<String, dynamic> j) =>
      ActivePlaybackSession(
        deviceId: j['device_id'] as String? ?? '',
        revocable: j['revocable'] as bool? ?? false,
        memberName: j['member_name'] as String? ?? '',
        client: j['client'] as String? ?? '',
        deviceName: j['device_name'] as String? ?? '',
        clientVersion: j['client_version'] as String? ?? '',
        media: j['media'] is Map
            ? MediaActivityTarget.fromJson(Map<String, dynamic>.from(j['media'] as Map))
            : const MediaActivityTarget(),
        positionMs: (j['position_ms'] as num?)?.toInt(),
        durationMs: (j['duration_ms'] as num?)?.toInt(),
        progressPercent: (j['progress_percent'] as num?)?.toInt(),
        paused: j['paused'] as bool? ?? false,
        playMethod: j['play_method'] as String? ?? 'local',
        rateBytesPerSecond: (j['rate_bytes_per_second'] as num?)?.toDouble(),
        bytesSent: (j['bytes_sent'] as num?)?.toInt(),
        connections: (j['connections'] as num?)?.toInt() ?? 0,
        delivery: j['delivery'] is Map
            ? PlaybackDeliveryView.fromJson(
                Map<String, dynamic>.from(j['delivery'] as Map),
              )
            : null,
        startedAt: j['started_at'] as String? ?? '',
        lastReportAt: j['last_report_at'] as String? ?? '',
      );
}

/// 设备正在拉的整文件（播放器离线缓存）——「正在下载」分区。
class ActiveFileDownload {
  const ActiveFileDownload({
    required this.deviceId,
    this.revocable = false,
    this.memberName = '',
    this.client = '',
    this.deviceName = '',
    this.media,
    this.fileName = '',
    this.sizeBytes = 0,
    this.bytesSent = 0,
    this.rateBytesPerSecond,
    this.connections = 0,
    this.positionBytes = 0,
    this.progressPercent,
    this.startedAt = '',
  });

  final String deviceId;
  final bool revocable;
  final String memberName;
  final String client;
  final String deviceName;
  final MediaActivityTarget? media;
  final String fileName;
  final int sizeBytes;
  final int bytesSent;
  final double? rateBytesPerSecond;
  final int connections;
  final int positionBytes;
  final int? progressPercent;
  final String startedAt;

  factory ActiveFileDownload.fromJson(Map<String, dynamic> j) =>
      ActiveFileDownload(
        deviceId: j['device_id'] as String? ?? '',
        revocable: j['revocable'] as bool? ?? false,
        memberName: j['member_name'] as String? ?? '',
        client: j['client'] as String? ?? '',
        deviceName: j['device_name'] as String? ?? '',
        media: j['media'] is Map
            ? MediaActivityTarget.fromJson(Map<String, dynamic>.from(j['media'] as Map))
            : null,
        fileName: j['file_name'] as String? ?? '',
        sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
        bytesSent: (j['bytes_sent'] as num?)?.toInt() ?? 0,
        rateBytesPerSecond: (j['rate_bytes_per_second'] as num?)?.toDouble(),
        connections: (j['connections'] as num?)?.toInt() ?? 0,
        positionBytes: (j['position_bytes'] as num?)?.toInt() ?? 0,
        progressPercent: (j['progress_percent'] as num?)?.toInt(),
        startedAt: j['started_at'] as String? ?? '',
      );
}

/// GET /playback/activity 的汇总。
class PlaybackActivityView {
  const PlaybackActivityView({
    this.sessions = const [],
    this.downloads = const [],
    this.hiddenSessionCount = 0,
    this.hiddenDownloadCount = 0,
  });

  final List<ActivePlaybackSession> sessions;
  final List<ActiveFileDownload> downloads;
  final int hiddenSessionCount;
  final int hiddenDownloadCount;

  factory PlaybackActivityView.fromJson(Map<String, dynamic> j) =>
      PlaybackActivityView(
        sessions: ((j['sessions'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => ActivePlaybackSession.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        downloads: ((j['downloads'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => ActiveFileDownload.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        hiddenSessionCount: (j['hidden_session_count'] as num?)?.toInt() ?? 0,
        hiddenDownloadCount: (j['hidden_download_count'] as num?)?.toInt() ?? 0,
      );
}

/// 观看统计：当前周期与上一周期成对返回。
class PlaybackStatsTotals {
  const PlaybackStatsTotals({
    this.plays = 0,
    this.watchedMs = 0,
    this.completed = 0,
    this.activeMembers = 0,
  });

  final int plays;
  final int watchedMs;
  final int completed;
  final int activeMembers;

  factory PlaybackStatsTotals.fromJson(Map<String, dynamic> j) =>
      PlaybackStatsTotals(
        plays: (j['plays'] as num?)?.toInt() ?? 0,
        watchedMs: (j['watched_ms'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        activeMembers: (j['active_members'] as num?)?.toInt() ?? 0,
      );
}

class PlaybackStatsDayRow {
  const PlaybackStatsDayRow({
    this.date = '',
    this.plays = 0,
    this.watchedMs = 0,
    this.completed = 0,
    this.members = 0,
  });

  final String date;
  final int plays;
  final int watchedMs;
  final int completed;
  final int members;

  factory PlaybackStatsDayRow.fromJson(Map<String, dynamic> j) =>
      PlaybackStatsDayRow(
        date: j['date'] as String? ?? '',
        plays: (j['plays'] as num?)?.toInt() ?? 0,
        watchedMs: (j['watched_ms'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        members: (j['members'] as num?)?.toInt() ?? 0,
      );
}

class PlaybackStatsMemberRow {
  const PlaybackStatsMemberRow({
    this.memberId = 0,
    this.memberName = '',
    this.plays = 0,
    this.watchedMs = 0,
    this.completed = 0,
  });

  final int memberId;
  final String memberName;
  final int plays;
  final int watchedMs;
  final int completed;

  factory PlaybackStatsMemberRow.fromJson(Map<String, dynamic> j) =>
      PlaybackStatsMemberRow(
        memberId: (j['member_id'] as num?)?.toInt() ?? 0,
        memberName: j['member_name'] as String? ?? '',
        plays: (j['plays'] as num?)?.toInt() ?? 0,
        watchedMs: (j['watched_ms'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as num?)?.toInt() ?? 0,
      );
}

class PlaybackStatsClientRow {
  const PlaybackStatsClientRow({
    this.client = '',
    this.plays = 0,
    this.watchedMs = 0,
  });

  final String client;
  final int plays;
  final int watchedMs;

  factory PlaybackStatsClientRow.fromJson(Map<String, dynamic> j) =>
      PlaybackStatsClientRow(
        client: j['client'] as String? ?? '',
        plays: (j['plays'] as num?)?.toInt() ?? 0,
        watchedMs: (j['watched_ms'] as num?)?.toInt() ?? 0,
      );
}

/// 播放方式档位统计（直连 / 重封装 / 音频转码 / 硬件转码 / 软件转码）。
class PlaybackStatsTierRow {
  const PlaybackStatsTierRow({
    this.tier = 0,
    this.label = '',
    this.plays = 0,
  });

  final int tier;
  final String label;
  final int plays;

  factory PlaybackStatsTierRow.fromJson(Map<String, dynamic> j) =>
      PlaybackStatsTierRow(
        tier: (j['tier'] as num?)?.toInt() ?? 0,
        label: (j['label'] ?? '').toString(),
        plays: (j['plays'] as num?)?.toInt() ?? 0,
      );
}

class PlaybackStatsTitleRow {
  const PlaybackStatsTitleRow({
    this.media = const MediaActivityTarget(),
    this.plays = 0,
    this.watchedMs = 0,
    this.members = 0,
  });

  final MediaActivityTarget media;
  final int plays;
  final int watchedMs;
  final int members;

  factory PlaybackStatsTitleRow.fromJson(Map<String, dynamic> j) =>
      PlaybackStatsTitleRow(
        media: j['media'] is Map
            ? MediaActivityTarget.fromJson(Map<String, dynamic>.from(j['media'] as Map))
            : const MediaActivityTarget(),
        plays: (j['plays'] as num?)?.toInt() ?? 0,
        watchedMs: (j['watched_ms'] as num?)?.toInt() ?? 0,
        members: (j['members'] as num?)?.toInt() ?? 0,
      );
}

class PlaybackWatchStatsView {
  const PlaybackWatchStatsView({
    this.days = 7,
    this.current = const PlaybackStatsTotals(),
    this.previous = const PlaybackStatsTotals(),
    this.previousAvailable = false,
    this.byDay = const [],
    this.previousByDay = const [],
    this.byHour = const [],
    this.byMember = const [],
    this.byClient = const [],
    this.byTier = const [],
    this.topTitles = const [],
    this.hiddenTitleCount = 0,
    this.favorites = const [],
    this.previousFavorites = const [],
  });

  final int days;
  final PlaybackStatsTotals current;
  final PlaybackStatsTotals previous;
  final bool previousAvailable;
  final List<PlaybackStatsDayRow> byDay;
  final List<PlaybackStatsDayRow> previousByDay;

  /// 7×24 观看时长矩阵（毫秒），0 行 = 周一。
  final List<List<int>> byHour;
  final List<PlaybackStatsMemberRow> byMember;
  final List<PlaybackStatsClientRow> byClient;
  final List<PlaybackStatsTierRow> byTier;
  final List<PlaybackStatsTitleRow> topTitles;
  final int hiddenTitleCount;
  final List<PlaybackStatsTitleRow> favorites;
  final List<PlaybackStatsTitleRow> previousFavorites;

  factory PlaybackWatchStatsView.fromJson(Map<String, dynamic> j) =>
      PlaybackWatchStatsView(
        days: (j['days'] as num?)?.toInt() ?? 7,
        current: j['current'] is Map
            ? PlaybackStatsTotals.fromJson(Map<String, dynamic>.from(j['current'] as Map))
            : const PlaybackStatsTotals(),
        previous: j['previous'] is Map
            ? PlaybackStatsTotals.fromJson(Map<String, dynamic>.from(j['previous'] as Map))
            : const PlaybackStatsTotals(),
        previousAvailable: j['previous_available'] as bool? ?? false,
        byDay: ((j['by_day'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => PlaybackStatsDayRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        previousByDay: ((j['previous_by_day'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => PlaybackStatsDayRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        byHour: ((j['by_hour'] as List<dynamic>?) ?? const [])
            .map(
              (row) => ((row as List<dynamic>?) ?? const <int>[])
                  .map((v) => (v as num?)?.toInt() ?? 0)
                  .toList(),
            )
            .toList(),
        byMember: ((j['by_member'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => PlaybackStatsMemberRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        byClient: ((j['by_client'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => PlaybackStatsClientRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        byTier: ((j['by_tier'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => PlaybackStatsTierRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        topTitles: ((j['top_titles'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => PlaybackStatsTitleRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        hiddenTitleCount: (j['hidden_title_count'] as num?)?.toInt() ?? 0,
        favorites: ((j['favorites'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => PlaybackStatsTitleRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        previousFavorites: ((j['previous_favorites'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => PlaybackStatsTitleRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// 一条播放历史（最近播放流水）。
class PlaybackLogEntry {
  const PlaybackLogEntry({
    required this.id,
    this.memberName = '',
    this.media = const MediaActivityTarget(),
    this.client = '',
    this.deviceName = '',
    this.startedAt = '',
    this.endedAt,
    this.watchedMs = 0,
    this.startPositionMs = 0,
    this.endPositionMs = 0,
    this.durationMs,
    this.progressPercent,
    this.completed = false,
  });

  final int id;
  final String memberName;
  final MediaActivityTarget media;
  final String client;
  final String deviceName;
  final String startedAt;
  final String? endedAt;
  final int watchedMs;
  final int startPositionMs;
  final int endPositionMs;
  final int? durationMs;
  final int? progressPercent;
  final bool completed;

  bool get isPlaying => endedAt == null;

  factory PlaybackLogEntry.fromJson(Map<String, dynamic> j) => PlaybackLogEntry(
        id: (j['id'] as num?)?.toInt() ?? 0,
        memberName: j['member_name'] as String? ?? '',
        media: j['media'] is Map
            ? MediaActivityTarget.fromJson(Map<String, dynamic>.from(j['media'] as Map))
            : const MediaActivityTarget(),
        client: j['client'] as String? ?? '',
        deviceName: j['device_name'] as String? ?? '',
        startedAt: j['started_at'] as String? ?? '',
        endedAt: j['ended_at'] as String?,
        watchedMs: (j['watched_ms'] as num?)?.toInt() ?? 0,
        startPositionMs: (j['start_position_ms'] as num?)?.toInt() ?? 0,
        endPositionMs: (j['end_position_ms'] as num?)?.toInt() ?? 0,
        durationMs: (j['duration_ms'] as num?)?.toInt(),
        progressPercent: (j['progress_percent'] as num?)?.toInt(),
        completed: j['completed'] as bool? ?? false,
      );
}

class PlaybackHistoryView {
  const PlaybackHistoryView({
    this.entries = const [],
    this.hiddenCount = 0,
    this.hasMore = false,
    this.nextCursor,
  });

  final List<PlaybackLogEntry> entries;
  final int hiddenCount;
  final bool hasMore;
  final int? nextCursor;

  factory PlaybackHistoryView.fromJson(Map<String, dynamic> j) =>
      PlaybackHistoryView(
        entries: ((j['entries'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => PlaybackLogEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        hiddenCount: (j['hidden_count'] as num?)?.toInt() ?? 0,
        hasMore: j['has_more'] as bool? ?? false,
        nextCursor: (j['next_cursor'] as num?)?.toInt(),
      );
}

/// 活动成员筛选条目（GET /api/v1/members）。
class ActivityMemberOption {
  const ActivityMemberOption({
    required this.id,
    required this.username,
    this.nickname = '',
  });

  final int id;
  final String username;
  final String nickname;

  String get displayName => nickname.trim().isNotEmpty ? nickname.trim() : username;

  factory ActivityMemberOption.fromJson(Map<String, dynamic> j) =>
      ActivityMemberOption(
        id: (j['id'] as num?)?.toInt() ?? 0,
        username: (j['username'] ?? '').toString(),
        nickname: (j['nickname'] ?? '').toString(),
      );
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const {};
}
