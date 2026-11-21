import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 会话与凭证（对齐原 mc_vault / mc_servers 快照设计）：
/// - mc_installation_id：安装唯一 id
/// - mc_token:<origin>:<user>：每服务器每账号令牌
/// - mc_servers：多服务器快照（不含令牌）
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  String? _baseUrl;
  String? _token;
  String? _username;
  String? _deviceName;

  String? get baseUrl => _baseUrl;
  String? get token => _token;

  /// 启动页展示用（对齐飞牛启动页：用户名 + 设备名）。
  /// 安装唯一 id（device/login 的 client.installation_id，8-128 字符）。
  /// 首次调用生成并持久化，之后稳定不变：同设备重登替换旧凭证而非新增设备。
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

  String get username => _username ?? '';

  String? _avatarUrl;

  String get avatarUrl => _avatarUrl ?? '';
  String get deviceName => _deviceName ?? '';
  bool get isReady => _baseUrl != null && _token != null;

  /// 测试专用：不经存储直接种入会话（@visibleForTesting）。
  @visibleForTesting
  void debugSeed({required String baseUrl, required String token}) {
    _baseUrl = baseUrl;
    _token = token;
  }

  /// 测试专用：清除内存会话。
  @visibleForTesting
  void logoutForTest() {
    _baseUrl = null;
    _token = null;
  }

  /// 多账号令牌键：mc_token:<origin>:<username>（旧版只有 mc_token:<origin>）。
  String _accountKey(String origin, String username) =>
      'mc_token:$origin:$username';

  Future<void> restore() async {
    final base = await _storage.read(key: 'mc_active_base');
    _baseUrl = base;
    if (base != null) {
      _token = await _storage.read(key: 'mc_token:$base');
      _username = await _storage.read(key: 'mc_username');
      _deviceName = await _storage.read(key: 'mc_device_name');
      _avatarUrl = await _storage.read(key: 'mc_avatar_url');
    }
  }

  Future<void> login({
    required String baseUrl,
    required String token,
    String? username,
    String? deviceName,
  }) async {
    _baseUrl = baseUrl;
    _token = token;
    if (username != null) _username = username;
    if (deviceName != null) _deviceName = deviceName;
    await _storage.write(key: 'mc_active_base', value: baseUrl);
    await _storage.write(key: 'mc_token:$baseUrl', value: token);
    // 同时落账号级快照（mc_token:<origin>:<user>），供切换账号免重登恢复。
    if (_username != null) {
      await _storage.write(key: _accountKey(baseUrl, _username!), value: token);
    }
    if (_username != null) {
      await _storage.write(key: 'mc_username', value: _username!);
    }
    if (_deviceName != null) {
      await _storage.write(key: 'mc_device_name', value: _deviceName!);
    }
  }

  /// 补存展示身份（登录后 GET /auth/me 回填；logout 已清空）。
  Future<void> saveProfile(
      {String? username, String? deviceName, String? avatarUrl}) async {
    if (username != null && username.isNotEmpty) {
      _username = username;
      await _storage.write(key: 'mc_username', value: username);
    }
    if (avatarUrl != null) {
      _avatarUrl = avatarUrl;
      await _storage.write(key: 'mc_avatar_url', value: avatarUrl);
    }
    if (deviceName != null && deviceName.isNotEmpty) {
      _deviceName = deviceName;
      await _storage.write(key: 'mc_device_name', value: deviceName);
    }
  }

  /// 快照当前会话令牌到 mc_token:<origin>:<user>（切换账号前先存，避免丢失）。
  Future<void> snapshotAccountToken({
    required String origin,
    required String username,
  }) async {
    final token = _token;
    if (token == null || username.isEmpty) return;
    await _storage.write(key: _accountKey(origin, username), value: token);
  }

  /// 切换到 <origin>:<username> 的已存令牌：命中账号键即激活会话；
  /// 向后兼容迁移——旧数据只有 mc_token:<origin> 单键时读它并回写到账号键。
  /// 没有任何令牌返回 false（调用方维持现状 / 走重新登录）。
  Future<bool> switchAccount({
    required String origin,
    required String username,
  }) async {
    var token = await _storage.read(key: _accountKey(origin, username));
    if (token == null || token.isEmpty) {
      token = await _storage.read(key: 'mc_token:$origin');
      if (token != null && token.isNotEmpty) {
        // 迁移：旧单键令牌补写账号键，之后两种键都在。
        await _storage.write(key: _accountKey(origin, username), value: token);
      }
    }
    if (token == null || token.isEmpty) return false;
    _baseUrl = origin;
    _token = token;
    _username = username;
    await _storage.write(key: 'mc_active_base', value: origin);
    await _storage.write(key: 'mc_username', value: username);
    return true;
  }

  /// 本机移除账号时清对应令牌快照（不动当前会话）。
  Future<void> deleteAccountToken({
    required String origin,
    required String username,
  }) async {
    await _storage.delete(key: _accountKey(origin, username));
  }

  Future<void> logout() async {
    final base = _baseUrl;
    _token = null;
    _username = null;
    _deviceName = null;
    await _storage.delete(key: 'mc_username');
    await _storage.delete(key: 'mc_device_name');
    if (base != null) {
      await _storage.delete(key: 'mc_token:$base');
    }
    await _storage.delete(key: 'mc_active_base');
    _baseUrl = null;
  }
}

/// 全 App 唯一会话实例（main 启动即 restore，router 重定向/各域 provider 共享）。
final SessionStore appSession = SessionStore();
