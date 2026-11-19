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

  String? get baseUrl => _baseUrl;
  String? get token => _token;
  bool get isReady => _baseUrl != null && _token != null;

  Future<void> restore() async {
    final base = await _storage.read(key: 'mc_active_base');
    _baseUrl = base;
    if (base != null) {
      _token = await _storage.read(key: 'mc_token:$base');
    }
  }

  Future<void> login({
    required String baseUrl,
    required String token,
  }) async {
    _baseUrl = baseUrl;
    _token = token;
    await _storage.write(key: 'mc_active_base', value: baseUrl);
    await _storage.write(key: 'mc_token:$baseUrl', value: token);
  }

  Future<void> logout() async {
    final base = _baseUrl;
    _token = null;
    if (base != null) {
      await _storage.delete(key: 'mc_token:$base');
    }
    await _storage.delete(key: 'mc_active_base');
    _baseUrl = null;
  }
}
