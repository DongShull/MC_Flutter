// settings 域模型（1:1 对齐 iOS Shared/Core/API/Generated/Models.swift 与 Settings 分区需求）。

/// 当前登录会话（GET /api/v1/auth/me → SessionView）。
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
          json['capabilities'] is Map
              ? Map<String, dynamic>.from(json['capabilities'] as Map)
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
    final n = nickname?.trim();
    return (n != null && n.isNotEmpty) ? n : username;
  }

  bool get isAdmin => role.toLowerCase() == 'admin';

  String get roleLabel => switch (role.toLowerCase()) {
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

  factory McCapabilities.fromJson(Map<String, dynamic> json) {
    bool readFlag(String snake, String camel) {
      final v = json[snake] ?? json[camel];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v.toLowerCase() == 'true' || v == '1';
      return false;
    }

    return McCapabilities(
      allowSubscribe: readFlag('allow_subscribe', 'allowSubscribe'),
      allowSearch: readFlag('allow_search', 'allowSearch'),
      allowDirectDownload:
          readFlag('allow_direct_download', 'allowDirectDownload'),
      allowVideoDownload:
          readFlag('allow_video_download', 'allowVideoDownload'),
    );
  }

  final bool allowSubscribe;
  final bool allowSearch;
  final bool allowDirectDownload;
  final bool allowVideoDownload;
}

/// 别名兼容（部分引用按 SessionCapabilities 命名）。
typedef SessionCapabilities = McCapabilities;

/// 设备推送通道状态（LoginDeviceView.push）。
class DevicePushStatus {
  const DevicePushStatus({
    this.status = '',
    this.statusText = '',
  });

  factory DevicePushStatus.fromJson(Map<String, dynamic> json) =>
      DevicePushStatus(
        status: (json['status'] ?? '').toString(),
        statusText:
            (json['status_text'] ?? json['statusText'] ?? '').toString(),
      );

  final String status;
  final String statusText;
}

/// 「我的设备」里的一台设备（登录设备 / 转码节点 / Jellyfin 播放器）。
class LoginDevice {
  const LoginDevice({
    required this.id,
    this.kind = '',
    this.kindLabel = '',
    this.family = '',
    this.name = '',
    this.scope = 'full',
    this.platform,
    this.clientVersion,
    this.createdAt,
    this.lastSeenAt,
    this.lastSeenIp,
    this.current = false,
    this.connected = false,
    this.renamable = true,
    this.ownerNickname = '',
    this.push,
  });

