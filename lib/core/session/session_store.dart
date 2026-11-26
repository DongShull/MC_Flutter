import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 会话与凭证（全局 ChangeNotifier，驱动 GoRouter 登录态守卫与多账号秒切）：
/// - `mc_installation_id`：本机稳定安装 ID
/// - `mc_token:<origin>:<user>`：每服务器每账号独立令牌
/// - `mc_servers`：多服务器账号快照（供 AccountSwitcherSheet 与 AccountPage 读取）
class SessionStore extends ChangeNotifier {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _serversKey = 'mc_servers';

  final FlutterSecureStorage _storage;
  String? _baseUrl;
  String? _token;
  String? _username;
  String? _deviceName;
  String? _avatarUrl;

  String? get baseUrl => _baseUrl;
  String? get token => _token;
  String get username => _username ?? '';
  String get avatarUrl => _avatarUrl ?? '';
  String get deviceName => _deviceName ?? '';
  bool get isReady => _baseUrl != null && _token != null;

  Future<String> installationId() async {
    var id = await _storage.read(key: 'mc_installation_id');
    if (id == null || id.length < 8) {
      final rnd = DateTime.now().microsecondsSinceEpoch;
      final h = rnd >> 11;
      id = 'inst-${rnd.toRadixString(36)}-${h.toRadixString(36)}';
      await _storage.write(key: 'mc_installation_id', value: id);
    }
    return id;
  }

  @visibleForTesting
  void debugSeed({required String baseUrl, required String token}) {
    _baseUrl = baseUrl;
    _token = token;
    notifyListeners();
  }

  @visibleForTesting
  void logoutForTest() {
    _baseUrl = null;
    _token = null;
    _username = null;
    _deviceName = null;
    _avatarUrl = null;
    notifyListeners();
  }

  String _accountKey(String origin, String username) =>
      'mc_token:$origin:$username';

  String _avatarKey(String origin, String username) =>
      'mc_avatar:$origin:$username';

  Future<void> restore() async {
    final base = await _storage.read(key: 'mc_active_base');
    _baseUrl = base;
    if (base != null) {
      _username = await _storage.read(key: 'mc_username');
      _deviceName = await _storage.read(key: 'mc_device_name');
      _avatarUrl = await _storage.read(key: 'mc_avatar_url');
      if (_username != null && _username!.isNotEmpty) {
        _token = await _storage.read(key: _accountKey(base, _username!)) ??
            await _storage.read(key: 'mc_token:$base');
      } else {
        _token = await _storage.read(key: 'mc_token:$base');
      }
    }
    notifyListeners();
  }

  Future<void> login({
    required String baseUrl,
    required String token,
    String? username,
    String? deviceName,
  }) async {
    _baseUrl = baseUrl;
    _token = token;
    if (username != null && username.isNotEmpty) _username = username;
    if (deviceName != null && deviceName.isNotEmpty) _deviceName = deviceName;
    await _storage.write(key: 'mc_active_base', value: baseUrl);
    await _storage.write(key: 'mc_token:$baseUrl', value: token);
    if (_username != null && _username!.isNotEmpty) {
      await _storage.write(
        key: _accountKey(baseUrl, _username!),
        value: token,
      );
      await _storage.write(key: 'mc_username', value: _username!);
      await upsertSavedAccount(origin: baseUrl, username: _username!);
    }
    if (_deviceName != null && _deviceName!.isNotEmpty) {
      await _storage.write(key: 'mc_device_name', value: _deviceName!);
    }
    notifyListeners();
  }

  Future<void> saveProfile({
    String? accountUsername,
    String? username,
    String? deviceName,
    String? avatarUrl,
    String? role,
  }) async {
    if (username != null && username.isNotEmpty) {
      _username = username;
      await _storage.write(key: 'mc_username', value: username);
    }
    if (avatarUrl != null) {
      _avatarUrl = avatarUrl;
      await _storage.write(key: 'mc_avatar_url', value: avatarUrl);
      final origin = _baseUrl;
      final keyUser = accountUsername ?? _username;
      if (origin != null && keyUser != null && keyUser.isNotEmpty) {
        await _storage.write(
          key: _avatarKey(origin, keyUser),
          value: avatarUrl,
        );
      }
    }
    if (deviceName != null && deviceName.isNotEmpty) {
      _deviceName = deviceName;
      await _storage.write(key: 'mc_device_name', value: deviceName);
    }
    final origin = _baseUrl;
    final acct = accountUsername ?? _username;
    if (origin != null && acct != null && acct.isNotEmpty) {
      if (_token != null && _token!.isNotEmpty) {
        await _storage.write(key: _accountKey(origin, acct), value: _token!);
      }
      await upsertSavedAccount(
        origin: origin,
        username: acct,
        nickname: username,
        role: role,
      );
    }
    notifyListeners();
  }

