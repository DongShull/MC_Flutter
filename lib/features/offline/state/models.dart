import '../../../core/models/format.dart';

/// 单个下载单元的状态（对齐 OfflineUnitStatus）。
enum OfflineUnitStatus { queued, running, paused, waitingWifi, done, failed }

extension OfflineUnitStatusX on OfflineUnitStatus {
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
    this.savePath,
    this.watched = false,
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

  DownloadUnit copyWith({
    OfflineUnitStatus? status,
    double? progress,
    int? speedBps,
    int? priority,
    String? savePath,
    bool? watched,
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
        savePath: savePath ?? this.savePath,
        watched: watched ?? this.watched,
      );

  bool get isActive =>
      status == OfflineUnitStatus.running ||
      status == OfflineUnitStatus.queued ||
      status == OfflineUnitStatus.waitingWifi;
}

/// 下载档位（画质选项）。
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

  String get subtitle {
    final parts = <String>[];
    if (estimatedBytes != null) {
      parts.add((isOriginal ? '' : '≈ ') + mcFormatBytes(estimatedBytes!));
    }
    if (transcode) parts.add('服务器转码后下载，边转边下');
    return parts.join(' · ');
  }
}

/// 一个媒体的下载候选（支持单集与本季全部批量下载）。
class DownloadCandidate {
  const DownloadCandidate({
    required this.fileId,
    required this.title,
    this.subtitle,
    required this.scopes,
    required this.profiles,
    this.seasonFileIds = const [],
    this.fullSeasonSelected = false,
  });

  final String fileId;
  final String title;
  final String? subtitle;
  final List<String> scopes;
  final List<DownloadProfile> profiles;
  final List<String> seasonFileIds;
  final bool fullSeasonSelected;
}

/// 本机存储容量（StorageCard）。
class StorageInfo {
  const StorageInfo({required this.availableBytes, required this.totalBytes});

  final int availableBytes;
  final int totalBytes;

  double get usedRatio =>
      totalBytes <= 0 ? 0 : 1 - availableBytes / totalBytes;
}

/// 服务器返回的 manifest（GET /api/v1/offline/manifest?file_id=）。
class OfflineManifest {
  const OfflineManifest({required this.fileId, this.episodes = const []});

  factory OfflineManifest.fromJson(Map<String, dynamic> json) =>
      OfflineManifest(
        fileId: (json['file_id'] ?? json['fileId'] ?? '').toString(),
        episodes: ((json['episodes'] ?? const []) as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
      );

  final String fileId;
  final List<String> episodes;
}
