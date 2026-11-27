import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_store.dart';

/// 权限与用户会话快照（对齐 iOS `Shared/Core/Session/Permissions.swift`）：
/// 客户端据此裁剪入口，安全边界仍在后端 403。
class McPermissions {
  const McPermissions({
    this.username = '',
    this.nickname = '',
    this.avatarUrl = '',
    this.role = 'member',
    bool isAdmin = false,
    this.allowSubscribe = false,
    this.allowSearch = false,
    this.allowDirectDownload = false,
    this.allowVideoDownload = false,
    this.aiEnabled = false,
  }) : _isAdminFlag = isAdmin;

  static const McPermissions none = McPermissions();

  /// 从 `/api/v1/auth/me` JSON 解析（同时兼容 snake_case 与 camelCase 字段）。
  factory McPermissions.fromJson(Map<String, dynamic> json) {
    final capsRaw = json['capabilities'];
    final caps = capsRaw is Map
        ? capsRaw.cast<String, dynamic>()
        : const <String, dynamic>{};

    bool readBool(String snake, String camel) {
      final v = caps[snake] ?? caps[camel] ?? json[snake] ?? json[camel];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v.toLowerCase() == 'true' || v == '1';
      return false;
    }

    final rawRole = (json['role'] ?? '').toString().trim();
    final adminFlag = readBool('is_admin', 'isAdmin') ||
        rawRole.toLowerCase() == 'admin';
    final effectiveRole =
        rawRole.isNotEmpty ? rawRole : (adminFlag ? 'admin' : 'member');

    return McPermissions(
      username: (json['username'] ?? '').toString().trim(),
      nickname: (json['nickname'] ?? '').toString().trim(),
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl'] ?? '').toString().trim(),
      role: effectiveRole,
      isAdmin: adminFlag,
      allowSubscribe: readBool('allow_subscribe', 'allowSubscribe'),
      allowSearch: readBool('allow_search', 'allowSearch'),
      allowDirectDownload:
          readBool('allow_direct_download', 'allowDirectDownload'),
      allowVideoDownload:
          readBool('allow_video_download', 'allowVideoDownload'),
      aiEnabled: readBool('ai_enabled', 'aiEnabled'),
    );
  }

  final String username;
  final String nickname;
  final String avatarUrl;
  final String role;
  final bool _isAdminFlag;
  final bool allowSubscribe;
  final bool allowSearch;
  final bool allowDirectDownload;
  final bool allowVideoDownload;
  final bool aiEnabled;

  bool get isAdmin => _isAdminFlag || role.toLowerCase() == 'admin';
  bool get canSubscribe => isAdmin || allowSubscribe;
  bool get canSearch => isAdmin || allowSearch;
  bool get canDirectDownload => isAdmin || allowDirectDownload;

  /// 下载影片到设备：旧服务器没有该字段时不显示离线下载入口（对齐 iOS Permissions.swift §22）。
  bool get canDownloadVideo => allowVideoDownload;

  bool get canManageLibraries => isAdmin;
  bool get canManageSubscriptions => isAdmin;
  bool get canGrabForSubscription =>
      isAdmin || (canSubscribe && canSearch && canDirectDownload);

  String get displayName => nickname.isNotEmpty ? nickname : username;
  String get initials => avatarInitials(displayName);

  /// 头像徽标字（对齐 iOS `API.SessionView.initials`）：
  /// 中文（CJK）取首字；拉丁字母/数字取前两位大写（例如 `al` -> `AL`）。
  static String avatarInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final runes = trimmed.runes.toList();
    final first = runes.first;
    final isCjk = (first >= 0x4E00 && first <= 0x9FFF) ||
        (first >= 0x3400 && first <= 0x4DBF) ||
        (first >= 0xF900 && first <= 0xFAFF);
    if (isCjk) {
      return String.fromCharCode(first);
    }
    final prefix = runes.take(2).map(String.fromCharCode).join();
    return prefix.toUpperCase();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'username': username,
        'nickname': nickname,
        'avatar_url': avatarUrl,
        'role': role,
        'is_admin': isAdmin,
        'ai_enabled': aiEnabled,
        'capabilities': <String, dynamic>{
          'allow_subscribe': allowSubscribe,
          'allow_search': allowSearch,
          'allow_direct_download': allowDirectDownload,
          'allow_video_download': allowVideoDownload,
        },
      };

  McPermissions copyWith({
    String? username,
    String? nickname,
    String? avatarUrl,
    String? role,
    bool? isAdmin,
    bool? allowSubscribe,
    bool? allowSearch,
    bool? allowDirectDownload,
    bool? allowVideoDownload,
    bool? aiEnabled,
  }) =>
      McPermissions(
        username: username ?? this.username,
        nickname: nickname ?? this.nickname,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role ?? this.role,
        isAdmin: isAdmin ?? this.isAdmin,
        allowSubscribe: allowSubscribe ?? this.allowSubscribe,
        allowSearch: allowSearch ?? this.allowSearch,
        allowDirectDownload: allowDirectDownload ?? this.allowDirectDownload,
        allowVideoDownload: allowVideoDownload ?? this.allowVideoDownload,
        aiEnabled: aiEnabled ?? this.aiEnabled,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is McPermissions &&
          other.username == username &&
          other.nickname == nickname &&
          other.avatarUrl == avatarUrl &&
          other.role == role &&
          other.isAdmin == isAdmin &&
          other.allowSubscribe == allowSubscribe &&
          other.allowSearch == allowSearch &&
          other.allowDirectDownload == allowDirectDownload &&
          other.allowVideoDownload == allowVideoDownload &&
          other.aiEnabled == aiEnabled;

  @override
  int get hashCode => Object.hash(
        username,
        nickname,
        avatarUrl,
        role,
        isAdmin,
        allowSubscribe,
        allowSearch,
        allowDirectDownload,
        allowVideoDownload,
        aiEnabled,
      );
}

/// 响应式当前账号权限 Provider：跟随 `appSession` 每次 `/auth/me` 刷新、冷启动恢复、切换账号、退出自动更新。
/// 不使用 `ChangeNotifierProvider` 直接暴露全局单例，避免测试中 `ProviderScope` 销毁时误调用 `appSession.dispose()`。
final permissionsProvider = Provider<McPermissions>((ref) {
  void onChanged() => ref.invalidateSelf();
  appSession.addListener(onChanged);
  ref.onDispose(() => appSession.removeListener(onChanged));
  return appSession.permissions;
});

/// 响应式会话代数 Provider：切换账号或重新登录时递增，可用于强制清理跨账号缓存状态。
final sessionGenerationProvider = Provider<int>((ref) {
  void onChanged() => ref.invalidateSelf();
  appSession.addListener(onChanged);
  ref.onDispose(() => appSession.removeListener(onChanged));
  return appSession.sessionGeneration;
});
