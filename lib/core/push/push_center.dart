import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/mc_l10n.dart';
import '../session/session_store.dart';
import 'push_crypto.dart';

/// 系统通知权限状态（线协议严格对齐 `PushRegistration.swift`）。
enum PushPermission {
  authorized('authorized'),
  provisional('provisional'),
  ephemeral('ephemeral'),
  denied('denied'),
  notDetermined('not_determined');

  const PushPermission(this.wireValue);

  final String wireValue;

  static PushPermission fromWire(String? raw) => switch (raw) {
        'authorized' => PushPermission.authorized,
        'provisional' => PushPermission.provisional,
        'ephemeral' => PushPermission.ephemeral,
        'denied' => PushPermission.denied,
        _ => PushPermission.notDetermined,
      };

  String label(McL10n l10n) => switch (this) {
        PushPermission.authorized => l10n.pushStatusAllowed,
        PushPermission.provisional => l10n.pushStatusProvisional,
        PushPermission.ephemeral => l10n.pushStatusEphemeral,
        PushPermission.denied => l10n.pushStatusDenied,
        PushPermission.notDetermined => l10n.pushStatusNotDetermined,
      };
}

/// 单个 `(origin, username)` 的 E2EE 推送密钥条目。
class PushKeyEntry {
  const PushKeyEntry({
    required this.keyId,
    required this.keyBytes,
  });

  final String keyId;
  final Uint8List keyBytes;

  String get keyBase64Url => PushCrypto.encodeBase64Url(keyBytes);
}

/// 已登记推送的登录元数据（`key_id` -> 登录对照）。
class PushLoginInfo {
  const PushLoginInfo({
    required this.origin,
    required this.username,
    required this.serverName,
    required this.accountName,
  });

  final String origin;
  final String username;
  final String serverName;
  final String accountName;

  String get accountKey => '$origin#${username.toLowerCase()}';

