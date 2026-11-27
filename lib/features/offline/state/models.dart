import '../../../core/models/format.dart';

/// 单个下载单元的状态（对齐 iOS OfflineUnit.State + 蜂窝/转码排队状态）。
enum OfflineUnitStatus {
  preparing,
  queued,
  running,
  paused,
  waitingWifi,
  waitingTranscode,
  done,
  failed,
}

extension OfflineUnitStatusX on OfflineUnitStatus {
  String text({
    int ahead = 0,
    bool waitingForWifi = false,
    String? transcodeWait,
    double? progress,
    int? receivedBytes,
    int? expectedBytes,
    String? error,
    bool retryable = true,
    bool damaged = false,
  }) {
    if (damaged) return '文件损坏';
    if (waitingForWifi &&
        (this == OfflineUnitStatus.queued ||
            this == OfflineUnitStatus.running ||
            this == OfflineUnitStatus.waitingWifi)) {
      return '等待 Wi-Fi';
    }
    switch (this) {
      case OfflineUnitStatus.preparing:
        return '准备中…';
      case OfflineUnitStatus.queued:
        if (ahead == 1) return '下一个下载';
        if (ahead > 1) return '等待下载，前面还有 $ahead 个';
        return '排队中';
      case OfflineUnitStatus.running:
        if (expectedBytes != null && expectedBytes > 0 && progress != null) {
          return '正在下载 ${(progress.clamp(0.0, 1.0) * 100).round()}%';
        }
        if (receivedBytes != null && receivedBytes > 0) {
          return '正在下载 ${mcFormatBytes(receivedBytes)}';
        }
        return '正在下载';
      case OfflineUnitStatus.paused:
        if (progress != null && progress > 0) {
          return '已暂停 ${(progress.clamp(0.0, 1.0) * 100).round()}%';
        }
        return '已暂停';
      case OfflineUnitStatus.waitingWifi:
        return '等待 Wi-Fi';
      case OfflineUnitStatus.waitingTranscode:
        return transcodeWait?.isNotEmpty == true ? transcodeWait! : '等待服务器转码';
      case OfflineUnitStatus.done:
        return '已下载';
      case OfflineUnitStatus.failed:
        if (transcodeWait != null && transcodeWait.isNotEmpty) {
          return transcodeWait;
        }
        if (retryable) return '下载中断，稍后自动重试';
        return (error != null && error.isNotEmpty) ? error : '下载失败';
    }
  }
}

/// 一个下载单元（一集 / 一部电影的一个档位，对齐 iOS OfflineUnit）。
class DownloadUnit {
  const DownloadUnit({
    required this.id,
    required this.title,
    this.seasonEpisode,
    required this.profileLabel,
    this.status = OfflineUnitStatus.queued,
    this.progress = 0,
    this.speedBps = 0,
    this.priority = 0,
    this.totalBytes,
    this.savePath,
    this.watched = false,
    this.mediaItemId,
    this.fileId,
    this.libraryId,
    this.libraryName,
    this.libraryKind,
    this.kind = 'movie',
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.profile = 'original',
    this.fileExtension = 'mkv',
    this.exportId,
    this.posterUrl,
    this.backdropUrl,
    this.stillUrl,
    this.year,
    this.receivedBytes = 0,
    this.expectedBytes = 0,
    this.error,
    this.transcodeWait,
    this.retryable = true,
    this.attempts = 0,
    this.nextRetryAt,
    this.damaged = false,
    this.createdAt,
    this.completedAt,
    this.queueOrder,
  });

  final String id;
  final String title;
  final String? seasonEpisode;
  final String profileLabel;
  final OfflineUnitStatus status;
  final double progress;
  final int speedBps;
  final int priority;
  final int? totalBytes;
  final String? savePath;
  final bool watched;

  final int? mediaItemId;
  final int? fileId;
  final int? libraryId;
  final String? libraryName;
  final String? libraryKind;
  final String kind;
  final int seasonNumber;
  final int episodeNumber;
  final String profile;
  final String fileExtension;
  final String? exportId;
  final String? posterUrl;
  final String? backdropUrl;
  final String? stillUrl;
  final int? year;
  final int receivedBytes;
  final int expectedBytes;
  final String? error;
  final String? transcodeWait;
  final bool retryable;
  final int attempts;
  final DateTime? nextRetryAt;
  final bool damaged;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final double? queueOrder;

