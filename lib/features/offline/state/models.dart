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