  /// 维护 `mc_servers` 多服务器多账号索引，确保切换面板与账号页始终最新。
  Future<void> upsertSavedAccount({
    required String origin,
    required String username,
    String? nickname,
    String? role,
  }) async {
    if (origin.isEmpty || username.isEmpty) return;
    try {
      final raw = await _storage.read(key: _serversKey);
      final servers = <Map<String, dynamic>>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) servers.add(Map<String, dynamic>.from(item));
          }
        }
      }
      var sIdx = servers.indexWhere((s) => s['origin']?.toString() == origin);
      if (sIdx < 0) {
        servers.add({'origin': origin, 'accounts': <Map<String, dynamic>>[]});
        sIdx = servers.length - 1;
      }
      final accounts = <Map<String, dynamic>>[
        for (final a in (servers[sIdx]['accounts'] as List? ?? const []))
          if (a is Map) Map<String, dynamic>.from(a),
      ];
      final aIdx =
          accounts.indexWhere((a) => a['username']?.toString() == username);
      final prev = aIdx >= 0 ? accounts[aIdx] : const <String, dynamic>{};
      final nextAcct = <String, dynamic>{
        'username': username,
        if ((nickname ?? prev['nickname']) != null)
          'nickname': nickname ?? prev['nickname'],
        'role': role ?? prev['role'] ?? 'member',
        'expired': false,
      };
      if (aIdx >= 0) {
        accounts[aIdx] = nextAcct;
      } else {
        accounts.add(nextAcct);
      }
      servers[sIdx]['accounts'] = accounts;
      await _storage.write(key: _serversKey, value: jsonEncode(servers));
    } catch (_) {}
  }

  Future<void> snapshotAccountToken({
    required String origin,
    required String username,
  }) async {
    final token = _token;
    if (token == null || username.isEmpty) return;
    await _storage.write(key: _accountKey(origin, username), value: token);
  }

  Future<bool> switchAccount({
    required String origin,
    required String username,
  }) async {
    var token = await _storage.read(key: _accountKey(origin, username));
    if (token == null || token.isEmpty) {
      token = await _storage.read(key: 'mc_token:$origin');
      if (token != null && token.isNotEmpty) {
        await _storage.write(key: _accountKey(origin, username), value: token);
      }
    }
    if (token == null || token.isEmpty) return false;
    _baseUrl = origin;
    _token = token;
    _username = username;
    _avatarUrl = await _storage.read(key: _avatarKey(origin, username));
    await _storage.write(key: 'mc_active_base', value: origin);
    await _storage.write(key: 'mc_token:$origin', value: token);
    await _storage.write(key: 'mc_username', value: username);
    if (_avatarUrl != null) {
      await _storage.write(key: 'mc_avatar_url', value: _avatarUrl!);
    } else {
      await _storage.delete(key: 'mc_avatar_url');
    }
    notifyListeners();
    return true;
  }

  Future<void> deleteAccountToken({
    required String origin,
    required String username,
  }) async {
    await _storage.delete(key: _accountKey(origin, username));
    await _storage.delete(key: _avatarKey(origin, username));
  }

  Future<void> logout() async {
    final base = _baseUrl;
    _token = null;
    _username = null;
    _deviceName = null;
    _avatarUrl = null;
    await _storage.delete(key: 'mc_username');
    await _storage.delete(key: 'mc_device_name');
    await _storage.delete(key: 'mc_avatar_url');
    if (base != null) {
      await _storage.delete(key: 'mc_token:$base');
    }
    await _storage.delete(key: 'mc_active_base');
    _baseUrl = null;
    notifyListeners();
  }
}

final SessionStore appSession = SessionStore();