  bool get isMovie => kind != 'tv' && seasonNumber == 0 && episodeNumber == 0;
  bool get playable => status == OfflineUnitStatus.done && !damaged;
  bool get waitingForTranscode =>
      status == OfflineUnitStatus.waitingTranscode ||
      (status == OfflineUnitStatus.failed &&
          retryable &&
          transcodeWait != null &&
          transcodeWait!.isNotEmpty);
  bool get needsAttention =>
      (status == OfflineUnitStatus.failed && !waitingForTranscode) || damaged;

  /// 非完成态均归入「下载中」列表（含准备中、排队、下载中、暂停、等待 Wi-Fi、等待转码、失败）。
  bool get isActive => status != OfflineUnitStatus.done;

  /// 仍在调度队列中、迟早轮到它（暂停和不可重试的失败除外）。
  bool get inQueue =>
      status == OfflineUnitStatus.preparing ||
      status == OfflineUnitStatus.queued ||
      status == OfflineUnitStatus.running ||
      status == OfflineUnitStatus.waitingWifi ||
      status == OfflineUnitStatus.waitingTranscode ||
      (status == OfflineUnitStatus.failed && retryable);

  String get unitKey => '$seasonNumber-$episodeNumber';

  int get effectiveTotalBytes =>
      totalBytes ?? (expectedBytes > 0 ? expectedBytes : 0);

  double get progressFraction {
    if (status == OfflineUnitStatus.done) return 1.0;
    if (effectiveTotalBytes > 0 && receivedBytes > 0) {
      return (receivedBytes / effectiveTotalBytes).clamp(0.0, 1.0);
    }
    return progress.clamp(0.0, 1.0);
  }

  /// 真实季集标签（绝不使用数组下标冒充）。
  String? get displaySeasonEpisode {
    if (seasonEpisode != null && seasonEpisode!.isNotEmpty) {
      return seasonEpisode;
    }
    if (seasonNumber > 0 || episodeNumber > 0) {
      if (seasonNumber == 0) return '特别篇 第 $episodeNumber 集';
      return '第 $seasonNumber 季 第 $episodeNumber 集';
    }
    return null;
  }

  DownloadUnit copyWith({
    OfflineUnitStatus? status,
    double? progress,
    int? speedBps,
    int? priority,
    int? totalBytes,
    String? savePath,
    bool? watched,
    String? exportId,
    bool clearExportId = false,
    String? posterUrl,
    String? backdropUrl,
    String? stillUrl,
    int? receivedBytes,
    int? expectedBytes,
    String? error,
    bool clearError = false,
    String? transcodeWait,
    bool clearTranscodeWait = false,
    bool? retryable,
    int? attempts,
    DateTime? nextRetryAt,
    bool clearNextRetryAt = false,
    bool? damaged,
    DateTime? completedAt,
    double? queueOrder,
    String? fileExtension,
    String? seasonEpisode,
    int? seasonNumber,
    int? episodeNumber,
    int? mediaItemId,
    int? libraryId,
    String? libraryName,
    String? libraryKind,
    String? kind,
    int? year,
  }) =>
      DownloadUnit(
        id: id,
        title: title,
        seasonEpisode: seasonEpisode ?? this.seasonEpisode,
        profileLabel: profileLabel,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        speedBps: speedBps ?? this.speedBps,
        priority: priority ?? this.priority,
        totalBytes: totalBytes ?? this.totalBytes,
        savePath: savePath ?? this.savePath,
        watched: watched ?? this.watched,
        mediaItemId: mediaItemId ?? this.mediaItemId,
        fileId: fileId,
        libraryId: libraryId ?? this.libraryId,
        libraryName: libraryName ?? this.libraryName,
        libraryKind: libraryKind ?? this.libraryKind,
        kind: kind ?? this.kind,
        seasonNumber: seasonNumber ?? this.seasonNumber,
        episodeNumber: episodeNumber ?? this.episodeNumber,
        profile: profile,
        fileExtension: fileExtension ?? this.fileExtension,
        exportId: clearExportId ? null : (exportId ?? this.exportId),
        posterUrl: posterUrl ?? this.posterUrl,
        backdropUrl: backdropUrl ?? this.backdropUrl,
        stillUrl: stillUrl ?? this.stillUrl,
        year: year ?? this.year,
        receivedBytes: receivedBytes ?? this.receivedBytes,
        expectedBytes: expectedBytes ?? this.expectedBytes,
        error: clearError ? null : (error ?? this.error),
        transcodeWait: clearTranscodeWait
            ? null
            : (transcodeWait ?? this.transcodeWait),
        retryable: retryable ?? this.retryable,
        attempts: attempts ?? this.attempts,
        nextRetryAt:
            clearNextRetryAt ? null : (nextRetryAt ?? this.nextRetryAt),
        damaged: damaged ?? this.damaged,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
        queueOrder: queueOrder ?? this.queueOrder,
      );
}

