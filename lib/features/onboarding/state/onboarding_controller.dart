import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/server_addresses_api.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/session/session_store.dart';

/// 登录与初始化状态（支持常规账密登录、未初始化服务器超管创建向导、以及 TV/桌面免密配对码登录）。
class OnboardingState {
  const OnboardingState({
    this.busy = false,
    this.error,
    this.done = false,
    this.needsInit = false,
    this.pairingUserCode,
    this.pairingVerifyUrl,
    this.pairingExpiresIn = 0,
  });

  final bool busy;
  final String? error;
  final bool done;
  final bool needsInit;
  final String? pairingUserCode;
  final String? pairingVerifyUrl;
  final int pairingExpiresIn;

  OnboardingState copyWith({
    bool? busy,
    Object? error = _sentinel,
    bool? done,
    bool? needsInit,
    Object? pairingUserCode = _sentinel,
    Object? pairingVerifyUrl = _sentinel,
    int? pairingExpiresIn,
  }) =>
      OnboardingState(
        busy: busy ?? this.busy,
        error: identical(error, _sentinel) ? this.error : error as String?,
        done: done ?? this.done,
        needsInit: needsInit ?? this.needsInit,
        pairingUserCode: identical(pairingUserCode, _sentinel)
            ? this.pairingUserCode
            : pairingUserCode as String?,
        pairingVerifyUrl: identical(pairingVerifyUrl, _sentinel)
            ? this.pairingVerifyUrl
            : pairingVerifyUrl as String?,
        pairingExpiresIn: pairingExpiresIn ?? this.pairingExpiresIn,
      );

  static const _sentinel = Object();
}

class OnboardingController extends Notifier<OnboardingState> {
  McClient? _client;
  Timer? _pairTimer;

  @override
  OnboardingState build() {
    ref.onDispose(() => _pairTimer?.cancel());
    return const OnboardingState();
  }

  static (String kind, String defaultName, String platformLabel)
      _platformMeta() {
    if (kIsWeb) return ('ios', 'MovieClaw Web', 'Web · Flutter');
    if (Platform.isIOS) return ('ios', 'iPhone / iPad', 'iOS · Flutter');
    if (Platform.isMacOS) return ('macos', 'Mac', 'macOS · Flutter');
    if (Platform.isWindows) return ('windows', 'Windows PC', 'Windows · Flutter');
    if (Platform.isLinux) return ('macos', 'Linux Desktop', 'Linux · Flutter');
    return ('android', 'Android Device', 'Android · Flutter');
  }

  Future<bool> probeHealth(String base) async {
    final res = await _client!
        .get(Channel.general, '/api/v1/health')
        .timeout(const Duration(seconds: 8));
    return res.statusCode == 200;
  }