  factory PushLoginInfo.fromJson(Map<String, dynamic> j) => PushLoginInfo(
        origin: (j['origin'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        serverName: (j['serverName'] ?? j['server_name'] ?? '').toString(),
        accountName: (j['accountName'] ?? j['account_name'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'origin': origin,
        'username': username,
        'serverName': serverName,
        'accountName': accountName,
      };
}

/// 解密后的通知点击目标。
class PushTapTarget {
  const PushTapTarget({
    required this.login,
    required this.payload,
    this.openPath,
    this.actionId,
  });

  final PushLoginInfo login;
  final PushPayload payload;
  final String? openPath;
  final String? actionId;
}

/// MovieClaw 推送中心单例（1:1 对齐 iOS `PushCenter.swift` + `PushKeyStore.swift`）。
///
/// 职责：
/// - 在 `FlutterSecureStorage` 中按 `(origin, username)` 维护独立 AES-256 密钥与 `key_id`；
/// - 桥接 iOS `MethodChannel('mc/native/push')`（非 iOS 或测试环境静默降级）；
/// - 对本机全部已保存账号并发登记 `PUT /api/v1/push/me/registration`（按日指纹去重）；
/// - 追踪 `visibleSessionPath` 实现当前 AI 会话前台静默；
/// - 提供 `muteItem(origin, token, itemId)` 调用 `PUT /api/v1/push/me/muted-items/{id}`。
class PushCenter extends ChangeNotifier {
  PushCenter({
    FlutterSecureStorage? storage,
    Dio? dio,
    MethodChannel? channel,
    this.clientVersion = '0.1.0',
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
                headers: const {'User-Agent': 'MovieClaw-Flutter/1.0.0'},
                validateStatus: (_) => true,
              ),
            ),
        _channel = channel ?? const MethodChannel('mc/native/push');

  static final PushCenter instance = PushCenter();

  static const _apnsTokenStorageKey = 'mc_push_apns_token';
  static const _loginsIndexKey = 'mc_push_logins';
  static const _serversStorageKey = 'mc_servers';
  static const List<String> supportedTypes = ['alert'];

  final FlutterSecureStorage _storage;
  final Dio _dio;
  final MethodChannel _channel;
  final String clientVersion;

  PushPermission _permission = PushPermission.notDetermined;
  String? _apnsToken;
  String _topic = 'io.movieclaw.app';
  String _environment = 'production';
  bool _apnsAnswered = false;
  bool _unsupportedBuild = false;
  bool _started = false;
  bool _syncing = false;
  bool _syncAgain = false;
  int _registrationRound = 0;

  String? _visibleSessionPath;
  PushTapTarget? _pendingTap;

  final Map<String, String> _registeredFingerprints = {};
  final StreamController<PushTapTarget> _tapController =
      StreamController<PushTapTarget>.broadcast();

  PushPermission get permission => _permission;
  String? get apnsToken => _apnsToken;
  String get topic => _topic;
  String get environment => _environment;
  bool get unsupportedBuild => _unsupportedBuild;
  int get registrationRound => _registrationRound;
  PushTapTarget? get pendingTap => _pendingTap;
  Stream<PushTapTarget> get onTap => _tapController.stream;

  /// 当前正在浏览的 AI 会话站内路径（例如 `/sessions/{id}`）；用于前台抑制同一会话推送。
  String? get visibleSessionPath => _visibleSessionPath;
  set visibleSessionPath(String? path) {
    final normalized = PushPayload.sanitizeSitePath(path);
    if (_visibleSessionPath == normalized) return;
    _visibleSessionPath = normalized;
    unawaited(_invokeNative<void>('setVisibleSessionPath', {'path': normalized}));
  }

  /// 消费并清空待处理的通知点击目标。
  PushTapTarget? consumePendingTap() {
    final target = _pendingTap;
    _pendingTap = null;
    if (target != null) notifyListeners();
    return target;
  }

  /// 纯函数：判断一条推送在前台是否应当展示横幅（对齐 `PushCenter.foregroundOptions`）。
  static bool shouldPresentInForeground({
    required bool passive,
    String? openPath,
    String? visibleSessionPath,
  }) {
    if (openPath != null &&
        visibleSessionPath != null &&
        openPath.isNotEmpty &&
        openPath == visibleSessionPath) {
      return false;
    }
    return !passive;
  }

  /// 启动推送桥接（可幂等多次调用）。
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _apnsToken = await _storage.read(key: _apnsTokenStorageKey);
    _channel.setMethodCallHandler(_handleNativeCall);

    await refreshPushInfo();
    await _invokeNative<void>('registerCategories');
    await _invokeNative<void>('registerForRemoteNotifications');

    final initial =
        await _invokeNative<Map<dynamic, dynamic>>('getInitialNotification');
    if (initial != null) {
      unawaited(_handleNotificationTapPayload(initial));
    }
  }

  /// 刷新系统通知权限、APNs 环境（来自 `embedded.mobileprovision`）与 Bundle ID。
  Future<void> refreshPushInfo() async {
    final info = await _invokeNative<Map<dynamic, dynamic>>('getPushInfo');
    if (info != null) {
      var changed = false;
      final nextPerm = PushPermission.fromWire(info['permission']?.toString());
      if (nextPerm != _permission) {
        _permission = nextPerm;
        changed = true;
      }
      final env = info['apsEnvironment']?.toString();
      if (env != null && env.isNotEmpty) _environment = env;
      final bundleTopic = info['topic']?.toString();
      if (bundleTopic != null && bundleTopic.isNotEmpty) _topic = bundleTopic;
      final token = info['apnsToken']?.toString();
      if (token != null && token.isNotEmpty) {
        _apnsToken = token;
        _apnsAnswered = true;
        await _storage.write(key: _apnsTokenStorageKey, value: token);
      }
      if (info['unsupportedBuild'] == true && !_unsupportedBuild) {
        _unsupportedBuild = true;
        changed = true;
      }
      if (changed) notifyListeners();
      return;
    }

    final status = await _invokeNative<String>('getAuthorizationStatus');
    if (status != null) {
      final next = PushPermission.fromWire(status);
      if (next != _permission) {
        _permission = next;
        notifyListeners();
      }
    }
  }

  /// 请求系统通知权限（仅未决定时弹框），随后向 APNs 注册并同步本机全部登录。
  Future<PushPermission> requestAuthorization({bool prompt = true}) async {
    await refreshPushInfo();
    if (prompt && _permission == PushPermission.notDetermined) {
      final status = await _invokeNative<String>('requestAuthorization');
      if (status != null) {
        _permission = PushPermission.fromWire(status);
        notifyListeners();
      }
    }
    await _invokeNative<void>('registerForRemoteNotifications');
    await sync();
    return _permission;
  }

  /// 供测试或原生事件注入 APNs 令牌。
  Future<void> onDeviceTokenReceived(String hexToken) async {
    if (hexToken.isEmpty) return;
    _apnsToken = hexToken;
    _apnsAnswered = true;
    _unsupportedBuild = false;
    await _storage.write(key: _apnsTokenStorageKey, value: hexToken);
    notifyListeners();
    await sync();
  }

  // MARK: - 每账号密钥管理（FlutterSecureStorage）

  String _keyStorageKey(String origin, String username) =>
      'mc_push_key:$origin#${username.toLowerCase()}';

  /// 获取或创建 `(origin, username)` 的 E2EE 推送密钥，同时更新 `key_id -> login` 对照表。
  Future<PushKeyEntry> ensureKey({
    required String origin,
    required String username,
    String? serverName,
    String? accountName,
  }) async {
    final normalizedOrigin = _normalizeOrigin(origin);
    final info = PushLoginInfo(
      origin: normalizedOrigin,
      username: username,
      serverName: serverName ?? _hostLabel(normalizedOrigin),
      accountName: accountName ?? username,
    );
    final storageKey = _keyStorageKey(normalizedOrigin, username);
    final raw = await _storage.read(key: storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final keyId = map['key_id']?.toString() ?? '';
        final keyB64 = map['key']?.toString() ?? '';
        final decodedKey = PushCrypto.decodeBase64Url(keyB64);
        if (keyId.isNotEmpty &&
            decodedKey != null &&
            decodedKey.length == PushCrypto.keyByteCount) {
          await _setLoginIndex(keyId, info);
          return PushKeyEntry(keyId: keyId, keyBytes: decodedKey);
        }
      } catch (_) {}
    }

    final keyId = PushCrypto.generateKeyId();
    final keyBytes = PushCrypto.generateKey();
    final encoded = jsonEncode({
      'key_id': keyId,
      'key': PushCrypto.encodeBase64Url(keyBytes),
    });
    await _storage.write(key: storageKey, value: encoded);
    await _setLoginIndex(keyId, info);
    return PushKeyEntry(keyId: keyId, keyBytes: keyBytes);
  }

  /// 按 `key_id` 查找对应的登录与对称密钥（解密收到推送时使用）。
  Future<({PushLoginInfo login, Uint8List key})?> lookupKeyById(
    String keyId,
  ) async {
    final index = await _readLoginIndex();
    final info = index[keyId];
    if (info == null) return null;
    final raw =
        await _storage.read(key: _keyStorageKey(info.origin, info.username));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['key_id']?.toString() != keyId) return null;
      final keyBytes = PushCrypto.decodeBase64Url(map['key']?.toString() ?? '');
      if (keyBytes == null || keyBytes.length != PushCrypto.keyByteCount) {
        return null;
      }
      return (login: info, key: keyBytes);
    } catch (_) {
      return null;
    }
  }

