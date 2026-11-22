import '../../../core/models/format.dart';

// 离线下载域模型（1:1 对齐 Kotlin feature/offline 的核心数据）。

/// 单个下载单元的状态（对齐 OfflineUnitStatus）。
enum OfflineUnitStatus { queued, running, paused, waitingWifi, done, failed }

extension OfflineUnitStatusX on OfflineUnitStatus {
  /// 状态行文本（对齐 OfflineUnitStatus.text）。
  String text({int ahead = 0, bool waitingForWifi = false}) => switch (this) {
        OfflineUnitStatus.queued => '排队中',
        OfflineUnitStatus.running => '正在下载',
        OfflineUnitStatus.paused => '已暂停',
        OfflineUnitStatus.waitingWifi => '等待 Wi-Fi',
        OfflineUnitStatus.done => '已下载',
        OfflineUnitStatus.failed => '下载失败',
      };
}

/// 一个下载单元（一集 / 一部电影的一个档位）。
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
  });

  final String id;
  final String title;
  final String? seasonEpisode;
  final String profileLabel;
  final OfflineUnitStatus status;
  final double progress; // 0..1
  final int speedBps;
  final int priority; // 越大越优先（对齐拖动排序 -> 优先级）
  final int? totalBytes;

  DownloadUnit copyWith({
    OfflineUnitStatus? status,
    double? progress,
    int? speedBps,
    int? priority,
  }) =>
      DownloadUnit(
        id: id,
        title: title,
        seasonEpisode: seasonEpisode,
        profileLabel: profileLabel,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        speedBps: speedBps ?? this.speedBps,
        priority: priority ?? this.priority,
        totalBytes: totalBytes,
      );

  bool get isActive =>
      status == OfflineUnitStatus.running ||
      status == OfflineUnitStatus.queued ||
      status == OfflineUnitStatus.waitingWifi;
}

/// 下载档位（画质选项；对齐 DownloadProfileSheet 的行）。
class DownloadProfile {
  const DownloadProfile({
    required this.id,
    required this.label,
    required this.isOriginal,
    this.estimatedBytes,
    this.transcode = false,
  });

  final String id;
  final String label;
  final bool isOriginal;
  final int? estimatedBytes;
  final bool transcode;

  /// 行说明：原画显示准确大小，其余加 ≈ 前缀；转码档补一句说明。
  String get subtitle {
    final parts = <String>[];
    if (estimatedBytes != null) {
      parts.add((isOriginal ? '' : '≈ ') + mcFormatBytes(estimatedBytes!));
    }
    if (transcode) parts.add('服务器转码后下载，边转边下');
    return parts.join(' · ');
  }
}

// 字节/速度格式化已下沉 core（mcFormatBytes / mcFormatSpeed）。}

/// 一个媒体的下载候选（profile sheet 的数据源）。
class DownloadCandidate {
  const DownloadCandidate({
    required this.fileId,
    required this.title,
    this.subtitle,
    required this.scopes,
    required this.profiles,
  });

  final String fileId;
  final String title;
  final String? subtitle;
  final List<String> scopes; // e.g. ['本片', '全季']
  final List<DownloadProfile> profiles;
}

/// 服务器存储容量（StorageCard）。
class StorageInfo {
  const StorageInfo({required this.availableBytes, required this.totalBytes});

  final int availableBytes;
  final int totalBytes;

  double get usedRatio =>
      totalBytes <= 0 ? 0 : 1 - availableBytes / totalBytes;
}

/// 服务器返回的 manifest（GET /api/v1/offline/manifest?file_id=）。
/// 字段名对照安卓 `OfflineModels.OfflineManifest`；服务端同时可能
/// 用蛇形或驼峰，解析时两者都认（file_id/fileId 已有先例）。
class OfflineManifest {
  const OfflineManifest({
    required this.fileId,
    this.episodes = const [],
    this.mediaItemId = 0,
    this.seasonNumber = 0,
    this.durationMs,
    this.container,
    this.resumePositionMs,
    this.item,
    this.library,
    this.season,
    this.chapters,
    this.segments,
    this.audioTracks,
    this.defaultAudio,
    this.defaultSubtitle,
    this.subtitles = const [],
  });

