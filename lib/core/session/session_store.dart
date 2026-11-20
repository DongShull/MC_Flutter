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
  String get username => _username ?? '';
  String get deviceName => _deviceName ?? '';
  bool get isReady => _baseUrl != null && _token != null;

  Future<void> restore() async {
    final base = await _storage.read(key: 'mc_active_base');
    _baseUrl = base;
    if (base != null) {
      _token = await _storage.read(key: 'mc_token:\${base}');
      _username = await _storage.read(key: 'mc_username');
      _deviceName = await _storage.read(key: 'mc_device_name');
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
    if (_username != null) {
      await _storage.write(key: 'mc_username', value: _username!);
    }
    if (_deviceName != null) {
      await _storage.write(key: 'mc_device_name', value: _deviceName!);
    }
  }

  /// 补存展示身份（登录后 GET /auth/me 回填；logout 已清空）。
  Future<void> saveProfile({String? username, String? deviceName}) async {
    if (username != null && username.isNotEmpty) {
      _username = username;
      await _storage.write(key: 'mc_username', value: username);
    }
    if (deviceName != null && deviceName.isNotEmpty) {
      _deviceName = deviceName;
      await _storage.write(key: 'mc_device_name', value: deviceName);
    }
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
