import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';

/// account 域复用全局 McClient 单例（SessionStore/McClient 全 App 唯一实例）。
final accountClientProvider = mcClientProvider;

/// 本机保存的一个账号（对齐 Kotlin core/session SavedAccount）。
class SavedAccount {
  const SavedAccount({
    required this.username,
    this.nickname,
    this.role = 'member',
    this.expired = false,
  });

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        username: (json['username'] ?? '').toString(),
        nickname: json['nickname']?.toString(),
        role: (json['role'] ?? 'member').toString(),
        expired: json['expired'] == true,
      );

  final String username;
  final String? nickname;
  final String role;
  final bool expired;

  Map<String, dynamic> toJson() => {
        'username': username,
        if (nickname != null) 'nickname': nickname,
        'role': role,
        'expired': expired,
      };
}

/// 本机保存的一台服务器及其账号（对齐 Kotlin SavedServer）。
class SavedServer {
  const SavedServer({required this.origin, required this.accounts});

  factory SavedServer.fromJson(Map<String, dynamic> json) => SavedServer(
        origin: (json['origin'] ?? '').toString(),
        accounts: ((json['accounts'] ?? const []) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(SavedAccount.fromJson)
            .toList(),
      );

  final String origin;
  final List<SavedAccount> accounts;

  /// 去协议头的展示名（对齐 Kotlin：https://a.b:8080 -> a.b:8080）。
  String get displayOrigin => origin
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'/$'), '');

  Map<String, dynamic> toJson() => {
        'origin': origin,
        'accounts': accounts.map((a) => a.toJson()).toList(),
      };
}

/// GET /auth/me 的用户信息（在线可取；离线退回本机账号名）。
class MeView {
  const MeView({this.username, this.nickname, this.role});

  factory MeView.fromJson(Map<String, dynamic> json) => MeView(
        username: json['username']?.toString(),
        nickname: json['nickname']?.toString(),
        role: json['role']?.toString(),
      );

  final String? username;
  final String? nickname;
  final String? role;
}

/// 一台已登录设备（GET /auth/devices 的条目；对齐 Kotlin 设备管理段）。
class DeviceView {
  const DeviceView({
    required this.id,
    this.name,
    this.platform,
    this.current = false,
    this.lastSeen,
  });

  factory DeviceView.fromJson(Map<String, dynamic> json) => DeviceView(
        id: (json['id'] ?? '').toString(),
        name: json['name']?.toString(),
        platform: json['platform']?.toString(),
        current: json['current'] == true,
        lastSeen: json['last_seen']?.toString() ?? json['lastSeen']?.toString(),
      );

  final String id;
  final String? name;
  final String? platform;
  final bool current;
  final String? lastSeen;
}

/// 账户页 UI 状态：本机账号快照 + 当前登录 + 用户信息 + 设备清单。
class AccountUiState {
  const AccountUiState({
    this.servers = const <SavedServer>[],
    this.currentOrigin,
    this.currentUsername,
    this.me,
    this.devices = const <DeviceView>[],
    this.busy = false,
    this.error,
  });

  final List<SavedServer> servers;
  final String? currentOrigin;
  final String? currentUsername;
  final MeView? me;
  final List<DeviceView> devices;
  final bool busy;
  final String? error;

  AccountUiState copyWith({
    List<SavedServer>? servers,
    String? currentOrigin,
    String? currentUsername,
    MeView? me,
    bool clearMe = false,
    List<DeviceView>? devices,
    bool? busy,
    String? error,
    bool clearError = false,
  }) =>
      AccountUiState(
        servers: servers ?? this.servers,
        currentOrigin: currentOrigin ?? this.currentOrigin,
        currentUsername: currentUsername ?? this.currentUsername,
        me: clearMe ? null : (me ?? this.me),
        devices: devices ?? this.devices,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 账户控制器（对齐 Kotlin AccountSwitcherViewModel）：
/// 本机多账号快照的切换 / 移除 / 全部退出，在线时拉用户信息与设备清单。
class AccountController extends Notifier<AccountUiState> {
  static const _serversKey = 'mc_servers';

  FlutterSecureStorage get _storage => const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  @override
  AccountUiState build() {
    restore();
    return const AccountUiState();
  }

  SessionStore get _session => ref.read(sessionStoreProvider);

  /// 启动恢复：本机账号快照 + 当前会话。
  Future<void> restore() async {
    final raw = await _storage.read(key: _serversKey);
    final servers = <SavedServer>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        for (final item in (jsonDecode(raw) as List<dynamic>)
            .whereType<Map<String, dynamic>>()) {
          servers.add(SavedServer.fromJson(item));
        }
      } catch (_) {
        // 快照损坏当作空（不认识的版本跳过不崩溃）。
      }
    }
    state = state.copyWith(
      servers: servers,
      currentOrigin: _session.baseUrl,
      currentUsername: _session.baseUrl == null
          ? null
          : _guessUsername(servers, _session.baseUrl!),
    );
    loadMe();
    loadDevices();
  }