/// 下载档位（画质选项，对齐 iOS OfflineProfileView）。
class DownloadProfile {
  const DownloadProfile({
    required this.id,
    required this.label,
    required this.isOriginal,
    this.estimatedBytes,
    this.transcode = false,
    this.height,
  });

  final String id;
  final String label;
  final bool isOriginal;
  final int? estimatedBytes;
  final bool transcode;
  final int? height;

  int get expectedBytes => estimatedBytes ?? 0;

  String get subtitle {
    final parts = <String>[];
    if (estimatedBytes != null && estimatedBytes! > 0) {
      parts.add((isOriginal ? '' : '≈ ') + mcFormatBytes(estimatedBytes!));
    }
    if (transcode) {
      parts.add('服务器转码后下载，体积更小');
    } else if (isOriginal) {
      parts.add('与源文件完全一致');
    }
    return parts.join(' · ');
  }

  factory DownloadProfile.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] ?? json['id'] ?? 'original').toString();
    final isOrig = profile == 'original';
    final expected = _asInt(json['expected_bytes'] ?? json['expectedBytes']);
    return DownloadProfile(
      id: profile,
      label: (json['label'] ?? (isOrig ? '原画' : profile.toUpperCase()))
          .toString(),
      isOriginal: isOrig,
      estimatedBytes: expected,
      transcode: !isOrig,
      height: _asInt(json['height']),
    );
  }
}

/// 批量档位查询返回的单文件项（POST /api/v1/offline/profiles → files[]）。
class OfflineFileProfiles {
  const OfflineFileProfiles({
    required this.fileId,
    required this.mediaItemId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.container,
    this.profiles = const [],
    this.unavailableReason,
  });

  final int fileId;
  final int mediaItemId;
  final int seasonNumber;
  final int episodeNumber;
  final String? container;
  final List<DownloadProfile> profiles;
  final String? unavailableReason;

  factory OfflineFileProfiles.fromJson(Map<String, dynamic> json) {
    final rawProfiles = (json['profiles'] as List?) ?? const [];
    return OfflineFileProfiles(
      fileId: _asInt(json['file_id'] ?? json['fileId']) ?? 0,
      mediaItemId: _asInt(json['media_item_id'] ?? json['mediaItemId']) ?? 0,
      seasonNumber: _asInt(json['season_number'] ?? json['seasonNumber']) ?? 0,
      episodeNumber:
          _asInt(json['episode_number'] ?? json['episodeNumber']) ?? 0,
      container: _asString(json['container']),
      profiles: rawProfiles
          .whereType<Map>()
          .map((e) => DownloadProfile.fromJson(e.cast<String, dynamic>()))
          .toList(),
      unavailableReason:
          _asString(json['unavailable_reason'] ?? json['unavailableReason']),
    );
  }
}

/// 转码导出响应（POST /api/v1/offline/exports / GET /api/v1/offline/exports/{id}）。
class OfflineExportInfo {
  const OfflineExportInfo({
    required this.exportId,
    required this.status,
    this.etag,
    this.expectedBytes = 0,
    this.finalBytes,
    this.error,
    this.queuePosition,
    required this.contentUrl,
  });

  final String exportId;
  final String status;
  final String? etag;
  final int expectedBytes;
  final int? finalBytes;
  final String? error;
  final int? queuePosition;
  final String contentUrl;

  factory OfflineExportInfo.fromJson(Map<String, dynamic> json) =>
      OfflineExportInfo(
        exportId: (json['export_id'] ?? json['exportId'] ?? '').toString(),
        status: (json['status'] ?? 'queued').toString(),
        etag: _asString(json['etag']),
        expectedBytes:
            _asInt(json['expected_bytes'] ?? json['expectedBytes']) ?? 0,
        finalBytes: _asInt(json['final_bytes'] ?? json['finalBytes']),
        error: _asString(json['error']),
        queuePosition: _asInt(json['queue_position'] ?? json['queuePosition']),
        contentUrl:
            (json['content_url'] ?? json['contentUrl'] ?? '').toString(),
      );
}

