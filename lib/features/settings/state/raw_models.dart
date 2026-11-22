// 设置域原始（未进 typed McApi）端点的轻量模型。
// 来源：web lib/api/plugins.ts（PluginInfo/PluginsOverview）、
// lib/api/drives.ts（DriveBackend/DriveAccount/DriveStatus/DriveSettings）、
// lib/api/extension.ts（SyncTokenView）。
// 字段全部容错解析：旧服务端可能缺字段，缺失时用默认值，不抛错。

/// 插件状态（web PluginState）。
typedef PluginStateName = String;

/// 一个插件（GET /app/plugins 的 plugins[] 项，取展示用子集）。
class PluginInfo {
  const PluginInfo({
    required this.id,
    this.title = '',
    this.state = '',
    this.critical = false,
    this.disableable = false,
    this.switchable = false,
    this.removable = false,
    this.source = '',
    this.group,
    this.tier,
    this.disabledBy,
    this.error,
    this.blockedReasons = const [],
  });

  factory PluginInfo.fromJson(Map<String, dynamic> json) => PluginInfo(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? json['plugin'] ?? '').toString(),
        state: (json['state'] ?? '').toString(),
        critical: json['critical'] == true,
        disableable: json['disableable'] == true,
        switchable: json['switchable'] == true,
        removable: json['removable'] == true,
        source: (json['source'] ?? '').toString(),
        group: json['group']?.toString(),
        tier: json['tier']?.toString(),
        disabledBy: json['disabled_by']?.toString(),
        error: json['error']?.toString(),
        blockedReasons: ((json['blocked_by'] ?? const []) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map((e) =>
                (e['reason'] ?? e['key'] ?? '').toString())
            .where((e) => e.isNotEmpty)
            .toList(),
      );

  final String id;
  final String title;
  final String state;
  final bool critical;
  final bool disableable;
  final bool switchable;
  final bool removable;
  final String source;
  final String? group;
  final String? tier;
  final String? disabledBy;
  final String? error;
  final List<String> blockedReasons;

  bool get active => state == 'active';
  bool get canToggle => switchable || disableable;

  String get stateLabel => switch (state) {
        'active' => '运行中',
        'disabled' => '已停用',
        'failed' => '故障',
        'pending' => '待启动',
        'loading' => '启动中',
        'incompatible' => '不兼容',
        'unloading' => '卸载中',
        'disposed' => '已卸载',
        _ => state.isEmpty ? '未知' : state,
      };
}

/// GET /app/plugins 概览。
class PluginsOverview {
  const PluginsOverview({
    this.plugins = const [],
    this.safeModeActive = false,
    this.safeModeReason = '',
  });

