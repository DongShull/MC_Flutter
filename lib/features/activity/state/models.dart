/// 活动域模型（对齐 core/model/Activity.kt，手写 fromJson，snake_case 直读）。
library;

import '../../../core/models/format.dart';

/// 任务进度（服务端 JobView.progress）。
class JobProgress {
  const JobProgress({
    this.mode = '',
    this.phase = '',
    this.message = '',
    this.current,
    this.total,
    this.percent,
    this.details = const {},
  });

  final String mode;
  final String phase;
  final String message;
  final int? current;
  final int? total;
  final double? percent;

  /// 领域进度明细（历史行标题/摘要从这里取 media_title、identified 等键）。
  final Map<String, dynamic> details;

  factory JobProgress.fromJson(Map<String, dynamic> j) => JobProgress(
        mode: j['mode'] as String? ?? '',
        phase: j['phase'] as String? ?? '',
        message: j['message'] as String? ?? '',
        current: (j['current'] as num?)?.toInt(),
        total: (j['total'] as num?)?.toInt(),
        percent: (j['percent'] as num?)?.toDouble(),
        details: (j['details'] as Map<String, dynamic>?) ?? const {},
      );
}

/// 任务错误动作（type 机器名 + label 服务端给）。
class JobErrorAction {
  JobErrorAction({this.type = '', this.label = ''});

  final String type;
  final String label;

  factory JobErrorAction.fromJson(Map<String, dynamic> j) => JobErrorAction(
        type: j['type'] as String? ?? '',
        label: j['label'] as String? ?? '',
      );
}

/// 任务错误：{code, message, actions}。
class JobErrorView {
  JobErrorView({this.code = '', this.message = '', this.actions = const []});

  final String code;
  final String message;
  final List<JobErrorAction> actions;