/// 清单内的一条字幕项（OfflineSubtitleView）。
class OfflineSubtitleInfo {
  const OfflineSubtitleInfo({
    required this.trackRef,
    required this.format,
    this.language,
    this.title,
    this.isDefault = false,
    this.isForced = false,
    this.isAi = false,
    this.embedded = false,
    required this.url,
  });

  final String trackRef;
  final String format;
  final String? language;
  final String? title;
  final bool isDefault;
  final bool isForced;
  final bool isAi;
  final bool embedded;
  final String url;

  factory OfflineSubtitleInfo.fromJson(Map<String, dynamic> json) =>
      OfflineSubtitleInfo(
        trackRef: (json['track_ref'] ?? json['trackRef'] ?? '').toString(),
        format: (json['format'] ?? 'srt').toString().toLowerCase(),
        language: _asString(json['language']),
        title: _asString(json['title']),
        isDefault: json['is_default'] == true || json['isDefault'] == true,
        isForced: json['is_forced'] == true || json['isForced'] == true,
        isAi: json['is_ai'] == true || json['isAi'] == true,
        embedded: json['embedded'] == true,
        url: (json['url'] ?? '').toString(),
      );
}

/// 服务器返回的完整离线清单（GET /api/v1/offline/manifest?file_id=）。
class OfflineManifest {
  const OfflineManifest({
    required this.fileId,
    this.mediaItemId = 0,
    this.libraryId = 0,
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.container,
    this.sizeBytes = 0,
    this.durationMs,
    this.itemJson,
    this.libraryJson,
    this.seasonJson,
    this.chaptersJson = const [],
    this.segmentsJson = const [],
    this.audioTracksJson = const [],
    this.defaultAudio,
    this.defaultSubtitle,
    this.subtitles = const [],
    this.fontsUrl,
    this.profiles = const [],
    this.unavailableReason,
    this.resumePositionMs,
    this.episodes = const [],
  });

  final String fileId;
  final int mediaItemId;
  final int libraryId;
  final int seasonNumber;
  final int episodeNumber;
  final String? container;
  final int sizeBytes;
  final int? durationMs;
  final Map<String, dynamic>? itemJson;
  final Map<String, dynamic>? libraryJson;
  final Map<String, dynamic>? seasonJson;
  final List<Map<String, dynamic>> chaptersJson;
  final List<Map<String, dynamic>> segmentsJson;
  final List<Map<String, dynamic>> audioTracksJson;
  final String? defaultAudio;
  final String? defaultSubtitle;
  final List<OfflineSubtitleInfo> subtitles;
  final String? fontsUrl;
  final List<DownloadProfile> profiles;
  final String? unavailableReason;
  final int? resumePositionMs;
  final List<String> episodes;

  int get fileIdInt => int.tryParse(fileId) ?? 0;

  String get itemTitle => _asString(itemJson?['title']) ?? '';
  String get itemKind => _asString(itemJson?['kind']) ?? 'movie';
  int? get itemYear => _asInt(itemJson?['year']);
  String? get itemPosterUrl =>
      _asString(itemJson?['poster_url'] ?? itemJson?['posterUrl']);
  String? get itemBackdropUrl =>
      _asString(itemJson?['backdrop_url'] ?? itemJson?['backdropUrl']);
  String get libraryName => _asString(libraryJson?['name']) ?? '媒体库';
  String get libraryKind => _asString(libraryJson?['kind']) ?? itemKind;

  String? get episodeStillUrl {
    final eps = seasonJson?['episodes'];
    if (eps is List) {
      for (final raw in eps.whereType<Map>()) {
        final epNum =
            _asInt(raw['episode_number'] ?? raw['episodeNumber']);
        if (epNum == episodeNumber) {
          return _asString(raw['still_url'] ?? raw['stillUrl']);
        }
      }
    }
    return null;
  }

  OfflineFileProfiles toFileProfiles() => OfflineFileProfiles(
        fileId: fileIdInt,
        mediaItemId: mediaItemId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        container: container,
        profiles: profiles,
        unavailableReason: unavailableReason,
      );