  factory LoginDevice.fromJson(Map<String, dynamic> json) => LoginDevice(
        id: (json['id'] ?? '').toString(),
        kind: (json['kind'] ?? '').toString(),
        kindLabel: (json['kind_label'] ?? json['kindLabel'] ?? '').toString(),
        family: (json['family'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        scope: (json['scope'] ?? 'full').toString(),
        platform: json['platform']?.toString(),
        clientVersion: json['client_version']?.toString() ??
            json['clientVersion']?.toString(),
        createdAt:
            json['created_at']?.toString() ?? json['createdAt']?.toString(),
        lastSeenAt: json['last_seen_at']?.toString() ??
            json['lastSeenAt']?.toString(),
        lastSeenIp: json['last_seen_ip']?.toString() ??
            json['lastSeenIp']?.toString(),
        current: json['current'] == true,
        connected: json['connected'] == true,
        renamable: json['renamable'] != false,
        ownerNickname:
            (json['owner_nickname'] ?? json['ownerNickname'] ?? '').toString(),
        push: json['push'] is Map
            ? DevicePushStatus.fromJson(
                Map<String, dynamic>.from(json['push'] as Map),
              )
            : null,
      );

  final String id;
  final String kind;
  final String kindLabel;
  final String family;
  final String name;
  final String scope;
  final String? platform;
  final String? clientVersion;
  final String? createdAt;
  final String? lastSeenAt;
  final String? lastSeenIp;
  final bool current;
  final bool connected;
  final bool renamable;
  final String ownerNickname;
  final DevicePushStatus? push;

  bool get isTranscode => scope == 'transcode' || kind == 'worker';

  /// 所属四分类（browser / app / paired / player）。
  String get groupId {
    if (kind == 'web') return 'browser';
    if (const {'ios', 'tvos', 'macos', 'android', 'androidtv'}
        .contains(kind)) {
      return 'app';
    }
    if (kind == 'jellyfin') return 'player';
    return 'paired';
  }

  /// 是否在线：本机恒在线；转码器看长连接；其余看最近 5 分钟活跃。
  bool get isLive {
    if (current) return true;
    if (isTranscode) return connected;
    final dt = DateTime.tryParse(lastSeenAt ?? '');
    if (dt == null) return false;
    return DateTime.now().difference(dt.toLocal()).inMinutes < 5;
  }

  /// 是否超过 90 天未活跃（休眠提示）。
  bool get isDormant {
    if (current) return false;
    final dt = DateTime.tryParse(lastSeenAt ?? createdAt ?? '');
    if (dt == null) return false;
    return DateTime.now().difference(dt.toLocal()).inDays >= 90;
  }

  /// 行标题：name 优先，回落 kindLabel。
  String get title {
    final n = name.trim();
    return n.isNotEmpty ? n : (kindLabel.isNotEmpty ? kindLabel : id);
  }

  /// 副行：owner · kindLabel · platform · 版本 · 在线。
  String subtitleFor({bool showOwner = false}) => [
        if (showOwner && ownerNickname.isNotEmpty) ownerNickname,
        if (kindLabel.isNotEmpty && kind != 'web') kindLabel,
        if (platform != null && platform!.isNotEmpty) platform!,
        if (clientVersion != null && clientVersion!.isNotEmpty)
          'v$clientVersion',
        if (current) '当前设备' else if (isLive) '在线',
      ].join(' · ');

  String get subtitle => subtitleFor(showOwner: false);
}

/// 「清理长期没用的设备」名单里的一项。
class DeviceCleanupItem {
  const DeviceCleanupItem({
    this.id = '',
    this.name = '',
    this.ownerNickname = '',
  });

  factory DeviceCleanupItem.fromJson(Map<String, dynamic> json) =>
      DeviceCleanupItem(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        ownerNickname:
            (json['owner_nickname'] ?? json['ownerNickname'] ?? '').toString(),
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
            .whereType<Map>()
            .map((e) => DeviceCleanupItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  final List<DeviceCleanupItem> devices;
}

/// 片段预切进度（PlaybackPolicyView.reel_clips_progress）。
class ReelClipProgress {
  const ReelClipProgress({
    this.state = '',
    this.ready = 0,
    this.total = 0,
  });

  factory ReelClipProgress.fromJson(Map<String, dynamic> json) =>
      ReelClipProgress(
        state: (json['state'] ?? '').toString(),
        ready: (json['ready'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );

  final String state;
  final int ready;
  final int total;
}

/// 播放策略（意愿开关 + 已看判定 + 云端直链模式 + 片段预切 + 实测硬件能力）。
class PlaybackPolicy {
  const PlaybackPolicy({
    this.softwareTranscodeEnabled = false,
    this.playedThresholdPercent = 90.0,
    this.playedUseOutro = true,
    this.trickplayEnabled = true,
    this.transcodeCacheEnabled = true,
    this.reelClipsEnabled = false,
    this.reelClipsProgress,
    this.cloudStreamMode,
    this.hardwareAvailable = false,
    this.hwBackends = const [],
  });

  factory PlaybackPolicy.fromJson(Map<String, dynamic> json) {
    bool readBool(String snake, String camel, {bool fallback = false}) {
      final v = json[snake] ?? json[camel];
      if (v is bool) return v;
      return fallback;
    }

    final thresholdRaw =
        json['played_threshold_percent'] ?? json['playedThresholdPercent'];
    final progressRaw =
        json['reel_clips_progress'] ?? json['reelClipsProgress'];

    return PlaybackPolicy(
      softwareTranscodeEnabled: readBool(
        'software_transcode_enabled',
        'softwareTranscodeEnabled',
      ),
      playedThresholdPercent:
          thresholdRaw is num ? thresholdRaw.toDouble() : 90.0,
      playedUseOutro: readBool(
        'played_use_outro',
        'playedUseOutro',
        fallback: true,
      ),
      trickplayEnabled: readBool(
        'trickplay_enabled',
        'trickplayEnabled',
        fallback: true,
      ),
      transcodeCacheEnabled: readBool(
        'transcode_cache_enabled',
        'transcodeCacheEnabled',
        fallback: true,
      ),
      reelClipsEnabled: readBool('reel_clips_enabled', 'reelClipsEnabled'),
      reelClipsProgress: progressRaw is Map
          ? ReelClipProgress.fromJson(Map<String, dynamic>.from(progressRaw))
          : null,
      cloudStreamMode: (json['cloud_stream_mode'] ?? json['cloudStreamMode'])
          ?.toString(),
      hardwareAvailable: readBool('hardware_available', 'hardwareAvailable'),
      hwBackends: ((json['hw_backends'] ?? json['hwBackends'] ?? const [])
              as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
    );
  }

  final bool softwareTranscodeEnabled;
  final double playedThresholdPercent;
  final bool playedUseOutro;
  final bool trickplayEnabled;
  final bool transcodeCacheEnabled;
  final bool reelClipsEnabled;
  final ReelClipProgress? reelClipsProgress;
  final String? cloudStreamMode;
  final bool hardwareAvailable;
  final List<String> hwBackends;

  PlaybackPolicy copyWith({
    bool? softwareTranscodeEnabled,
    double? playedThresholdPercent,
    bool? playedUseOutro,
    bool? trickplayEnabled,
    bool? transcodeCacheEnabled,
    bool? reelClipsEnabled,
    ReelClipProgress? reelClipsProgress,
    String? cloudStreamMode,
  }) =>
      PlaybackPolicy(
        softwareTranscodeEnabled:
            softwareTranscodeEnabled ?? this.softwareTranscodeEnabled,
        playedThresholdPercent:
            playedThresholdPercent ?? this.playedThresholdPercent,
        playedUseOutro: playedUseOutro ?? this.playedUseOutro,
        trickplayEnabled: trickplayEnabled ?? this.trickplayEnabled,
        transcodeCacheEnabled:
            transcodeCacheEnabled ?? this.transcodeCacheEnabled,
        reelClipsEnabled: reelClipsEnabled ?? this.reelClipsEnabled,
        reelClipsProgress: reelClipsProgress ?? this.reelClipsProgress,
        cloudStreamMode: cloudStreamMode ?? this.cloudStreamMode,
        hardwareAvailable: hardwareAvailable,
        hwBackends: hwBackends,
      );

  /// PUT /api/v1/playback/policy 的补丁体；只带本次变更字段。
  Map<String, dynamic> toPatch({
    bool? softwareTranscodeEnabled,
    double? playedThresholdPercent,
    bool? playedUseOutro,
    bool? trickplayEnabled,
    bool? transcodeCacheEnabled,
    bool? reelClipsEnabled,
    String? cloudStreamMode,
  }) =>
      <String, dynamic>{
        if (softwareTranscodeEnabled != null)
          'software_transcode_enabled': softwareTranscodeEnabled,
        if (playedThresholdPercent != null)
          'played_threshold_percent': playedThresholdPercent,
        if (playedUseOutro != null) 'played_use_outro': playedUseOutro,
        if (trickplayEnabled != null) 'trickplay_enabled': trickplayEnabled,
        if (transcodeCacheEnabled != null)
          'transcode_cache_enabled': transcodeCacheEnabled,
        if (reelClipsEnabled != null) 'reel_clips_enabled': reelClipsEnabled,
        if (cloudStreamMode != null) 'cloud_stream_mode': cloudStreamMode,
      };
}

/// 存储清理：一个登记目录（GET /api/v1/app/storage 的 dirs 项）。
class StorageDir {
  const StorageDir({
    this.key = '',
    this.title = '',
    this.summary = '',
    this.description = '',
    this.path = '',
    this.bytes = 0,
    this.group = 'data',
    this.clearable = false,
    this.orphanAware = false,
    this.rebuildCost = '',
    this.exists = true,
  });

  factory StorageDir.fromJson(Map<String, dynamic> json) => StorageDir(
        key: (json['key'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        path: (json['path'] ?? '').toString(),
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        group: (json['group'] ?? 'data').toString(),
        clearable: json['clearable'] == true,
        orphanAware:
            json['orphan_aware'] == true || json['orphanAware'] == true,
        rebuildCost:
            (json['rebuild_cost'] ?? json['rebuildCost'] ?? '').toString(),
        exists: json['exists'] != false,
      );

  final String key;
  final String title;
  final String summary;
  final String description;
  final String path;
  final int bytes;
  final String group;
  final bool clearable;
  final bool orphanAware;
  final String rebuildCost;
  final bool exists;
}

/// 未登记的数据目录条目。
class UnregisteredStorageEntry {
  const UnregisteredStorageEntry({this.path = '', this.bytes = 0});

  factory UnregisteredStorageEntry.fromJson(Map<String, dynamic> json) =>
      UnregisteredStorageEntry(
        path: (json['path'] ?? '').toString(),
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      );

  final String path;
  final int bytes;
}

/// 存储用量（GET /api/v1/app/storage，包一层 {usage, computing, error}）。
class StorageState {
  const StorageState({
    this.hasUsage = false,
    this.dataRoot = '',
    this.diskTotal = 0,
    this.diskUsed = 0,
    this.diskFree = 0,
    this.cacheBytes = 0,
    this.dataBytes = 0,
    this.computedAt = 0,
    this.dirs = const [],
    this.unregistered = const [],
    this.computing = false,
    this.error,
  });

  factory StorageState.fromJson(Map<String, dynamic> json) {
    final rawUsage = json['usage'];
    final hasUsage = rawUsage is Map || json.containsKey('disk_total');
    final usage = rawUsage is Map
        ? Map<String, dynamic>.from(rawUsage)
        : json;
    int intOf(String snake, String camel) {
      final v = usage[snake] ?? usage[camel];
      return v is num ? v.toInt() : 0;
    }

    return StorageState(
      hasUsage: hasUsage,
      dataRoot: (usage['data_root'] ?? usage['dataRoot'] ?? '').toString(),
      diskTotal: intOf('disk_total', 'diskTotal'),
      diskUsed: intOf('disk_used', 'diskUsed'),
      diskFree: intOf('disk_free', 'diskFree'),
      cacheBytes: intOf('cache_bytes', 'cacheBytes'),
      dataBytes: intOf('data_bytes', 'dataBytes'),
      computedAt: intOf('computed_at', 'computedAt'),
      dirs: ((usage['dirs'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map((e) => StorageDir.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      unregistered: ((usage['unregistered'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map(
            (e) =>
                UnregisteredStorageEntry.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      computing: json['computing'] == true,
      error: json['error']?.toString(),
    );
  }

  final bool hasUsage;
  final String dataRoot;
  final int diskTotal;
  final int diskUsed;
  final int diskFree;
  final int cacheBytes;
  final int dataBytes;
  final int computedAt;
  final List<StorageDir> dirs;
  final List<UnregisteredStorageEntry> unregistered;
  final bool computing;
  final String? error;
}

/// 清理结果（POST /api/v1/app/storage/{key}/clean）。
class CleanResult {
  const CleanResult({
    this.removed = 0,
    this.freedBytes = 0,
    this.skippedBusy = 0,
  });

  factory CleanResult.fromJson(Map<String, dynamic> json) {
    int intOf(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is num) return v.toInt();
      }
      return 0;
    }

    return CleanResult(
      removed: intOf(const ['removed']),
      freedBytes: intOf(const ['freed_bytes', 'freedBytes']),
      skippedBusy: intOf(const ['skipped_busy', 'skippedBusy']),
    );
  }

  final int removed;
  final int freedBytes;
  final int skippedBusy;
}

/// 待更新快照（GET /api/v1/app/update/pending）。
class PendingUpdate {
  const PendingUpdate({
    this.appVersion,
    this.appChangelog = '',
    this.modelTag,
    this.appCompatible = true,
  });

  factory PendingUpdate.fromJson(Map<String, dynamic> json) => PendingUpdate(
        appVersion:
            json['app_version']?.toString() ?? json['appVersion']?.toString(),
        appChangelog:
            (json['app_changelog'] ?? json['appChangelog'] ?? '').toString(),
        modelTag:
            json['model_tag']?.toString() ?? json['modelTag']?.toString(),
        appCompatible:
            json['app_compatible'] != false && json['appCompatible'] != false,
      );

  final String? appVersion;
  final String appChangelog;
  final String? modelTag;
  final bool appCompatible;

  bool get hasUpdate =>
      (appVersion != null && appVersion!.isNotEmpty) ||
      (modelTag != null && modelTag!.isNotEmpty);

  String? get label => appVersion != null && appVersion!.isNotEmpty
      ? '新版本 v$appVersion'
      : modelTag != null && modelTag!.isNotEmpty
          ? '新识别模型 $modelTag'
          : null;
}

/// 上一次异常退出信息（UpdateStatusView.last_abnormal_exit）。
class AbnormalExitInfo {
  const AbnormalExitInfo({
    this.at = 0,
    this.exitCode = 0,
    this.detail = '',
  });

  factory AbnormalExitInfo.fromJson(Map<String, dynamic> json) =>
      AbnormalExitInfo(
        at: (json['at'] as num?)?.toInt() ?? 0,
        exitCode: (json['exit_code'] ?? json['exitCode'] as num?) is num
            ? ((json['exit_code'] ?? json['exitCode']) as num).toInt()
            : 0,
        detail: (json['detail'] ?? '').toString(),
      );

  final int at;
  final int exitCode;
  final String detail;
}

/// 服务器版本信息（GET /api/v1/app/update/status）。
class UpdateStatus {
  const UpdateStatus({
    this.currentVersion = '',
    this.codeSource = '',
    this.canUpdate = false,
    this.modelTag,
    this.inactiveOverlayVersion,
    this.inactiveOverlayReason,
    this.badVersions = const [],
    this.lastAbnormalExit,
  });

  factory UpdateStatus.fromJson(Map<String, dynamic> json) {
    final exitRaw = json['last_abnormal_exit'] ?? json['lastAbnormalExit'];
    return UpdateStatus(
      currentVersion:
          (json['current_version'] ?? json['currentVersion'] ?? '').toString(),
      codeSource: (json['code_source'] ?? json['codeSource'] ?? '').toString(),
      canUpdate: json['can_update'] == true || json['canUpdate'] == true,
      modelTag: json['model_tag']?.toString() ?? json['modelTag']?.toString(),
      inactiveOverlayVersion: (json['inactive_overlay_version'] ??
              json['inactiveOverlayVersion'])
          ?.toString(),
      inactiveOverlayReason:
          (json['inactive_overlay_reason'] ?? json['inactiveOverlayReason'])
              ?.toString(),
      badVersions: ((json['bad_versions'] ?? json['badVersions'] ?? const [])
              as List<dynamic>)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      lastAbnormalExit: exitRaw is Map
          ? AbnormalExitInfo.fromJson(Map<String, dynamic>.from(exitRaw))
          : null,
    );
  }

  final String currentVersion;
  final String codeSource;
  final bool canUpdate;
  final String? modelTag;
  final String? inactiveOverlayVersion;
  final String? inactiveOverlayReason;
  final List<String> badVersions;
  final AbnormalExitInfo? lastAbnormalExit;

  UpdateStatus copyWithoutExit() => UpdateStatus(
        currentVersion: currentVersion,
        codeSource: codeSource,
        canUpdate: canUpdate,
        modelTag: modelTag,
        inactiveOverlayVersion: inactiveOverlayVersion,
        inactiveOverlayReason: inactiveOverlayReason,
        badVersions: badVersions,
        lastAbnormalExit: null,
      );
}

/// 更新检查结果（POST /api/v1/app/update/check）。
class UpdateCheckView {
  const UpdateCheckView({
    this.updateAvailable = false,
    this.latestVersion = '',
    this.compatible = true,
    this.changelog = '',
    this.latestKnownBad = false,
  });

  factory UpdateCheckView.fromJson(Map<String, dynamic> json) =>
      UpdateCheckView(
        updateAvailable: json['update_available'] == true ||
            json['updateAvailable'] == true,
        latestVersion:
            (json['latest_version'] ?? json['latestVersion'] ?? '').toString(),
        compatible: json['compatible'] != false,
        changelog: (json['changelog'] ?? '').toString(),
        latestKnownBad: json['latest_known_bad'] == true ||
            json['latestKnownBad'] == true,
      );

  final bool updateAvailable;
  final String latestVersion;
  final bool compatible;
  final String changelog;
  final bool latestKnownBad;
}

/// NER 模型更新检查（POST /api/v1/app/update/model/check）。
class ModelUpdateCheckView {
  const ModelUpdateCheckView({
    this.updateAvailable = false,
    this.installable = false,
    this.latestTag = '',
  });

  factory ModelUpdateCheckView.fromJson(Map<String, dynamic> json) =>
      ModelUpdateCheckView(
        updateAvailable: json['update_available'] == true ||
            json['updateAvailable'] == true,
        installable: json['installable'] == true,
        latestTag: (json['latest_tag'] ?? json['latestTag'] ?? '').toString(),
      );

  final bool updateAvailable;
  final bool installable;
  final String latestTag;
}

/// 更新进度（GET /api/v1/app/update/progress）。
class UpdateProgressView {
  const UpdateProgressView({
    this.phase = 'idle',
    this.detail = '',
    this.percent,
    this.targetVersion,
    this.error,
  });

  factory UpdateProgressView.fromJson(Map<String, dynamic> json) =>
      UpdateProgressView(
        phase: (json['phase'] ?? 'idle').toString(),
        detail: (json['detail'] ?? '').toString(),
        percent: (json['percent'] as num?)?.toDouble(),
        targetVersion:
            (json['target_version'] ?? json['targetVersion'])?.toString(),
        error: json['error']?.toString(),
      );

  final String phase;
  final String detail;
  final double? percent;
  final String? targetVersion;
  final String? error;
}

/// 回退候选版本项。
class RollbackTargetView {
  const RollbackTargetView({
    this.kind = 'overlay',
    this.version,
    this.schemaAction = 'switch',
    this.backupTakenAt,
    this.installedAt,
    this.sizeBytes,
    this.changelog,
  });

  factory RollbackTargetView.fromJson(Map<String, dynamic> json) =>
      RollbackTargetView(
        kind: (json['kind'] ?? 'overlay').toString(),
        version: json['version']?.toString(),
        schemaAction:
            (json['schema_action'] ?? json['schemaAction'] ?? 'switch')
                .toString(),
        backupTakenAt:
            (json['backup_taken_at'] ?? json['backupTakenAt'])?.toString(),
        installedAt: (json['installed_at'] ?? json['installedAt'])?.toString(),
        sizeBytes: ((json['size_bytes'] ?? json['sizeBytes']) as num?)?.toInt(),
        changelog: json['changelog']?.toString(),
      );

  final String kind;
  final String? version;
  final String schemaAction; // switch / restore / unavailable
  final String? backupTakenAt;
  final String? installedAt;
  final int? sizeBytes;
  final String? changelog;

  String get displayLabel => kind == 'baseline'
      ? '镜像内置版${version != null && version!.isNotEmpty ? ' v$version' : ''}'
      : 'v${version ?? ''}';
}

/// 回退选项与保留策略（GET /api/v1/app/update/rollback/options）。
class RollbackOptionsView {
  const RollbackOptionsView({
    this.keepVersions = 5,
    this.versionsDirBytes = 0,
    this.targets = const [],
  });

  factory RollbackOptionsView.fromJson(Map<String, dynamic> json) =>
      RollbackOptionsView(
        keepVersions: ((json['keep_versions'] ?? json['keepVersions']) as num?)
                ?.toInt() ??
            5,
        versionsDirBytes:
            ((json['versions_dir_bytes'] ?? json['versionsDirBytes']) as num?)
                    ?.toInt() ??
                0,
        targets: ((json['targets'] ?? const []) as List<dynamic>)
            .whereType<Map>()
            .map(
              (e) => RollbackTargetView.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
      );

  final int keepVersions;
  final int versionsDirBytes;
  final List<RollbackTargetView> targets;
}
