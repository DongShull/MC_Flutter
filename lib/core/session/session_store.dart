import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/server_routes.dart';
import '../storage/page_snapshots.dart';
import 'pending_revocations.dart';
import 'permissions.dart';

/// App 会话顶层生命周期状态（对齐 iOS `AppModel.Phase`）。
enum SessionPhase {
  loading,
  ready,
  unreachable,
  chooseAccount,
  needsLogin,
}

/// 指向某台服务器上某个账号的轻量引用（供 `previousAccount` 双击快切与退出自动切兄弟账号使用）。
class SavedAccountRef {
  const SavedAccountRef({required this.origin, required this.username});

  factory SavedAccountRef.fromJson(Map<String, dynamic> json) =>
      SavedAccountRef(
        origin: SessionStore.normalizeOrigin((json['origin'] ?? '').toString()),
        username: (json['username'] ?? '').toString().trim(),
      );

  final String origin;
  final String username;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'origin': origin,
        'username': username,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedAccountRef &&
          SessionStore.normalizeOrigin(other.origin) ==
              SessionStore.normalizeOrigin(origin) &&
          SessionStore.normalizeUsername(other.username) ==
              SessionStore.normalizeUsername(username);

  @override
  int get hashCode => Object.hash(
        SessionStore.normalizeOrigin(origin),
        SessionStore.normalizeUsername(username),
      );
}