  factory OfflineManifest.fromJson(Map<String, dynamic> json) {
    num? numOf(String snake, String camel) {
      final v = json[snake] ?? json[camel];
      return v is num ? v : null;
    }

    String? strOf(String snake, String camel) {
      final v = json[snake] ?? json[camel];
      return v?.toString();
    }

    Map<String, dynamic>? mapOf(String snake, String camel) {
      final v = json[snake] ?? json[camel];
      return v is Map<String, dynamic> ? v : null;
    }

    final subs = json['subtitles'];
    return OfflineManifest(
      fileId: (json['file_id'] ?? json['fileId'] ?? '').toString(),
      episodes: ((json['episodes'] ?? const []) as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      mediaItemId: numOf('media_item_id', 'mediaItemId')?.toInt() ?? 0,
      seasonNumber: numOf('season_number', 'seasonNumber')?.toInt() ?? 0,
      durationMs: numOf('duration_ms', 'durationMs')?.toInt(),
      container: strOf('container', 'container'),
      resumePositionMs:
          numOf('resume_position_ms', 'resumePositionMs')?.toInt(),
      item: mapOf('item', 'item'),
      library: mapOf('library', 'library'),
      season: mapOf('season', 'season'),
      chapters: json['chapters'],
      segments: json['segments'],
      audioTracks: json['audio_tracks'] ?? json['audioTracks'],
      defaultAudio: strOf('default_audio', 'defaultAudio'),
      defaultSubtitle: strOf('default_subtitle', 'defaultSubtitle'),
      subtitles: subs is List
          ? [
              for (final s in subs)
                if (s is Map<String, dynamic>) OfflineSubtitleRef.fromJson(s),
            ]
          : const [],
    );
  }

  final String fileId;
  final List<String> episodes;

  /// 条目 id（打包目录与 playback.json 用；0 = 服务端未给）。
  final int mediaItemId;
  final int seasonNumber;
  final int? durationMs;
  final String? container;

  /// 打包时服务器上的续播点（本机还没有进度时先用它）。
  final int? resumePositionMs;

  /// LibraryItemDetailView / LibraryView / SeasonEpisodesView 原样。
  final Map<String, dynamic>? item;
  final Map<String, dynamic>? library;
  final Map<String, dynamic>? season;

  /// 章节 / 可跳区间 / 音轨（原样透传进 playback.json）。
  final dynamic chapters;
  final dynamic segments;
  final dynamic audioTracks;
  final String? defaultAudio;
  final String? defaultSubtitle;

  final List<OfflineSubtitleRef> subtitles;
}

/// 清单里的一条外挂字幕引用（对照安卓 `OfflineSubtitleRef`）。
class OfflineSubtitleRef {
  const OfflineSubtitleRef({
    this.trackRef = '',
    this.format = '',
    this.language,
    this.title,
    this.isDefault = false,
    this.isForced = false,
    this.isAi = false,
    this.embedded = false,
    this.url,
  });

  factory OfflineSubtitleRef.fromJson(Map<String, dynamic> json) {
    bool boolOf(String snake, String camel) =>
        json[snake] == true || json[camel] == true;
    return OfflineSubtitleRef(
      trackRef: (json['track_ref'] ?? json['trackRef'] ?? '').toString(),
      format: (json['format'] ?? '').toString(),
      language: (json['language'] as String?) ??
          (json['language']?.toString()),
      title: json['title']?.toString(),
      isDefault: boolOf('is_default', 'isDefault'),
      isForced: boolOf('is_forced', 'isForced'),
      isAi: boolOf('is_ai', 'isAi'),
      embedded: boolOf('embedded', 'embedded'),
      url: json['url']?.toString(),
    );
  }

  final String trackRef;

  /// 存盘格式：srt / ass / ssa / vtt。
  final String format;
  final String? language;
  final String? title;
  final bool isDefault;
  final bool isForced;
  final bool isAi;

  /// 内封轨抽出来的（原画档不用下，引擎直接读文件里的）。
  final bool embedded;

  /// 清单里的地址是 `/api/v1/...` 的绝对路径（字幕带了签名 token）。
  final String? url;
}