  /// 删除指定登录的推送密钥与对照表记录（退出登录或 401 时调用）。
  Future<void> removeKey(String origin, String username) async {
    final normalizedOrigin = _normalizeOrigin(origin);
    await _storage.delete(key: _keyStorageKey(normalizedOrigin, username));
    final accountKey = '$normalizedOrigin#${username.toLowerCase()}';
    final index = await _readLoginIndex();
    final next = Map<String, PushLoginInfo>.from(index)
      ..removeWhere((_, v) => v.accountKey == accountKey);
    if (next.length != index.length) {
      await _writeLoginIndex(next);
    }
    _registeredFingerprints.remove(accountKey);
  }

  /// 清除本机全部推送密钥。
  Future<void> removeAllKeys() async {
    final index = await _readLoginIndex();
    for (final info in index.values) {
      await _storage.delete(key: _keyStorageKey(info.origin, info.username));
    }
    await _storage.delete(key: _loginsIndexKey);
    _registeredFingerprints.clear();
  }

  /// 解密 APNs `userInfo['e']`，返回登录与明文载荷；密文无效或无密钥时返回 null。
  Future<({PushLoginInfo login, PushPayload payload})?> decryptUserInfo(
    Map<String, dynamic> userInfo,
  ) async {
    final ciphertext = userInfo['e']?.toString();
    if (ciphertext == null || ciphertext.isEmpty) return null;
    try {
      final envelope = PushCrypto.parse(ciphertext);
      final found = await lookupKeyById(envelope.keyId);
      if (found == null) return null;
      final payload = await PushCrypto.decryptPayload(
        ciphertext,
        key: found.key,
      );
      if (!payload.isAlert) return null;
      return (login: found.login, payload: payload);
    } catch (_) {
      return null;
    }
  }