  factory OfflineManifest.fromJson(Map<String, dynamic> json) {
    final item = json['item'] is Map
        ? (json['item'] as Map).cast<String, dynamic>()
        : null;
    final lib = json['library'] is Map
        ? (json['library'] as Map).cast<String, dynamic>()
        : null;
    final season = json['season'] is Map
        ? (json['season'] as Map).cast<String, dynamic>()
        : null;
    return OfflineManifest(
      fileId: (json['file_id'] ?? json['fileId'] ?? '').toString(),
      mediaItemId: _asInt(json['media_item_id'] ?? json['mediaItemId']) ??
          _asInt(item?['media_item_id'] ?? item?['mediaItemId']) ??
          0,
      libraryId: _asInt(json['library_id'] ?? json['libraryId']) ??
          _asInt(lib?['id']) ??
          0,
      seasonNumber: _asInt(json['season_number'] ?? json['seasonNumber']) ?? 0,
      episodeNumber:
          _asInt(json['episode_number'] ?? json['episodeNumber']) ?? 0,
      container: _asString(json['container']),
      sizeBytes: _asInt(json['size_bytes'] ?? json['sizeBytes']) ?? 0,
      durationMs: _asInt(json['duration_ms'] ?? json['durationMs']),
      itemJson: item,
      libraryJson: lib,
      seasonJson: season,
      chaptersJson: ((json['chapters'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      segmentsJson: ((json['segments'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      audioTracksJson:
          (((json['audio_tracks'] ?? json['audioTracks']) as List?) ?? const [])
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList(),
      defaultAudio: _asString(json['default_audio'] ?? json['defaultAudio']),
      defaultSubtitle:
          _asString(json['default_subtitle'] ?? json['defaultSubtitle']),
      subtitles: ((json['subtitles'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => OfflineSubtitleInfo.fromJson(e.cast<String, dynamic>()))
          .toList(),
      fontsUrl: _asString(json['fonts_url'] ?? json['fontsUrl']),
      profiles: ((json['profiles'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => DownloadProfile.fromJson(e.cast<String, dynamic>()))
          .toList(),
      unavailableReason:
          _asString(json['unavailable_reason'] ?? json['unavailableReason']),
      resumePositionMs:
          _asInt(json['resume_position_ms'] ?? json['resumePositionMs']),
      episodes: ((json['episodes'] ?? const []) as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// 离线条目展示摘要（存盘 summary.json，离线媒体库只读它）。
class OfflineItemSummary {
  const OfflineItemSummary({
    required this.mediaItemId,
    this.libraryId = 0,
    this.libraryName = '媒体库',
    this.libraryKind = 'movie',
    this.kind = 'movie',
    required this.title,
    this.year,
    this.posterUrl,
    this.backdropUrl,
    this.primaryAspect = 2 / 3,
    required this.addedAt,
  });

  final int mediaItemId;
  final int libraryId;
  final String libraryName;
  final String libraryKind;
  final String kind;
  final String title;
  final int? year;
  final String? posterUrl;
  final String? backdropUrl;
  final double primaryAspect;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {
        'format': 1,
        'mediaItemId': mediaItemId,
        'libraryId': libraryId,
        'libraryName': libraryName,
        'libraryKind': libraryKind,
        'kind': kind,
        'title': title,
        if (year != null) 'year': year,
        if (posterUrl != null) 'posterUrl': posterUrl,
        if (backdropUrl != null) 'backdropUrl': backdropUrl,
        'primaryAspect': primaryAspect,
        'addedAt': addedAt.toUtc().toIso8601String(),
      };

  factory OfflineItemSummary.fromJson(Map<String, dynamic> json) =>
      OfflineItemSummary(
        mediaItemId: _asInt(json['mediaItemId'] ?? json['media_item_id']) ?? 0,
        libraryId: _asInt(json['libraryId'] ?? json['library_id']) ?? 0,
        libraryName:
            _asString(json['libraryName'] ?? json['library_name']) ?? '媒体库',
        libraryKind:
            _asString(json['libraryKind'] ?? json['library_kind']) ?? 'movie',
        kind: _asString(json['kind']) ?? 'movie',
        title: _asString(json['title']) ?? '',
        year: _asInt(json['year']),
        posterUrl: _asString(json['posterUrl'] ?? json['poster_url']),
        backdropUrl: _asString(json['backdropUrl'] ?? json['backdrop_url']),
        primaryAspect:
            (json['primaryAspect'] as num?)?.toDouble() ?? (2.0 / 3.0),
        addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// 离线播放规格（存盘 playback.json，含本地旁挂字幕、字体、章节、片头片尾片段）。
class OfflineLocalSubtitle {
  const OfflineLocalSubtitle({
    required this.ref,
    required this.fileName,
    required this.kind,
    this.language,
    this.title,
    this.isDefault = false,
    this.isForced = false,
    this.isAi = false,
    required this.sourceRef,
  });

  final String ref;
  final String fileName;
  final String kind;
  final String? language;
  final String? title;
  final bool isDefault;
  final bool isForced;
  final bool isAi;
  final String sourceRef;

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'fileName': fileName,
        'kind': kind,
        if (language != null) 'language': language,
        if (title != null) 'title': title,
        'isDefault': isDefault,
        'isForced': isForced,
        'isAi': isAi,
        'sourceRef': sourceRef,
      };

  factory OfflineLocalSubtitle.fromJson(Map<String, dynamic> json) =>
      OfflineLocalSubtitle(
        ref: (json['ref'] ?? '').toString(),
        fileName: (json['fileName'] ?? '').toString(),
        kind: (json['kind'] ?? 'vtt').toString(),
        language: _asString(json['language']),
        title: _asString(json['title']),
        isDefault: json['isDefault'] == true,
        isForced: json['isForced'] == true,
        isAi: json['isAi'] == true,
        sourceRef: (json['sourceRef'] ?? '').toString(),
      );
}

class OfflinePlaybackSpec {
  const OfflinePlaybackSpec({
    this.durationMs,
    this.chapters = const [],
    this.segments = const [],
    this.audioTracks = const [],
    this.defaultAudio,
    this.subtitles = const [],
    this.fonts = const [],
    this.resolution,
    this.videoCodec,
    this.container,
  });

  final int? durationMs;
  final List<Map<String, dynamic>> chapters;
  final List<Map<String, dynamic>> segments;
  final List<Map<String, dynamic>> audioTracks;
  final String? defaultAudio;
  final List<OfflineLocalSubtitle> subtitles;
  final List<String> fonts;
  final String? resolution;
  final String? videoCodec;
  final String? container;

  Map<String, dynamic> toJson() => {
        'format': 1,
        if (durationMs != null) 'durationMs': durationMs,
        'chapters': chapters,
        'segments': segments,
        'audioTracks': audioTracks,
        if (defaultAudio != null) 'defaultAudio': defaultAudio,
        'subtitles': [for (final s in subtitles) s.toJson()],
        'fonts': fonts,
        if (resolution != null) 'resolution': resolution,
        if (videoCodec != null) 'videoCodec': videoCodec,
        if (container != null) 'container': container,
      };

  factory OfflinePlaybackSpec.fromJson(Map<String, dynamic> json) =>
      OfflinePlaybackSpec(
        durationMs: _asInt(json['durationMs']),
        chapters: ((json['chapters'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
        segments: ((json['segments'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
        audioTracks: ((json['audioTracks'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
        defaultAudio: _asString(json['defaultAudio']),
        subtitles: ((json['subtitles'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) =>
                OfflineLocalSubtitle.fromJson(e.cast<String, dynamic>()))
            .toList(),
        fonts: ((json['fonts'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        resolution: _asString(json['resolution']),
        videoCodec: _asString(json['videoCodec']),
        container: _asString(json['container']),
      );
}

/// 本机续播点（存盘 progress.json）。
class OfflineProgress {
  const OfflineProgress({
    required this.positionMs,
    required this.played,
    this.durationMs,
    required this.updatedAt,
  });

  final int positionMs;
  final bool played;
  final int? durationMs;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'positionMs': positionMs,
        'played': played,
        if (durationMs != null) 'durationMs': durationMs,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory OfflineProgress.fromJson(Map<String, dynamic> json) =>
      OfflineProgress(
        positionMs: _asInt(json['positionMs']) ?? 0,
        played: json['played'] == true,
        durationMs: _asInt(json['durationMs']),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// 剧集范围选择的一集输入（对齐 iOS OfflineDownloadChoices.Episode）。
enum OfflineChoiceLocalState { done, active }

class OfflineChoiceEpisode {
  const OfflineChoiceEpisode({
    required this.season,
    required this.episode,
    this.fileId,
    this.played = false,
    this.local,
  });

  final int season;
  final int episode;
  final int? fileId;
  final bool played;
  final OfflineChoiceLocalState? local;
}

/// 剧集下载的一个范围分段（如「第 3 集」「接下来 5 集」「未看 8 集」「剩余 12 集」）。
class OfflineDownloadScope {
  const OfflineDownloadScope({
    required this.id,
    required this.label,
    required this.fileIds,
    this.detail,
    this.preferred = false,
  });

  final String id;
  final String label;
  final List<int> fileIds;
  final String? detail;
  final bool preferred;

  OfflineDownloadScope copyWith({bool? preferred}) => OfflineDownloadScope(
        id: id,
        label: label,
        fileIds: fileIds,
        detail: detail,
        preferred: preferred ?? this.preferred,
      );
}

/// 当季智能下载范围集合（1:1 对齐 iOS 0f372ee4 `OfflineDownloadChoices.make`）：
/// 严格收敛到 `targetSeason`，自动剔除已下载/下载中剧集，动态给出：
/// 当前集 / 接下来 5 集 / 未看 N 集（默认优选）/ 剩余 N 集 / 全部 N 集。
class OfflineDownloadChoices {
  const OfflineDownloadChoices({
    required this.scopes,
    this.note,
    this.seasonLabel,
    this.hasLocal = false,
  });

  final List<OfflineDownloadScope> scopes;
  final String? note;
  final String? seasonLabel;
  final bool hasLocal;

  static OfflineDownloadChoices make({
    required List<OfflineChoiceEpisode> episodes,
    ({int season, int episode})? selected,
    int? selectedFile,
    required bool multiSeason,
    int? season,
    int nextCount = 5,
  }) {
    final targetSeason =
        season ?? selected?.season ?? (episodes.isNotEmpty ? episodes.first.season : null);
    final seasonEpisodes = targetSeason != null
        ? episodes.where((e) => e.season == targetSeason).toList()
        : List<OfflineChoiceEpisode>.from(episodes);
    seasonEpisodes.sort((a, b) {
      final s = a.season.compareTo(b.season);
      return s != 0 ? s : a.episode.compareTo(b.episode);
    });

    String seasonName(int s) => s == 0 ? '特别篇' : '第 $s 季';
    String fullName(int s, int ep) {
      if (!multiSeason) return '第 $ep 集';
      return s == 0 ? '特别篇 第 $ep 集' : '第 $s 季 第 $ep 集';
    }

    String describe(List<OfflineChoiceEpisode> list) {
      if (list.isEmpty) return '';
      final first = list.first;
      final last = list.last;
      if (list.length == 1) return fullName(first.season, first.episode);
      if (first.season == last.season &&
          last.episode - first.episode + 1 == list.length) {
        if (!multiSeason) {
          return '第 ${first.episode}～${last.episode} 集，共 ${list.length} 集';
        }
        return first.season == 0
            ? '特别篇 第 ${first.episode}～${last.episode} 集，共 ${list.length} 集'
            : '第 ${first.season} 季 第 ${first.episode}～${last.episode} 集，共 ${list.length} 集';
      }
      return '${fullName(first.season, first.episode)} 起，共 ${list.length} 集';
    }

    final candidates = seasonEpisodes
        .where((e) => e.fileId != null && e.local == null)
        .toList();
    final done = seasonEpisodes
        .where((e) => e.local == OfflineChoiceLocalState.done)
        .length;
    final active = seasonEpisodes
        .where((e) => e.local == OfflineChoiceLocalState.active)
        .length;

    final scopes = <OfflineDownloadScope>[];
    final notes = <String>[];

    if (selected != null) {
      final index = seasonEpisodes.indexWhere(
        (e) => e.season == selected.season && e.episode == selected.episode,
      );
      if (index >= 0) {
        final current = seasonEpisodes[index];
        if (current.local != null) {
          notes.add(
            current.local == OfflineChoiceLocalState.done
                ? '${fullName(current.season, current.episode)}已下载'
                : '${fullName(current.season, current.episode)}下载中',
          );
          final next = seasonEpisodes
              .sublist(index + 1)
              .where((e) => e.fileId != null && e.local == null)
              .take(nextCount)
              .toList();
          if (next.isNotEmpty && next.length < candidates.length) {
            scopes.add(
              OfflineDownloadScope(
                id: 'next',
                label: '接下来 ${next.length} 集',
                fileIds: [for (final e in next) e.fileId!],
                detail: describe(next),
              ),
            );
          }
        } else if ((selectedFile ?? current.fileId) != null) {
          final fid = selectedFile ?? current.fileId!;
          scopes.add(
            OfflineDownloadScope(
              id: 'selected',
              label: '第 ${current.episode} 集',
              fileIds: [fid],
              detail: fullName(current.season, current.episode),
            ),
          );
        }
      }
    }

    if (done + active > 0) {
      final parts = <String>[
        if (done > 0) '已下载 $done 集',
        if (active > 0) '下载中 $active 集',
      ];
      notes.add('${parts.join('、')} · 不重复下载');
    }

    final unwatched = candidates.where((e) => !e.played).toList();
    final hasWatched = seasonEpisodes.any((e) => e.played);
    if (unwatched.isNotEmpty && unwatched.length < candidates.length) {
      scopes.add(
        OfflineDownloadScope(
          id: 'unwatched',
          label: '未看 ${unwatched.length} 集',
          fileIds: [for (final e in unwatched) e.fileId!],
          detail: describe(unwatched),
          preferred: true,
        ),
      );
    }

    if (candidates.isNotEmpty) {
      final String label;
      if (hasWatched && unwatched.length == candidates.length) {
        label = '未看 ${candidates.length} 集';
      } else if (done + active == 0) {
        label = '全部 ${candidates.length} 集';
      } else {
        label = '剩余 ${candidates.length} 集';
      }
      scopes.add(
        OfflineDownloadScope(
          id: 'all',
          label: label,
          fileIds: [for (final e in candidates) e.fileId!],
          detail: describe(candidates),
        ),
      );
    }

    // 内容完全相同的范围去重只留前者。
    final seen = <String>{};
    final deduped = <OfflineDownloadScope>[];
    for (final s in scopes) {
      final sig = s.fileIds.join(',');
      if (seen.add(sig)) deduped.add(s);
    }

    // 默认选中规则：未看 > 接下来 > 全未看时的全部/剩余 > 第一个。
    if (!deduped.any((s) => s.preferred) && deduped.isNotEmpty) {
      var fallbackIdx = deduped.indexWhere((s) => s.id == 'next');
      if (fallbackIdx < 0 && unwatched.length == candidates.length) {
        fallbackIdx = deduped.indexWhere((s) => s.id == 'all');
      }
      if (fallbackIdx < 0) fallbackIdx = 0;
      deduped[fallbackIdx] = deduped[fallbackIdx].copyWith(preferred: true);
    }

    return OfflineDownloadChoices(
      scopes: deduped,
      note: notes.isEmpty ? null : notes.join(' · '),
      seasonLabel:
          multiSeason && targetSeason != null ? seasonName(targetSeason) : null,
      hasLocal: done + active > 0,
    );
  }
}

/// 一个媒体的下载候选（兼容 detail_page.dart 旧调用，并支持当季智能范围）。
class DownloadCandidate {
  const DownloadCandidate({
    required this.fileId,
    required this.title,
    this.subtitle,
    required this.scopes,
    required this.profiles,
    this.seasonFileIds = const [],
    this.fullSeasonSelected = false,
    this.mediaItemId,
    this.libraryId,
    this.kind,
    this.seasonNumber,
    this.episodeNumber,
    this.posterUrl,
    this.backdropUrl,
    this.seasonEpisodes = const [],
    this.multiSeason = false,
  });

  final String fileId;
  final String title;
  final String? subtitle;
  final List<String> scopes;
  final List<DownloadProfile> profiles;
  final List<String> seasonFileIds;
  final bool fullSeasonSelected;

  final int? mediaItemId;
  final int? libraryId;
  final String? kind;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? posterUrl;
  final String? backdropUrl;
  final List<OfflineChoiceEpisode> seasonEpisodes;
  final bool multiSeason;
}

/// 本机存储容量（StorageCard）。
class StorageInfo {
  const StorageInfo({required this.availableBytes, required this.totalBytes});

  final int availableBytes;
  final int totalBytes;

  double get usedRatio =>
      totalBytes <= 0 ? 0 : 1 - availableBytes / totalBytes;
}

String? _asString(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int? _asInt(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