  String? _guessUsername(List<SavedServer> servers, String origin) {
    for (final server in servers) {
      for (final account in server.accounts) {
        if (server.origin == origin) return account.username;
      }
    }
    return null;
  }

  /// GET /auth/me；失败静默（离线时只显示本机账号名）。
  Future<void> loadMe() async {
    if (!_session.isReady) return;
    try {
      final body = await ref
          .read(accountClientProvider)
          .unwrap<Map<String, dynamic>>(Channel.general, 'GET', '/api/v1/auth/me');
      state = state.copyWith(me: MeView.fromJson(body), clearError: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// GET /auth/devices（设备管理清单）。
  Future<void> loadDevices() async {
    if (!_session.isReady) return;
    try {
      final body = await ref
          .read(accountClientProvider)
          .unwrap<List<dynamic>>(Channel.general, 'GET', '/api/v1/auth/devices');
      state = state.copyWith(
        devices: body
            .whereType<Map<String, dynamic>>()
            .map(DeviceView.fromJson)
            .toList(),
      );
    } catch (_) {
      // 设备清单拉不到不打断账号切换主流程。
    }
  }

  /// PATCH /auth/devices/{id}：重命名设备。
  Future<void> renameDevice(String id, String name) async {
    try {
      await ref.read(accountClientProvider).unwrap<Map<String, dynamic>>(
            Channel.general,
            'PATCH',
            '/api/v1/auth/devices/$id',
            body: {'name': name},
          );
      await loadDevices();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// DELETE /auth/devices/{id}：吊销一台设备。
  Future<void> revokeDevice(String id) async {
    try {
      await ref
          .read(accountClientProvider)
          .delete(Channel.general, '/api/v1/auth/devices/$id');
      await loadDevices();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// POST /auth/devices/cleanup：清理其他所有设备。
  Future<void> cleanupDevices() async {
    try {
      await ref
          .read(accountClientProvider)
          .post(Channel.general, '/api/v1/auth/devices/cleanup');
      await loadDevices();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _persist(List<SavedServer> servers) {
    _storage.write(
      key: _serversKey,
      value: jsonEncode(servers.map((s) => s.toJson()).toList()),
    );
  }

  int? _indexOfServer(List<SavedServer> servers, String origin) {
    for (final i in servers.indexed) {
      if (i.$2.origin == origin) return i.$1;
    }
    return null;
  }

  /// 切换账号（对齐 switchTo）：恢复该账号会话并刷新 me。
  Future<void> switchTo(String origin, String username) async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    // TODO(多账号令牌)：core SessionStore 落 mc_token:<origin>:<user> 快照后，
    // 切换即恢复对应令牌，无需重新输密码；当前先恢复现有会话。
    await _session.restore();
    state = state.copyWith(
      busy: false,
      currentOrigin: origin,
      currentUsername: username,
    );
    loadMe();
  }

  /// 从本机移除一个账号（不动服务器端；对齐 remove）。
  Future<void> remove(String origin, String username) async {
    final servers = [...state.servers];
    final index = _indexOfServer(servers, origin);
    if (index == null) return;
    final server = servers[index];
    final accounts =
        server.accounts.where((a) => a.username != username).toList();
    final next = [...servers];
    if (accounts.isEmpty) {
      next.removeAt(index);
    } else {
      next[index] = SavedServer(origin: server.origin, accounts: accounts);
    }
    state = state.copyWith(servers: next);
    _persist(next);
  }

  /// 退出全部账号：清 sessionStore 令牌 + 清本机快照；界面随后跳 /onboarding。
  Future<void> logoutAll({bool wipeOffline = false}) async {
    if (wipeOffline) {
      // TODO(平台通道)：删除本机已下载文件需要平台通道，先只清状态。
    }
    await _session.logout();
    state = const AccountUiState(servers: <SavedServer>[]);
    _persist(const <SavedServer>[]);
  }
}

final accountProvider =
    NotifierProvider<AccountController, AccountUiState>(AccountController.new);
