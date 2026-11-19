// settings 域模型（对齐 Kotlin core/model/Settings.kt / Maintenance.kt 的相关段）。

/// 当前登录会话（GET /auth/me → SessionView）。
class McSession {
  const McSession({
    required this.username,
    this.nickname,
    this.avatarUrl,
    this.role = 'member',
    this.capabilities = const McCapabilities(),
  });

  factory McSession.fromJson(Map<String, dynamic> json) => McSession(
        username: (json['username'] ?? '').toString(),
        nickname: json['nickname']?.toString(),
        avatarUrl:
            json['avatar_url']?.toString() ?? json['avatarUrl']?.toString(),
        role: (json['role'] ?? 'member').toString(),
        capabilities: McCapabilities.fromJson(
          json['capabilities'] is Map<String, dynamic>
              ? json['capabilities'] as Map<String, dynamic>
              : const <String, dynamic>{},
        ),
      );

  final String username;
  final String? nickname;
  final String? avatarUrl;
  final String role;
  final McCapabilities capabilities;

  /// 展示名：昵称 → 用户名。
  String get displayName {
    final n = nickname;
    return (n != null && n.isNotEmpty) ? n : username;
  }

  bool get isAdmin => role == 'admin';

  String get roleLabel => switch (role) {
        'admin' => '超级管理员',
        'member' => '成员',
        _ => '访客',
      };
}

class McCapabilities {
  const McCapabilities({
    this.allowSubscribe = false,
    this.allowSearch = false,
    this.allowDirectDownload = false,
    this.allowVideoDownload = false,
  });

  factory McCapabilities.fromJson(Map<String, dynamic> json) => McCapabilities(
        allowSubscribe: json['allowSubscribe'] == true,
        allowSearch: json['allowSearch'] == true,
        allowDirectDownload: json['allowDirectDownload'] == true,
        allowVideoDownload:
            json['allow_video_download'] == true ||
            json['allowVideoDownload'] == true,
      );

  final bool allowSubscribe;
  final bool allowSearch;
  final bool allowDirectDownload;
  final bool allowVideoDownload;
}

/// 「我的设备」里的一台设备（登录设备 / Jellyfin 播放器）。
class LoginDevice {
  const LoginDevice({
    required this.id,
    this.kind = '',
    this.kindLabel = '',
    this.name = '',
    this.scope = 'full',
    this.platform,
    this.clientVersion,
    this.createdAt,
    this.lastSeenAt,
    this.current = false,
    this.connected = false,
    this.renamable = true,
    this.ownerNickname = '',
  });

