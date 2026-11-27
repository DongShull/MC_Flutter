import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/platform/download_channel.dart';
import '../../../core/session/pending_revocations.dart';
import '../../../core/session/session_store.dart';

/// 与 OfflineController._tasksKey 保持一致（删除本机下载副本用）。
const _offlineTasksKey = 'offline_tasks_v2';

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
        origin: SessionStore.normalizeOrigin((json['origin'] ?? '').toString()),
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

/// 一台已登录设备（GET /auth/devices 的条目）。
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

/// 账户控制器：
/// 本机多账号快照的切换 / 移除 / 全部退出（统一走 `SessionStore` 与 `PendingRevocations` 注销服务端令牌）。
class AccountController extends Notifier<AccountUiState> {
  static const _serversKey = 'mc_servers';

  FlutterSecureStorage get _storage => const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
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
      } catch (_) {}
    }
    final activeOrigin = _session.baseUrl != null
        ? SessionStore.normalizeOrigin(_session.baseUrl!)
        : null;
    final activeUser = _session.accountUsername.isNotEmpty
        ? _session.accountUsername
        : (activeOrigin == null ? null : _guessUsername(servers, activeOrigin));
    state = state.copyWith(
      servers: servers,
      currentOrigin: activeOrigin,
      currentUsername: activeUser,
    );
    loadMe();
    loadDevices();
  }

  String? _guessUsername(List<SavedServer> servers, String origin) {
    final norm = SessionStore.normalizeOrigin(origin);
    for (final server in servers) {
      if (SessionStore.normalizeOrigin(server.origin) == norm &&
          server.accounts.isNotEmpty) {
        return server.accounts.first.username;
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
      await _session.updateFromMeJson(body);
      state = state.copyWith(
        me: MeView.fromJson(body),
        currentUsername: _session.accountUsername,
        clearError: true,
      );
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
    } catch (_) {}
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

  /// DELETE /auth/devices/{id}：吊销单台设备。
  Future<void> revokeDevice(String id) async {
    try {
      await ref.read(accountClientProvider).unwrap<Map<String, dynamic>?>(
            Channel.general,
            'DELETE',
            '/api/v1/auth/devices/$id',
          );
      await loadDevices();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 切换账号：快照当前令牌 → 恢复目标账号令牌并刷新 me。
  Future<void> switchTo(String origin, String username) async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    final curOrigin = _session.baseUrl;
    final curUser = _session.accountUsername;
    if (curOrigin != null && curUser.isNotEmpty) {
      await _session.snapshotAccountToken(origin: curOrigin, username: curUser);
    }
    final ok = await _session.switchAccount(origin: origin, username: username);
    if (!ok) {
      await _session.restore();
    }
    state = state.copyWith(
      busy: false,
      currentOrigin: _session.baseUrl != null
          ? SessionStore.normalizeOrigin(_session.baseUrl!)
          : origin,
      currentUsername: _session.accountUsername.isNotEmpty
          ? _session.accountUsername
          : username,
    );
    await loadMe();
    await loadDevices();
  }

  /// 从本机移除一个账号并经 `PendingRevocations` 注销其服务端设备令牌。
  Future<void> remove(String origin, String username) async {
    final token = _session.tokenFor(origin: origin, username: username);
    if (token != null && token.isNotEmpty) {
      await PendingRevocations.instance.enqueueAndRevoke(origin, token);
    }
    await _session.removeAccount(origin: origin, username: username);
    await restore();
  }

  /// 退出全部账号：经 `PendingRevocations` 注销全部服务端令牌 + 可选删除本机离线副本。
  Future<void> logoutAll({bool wipeOffline = false}) async {
    if (wipeOffline) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_offlineTasksKey);
        if (raw != null && raw.isNotEmpty) {
          final tasks = jsonDecode(raw) as List<dynamic>;
          for (final t in tasks) {
            final path = (t as Map<String, dynamic>)['savePath']?.toString();
            if (path != null && path.isNotEmpty) {
              await McDownloadChannel.delete(path);
            }
          }
          await prefs.remove(_offlineTasksKey);
        }
      } catch (_) {}
    }
    await _session.logoutAll();
    state = const AccountUiState(servers: <SavedServer>[]);
  }
}

final accountProvider =
    NotifierProvider<AccountController, AccountUiState>(AccountController.new);