  // MARK: - 跨账号推送登记（PUT /api/v1/push/me/registration）

  /// 向本机所有已保存账号同步推送登记（同一天内同指纹自动跳过，并发发往不同服务器）。
  Future<void> sync({SessionStore? session, bool force = false}) async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        await _registerAll(session: session ?? appSession, force: force);
      } while (_syncAgain);
      _registrationRound += 1;
      notifyListeners();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _registerAll({
    required SessionStore session,
    required bool force,
  }) async {
    if (!force && !_apnsAnswered && _permission != PushPermission.denied) {
      return;
    }
    final accounts = await _collectSavedAccounts(session);
    if (accounts.isEmpty) return;

    final utcDay = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
    final jobs = <_RegistrationJob>[];

    for (final acct in accounts) {
      final body = <String, dynamic>{
        'topic': _topic,
        'environment': _environment,
        'types': supportedTypes,
        'permission': _permission.wireValue,
        'client_version': clientVersion,
        if (_unsupportedBuild) 'unsupported_build': true,
      };
      if (!_unsupportedBuild &&
          _apnsToken != null &&
          _apnsToken!.isNotEmpty &&
          _permission != PushPermission.denied) {
        final keyEntry = await ensureKey(
          origin: acct.origin,
          username: acct.username,
          serverName: acct.serverName,
          accountName: acct.accountName,
        );
        body['token'] = _apnsToken;
        body['key_id'] = keyEntry.keyId;
        body['key'] = keyEntry.keyBase64Url;
      }

      final fingerprint = sha256
          .convert(utf8.encode('${acct.token}|${jsonEncode(body)}|$utcDay'))
          .toString();
      final accountKey = '${acct.origin}#${acct.username.toLowerCase()}';
      if (!force && _registeredFingerprints[accountKey] == fingerprint) {
        continue;
      }
      jobs.add(
        _RegistrationJob(
          accountKey: accountKey,
          origin: acct.origin,
          username: acct.username,
          token: acct.token,
          body: body,
          fingerprint: fingerprint,
        ),
      );
    }

    if (jobs.isEmpty) return;

    await Future.wait(
      jobs.map((job) async {
        try {
          final res = await _dio.put<dynamic>(
            '${job.origin}/api/v1/push/me/registration',
            data: job.body,
            options: Options(
              headers: {'Authorization': 'Bearer ${job.token}'},
            ),
          );
          final code = res.statusCode ?? 0;
          if (code >= 200 && code < 300) {
            _registeredFingerprints[job.accountKey] = job.fingerprint;
          } else if (code == 401) {
            await removeKey(job.origin, job.username);
            await session.deleteAccountToken(
              origin: job.origin,
              username: job.username,
            );
          }
        } catch (e) {
          debugPrint('Push registration failed for ${job.origin}: $e');
        }
      }),
    );
  }

  /// 将指定条目静音（只关闭该片推送提醒，订阅仍照常下载）。
  ///
  /// 对应接口：`PUT /api/v1/push/me/muted-items/{item_id}`
  Future<bool> muteItem(String origin, String token, int itemId) async {
    final base = _normalizeOrigin(origin);
    if (base.isEmpty || token.isEmpty || itemId <= 0) return false;
    try {
      final res = await _dio.put<dynamic>(
        '$base/api/v1/push/me/muted-items/$itemId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      final code = res.statusCode ?? 0;
      return code >= 200 && code < 300;
    } catch (e) {
      debugPrint('Push muteItem($itemId) failed: $e');
      return false;
    }
  }

  /// 注销指定账号的推送登记（退出登录时调用：`DELETE /api/v1/push/me/registration`）。
  Future<void> unregister({
    required String origin,
    required String token,
    required String username,
  }) async {
    final base = _normalizeOrigin(origin);
    await removeKey(base, username);
    if (base.isEmpty || token.isEmpty) return;
    try {
      await _dio.delete<dynamic>(
        '$base/api/v1/push/me/registration',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}
  }

  // MARK: - 原生通道回调处理

  Future<void> _handleNativeCall(MethodCall call) async {
    final args = call.arguments is Map
        ? (call.arguments as Map).cast<dynamic, dynamic>()
        : const <dynamic, dynamic>{};
    switch (call.method) {
      case 'onDeviceToken':
        final token = args['token']?.toString();
        final env = args['apsEnvironment']?.toString();
        final topic = args['topic']?.toString();
        if (env != null && env.isNotEmpty) _environment = env;
        if (topic != null && topic.isNotEmpty) _topic = topic;
        if (token != null && token.isNotEmpty) {
          await onDeviceTokenReceived(token);
        }
      case 'onRegisterError':
        _apnsAnswered = true;
        if (args['unsupportedBuild'] == true) {
          _unsupportedBuild = true;
          notifyListeners();
        }
        await sync();
      case 'onNotificationTap':
        await _handleNotificationTapPayload(args);
    }
  }

  Future<void> _handleNotificationTapPayload(
    Map<dynamic, dynamic> raw,
  ) async {
    final actionId = raw['actionIdentifier']?.toString();
    final rawUserInfo = raw['userInfo'];
    if (rawUserInfo is! Map) return;
    final userInfo = <String, dynamic>{
      for (final e in rawUserInfo.entries) e.key.toString(): e.value,
    };
    final decrypted = await decryptUserInfo(userInfo);
    if (decrypted == null) return;

    if (actionId == 'mute' && !decrypted.payload.isNewer) {
      final itemId = decrypted.payload.itemId;
      if (itemId != null) {
        final token = await _readAccountToken(
          decrypted.login.origin,
          decrypted.login.username,
        );
        if (token != null && token.isNotEmpty) {
          await muteItem(decrypted.login.origin, token, itemId);
        }
      }
      return;
    }

    String? openPath;
    if (!decrypted.payload.isNewer) {
      if (actionId != null &&
          actionId.isNotEmpty &&
          actionId != 'com.apple.UNNotificationDefaultActionIdentifier') {
        for (final action in decrypted.payload.actions) {
          if (action.id == actionId && action.openPath != null) {
            openPath = action.openPath;
            break;
          }
        }
      }
      openPath ??= decrypted.payload.openPath;
    }

    final target = PushTapTarget(
      login: decrypted.login,
      payload: decrypted.payload,
      openPath: openPath,
      actionId: actionId,
    );
    _pendingTap = target;
    if (!_tapController.isClosed) {
      _tapController.add(target);
    }
    notifyListeners();
  }

  // MARK: - 内部持久化辅助

  Future<T?> _invokeNative<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, PushLoginInfo>> _readLoginIndex() async {
    final raw = await _storage.read(key: _loginsIndexKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, PushLoginInfo>{};
      for (final entry in decoded.entries) {
        if (entry.value is Map) {
          out[entry.key.toString()] = PushLoginInfo.fromJson(
            (entry.value as Map).cast<String, dynamic>(),
          );
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeLoginIndex(Map<String, PushLoginInfo> entries) async {
    final map = <String, dynamic>{
      for (final e in entries.entries) e.key: e.value.toJson(),
    };
    await _storage.write(key: _loginsIndexKey, value: jsonEncode(map));
  }

  Future<void> _setLoginIndex(String keyId, PushLoginInfo info) async {
    final current = await _readLoginIndex();
    final next = <String, PushLoginInfo>{
      for (final e in current.entries)
        if (e.value.accountKey != info.accountKey) e.key: e.value,
      keyId: info,
    };
    await _writeLoginIndex(next);
  }

  Future<String?> _readAccountToken(String origin, String username) async {
    final direct = await _storage.read(key: 'mc_token:$origin:$username');
    if (direct != null && direct.isNotEmpty) return direct;
    return _storage.read(key: 'mc_token:$origin');
  }

  Future<List<_SavedAccount>> _collectSavedAccounts(
    SessionStore session,
  ) async {
    final seen = <String>{};
    final out = <_SavedAccount>[];

    final raw = await _storage.read(key: _serversStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final server in decoded) {
            if (server is! Map) continue;
            final origin = _normalizeOrigin(server['origin']?.toString() ?? '');
            if (origin.isEmpty) continue;
            final accounts = server['accounts'];
            if (accounts is! List) continue;
            for (final acct in accounts) {
              if (acct is! Map) continue;
              final username = (acct['username'] ?? '').toString();
              if (username.isEmpty) continue;
              final token = await _readAccountToken(origin, username);
              if (token == null || token.isEmpty) continue;
              final key = '$origin#${username.toLowerCase()}';
              if (seen.add(key)) {
                out.add(
                  _SavedAccount(
                    origin: origin,
                    username: username,
                    token: token,
                    serverName: _hostLabel(origin),
                    accountName: (acct['nickname'] ?? username).toString(),
                  ),
                );
              }
            }
          }
        }
      } catch (_) {}
    }

    // 补充当前活跃会话（防止刚登录还未写入 mc_servers 时漏登）。
    final activeBase = _normalizeOrigin(session.baseUrl ?? '');
    final activeToken = session.token;
    final activeUser = session.username;
    if (activeBase.isNotEmpty &&
        activeToken != null &&
        activeToken.isNotEmpty &&
        activeUser.isNotEmpty) {
      final key = '$activeBase#${activeUser.toLowerCase()}';
      if (seen.add(key)) {
        out.add(
          _SavedAccount(
            origin: activeBase,
            username: activeUser,
            token: activeToken,
            serverName: _hostLabel(activeBase),
            accountName: activeUser,
          ),
        );
      }
    }

    return out;
  }

  static String _normalizeOrigin(String raw) {
    var trimmed = raw.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static String _hostLabel(String origin) {
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.host.isEmpty) return origin;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }
}

class _SavedAccount {
  const _SavedAccount({
    required this.origin,
    required this.username,
    required this.token,
    required this.serverName,
    required this.accountName,
  });

  final String origin;
  final String username;
  final String token;
  final String serverName;
  final String accountName;
}

class _RegistrationJob {
  const _RegistrationJob({
    required this.accountKey,
    required this.origin,
    required this.username,
    required this.token,
    required this.body,
    required this.fingerprint,
  });

  final String accountKey;
  final String origin;
  final String username;
  final String token;
  final Map<String, dynamic> body;
  final String fingerprint;
}