  factory LoginDevice.fromJson(Map<String, dynamic> json) => LoginDevice(
        id: (json['id'] ?? '').toString(),
        kind: (json['kind'] ?? '').toString(),
        kindLabel: (json['kindLabel'] ?? json['kind_label'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        scope: (json['scope'] ?? 'full').toString(),
        platform: json['platform']?.toString(),
        clientVersion: json['clientVersion']?.toString() ??
            json['client_version']?.toString(),
        createdAt:
            json['createdAt']?.toString() ?? json['created_at']?.toString(),
        lastSeenAt: json['lastSeenAt']?.toString() ??
            json['last_seen_at']?.toString(),
        current: json['current'] == true,
        connected: json['connected'] == true,
        renamable: json['renamable'] != false,
        ownerNickname: (json['ownerNickname'] ?? json['owner_nickname'] ?? '')
            .toString(),
      );

  final String id;
  final String kind;
  final String kindLabel;
  final String name;
  final String scope;
  final String? platform;
  final String? clientVersion;
  final String? createdAt;
  final String? lastSeenAt;
  final bool current;
  final bool connected;
  final bool renamable;
  final String ownerNickname;

  bool get isTranscode => scope == 'transcode';

  /// 行标题：name 优先，回落 kindLabel。
  String get title {
    final n = name;
    return n.isNotEmpty ? n : (kindLabel.isNotEmpty ? kindLabel : id);
  }

  /// 副行：kindLabel · platform · 版本 · 在线 · owner。
  String get subtitle => [
        if (kindLabel.isNotEmpty) kindLabel,
        if (platform != null && platform!.isNotEmpty) platform!,
        if (clientVersion != null && clientVersion!.isNotEmpty)
          'v\$clientVersion',
        if (connected) '在线',
        if (ownerNickname.isNotEmpty) ownerNickname,
      ].join(' · ');
}

/// 「清理长期没用的设备」名单里的一项。
class DeviceCleanupItem {
  const DeviceCleanupItem(
      {this.id = '', this.name = '', this.ownerNickname = ''});

  factory DeviceCleanupItem.fromJson(Map<String, dynamic> json) =>
      DeviceCleanupItem(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        ownerNickname:
            (json['ownerNickname'] ?? json['owner_nickname'] ?? '').toString(),
      );

  final String id;
  final String name;
  final String ownerNickname;
}

/// 设备清理结果（dryRun 预览或真跑）。
class DeviceCleanupView {
  const DeviceCleanupView({this.devices = const []});

  factory DeviceCleanupView.fromJson(Map<String, dynamic> json) =>
      DeviceCleanupView(
        devices: ((json['devices'] ?? const []) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(DeviceCleanupItem.fromJson)
            .toList(),
      );

  final List<DeviceCleanupItem> devices;
}

/// 播放策略（意愿开关 + 实测硬件能力，GET/PUT /playback/policy）。
class PlaybackPolicy {
  const PlaybackPolicy({
    this.softwareTranscodeEnabled = false,
    this.trickplayEnabled = true,
    this.transcodeCacheEnabled = true,
    this.hardwareAvailable = false,
    this.hwBackends = const [],
  });

  factory PlaybackPolicy.fromJson(Map<String, dynamic> json) => PlaybackPolicy(
        softwareTranscodeEnabled: json['softwareTranscodeEnabled'] == true ||
            json['software_transcode_enabled'] == true,
        trickplayEnabled:
            json['trickplayEnabled'] == true || json['trickplay_enabled'] == true,
        transcodeCacheEnabled: json['transcodeCacheEnabled'] == true ||
            json['transcode_cache_enabled'] == true,
        hardwareAvailable:
            json['hardwareAvailable'] == true || json['hardware_available'] == true,
        hwBackends: ((json['hwBackends'] ?? json['hw_backends'] ?? const [])
                as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
      );

  final bool softwareTranscodeEnabled;
  final bool trickplayEnabled;
  final bool transcodeCacheEnabled;
  final bool hardwareAvailable;
  final List<String> hwBackends;

  /// PUT /playback/policy 的补丁体；只带本次变了的开关（null = 不变）。
  Map<String, dynamic> toPatch({
    bool? softwareTranscodeEnabled,
    bool? trickplayEnabled,
    bool? transcodeCacheEnabled,
  }) =>
      <String, dynamic>{
        // 服务端 camel / snake 两种键都收，两种都带上最稳。
        if (softwareTranscodeEnabled != null) ...<String, dynamic>{
          'softwareTranscodeEnabled': softwareTranscodeEnabled,
          'software_transcode_enabled': softwareTranscodeEnabled,
        },
        if (trickplayEnabled != null) ...<String, dynamic>{
          'trickplayEnabled': trickplayEnabled,
          'trickplay_enabled': trickplayEnabled,
        },
        if (transcodeCacheEnabled != null) ...<String, dynamic>{
          'transcodeCacheEnabled': transcodeCacheEnabled,
          'transcode_cache_enabled': transcodeCacheEnabled,
        },
      };
}

/// 存储清理：一个登记目录（GET /app/storage 的 dirs 项）。
class StorageDir {
  const StorageDir({
    this.key = '',
    this.title = '',
    this.summary = '',
    this.description = '',
    this.group = 'data',
    this.clearable = false,
    this.exists = true,
  });

  factory StorageDir.fromJson(Map<String, dynamic> json) => StorageDir(
        key: (json['key'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        group: (json['group'] ?? 'data').toString(),
        clearable: json['clearable'] == true,
        exists: json['exists'] != false,
      );

  final String key;
  final String title;
  final String summary;
  final String description;
  final String group;
  final bool clearable;
  final bool exists;
}

/// 存储用量（GET /app/storage，包一层 {usage,computing}）。
class StorageState {
  const StorageState({
    this.dataRoot = '',
    this.diskTotal = 0,
    this.diskUsed = 0,
    this.diskFree = 0,
    this.cacheBytes = 0,
    this.dataBytes = 0,
    this.dirs = const [],
    this.computing = false,
  });

  factory StorageState.fromJson(Map<String, dynamic> json) {
    final usage = json['usage'] is Map<String, dynamic>
        ? json['usage'] as Map<String, dynamic>
        : json;
    int intOf(String camel, String snake) {
      final v = usage[camel] ?? usage[snake];
      return v is num ? v.toInt() : 0;
    }

    return StorageState(
      dataRoot: (usage['dataRoot'] ?? usage['data_root'] ?? '').toString(),
      diskTotal: intOf('diskTotal', 'disk_total'),
      diskUsed: intOf('diskUsed', 'disk_used'),
      diskFree: intOf('diskFree', 'disk_free'),
      cacheBytes: intOf('cacheBytes', 'cache_bytes'),
      dataBytes: intOf('dataBytes', 'data_bytes'),
      dirs: ((usage['dirs'] ?? const []) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(StorageDir.fromJson)
          .toList(),
      computing: json['computing'] == true,
    );
  }

  final String dataRoot;
  final int diskTotal;
  final int diskUsed;
  final int diskFree;
  final int cacheBytes;
  final int dataBytes;
  final List<StorageDir> dirs;
  final bool computing;
}

/// 清理结果（POST /app/storage/{key}/clean）。
class CleanResult {
  const CleanResult(
      {this.removed = 0, this.freedBytes = 0, this.skippedBusy = 0});

  factory CleanResult.fromJson(Map<String, dynamic> json) {
    int intOf(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is num) return v.toInt();
      }
      return 0;
    }

    return CleanResult(
      removed: intOf(<String>['removed']),
      freedBytes: intOf(<String>['freedBytes', 'freed_bytes']),
      skippedBusy: intOf(<String>['skippedBusy', 'skipped_busy']),
    );
  }

  final int removed;
  final int freedBytes;
  final int skippedBusy;
}

/// 待更新快照（GET /app/update/pending）：维护区 / 我的页提醒组用它。
class PendingUpdate {
  const PendingUpdate({this.appVersion, this.modelTag, this.appCompatible = true});

  factory PendingUpdate.fromJson(Map<String, dynamic> json) => PendingUpdate(
        appVersion:
            json['appVersion']?.toString() ?? json['app_version']?.toString(),
        modelTag:
            json['modelTag']?.toString() ?? json['model_tag']?.toString(),
        appCompatible:
            json['appCompatible'] != false && json['app_compatible'] != false,
      );

  final String? appVersion;
  final String? modelTag;
  final bool appCompatible;

  bool get hasUpdate => appVersion != null || modelTag != null;

  /// 「新版本 vX / 新识别模型 X」；两者都有时只说应用版本。
  String? get label => appVersion != null
      ? '新版本 v\$appVersion'
      : modelTag != null
          ? '新识别模型 \$modelTag'
          : null;
}

/// 服务器版本信息（GET /app/update/status 的子集）。
class UpdateStatus {
  const UpdateStatus({
    this.currentVersion = '',
    this.codeSource = '',
    this.modelTag,
  });

  factory UpdateStatus.fromJson(Map<String, dynamic> json) => UpdateStatus(
        currentVersion:
            (json['currentVersion'] ?? json['current_version'] ?? '').toString(),
        codeSource:
            (json['codeSource'] ?? json['code_source'] ?? '').toString(),
        modelTag: json['modelTag']?.toString() ?? json['model_tag']?.toString(),
      );

  final String currentVersion;
  final String codeSource;
  final String? modelTag;
}