  factory PluginsOverview.fromJson(Map<String, dynamic> json) {
    final safe = json['safe_mode'] is Map<String, dynamic>
        ? json['safe_mode'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return PluginsOverview(
      plugins: ((json['plugins'] ?? const []) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(PluginInfo.fromJson)
          .toList(),
      safeModeActive: safe['active'] == true,
      safeModeReason: (safe['reason'] ?? '').toString(),
    );
  }

  final List<PluginInfo> plugins;
  final bool safeModeActive;
  final String safeModeReason;
}

/// 插件功能开关（GET /app/features 的一项）。
class PluginFeature {
  const PluginFeature({
    required this.key,
    this.title = '',
    this.enabled = false,
    this.switchable = false,
    this.lockedBy,
  });

  factory PluginFeature.fromJson(Map<String, dynamic> json) =>
      PluginFeature(
        key: (json['key'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        enabled: json['enabled'] == true,
        switchable: json['switchable'] == true,
        lockedBy: json['locked_by']?.toString(),
      );

  final String key;
  final String title;
  final bool enabled;
  final bool switchable;
  final String? lockedBy;
}

/// 网盘后端（GET /drives/backends 的一项，取展示用子集）。
class DriveBackend {
  const DriveBackend({
    required this.type,
    this.title = '',
    this.description = '',
    this.scanLogin = false,
    this.cookieLogin = false,
    this.formLogin = false,
  });

  factory DriveBackend.fromJson(Map<String, dynamic> json) {
    final login = json['login'] is Map<String, dynamic>
        ? json['login'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final cookie = login['cookie'];
    return DriveBackend(
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      scanLogin: login['scan'] == true,
      cookieLogin: cookie is Map<String, dynamic>
          ? cookie['supported'] == true
          : cookie == true,
      formLogin: login['form'] != null,
    );
  }

  final String type;
  final String title;
  final String description;
  final bool scanLogin;
  final bool cookieLogin;
  final bool formLogin;
}

/// 网盘账号（GET /drives/accounts 的一项）。
class DriveAccount {
  const DriveAccount({
    required this.id,
    this.backend = '',
    this.backendTitle = '',
    this.name = '',
    this.status = '',
    this.statusMessage,
    this.loginMethod = '',
    this.vip,
    this.quotaTotal,
    this.quotaUsed,
    this.usedToday = 0,
  });

  factory DriveAccount.fromJson(Map<String, dynamic> json) => DriveAccount(
        id: (json['id'] as num?)?.toInt() ?? 0,
        backend: (json['backend'] ?? '').toString(),
        backendTitle:
            (json['backend_title'] ?? json['backend'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        statusMessage: json['status_message']?.toString(),
        loginMethod: (json['login_method'] ?? '').toString(),
        vip: json['vip']?.toString(),
        quotaTotal: (json['quota_total'] as num?)?.toInt(),
        quotaUsed: (json['quota_used'] as num?)?.toInt(),
        usedToday: (json['used_today'] as num?)?.toInt() ?? 0,
      );

  final int id;
  final String backend;
  final String backendTitle;
  final String name;
  final String status;
  final String? statusMessage;
  final String loginMethod;
  final String? vip;
  final int? quotaTotal;
  final int? quotaUsed;
  final int usedToday;

  String get statusLabel => switch (status) {
        'ok' => '正常',
        'auth_expired' => '登录过期',
        'rate_limited' => '限流中',
        'api_broken' => '接口异常',
        'disabled' => '已停用',
        _ => status.isEmpty ? '未知' : status,
      };
}

/// 网盘功能状态（GET /drives/status）。
class DriveStatus {
  const DriveStatus({this.awake = false, this.message = ''});

  factory DriveStatus.fromJson(Map<String, dynamic> json) => DriveStatus(
        awake: json['awake'] == true || json['enabled'] == true,
        message: (json['message'] ?? json['reason'] ?? '').toString(),
      );

  final bool awake;
  final String message;
}

/// 网盘设置（GET /drives/settings）。
class DriveSettings {
  const DriveSettings({this.removeDownloadTasks = false});

  factory DriveSettings.fromJson(Map<String, dynamic> json) =>
      DriveSettings(
        removeDownloadTasks: json['remove_download_tasks'] == true,
      );

  final bool removeDownloadTasks;

  Map<String, dynamic> toJson() =>
      {'remove_download_tasks': removeDownloadTasks};
}

/// 扫码登录会话（POST /drives/logins）。
class DriveLogin {
  const DriveLogin({
    this.loginId = '',
    this.backend = '',
    this.status = '',
    this.message = '',
    this.qrImage = '',
  });

  factory DriveLogin.fromJson(Map<String, dynamic> json) => DriveLogin(
        loginId: (json['login_id'] ?? '').toString(),
        backend: (json['backend'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
        qrImage: (json['qr_image'] ?? '').toString(),
      );

  final String loginId;
  final String backend;
  final String status;
  final String message;
  final String qrImage;

  bool get confirmed => status == 'confirmed';
  bool get expired => status == 'expired' || status == 'failed';
}

/// 浏览器扩展同步令牌（GET /extension/token）。
class SyncTokenView {
  const SyncTokenView({
    this.enabled = false,
    this.token,
    this.createdAt,
  });

  factory SyncTokenView.fromJson(Map<String, dynamic> json) =>
      SyncTokenView(
        enabled: json['enabled'] == true,
        token: json['token']?.toString(),
        createdAt: json['created_at']?.toString(),
      );

  final bool enabled;
  final String? token;
  final String? createdAt;
}