  factory JobErrorView.fromJson(Map<String, dynamic> j) => JobErrorView(
        code: j['code'] as String? ?? '',
        message: j['message'] as String? ?? '',
        actions: ((j['actions'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(JobErrorAction.fromJson)
            .toList(),
      );
}

/// 任务占用的资源；library.ingest 挂 download 资源时 resource_id = info_hash。
class JobResourceView {
  JobResourceView({this.resourceType = '', this.resourceId = ''});

  final String resourceType;
  final String resourceId;

  factory JobResourceView.fromJson(Map<String, dynamic> j) => JobResourceView(
        resourceType: j['resource_type'] as String? ?? '',
        resourceId: j['resource_id'] as String? ?? '',
      );
}

/// 后台任务（服务端 JobView）。
class JobView {
  JobView({
    required this.id,
    this.jobType = '',
    this.jobTypeLabel,
    this.subject,
    this.status = '',
    this.progress = const JobProgress(),
    this.error,
    this.resources = const [],
    this.inputData = const {},
    this.startedAt,
    this.dismissedAt,
    this.cancelRequestedBy,
    this.finishedAt,
    this.createdAt,
  });

  final String id;
  final String jobType;
  final String? jobTypeLabel;
  final String? subject;
  final String status;
  final JobProgress progress;
  final JobErrorView? error;
  final List<JobResourceView> resources;
  final Map<String, dynamic> inputData;
  final String? startedAt;

  /// 非空 = 被用户忽略，不再出现在「需要处理」。
  final String? dismissedAt;

  /// system: 前缀 = 系统取消（不给「重新执行」）。
  final String? cancelRequestedBy;
  final String? finishedAt;
  final String? createdAt;

  factory JobView.fromJson(Map<String, dynamic> j) => JobView(
        id: j['id'] as String? ?? '',
        jobType: j['job_type'] as String? ?? '',
        jobTypeLabel: j['job_type_label'] as String?,
        subject: j['subject'] as String?,
        status: j['status'] as String? ?? '',
        progress: j['progress'] is Map<String, dynamic>
            ? JobProgress.fromJson(j['progress'] as Map<String, dynamic>)
            : const JobProgress(),
        error: j['error'] is Map<String, dynamic>
            ? JobErrorView.fromJson(j['error'] as Map<String, dynamic>)
            : null,
        resources: ((j['resources'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(JobResourceView.fromJson)
            .toList(),
        inputData: (j['input_data'] as Map<String, dynamic>?) ?? const {},
        startedAt: j['started_at'] as String?,
        dismissedAt: j['dismissed_at'] as String?,
        cancelRequestedBy: j['cancel_requested_by'] as String?,
        finishedAt: j['finished_at'] as String?,
        createdAt: j['created_at'] as String?,
      );

  String? detailString(String key) {
    final v = progress.details[key] ?? inputData[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }
}

/// 订阅逐集覆盖（下载任务卡上的「覆盖 N 集 · 已入库 M」）。
class DownloadTaskUnit {
  DownloadTaskUnit({
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
  DownloadTaskSubscription({this.units = const []});

  final List<DownloadTaskUnit> units;

  factory DownloadTaskSubscription.fromJson(Map<String, dynamic> j) =>
      DownloadTaskSubscription(
        units: ((j['units'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DownloadTaskUnit.fromJson)
            .toList(),
      );
}

/// 下载器快照里的种子任务。
class DownloadTask {
  DownloadTask({
    required this.id,
    this.infoHash = '',
    this.name,
    this.downloaderId,
    this.progress,
    this.state = '',
    this.source = '',
    this.mediaTitle,
    this.mediaKind,
    this.posterUrl,
    this.errorMessage,
    this.landingError,
    this.canReplace = false,
    this.mediaItemId,
    this.subscriptions = const [],
  });

  final String id;
  final String infoHash;
  final String? name;
  final int? downloaderId;

  /// 0..1；缺失为 null。
  final double? progress;
  final String state;
  final String source;
  final String? mediaTitle;
  final String? mediaKind;
  final String? posterUrl;
  final String? errorMessage;

  /// 下载完成但看不到文件（落点核验失败）。
  final String? landingError;
  final bool canReplace;
  final int? mediaItemId;
  final List<DownloadTaskSubscription> subscriptions;

  factory DownloadTask.fromJson(Map<String, dynamic> j) => DownloadTask(
        id: j['id'] as String? ?? j['info_hash'] as String? ?? '',
        infoHash: j['info_hash'] as String? ?? '',
        name: j['name'] as String?,
        downloaderId: (j['downloader_id'] as num?)?.toInt(),
        progress: (j['progress'] as num?)?.toDouble(),
        state: j['state'] as String? ?? '',
        source: j['source'] as String? ?? '',
        mediaTitle: j['media_title'] as String?,
        mediaKind: j['media_kind'] as String?,
        posterUrl: j['poster_url'] as String?,
        errorMessage: j['error_message'] as String?,
        landingError: j['landing_error'] as String?,
        canReplace: j['can_replace'] as bool? ?? false,
        mediaItemId: (j['media_item_id'] as num?)?.toInt(),
        subscriptions: ((j['subscriptions'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DownloadTaskSubscription.fromJson)
            .toList(),
      );

  /// 内容核验证明种子里没有这几集（形如 S01E05 / S01E05 等 3 集）。
  String? contentMissingLabel() {
    final units =
        subscriptions.firstOrNull?.units.where((u) => u.contentMissing).toList() ??
            const <DownloadTaskUnit>[];
    if (units.isEmpty) return null;
    final first = units.first;
    final label =
        mcEpisodeLabel(first.seasonNumber, first.episodeNumber);
    return units.length == 1 ? label : '$label 等 ${units.length} 集';
  }

  /// 覆盖与入库进度（imported 或 replaced 算已入库）。
  (int, int)? unitSummary() {
    final units = subscriptions.firstOrNull?.units;
    if (units == null || units.isEmpty) return null;
    return (units.length, units.where((u) => u.status == 'imported' || u.replaced).length);
  }
}

/// 活动页作品目标（正在播放 / 历史行共用的条目元信息）。
class MediaActivityTarget {
  const MediaActivityTarget({
    this.mediaItemId = 0,
    this.libraryId,
    this.kind = 'movie',
    this.title = '',
    this.year,
    this.posterUrl,
    this.seasonNumber = 0,
    this.episodeNumber = 0,
  });

  final int mediaItemId;
  final int? libraryId;
  final String kind;
  final String title;
  final int? year;
  final String? posterUrl;
  final int seasonNumber;
  final int episodeNumber;

  factory MediaActivityTarget.fromJson(Map<String, dynamic> j) => MediaActivityTarget(
        mediaItemId: (j['media_item_id'] as num?)?.toInt() ?? 0,
        libraryId: (j['library_id'] as num?)?.toInt(),
        kind: j['kind'] as String? ?? 'movie',
        title: j['title'] as String? ?? '',
        year: (j['year'] as num?)?.toInt(),
        posterUrl: j['poster_url'] as String?,
        seasonNumber: (j['season_number'] as num?)?.toInt() ?? 0,
        episodeNumber: (j['episode_number'] as num?)?.toInt() ?? 0,
      );
}

/// 一条正在进行的播放会话（观看视角「正在播放」卡）。
class ActivePlaybackSession {
  ActivePlaybackSession({
    required this.deviceId,
    this.memberName = '',
    this.client = '',
    this.deviceName = '',
    this.media = const MediaActivityTarget(),
    this.positionMs,
    this.durationMs,
    this.paused = false,
    this.playMethod = '',
    this.rateBytesPerSecond,
  });

  final String deviceId;
  final String memberName;
  final String client;
  final String deviceName;
  final MediaActivityTarget media;
  final int? positionMs;
  final int? durationMs;
  final bool paused;

  /// local = 本机直连；remote = 网盘直链。
  final String playMethod;
  final double? rateBytesPerSecond;

  factory ActivePlaybackSession.fromJson(Map<String, dynamic> j) =>
      ActivePlaybackSession(
        deviceId: j['device_id'] as String? ?? '',
        memberName: j['member_name'] as String? ?? '',
        client: j['client'] as String? ?? '',
        deviceName: j['device_name'] as String? ?? '',
        media: j['media'] is Map<String, dynamic>
            ? MediaActivityTarget.fromJson(j['media'] as Map<String, dynamic>)
            : const MediaActivityTarget(),
        positionMs: (j['position_ms'] as num?)?.toInt(),
        durationMs: (j['duration_ms'] as num?)?.toInt(),
        paused: j['paused'] as bool? ?? false,
        playMethod: j['play_method'] as String? ?? '',
        rateBytesPerSecond: (j['rate_bytes_per_second'] as num?)?.toDouble(),
      );
}

/// 设备正在拉的整文件（播放器离线缓存）——「正在下载」分区。
class ActiveFileDownload {
  ActiveFileDownload({
    required this.deviceId,
    this.memberName = '',
    this.deviceName = '',
    this.media,
    this.fileName = '',
    this.sizeBytes = 0,
    this.rateBytesPerSecond,
    this.progressPercent,
  });

  final String deviceId;
  final String memberName;
  final String deviceName;
  final MediaActivityTarget? media;
  final String fileName;
  final int sizeBytes;
  final double? rateBytesPerSecond;
  final int? progressPercent;

  factory ActiveFileDownload.fromJson(Map<String, dynamic> j) =>
      ActiveFileDownload(
        deviceId: j['device_id'] as String? ?? '',
        memberName: j['member_name'] as String? ?? '',
        deviceName: j['device_name'] as String? ?? '',
        media: j['media'] is Map<String, dynamic>
            ? MediaActivityTarget.fromJson(j['media'] as Map<String, dynamic>)
            : null,
        fileName: j['file_name'] as String? ?? '',
        sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
        rateBytesPerSecond: (j['rate_bytes_per_second'] as num?)?.toDouble(),
        progressPercent: (j['progress_percent'] as num?)?.toInt(),
      );
}

/// GET /playback/activity 的汇总。
class PlaybackActivityView {
  PlaybackActivityView({this.sessions = const [], this.downloads = const []});

  final List<ActivePlaybackSession> sessions;
  final List<ActiveFileDownload> downloads;

  factory PlaybackActivityView.fromJson(Map<String, dynamic> j) =>
      PlaybackActivityView(
        sessions: ((j['sessions'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ActivePlaybackSession.fromJson)
            .toList(),
        downloads: ((j['downloads'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ActiveFileDownload.fromJson)
            .toList(),
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
  PlaybackStatsDayRow({
    this.date = '',
    this.plays = 0,
    this.watchedMs = 0,
  });

  final String date;
  final int plays;
  final int watchedMs;

  factory PlaybackStatsDayRow.fromJson(Map<String, dynamic> j) =>
      PlaybackStatsDayRow(
        date: j['date'] as String? ?? '',
        plays: (j['plays'] as num?)?.toInt() ?? 0,
        watchedMs: (j['watched_ms'] as num?)?.toInt() ?? 0,
      );
}

class PlaybackStatsMemberRow {
  PlaybackStatsMemberRow({
    this.memberId = 0,
    this.memberName = '',
    this.plays = 0,
    this.watchedMs = 0,
  });

  final int memberId;
  final String memberName;
  final int plays;
  final int watchedMs;

  factory PlaybackStatsMemberRow.fromJson(Map<String, dynamic> j) =>
      PlaybackStatsMemberRow(
        memberId: (j['member_id'] as num?)?.toInt() ?? 0,
        memberName: j['member_name'] as String? ?? '',
        plays: (j['plays'] as num?)?.toInt() ?? 0,
        watchedMs: (j['watched_ms'] as num?)?.toInt() ?? 0,
      );
}

class PlaybackStatsClientRow {
  PlaybackStatsClientRow({this.client = '', this.plays = 0, this.watchedMs = 0});

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

class PlaybackStatsTitleRow {
  PlaybackStatsTitleRow({
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
        media: j['media'] is Map<String, dynamic>
            ? MediaActivityTarget.fromJson(j['media'] as Map<String, dynamic>)
            : const MediaActivityTarget(),
        plays: (j['plays'] as num?)?.toInt() ?? 0,
        watchedMs: (j['watched_ms'] as num?)?.toInt() ?? 0,
        members: (j['members'] as num?)?.toInt() ?? 0,
      );
}

class PlaybackWatchStatsView {
  PlaybackWatchStatsView({
    this.days = 7,
    this.current = const PlaybackStatsTotals(),
    this.previous = const PlaybackStatsTotals(),
    this.previousAvailable = false,
    this.byDay = const [],
    this.byHour = const [],
    this.byMember = const [],
    this.byClient = const [],
    this.byTier = const [],
    this.topTitles = const [],
    this.favorites = const [],
    this.previousFavorites = const [],
  });

  final int days;
  final PlaybackStatsTotals current;
  final PlaybackStatsTotals previous;
  final bool previousAvailable;
  final List<PlaybackStatsDayRow> byDay;

  /// 7×24 观看时长矩阵（毫秒），0 行 = 周一。
  final List<List<int>> byHour;
  final List<PlaybackStatsMemberRow> byMember;
  final List<PlaybackStatsClientRow> byClient;
  final List<Map<String, dynamic>> byTier;
  final List<PlaybackStatsTitleRow> topTitles;
  final List<PlaybackStatsTitleRow> favorites;
  final List<PlaybackStatsTitleRow> previousFavorites;

  factory PlaybackWatchStatsView.fromJson(Map<String, dynamic> j) =>
      PlaybackWatchStatsView(
        days: (j['days'] as num?)?.toInt() ?? 7,
        current: j['current'] is Map<String, dynamic>
            ? PlaybackStatsTotals.fromJson(j['current'] as Map<String, dynamic>)
            : const PlaybackStatsTotals(),
        previous: j['previous'] is Map<String, dynamic>
            ? PlaybackStatsTotals.fromJson(j['previous'] as Map<String, dynamic>)
            : const PlaybackStatsTotals(),
        previousAvailable: j['previous_available'] as bool? ?? false,
        byDay: ((j['by_day'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PlaybackStatsDayRow.fromJson)
            .toList(),
        byHour: ((j['by_hour'] as List<dynamic>?) ?? const [])
            .map((row) => ((row as List<dynamic>?) ?? const <int>[])
                .map((v) => (v as num?)?.toInt() ?? 0)
                .toList())
            .toList(),
        byMember: ((j['by_member'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PlaybackStatsMemberRow.fromJson)
            .toList(),
        byClient: ((j['by_client'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PlaybackStatsClientRow.fromJson)
            .toList(),
        byTier: ((j['by_tier'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
        topTitles: ((j['top_titles'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PlaybackStatsTitleRow.fromJson)
            .toList(),
        favorites: ((j['favorites'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PlaybackStatsTitleRow.fromJson)
            .toList(),
        previousFavorites: ((j['previous_favorites'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PlaybackStatsTitleRow.fromJson)
            .toList(),
      );
}

/// 一条播放历史（最近播放流水）。
class PlaybackLogEntry {
  PlaybackLogEntry({
    required this.id,
    this.memberName = '',
    this.media = const MediaActivityTarget(),
    this.client = '',
    this.deviceName = '',
    this.startedAt = '',
    this.watchedMs = 0,
    this.completed = false,
  });

  final int id;
  final String memberName;
  final MediaActivityTarget media;
  final String client;
  final String deviceName;
  final String startedAt;
  final int watchedMs;
  final bool completed;

  factory PlaybackLogEntry.fromJson(Map<String, dynamic> j) => PlaybackLogEntry(
        id: (j['id'] as num?)?.toInt() ?? 0,
        memberName: j['member_name'] as String? ?? '',
        media: j['media'] is Map<String, dynamic>
            ? MediaActivityTarget.fromJson(j['media'] as Map<String, dynamic>)
            : const MediaActivityTarget(),
        client: j['client'] as String? ?? '',
        deviceName: j['device_name'] as String? ?? '',
        startedAt: j['started_at'] as String? ?? '',
        watchedMs: (j['watched_ms'] as num?)?.toInt() ?? 0,
        completed: j['completed'] as bool? ?? false,
      );
}

class PlaybackHistoryView {
  PlaybackHistoryView({this.entries = const [], this.hasMore = false});

  final List<PlaybackLogEntry> entries;
  final bool hasMore;

  factory PlaybackHistoryView.fromJson(Map<String, dynamic> j) =>
      PlaybackHistoryView(
        entries: ((j['entries'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PlaybackLogEntry.fromJson)
            .toList(),
        hasMore: j['has_more'] as bool? ?? false,
      );
}