/// 会话与凭证（全局 ChangeNotifier，驱动 GoRouter 登录态守卫、多账号秒切与权限快照）：
/// - `mc_installation_id`：本机稳定安装 ID；
/// - `mc_token:<origin>:<normalized_user>`：每服务器每账号独立令牌（iOS Keychain `first_unlock_this_device`）；
/// - `mc_servers`：多服务器账号快照（供 AccountSwitcherSheet 与 AccountPage 读取）；
/// - `mc_previous_account`：上一个账号引用（支持双击头像一键切回）；
/// - `mc_session_cache`：每个账号缓存的 `McPermissions`，冷启动直接恢复 `.ready`。
class SessionStore extends ChangeNotifier {
  SessionStore({
    FlutterSecureStorage? storage,
    PendingRevocations? pendingRevocations,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            ),
        _pendingRevocations = pendingRevocations ?? PendingRevocations.instance;

  static const _serversKey = 'mc_servers';
  static const _previousAccountKey = 'mc_previous_account';
  static const _sessionCacheKey = 'mc_session_cache';

  final FlutterSecureStorage _storage;
  final PendingRevocations _pendingRevocations;

  /// 内存多账号令牌表：`<normalizedOrigin>#<normalizedUsername>` -> Bearer token
  /// 供 `mcImageHeadersFor(origin:, username:)` 加载其他已保存账号的头像。
  final Map<String, String> _accountTokens = <String, String>{};
  final Map<String, McPermissions> _permissionsCache =
      <String, McPermissions>{};

  String? _baseUrl;
  String? _token;
  String? _username;
  String? _accountUsername;
  String? _deviceName;
  String? _avatarUrl;

  SessionPhase _phase = SessionPhase.loading;
  String? _expiredUsername;
  String? _resumeLocation;
  String? _pendingNotice;
  SavedAccountRef? _previousAccount;
  McPermissions _permissions = McPermissions.none;
  int _sessionGeneration = 0;

  String? get baseUrl => _baseUrl;
  String? get token => _token;
  String get username => _username ?? '';
  String get accountUsername => _accountUsername ?? _username ?? '';
  String get avatarUrl => _avatarUrl ?? '';
  String get deviceName => _deviceName ?? '';
  bool get isReady => _baseUrl != null && _token != null;

  SessionPhase get phase => _phase;
  String? get expiredUsername => _expiredUsername;
  String? get resumeLocation => _resumeLocation;
  String? get pendingNotice => _pendingNotice;
  SavedAccountRef? get previousAccount => _previousAccount;
  McPermissions get permissions => _permissions;
  int get sessionGeneration => _sessionGeneration;

  static String normalizeUsername(String username) =>
      username.trim().toLowerCase();

  static String normalizeOrigin(String origin) {
    var v = origin.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  static String _memoryTokenKey(String origin, String username) =>
      '${normalizeOrigin(origin)}#${normalizeUsername(username)}';

  String _accountKey(String origin, String username) =>
      'mc_token:${normalizeOrigin(origin)}:${normalizeUsername(username)}';

  String _legacyAccountKey(String origin, String username) =>
      'mc_token:$origin:$username';

  String _avatarKey(String origin, String username) =>
      'mc_avatar:${normalizeOrigin(origin)}:${normalizeUsername(username)}';

  String _legacyAvatarKey(String origin, String username) =>
      'mc_avatar:$origin:$username';

  /// 查询内存令牌表（供 `mcImageHeadersFor` 加载任意已保存账号头像）。
  String? tokenFor({String? origin, String? username}) {
    final normOrigin = origin != null && origin.trim().isNotEmpty
        ? normalizeOrigin(origin)
        : (_baseUrl != null ? normalizeOrigin(_baseUrl!) : '');
    if (username != null && username.trim().isNotEmpty && normOrigin.isNotEmpty) {
      final hit = _accountTokens[_memoryTokenKey(normOrigin, username)];
      if (hit != null && hit.isNotEmpty) return hit;
    }
    if (normOrigin.isEmpty) return _token;
    final activeBase = _baseUrl != null ? normalizeOrigin(_baseUrl!) : '';
    if (normOrigin == activeBase ||
        (activeBase.isNotEmpty &&
            ServerRoutes.instance.belongsToServer(normOrigin, activeBase))) {
      return _token;
    }
    return null;
  }

  /// 本机内存中是否存在指定账号的有效令牌。
  bool hasTokenFor({required String origin, required String username}) {
    final tok = _accountTokens[_memoryTokenKey(origin, username)];
    return tok != null && tok.isNotEmpty;
  }

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
  void debugSeed({
    required String baseUrl,
    required String token,
    String? username,
    McPermissions? permissions,
  }) {
    final normBase = normalizeOrigin(baseUrl);
    _baseUrl = normBase;
    _token = token;
    if (username != null && username.isNotEmpty) {
      _username = username;
      _accountUsername = normalizeUsername(username);
      _accountTokens[_memoryTokenKey(normBase, username)] = token;
    }
    if (permissions != null) {
      _permissions = permissions;
    }
    _phase = SessionPhase.ready;
    _expiredUsername = null;
    notifyListeners();
  }

  @visibleForTesting
  void logoutForTest() {
    _baseUrl = null;
    _token = null;
    _username = null;
    _accountUsername = null;
    _deviceName = null;
    _avatarUrl = null;
    _previousAccount = null;
    _expiredUsername = null;
    _resumeLocation = null;
    _pendingNotice = null;
    _permissions = McPermissions.none;
    _accountTokens.clear();
    _permissionsCache.clear();
    _phase = SessionPhase.needsLogin;
    notifyListeners();
  }

  /// 冷启动恢复会话：
  /// - 载入全部已保存账号令牌到内存表（多账号头像加载）；
  /// - 载入 `mc_previous_account`（双击头像切回）与 `mc_session_cache`（缓存权限）；
  /// - 若存在有效令牌，立即置 `phase = SessionPhase.ready` 实现冷启动秒开。
  Future<void> restore() async {
    await _loadSessionCache();
    await _loadPreviousAccount();
    final servers = await _readServersList();

    // 预加载全部已保存账号的令牌到内存表，供 AccountSwitcherSheet 显示各账号头像。
    for (final server in servers) {
      final origin = normalizeOrigin((server['origin'] ?? '').toString());
      if (origin.isEmpty) continue;
      final accounts = server['accounts'] as List? ?? const <dynamic>[];
      for (final item in accounts) {
        if (item is! Map) continue;
        final acctUser = (item['username'] ?? '').toString().trim();
        if (acctUser.isEmpty) continue;
        final tok = await _readStoredAccountToken(origin, acctUser);
        if (tok != null && tok.isNotEmpty) {
          _accountTokens[_memoryTokenKey(origin, acctUser)] = tok;
        }
      }
    }

    final rawBase = await _storage.read(key: 'mc_active_base');
    final base = rawBase != null && rawBase.isNotEmpty
        ? normalizeOrigin(rawBase)
        : null;
    _baseUrl = base;

    if (base != null) {
      _username = await _storage.read(key: 'mc_username');
      _accountUsername = await _storage.read(key: 'mc_account_username') ??
          _username;
      _deviceName = await _storage.read(key: 'mc_device_name');
      _avatarUrl = await _storage.read(key: 'mc_avatar_url');

      final lookupUser = _accountUsername ?? _username;
      if (lookupUser != null && lookupUser.isNotEmpty) {
        _token = await _readStoredAccountToken(base, lookupUser) ??
            await _storage.read(key: 'mc_token:$base');
      } else {
        _token = await _storage.read(key: 'mc_token:$base');
      }

      if (_token != null && _token!.isNotEmpty) {
        if (lookupUser != null && lookupUser.isNotEmpty) {
          _accountTokens[_memoryTokenKey(base, lookupUser)] = _token!;
          _permissions =
              _permissionsCache[_memoryTokenKey(base, lookupUser)] ??
                  McPermissions.none;
          if (_permissions.avatarUrl.isNotEmpty &&
              (_avatarUrl == null || _avatarUrl!.isEmpty)) {
            _avatarUrl = _permissions.avatarUrl;
          }
        }
        _phase = SessionPhase.ready;
        _expiredUsername = null;
        unawaited(ServerRoutes.instance.activate(base, token: _token));
      } else {
        _expiredUsername = lookupUser;
        _phase = _hasAnySavedToken(servers)
            ? SessionPhase.chooseAccount
            : SessionPhase.needsLogin;
      }
    } else {
      _token = null;
      _permissions = McPermissions.none;
      _phase = _hasAnySavedToken(servers)
          ? SessionPhase.chooseAccount
          : SessionPhase.needsLogin;
    }

    notifyListeners();
  }

  /// 登录成功后保存当前会话、刷新多账号索引与记忆令牌表。
  Future<void> login({
    required String baseUrl,
    required String token,
    String? username,
    String? deviceName,
    McPermissions? permissions,
  }) async {
    final normBase = normalizeOrigin(baseUrl);
    final normUser = username != null && username.trim().isNotEmpty
        ? normalizeUsername(username)
        : null;

    // 正在登录中且切换到不同服务器或不同账号时，记录上一个账号供双击切回。
    await _recordPreviousIfChanging(
      targetOrigin: normBase,
      targetUsername: normUser ?? '',
    );

    _baseUrl = normBase;
    _token = token;
    if (username != null && username.trim().isNotEmpty) {
      _username = username.trim();
      _accountUsername = normUser;
    }
    if (deviceName != null && deviceName.isNotEmpty) {
      _deviceName = deviceName;
    }
    if (permissions != null) {
      _permissions = permissions;
    }
    _expiredUsername = null;
    _phase = SessionPhase.ready;
    _sessionGeneration++;

    await _storage.write(key: 'mc_active_base', value: normBase);
    await _storage.write(key: 'mc_token:$normBase', value: token);
    if (_accountUsername != null && _accountUsername!.isNotEmpty) {
      final acct = _accountUsername!;
      _accountTokens[_memoryTokenKey(normBase, acct)] = token;
      await _storage.write(key: _accountKey(normBase, acct), value: token);
      await _storage.write(key: 'mc_username', value: _username ?? acct);
      await _storage.write(key: 'mc_account_username', value: acct);
      await upsertSavedAccount(
        origin: normBase,
        username: acct,
        nickname: _username,
        role: permissions?.role,
      );
      if (permissions != null) {
        await _savePermissionsCache(normBase, acct, permissions);
      }
    }
    if (_deviceName != null && _deviceName!.isNotEmpty) {
      await _storage.write(key: 'mc_device_name', value: _deviceName!);
    }

    unawaited(ServerRoutes.instance.activate(normBase, token: token));
    notifyListeners();
  }

  /// 更新个人资料（昵称、头像、角色、权限），并同步到 `mc_servers` 与 `mc_session_cache`。
  Future<void> saveProfile({
    String? accountUsername,
    String? username,
    String? deviceName,
    String? avatarUrl,
    String? role,
    McPermissions? permissions,
  }) async {
    if (username != null && username.isNotEmpty) {
      _username = username;
      await _storage.write(key: 'mc_username', value: username);
    }
    if (accountUsername != null && accountUsername.trim().isNotEmpty) {
      _accountUsername = normalizeUsername(accountUsername);
      await _storage.write(
        key: 'mc_account_username',
        value: _accountUsername!,
      );
    }
    if (avatarUrl != null) {
      _avatarUrl = avatarUrl;
      await _storage.write(key: 'mc_avatar_url', value: avatarUrl);
      final origin = _baseUrl;
      final keyUser = accountUsername ?? _accountUsername ?? _username;
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
    if (permissions != null) {
      _permissions = permissions;
    }

    final origin = _baseUrl;
    final acct = accountUsername ?? _accountUsername ?? _username;
    if (origin != null && acct != null && acct.isNotEmpty) {
      final normOrigin = normalizeOrigin(origin);
      final normAcct = normalizeUsername(acct);
      if (_token != null && _token!.isNotEmpty) {
        _accountTokens[_memoryTokenKey(normOrigin, normAcct)] = _token!;
        await _storage.write(
          key: _accountKey(normOrigin, normAcct),
          value: _token!,
        );
      }
      await upsertSavedAccount(
        origin: normOrigin,
        username: normAcct,
        nickname: username ?? permissions?.nickname,
        role: role ?? permissions?.role,
        avatarUrl: avatarUrl ??
            (permissions != null && permissions.avatarUrl.isNotEmpty
                ? permissions.avatarUrl
                : null),
      );
      if (permissions != null) {
        await _savePermissionsCache(normOrigin, normAcct, permissions);
      }
    }
    notifyListeners();
  }

  /// 用 `/api/v1/auth/me` 返回的 JSON 刷新当前账号权限、昵称与头像快照。
  Future<McPermissions> updateFromMeJson(Map<String, dynamic> meJson) async {
    final parsed = McPermissions.fromJson(meJson);
    await saveProfile(
      accountUsername: parsed.username.isNotEmpty ? parsed.username : null,
      username: parsed.displayName.isNotEmpty ? parsed.displayName : null,
      avatarUrl: parsed.avatarUrl,
      role: parsed.role,
      permissions: parsed,
    );
    return parsed;
  }

  /// 更新权限快照并通知所有监听 `permissionsProvider` 的组件。
  Future<void> updatePermissions(McPermissions permissions) async {
    _permissions = permissions;
    final origin = _baseUrl;
    final acct = permissions.username.isNotEmpty
        ? permissions.username
        : accountUsername;
    if (origin != null && origin.isNotEmpty && acct.isNotEmpty) {
      await _savePermissionsCache(
        normalizeOrigin(origin),
        normalizeUsername(acct),
        permissions,
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
    String? avatarUrl,
  }) async {
    final normOrigin = normalizeOrigin(origin);
    final normUser = normalizeUsername(username);
    if (normOrigin.isEmpty || normUser.isEmpty) return;
    try {
      final servers = await _readServersList();
      var sIdx = servers.indexWhere(
        (s) => normalizeOrigin((s['origin'] ?? '').toString()) == normOrigin,
      );
      if (sIdx < 0) {
        servers.add(<String, dynamic>{
          'origin': normOrigin,
          'accounts': <Map<String, dynamic>>[],
        });
        sIdx = servers.length - 1;
      }
      final accounts = <Map<String, dynamic>>[
        for (final a in (servers[sIdx]['accounts'] as List? ?? const <dynamic>[]))
          if (a is Map) Map<String, dynamic>.from(a),
      ];
      final aIdx = accounts.indexWhere(
        (a) => normalizeUsername((a['username'] ?? '').toString()) == normUser,
      );
      final prev = aIdx >= 0 ? accounts[aIdx] : const <String, dynamic>{};
      final nextAcct = <String, dynamic>{
        'username': normUser,
        if ((nickname ?? prev['nickname']) != null)
          'nickname': nickname ?? prev['nickname'],
        if ((avatarUrl ?? prev['avatar_url']) != null)
          'avatar_url': avatarUrl ?? prev['avatar_url'],
        'role': role ?? prev['role'] ?? 'member',
        'expired': false,
      };
      if (aIdx >= 0) {
        accounts[aIdx] = nextAcct;
      } else {
        accounts.add(nextAcct);
      }
      servers[sIdx]['origin'] = normOrigin;
      servers[sIdx]['accounts'] = accounts;
      await _writeServersList(servers);
    } catch (_) {}
  }

  Future<void> snapshotAccountToken({
    required String origin,
    required String username,
  }) async {
    final tok = _token;
    final normOrigin = normalizeOrigin(origin);
    final normUser = normalizeUsername(username);
    if (tok == null || normOrigin.isEmpty || normUser.isEmpty) return;
    _accountTokens[_memoryTokenKey(normOrigin, normUser)] = tok;
    await _storage.write(key: _accountKey(normOrigin, normUser), value: tok);
  }

  /// 秒切到另一台服务器或同服务器上的已登录账号：
  /// - 持久化上一个账号（`mc_previous_account`）供双击头像切回；
  /// - 激活目标服务器对应的 `ServerRoutes` 地址簿；
  /// - 递增 `sessionGeneration` 驱动上层清理跨账号缓存。
  Future<bool> switchAccount({
    required String origin,
    required String username,
  }) async {
    final normOrigin = normalizeOrigin(origin);
    final normUser = normalizeUsername(username);
    if (normOrigin.isEmpty || normUser.isEmpty) return false;

    var tok = await _readStoredAccountToken(normOrigin, username);
    if (tok == null || tok.isEmpty) {
      tok = await _storage.read(key: 'mc_token:$normOrigin');
      if (tok != null && tok.isNotEmpty) {
        await _storage.write(key: _accountKey(normOrigin, normUser), value: tok);
      }
    }
    if (tok == null || tok.isEmpty) return false;

    await _recordPreviousIfChanging(
      targetOrigin: normOrigin,
      targetUsername: normUser,
    );

    _baseUrl = normOrigin;
    _token = tok;
    _accountUsername = normUser;
    _accountTokens[_memoryTokenKey(normOrigin, normUser)] = tok;

    // 恢复目标账号的缓存权限、昵称与头像
    final cachedPerms =
        _permissionsCache[_memoryTokenKey(normOrigin, normUser)];
    _permissions = cachedPerms ?? McPermissions.none;
    _username = (cachedPerms != null && cachedPerms.displayName.isNotEmpty)
        ? cachedPerms.displayName
        : username.trim();
    _avatarUrl = await _readStoredAvatar(normOrigin, username) ??
        (cachedPerms != null && cachedPerms.avatarUrl.isNotEmpty
            ? cachedPerms.avatarUrl
            : null);

    _expiredUsername = null;
    _phase = SessionPhase.ready;
    _sessionGeneration++;

    await _storage.write(key: 'mc_active_base', value: normOrigin);
    await _storage.write(key: 'mc_token:$normOrigin', value: tok);
    await _storage.write(key: 'mc_username', value: _username!);
    await _storage.write(key: 'mc_account_username', value: normUser);
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      await _storage.write(key: 'mc_avatar_url', value: _avatarUrl!);
    } else {
      await _storage.delete(key: 'mc_avatar_url');
    }

    // 激活目标服务器的路由地址簿，避免沿用上一台服务器的路由。
    unawaited(ServerRoutes.instance.activate(normOrigin, token: tok));
    notifyListeners();
    return true;
  }

  /// 处理全局 401 会话过期事件（对齐 iOS `AppModel.sessionExpired`）：
  /// - 仅认当前活跃服务器与当前令牌的 401（忽略旧令牌在途请求与切换账号探测）；
  /// - 删除失效令牌、保留 `expiredUsername` 与 `resumeLocation`、回到登录态。
  Future<void> handleUnauthorized({
    required String origin,
    String? rejectedToken,
    String? currentLocation,
  }) async {
    final activeBase = _baseUrl;
    if (!isReady || activeBase == null) return;
    final normOrigin = normalizeOrigin(origin);
    final sameServer = normOrigin.isEmpty ||
        normOrigin == normalizeOrigin(activeBase) ||
        ServerRoutes.instance.belongsToServer(normOrigin, activeBase);
    if (!sameServer) return;
    if (rejectedToken != null &&
        rejectedToken.isNotEmpty &&
        rejectedToken != _token) {
      return;
    }

    final acct = accountUsername;
    if (acct.isNotEmpty) {
      await deleteAccountToken(origin: activeBase, username: acct);
      await _markAccountExpired(activeBase, acct);
      _expiredUsername = acct;
    }
    if (currentLocation != null && currentLocation.isNotEmpty) {
      _resumeLocation = currentLocation;
    }
    _token = null;
    _permissions = McPermissions.none;
    _phase = SessionPhase.needsLogin;
    _sessionGeneration++;
    await _storage.delete(key: 'mc_token:$activeBase');
    notifyListeners();
  }

  void setPhase(SessionPhase nextPhase) {
    if (_phase == nextPhase) return;
    _phase = nextPhase;
    notifyListeners();
  }

  void setResumeLocation(String? location) {
    _resumeLocation = location;
  }

  String? takeResumeLocation() {
    final v = _resumeLocation;
    _resumeLocation = null;
    return v;
  }

  void setPendingNotice(String? notice) {
    _pendingNotice = notice;
  }

  String? takePendingNotice() {
    final v = _pendingNotice;
    _pendingNotice = null;
    return v;
  }

  Future<void> deleteAccountToken({
    required String origin,
    required String username,
  }) async {
    final normOrigin = normalizeOrigin(origin);
    final normUser = normalizeUsername(username);
    _accountTokens.remove(_memoryTokenKey(normOrigin, normUser));
    _permissionsCache.remove(_memoryTokenKey(normOrigin, normUser));
    await _storage.delete(key: _accountKey(normOrigin, normUser));
    if (normUser != username) {
      await _storage.delete(key: _legacyAccountKey(origin, username));
    }
    await _storage.delete(key: _avatarKey(normOrigin, normUser));
    if (normUser != username) {
      await _storage.delete(key: _legacyAvatarKey(origin, username));
    }
    await _persistSessionCache();
  }

  /// 退出当前账号：
  /// - 触发 `PendingRevocations.enqueueAndRevoke` 在服务端注销设备令牌；
  /// - 删除该账号本机令牌、头像缓存、会话缓存与页面快照；
  /// - 若 `autoSwitchSibling == true` 且同服务器还有其他已存令牌的兄弟账号，自动切换过去并返回该账号引用；
  /// - 否则依据其他服务器是否仍有账号转入 `chooseAccount` 或 `needsLogin`。
  Future<SavedAccountRef?> logoutCurrentAccount({
    bool autoSwitchSibling = true,
  }) async {
    final base = _baseUrl != null ? normalizeOrigin(_baseUrl!) : null;
    final tok = _token;
    final acct = accountUsername;

    if (base != null && base.isNotEmpty) {
      if (tok != null && tok.isNotEmpty) {
        unawaited(_pendingRevocations.enqueueAndRevoke(base, tok));
      }
      if (acct.isNotEmpty) {
        await deleteAccountToken(origin: base, username: acct);
        unawaited(PageSnapshots.clearForAccount(origin: base, username: acct));
        await _removeAccountFromServersList(base, acct);
      }
      await _storage.delete(key: 'mc_token:$base');
    }

    if (autoSwitchSibling && base != null && base.isNotEmpty) {
      final sibling = await _findSiblingAccountWithToken(base, excludeUser: acct);
      if (sibling != null) {
        final ok = await switchAccount(
          origin: base,
          username: sibling.username,
        );
        if (ok) return sibling;
      }
    }

    _token = null;
    _username = null;
    _accountUsername = null;
    _deviceName = null;
    _avatarUrl = null;
    _baseUrl = null;
    _expiredUsername = null;
    _permissions = McPermissions.none;
    _sessionGeneration++;

    await _storage.delete(key: 'mc_username');
    await _storage.delete(key: 'mc_account_username');
    await _storage.delete(key: 'mc_device_name');
    await _storage.delete(key: 'mc_avatar_url');
    await _storage.delete(key: 'mc_active_base');

    final remainingServers = await _readServersList();
    _phase = _hasAnySavedToken(remainingServers)
        ? SessionPhase.chooseAccount
        : SessionPhase.needsLogin;
    notifyListeners();
    return null;
  }

  /// 从本机移除指定账号：若是当前账号走 `logoutCurrentAccount`，否则注销其服务端令牌并删掉本机记录。
  Future<SavedAccountRef?> removeAccount({
    required String origin,
    required String username,
  }) async {
    final normOrigin = normalizeOrigin(origin);
    final normUser = normalizeUsername(username);
    final isCurrent = _baseUrl != null &&
        normalizeOrigin(_baseUrl!) == normOrigin &&
        normalizeUsername(accountUsername) == normUser;
    if (isCurrent) {
      return logoutCurrentAccount(autoSwitchSibling: true);
    }

    final tok = await _readStoredAccountToken(normOrigin, username);
    if (tok != null && tok.isNotEmpty) {
      unawaited(_pendingRevocations.enqueueAndRevoke(normOrigin, tok));
    }
    await deleteAccountToken(origin: normOrigin, username: username);
    unawaited(
      PageSnapshots.clearForAccount(origin: normOrigin, username: normUser),
    );
    await _removeAccountFromServersList(normOrigin, normUser);

    if (_previousAccount != null &&
        _previousAccount ==
            SavedAccountRef(origin: normOrigin, username: normUser)) {
      _previousAccount = null;
      await _storage.delete(key: _previousAccountKey);
    }
    notifyListeners();
    return null;
  }

  /// 退出本机所有服务器上的全部账号（共用设备归还前使用）。
  Future<void> logoutAll() async {
    final servers = await _readServersList();
    for (final server in servers) {
      final origin = normalizeOrigin((server['origin'] ?? '').toString());
      if (origin.isEmpty) continue;
      final accounts = server['accounts'] as List? ?? const <dynamic>[];
      for (final item in accounts) {
        if (item is! Map) continue;
        final acct = (item['username'] ?? '').toString().trim();
        if (acct.isEmpty) continue;
        final tok = await _readStoredAccountToken(origin, acct);
        if (tok != null && tok.isNotEmpty) {
          unawaited(_pendingRevocations.enqueueAndRevoke(origin, tok));
        }
        await deleteAccountToken(origin: origin, username: acct);
      }
      await _storage.delete(key: 'mc_token:$origin');
    }
    if (_baseUrl != null && _token != null && _token!.isNotEmpty) {
      unawaited(_pendingRevocations.enqueueAndRevoke(_baseUrl!, _token!));
      await _storage.delete(key: 'mc_token:${normalizeOrigin(_baseUrl!)}');
    }

    _accountTokens.clear();
    _permissionsCache.clear();
    _token = null;
    _username = null;
    _accountUsername = null;
    _deviceName = null;
    _avatarUrl = null;
    _baseUrl = null;
    _previousAccount = null;
    _expiredUsername = null;
    _resumeLocation = null;
    _permissions = McPermissions.none;
    _phase = SessionPhase.needsLogin;
    _sessionGeneration++;

    await _storage.delete(key: 'mc_username');
    await _storage.delete(key: 'mc_account_username');
    await _storage.delete(key: 'mc_device_name');
    await _storage.delete(key: 'mc_avatar_url');
    await _storage.delete(key: 'mc_active_base');
    await _storage.delete(key: _previousAccountKey);
    await _storage.delete(key: _sessionCacheKey);
    await _writeServersList(const <Map<String, dynamic>>[]);
    unawaited(PageSnapshots.clearAll());
    unawaited(ServerRoutes.instance.reset());
    notifyListeners();
  }

  /// 兼容旧 `logout()` 方法：吊销当前令牌、清理当前活跃会话与每账号令牌快照。
  Future<void> logout() async {
    await logoutCurrentAccount(autoSwitchSibling: false);
  }

  // ── 内部持久化工具 ────────────────────────────────────────────────────────

  Future<void> _recordPreviousIfChanging({
    required String targetOrigin,
    required String targetUsername,
  }) async {
    final curBase = _baseUrl != null ? normalizeOrigin(_baseUrl!) : '';
    final curUser = normalizeUsername(accountUsername);
    if (!isReady || curBase.isEmpty || curUser.isEmpty) return;
    if (curBase == targetOrigin &&
        curUser == normalizeUsername(targetUsername)) {
      return;
    }
    final prev = SavedAccountRef(origin: curBase, username: curUser);
    _previousAccount = prev;
    try {
      await _storage.write(
        key: _previousAccountKey,
        value: jsonEncode(prev.toJson()),
      );
    } catch (_) {}
  }

  Future<void> _loadPreviousAccount() async {
    try {
      final raw = await _storage.read(key: _previousAccountKey);
      if (raw == null || raw.isEmpty) {
        _previousAccount = null;
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final ref = SavedAccountRef.fromJson(decoded.cast<String, dynamic>());
        if (ref.origin.isNotEmpty && ref.username.isNotEmpty) {
          _previousAccount = ref;
          return;
        }
      }
      _previousAccount = null;
    } catch (_) {
      _previousAccount = null;
    }
  }

  Future<void> _loadSessionCache() async {
    try {
      final raw = await _storage.read(key: _sessionCacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _permissionsCache.clear();
        decoded.forEach((k, v) {
          if (v is Map) {
            _permissionsCache[k.toString()] =
                McPermissions.fromJson(v.cast<String, dynamic>());
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _savePermissionsCache(
    String origin,
    String username,
    McPermissions perms,
  ) async {
    _permissionsCache[_memoryTokenKey(origin, username)] = perms;
    await _persistSessionCache();
  }

  Future<void> _persistSessionCache() async {
    try {
      if (_permissionsCache.isEmpty) {
        await _storage.delete(key: _sessionCacheKey);
        return;
      }
      final encoded = jsonEncode(
        _permissionsCache
            .map((k, v) => MapEntry<String, dynamic>(k, v.toJson())),
      );
      await _storage.write(key: _sessionCacheKey, value: encoded);
    } catch (_) {}
  }

  Future<String?> _readStoredAccountToken(String origin, String username) async {
    final normOrigin = normalizeOrigin(origin);
    final normUser = normalizeUsername(username);
    var tok = await _storage.read(key: _accountKey(normOrigin, normUser));
    if ((tok == null || tok.isEmpty) && username != normUser) {
      tok = await _storage.read(key: _legacyAccountKey(origin, username));
      if (tok != null && tok.isNotEmpty) {
        await _storage.write(key: _accountKey(normOrigin, normUser), value: tok);
      }
    }
    return tok;
  }

  Future<String?> _readStoredAvatar(String origin, String username) async {
    final normOrigin = normalizeOrigin(origin);
    final normUser = normalizeUsername(username);
    var av = await _storage.read(key: _avatarKey(normOrigin, normUser));
    if ((av == null || av.isEmpty) && username != normUser) {
      av = await _storage.read(key: _legacyAvatarKey(origin, username));
    }
    return av;
  }

  Future<List<Map<String, dynamic>>> _readServersList() async {
    try {
      final raw = await _storage.read(key: _serversKey);
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return <Map<String, dynamic>>[
        for (final item in decoded)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writeServersList(List<Map<String, dynamic>> servers) async {
    try {
      await _storage.write(key: _serversKey, value: jsonEncode(servers));
    } catch (_) {}
  }

  Future<void> _removeAccountFromServersList(
    String origin,
    String username,
  ) async {
    final normOrigin = normalizeOrigin(origin);
    final normUser = normalizeUsername(username);
    final servers = await _readServersList();
    var changed = false;
    final nextServers = <Map<String, dynamic>>[];
    for (final s in servers) {
      final sOrigin = normalizeOrigin((s['origin'] ?? '').toString());
      if (sOrigin != normOrigin) {
        nextServers.add(s);
        continue;
      }
      final accounts = <Map<String, dynamic>>[
        for (final a in (s['accounts'] as List? ?? const <dynamic>[]))
          if (a is Map &&
              normalizeUsername((a['username'] ?? '').toString()) != normUser)
            Map<String, dynamic>.from(a),
      ];
      changed = true;
      if (accounts.isNotEmpty) {
        s['accounts'] = accounts;
        nextServers.add(s);
      }
    }
    if (changed) {
      await _writeServersList(nextServers);
    }
  }

  Future<void> _markAccountExpired(String origin, String username) async {
    final normOrigin = normalizeOrigin(origin);
    final normUser = normalizeUsername(username);
    final servers = await _readServersList();
    var changed = false;
    for (final s in servers) {
      if (normalizeOrigin((s['origin'] ?? '').toString()) != normOrigin) {
        continue;
      }
      final accounts = (s['accounts'] as List? ?? const <dynamic>[]);
      for (final a in accounts) {
        if (a is Map &&
            normalizeUsername((a['username'] ?? '').toString()) == normUser) {
          a['expired'] = true;
          changed = true;
        }
      }
    }
    if (changed) {
      await _writeServersList(servers);
    }
  }

  Future<SavedAccountRef?> _findSiblingAccountWithToken(
    String origin, {
    required String excludeUser,
  }) async {
    final normOrigin = normalizeOrigin(origin);
    final normExclude = normalizeUsername(excludeUser);
    final servers = await _readServersList();
    for (final s in servers) {
      if (normalizeOrigin((s['origin'] ?? '').toString()) != normOrigin) {
        continue;
      }
      final accounts = s['accounts'] as List? ?? const <dynamic>[];
      for (final a in accounts) {
        if (a is! Map) continue;
        final u = normalizeUsername((a['username'] ?? '').toString());
        if (u.isEmpty || u == normExclude) continue;
        final tok = await _readStoredAccountToken(normOrigin, u);
        if (tok != null && tok.isNotEmpty) {
          return SavedAccountRef(origin: normOrigin, username: u);
        }
      }
    }
    return null;
  }

  bool _hasAnySavedToken(List<Map<String, dynamic>> servers) {
    for (final s in servers) {
      final origin = normalizeOrigin((s['origin'] ?? '').toString());
      final accounts = s['accounts'] as List? ?? const <dynamic>[];
      for (final a in accounts) {
        if (a is! Map) continue;
        final u = normalizeUsername((a['username'] ?? '').toString());
        if (u.isNotEmpty && hasTokenFor(origin: origin, username: u)) {
          return true;
        }
      }
    }
    return false;
  }
}

final SessionStore appSession = SessionStore();