  Future<bool> checkBootstrap() async {
    final body = await _client!.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/auth/bootstrap',
    );
    return body['initialized'] == true;
  }

  String _normalizeBase(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = ServerRoutes.isPrivateHost(s) ? 'http://$s' : 'https://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// 首次运行服务器初始化（原生直接调用 `POST /api/v1/auth/bootstrap`，无需跳浏览器）。
  Future<void> bootstrapAndLogin(
    String base,
    String username,
    String password, {
    String? nickname,
  }) async {
    if (state.busy) return;
    state = state.copyWith(busy: true, error: null, done: false);
    try {
      final session = ref.read(sessionStoreProvider);
      final host = _normalizeBase(base);
      _client = McClient(session: session, baseUrlOverride: host);
      await _client!.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/auth/bootstrap',
        body: {
          'username': username,
          'password': password,
          if (nickname != null && nickname.trim().isNotEmpty)
            'nickname': nickname.trim(),
        },
      );
      state = state.copyWith(busy: false, needsInit: false);
      await login(host, username, password);
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(busy: false, error: '初始化服务器失败，请检查账号与密码长度');
    }
  }

  Future<void> login(String base, String username, String password) async {
    if (state.busy) return;
    if (base.trim().isEmpty) {
      state = state.copyWith(error: '请输入服务器地址');
      return;
    }
    state = state.copyWith(busy: true, error: null, done: false);
    try {
      final session = ref.read(sessionStoreProvider);
      final host = _normalizeBase(base);
      _client = McClient(session: session, baseUrlOverride: host);
      final ok = await probeHealth(host);
      if (!ok) {
        state = state.copyWith(busy: false, error: '服务器不可达，请检查地址与端口');
        return;
      }
      final initialized = await checkBootstrap();
      if (!initialized) {
        state = state.copyWith(busy: false, needsInit: true);
        return;
      }
      if (username.isEmpty || password.isEmpty) {
        state = state.copyWith(busy: false, error: '请输入账号与密码');
        return;
      }
      final (kind, defaultName, platformLabel) = _platformMeta();
      final body = await _client!.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/auth/device/login',
        body: {
          'username': username,
          'password': password,
          'client': {
            'kind': kind,
            'installation_id': await session.installationId(),
            'name': session.deviceName.isNotEmpty
                ? session.deviceName
                : defaultName,
            'platform': platformLabel,
            'client_version': '1.0.0',
          },
        },
      );
      await _completeWithToken(
        session: session,
        host: host,
        token: body['token']?.toString() ?? '',
        fallbackUsername: username,
        deviceName:
            ((body['device'] as Map<String, dynamic>?)?['name'] ?? '')
                .toString(),
      );
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(busy: false, error: '网络错误，请检查地址后重试');
    }
  }

  /// 免密配对码登录（供桌面 / iPad / TV 使用已登录手机一键扫码或输入 8 位码批准）。
  Future<void> startDevicePairing(String base) async {
    _pairTimer?.cancel();
    if (base.trim().isEmpty) {
      state = state.copyWith(error: '请先输入服务器地址');
      return;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      final session = ref.read(sessionStoreProvider);
      final host = _normalizeBase(base);
      _client = McClient(session: session, baseUrlOverride: host);
      if (!await probeHealth(host)) {
        state = state.copyWith(busy: false, error: '服务器不可达');
        return;
      }
      final (kind, defaultName, platformLabel) = _platformMeta();
      final body = await _client!.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/auth/device/authorize',
        body: {
          'client_type': kind,
          'client_name': defaultName,
          'platform': platformLabel,
          'client_version': '1.0.0',
        },
      );
      final userCode = (body['user_code'] ?? '').toString();
      final deviceCode = (body['device_code'] ?? '').toString();
      final verifyUrl = (body['verification_uri_complete'] ??
              body['verification_uri'] ??
              '$host/activate?code=$userCode')
          .toString();
      final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 300;
      final intervalSec =
          ((body['interval'] as num?)?.toInt() ?? 2).clamp(2, 10);

      state = state.copyWith(
        busy: false,
        pairingUserCode: userCode,
        pairingVerifyUrl: verifyUrl,
        pairingExpiresIn: expiresIn,
      );

      _pairTimer = Timer.periodic(Duration(seconds: intervalSec), (t) async {
        try {
          final poll = await _client!.post(
            Channel.live,
            '/api/v1/auth/device/token',
            body: {'device_code': deviceCode},
          );
          final data = poll.data?['data'];
          if (data is Map && (data['token']?.toString().isNotEmpty ?? false)) {
            t.cancel();
            await _completeWithToken(
              session: session,
              host: host,
              token: data['token'].toString(),
              fallbackUsername: data['granted_by']?.toString() ?? '',
              deviceName: data['client_name']?.toString() ?? defaultName,
            );
          }
        } catch (_) {}
      });
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(busy: false, error: '发起配对请求失败');
    }
  }

  void cancelDevicePairing() {
    _pairTimer?.cancel();
    state = state.copyWith(
      pairingUserCode: null,
      pairingVerifyUrl: null,
      pairingExpiresIn: 0,
    );
  }

  Future<void> _completeWithToken({
    required SessionStore session,
    required String host,
    required String token,
    required String fallbackUsername,
    required String deviceName,
  }) async {
    if (token.isEmpty) {
      state = state.copyWith(busy: false, error: '登录响应缺少令牌');
      return;
    }
    await session.login(
      baseUrl: host,
      token: token,
      username: fallbackUsername,
      deviceName: deviceName,
    );
    final authedClient = McClient(session: session, baseUrlOverride: host);
    unawaited(
      ServerRoutes.instance.configure(
        host,
        () => fetchServerAddresses(authedClient),
      ),
    );
    try {
      final me = await authedClient.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/auth/me',
      );
      final acctUser = (me['username'] ?? fallbackUsername).toString();
      final display = (me['nickname']?.toString().isNotEmpty == true)
          ? me['nickname'].toString()
          : acctUser;
      final isAdmin = me['is_admin'] == true || me['role'] == 'admin';
      await session.saveProfile(
        accountUsername: acctUser,
        username: display,
        avatarUrl: me['avatar_url']?.toString(),
        role: isAdmin ? 'admin' : 'member',
      );
    } catch (_) {}
    state = state.copyWith(
      busy: false,
      done: true,
      pairingUserCode: null,
      pairingVerifyUrl: null,
    );
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
