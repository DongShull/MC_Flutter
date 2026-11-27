import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/server_addresses_api.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/push/push_center.dart';
import '../../../core/session/session_store.dart';
import 'server_discovery.dart';

/// 登录与初始化状态（支持常规账密登录、未初始化服务器超管创建向导、以及 TV/桌面免密配对码登录）。
class OnboardingState {
  const OnboardingState({
    this.busy = false,
    this.error,
    this.done = false,
    this.needsInit = false,
    this.resolvedHost,
    this.pairingUserCode,
    this.pairingVerifyUrl,
    this.pairingExpiresIn = 0,
  });

  final bool busy;
  final String? error;
  final bool done;
  final bool needsInit;
  final String? resolvedHost;
  final String? pairingUserCode;
  final String? pairingVerifyUrl;
  final int pairingExpiresIn;

  OnboardingState copyWith({
    bool? busy,
    Object? error = _sentinel,
    bool? done,
    bool? needsInit,
    Object? resolvedHost = _sentinel,
    Object? pairingUserCode = _sentinel,
    Object? pairingVerifyUrl = _sentinel,
    int? pairingExpiresIn,
  }) =>
      OnboardingState(
        busy: busy ?? this.busy,
        error: identical(error, _sentinel) ? this.error : error as String?,
        done: done ?? this.done,
        needsInit: needsInit ?? this.needsInit,
        resolvedHost: identical(resolvedHost, _sentinel)
            ? this.resolvedHost
            : resolvedHost as String?,
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

class _ServerProbeResult {
  const _ServerProbeResult({required this.origin, this.version});

  final String origin;
  final String? version;
}

class OnboardingController extends Notifier<OnboardingState> {
  static const String minimumServerVersion = '0.28.0';

  McClient? _client;
  Timer? _pairTimer;

  @override
  OnboardingState build() {
    ref.onDispose(() => _pairTimer?.cancel());
    return const OnboardingState();
  }

  /// 逐段数字比较服务器版本是否低于最低要求（对齐 iOS `AppModel.isServerTooOld`）。
  static bool isServerTooOld(
    String version, {
    String minimum = minimumServerVersion,
  }) {
    final clean = version.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final core = clean.split(RegExp(r'[-+]')).first;
    final currentParts = core.split('.').map(int.tryParse).toList();
    final minParts = minimum.split('.').map(int.tryParse).toList();
    if (currentParts.any((e) => e == null) || minParts.any((e) => e == null)) {
      return false;
    }
    final len = currentParts.length > minParts.length
        ? currentParts.length
        : minParts.length;
    for (var i = 0; i < len; i++) {
      final a = i < currentParts.length ? currentParts[i]! : 0;
      final b = i < minParts.length ? minParts[i]! : 0;
      if (a != b) return a < b;
    }
    return false;
  }

  static (String kind, String defaultName, String platformLabel)
      _platformMeta() {
    if (Platform.isIOS) return ('ios', 'iPhone / iPad', 'iOS · Flutter');
    if (Platform.isMacOS) return ('macos', 'Mac', 'macOS · Flutter');
    if (Platform.isWindows) return ('windows', 'Windows PC', 'Windows · Flutter');
    if (Platform.isLinux) return ('macos', 'Linux Desktop', 'Linux · Flutter');
    return ('android', 'Android Device', 'Android · Flutter');
  }

  void resetNeedsInit() {
    if (state.needsInit || state.error != null) {
      state = state.copyWith(needsInit: false, error: null);
    }
  }

  void resetDone() {
    if (state.done) {
      state = state.copyWith(done: false);
    }
  }

  Future<_ServerProbeResult> _probeHealthAndVersion(
    SessionStore session,
    String rawBase,
  ) async {
    final settled = await ServerDiscovery.settleManualHost(rawBase);
    if (settled.isEmpty) {
      throw const ApiException('onboarding.empty_host', '请输入服务器地址');
    }
    final uri = Uri.tryParse(settled);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ApiException('onboarding.invalid_host', '服务器地址格式不正确');
    }

    _client = McClient(session: session, baseUrlOverride: settled);
    final dynamic payload;
    try {
      payload = await _client!
          .raw<dynamic>(Channel.general, 'GET', '/api/v1/health')
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      final label = ServerRoutes.hostLabelOf(settled);
      throw ApiException(
        'network.timeout',
        '连接服务器 $label 超时，请检查网络状态或确认地址与端口',
        isNetworkError: true,
        isTimeout: true,
      );
    } on ApiException catch (e) {
      if (e.code == 'network.decoding' || e.httpStatus == 404) {
        throw const ApiException(
          'onboarding.not_movieclaw',
          '该地址不是有效的 MovieClaw 服务器，请检查地址与端口',
        );
      }
      rethrow;
    }

    if (payload is! Map) {
      throw const ApiException(
        'onboarding.not_movieclaw',
        '该地址不是有效的 MovieClaw 服务器（返回内容异常）',
      );
    }
    final status = payload['status']?.toString() ?? '';
    if (status != 'ok') {
      throw ApiException(
        'onboarding.unhealthy',
        status.isEmpty
            ? '该地址不是有效的 MovieClaw 服务器'
            : '服务器当前状态异常（$status），请稍后重试',
      );
    }

    final version = payload['version']?.toString().trim();
    if (version != null && version.isNotEmpty && isServerTooOld(version)) {
      throw ApiException(
        'onboarding.server_too_old',
        '服务器版本过旧（当前 v$version，最低要求 v$minimumServerVersion），请先升级服务器',
      );
    }

    return _ServerProbeResult(origin: settled, version: version);
  }

  Future<bool> checkBootstrap() async {
    final body = await _client!.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/auth/bootstrap',
    );
    return body['initialized'] == true;
  }

  /// 首次运行服务器初始化（原生直接调用 `POST /api/v1/auth/bootstrap`，含参数校验与 409 回退）。
  Future<void> bootstrapAndLogin(
    String base,
    String username,
    String password, {
    String? confirmPassword,
    String? nickname,
  }) async {
    if (state.busy) return;
    final cleanUser = username.trim();
    if (base.trim().isEmpty) {
      state = state.copyWith(error: '请输入服务器地址');
      return;
    }
    if (cleanUser.length < 3) {
      state = state.copyWith(error: '管理员账号至少需要 3 个字符');
      return;
    }
    if (password.length < 8) {
      state = state.copyWith(error: '管理员密码至少需要 8 个字符');
      return;
    }
    if (confirmPassword != null && password != confirmPassword) {
      state = state.copyWith(error: '两次输入的密码不一致');
      return;
    }

    state = state.copyWith(busy: true, error: null, done: false);
    try {
      final session = ref.read(sessionStoreProvider);
      final probe = await _probeHealthAndVersion(session, base);
      final host = probe.origin;
      await _client!.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/auth/bootstrap',
        body: {
          'username': cleanUser,
          'password': password,
          if (nickname != null && nickname.trim().isNotEmpty)
            'nickname': nickname.trim(),
        },
      );
      state = state.copyWith(busy: false, needsInit: false, resolvedHost: host);
      await login(host, cleanUser, password);
    } on ApiException catch (e) {
      if (e.httpStatus == 409) {
        // 409 alreadyInitialized：其他设备已抢先初始化，平滑切回普通登录模式。
        state = state.copyWith(
          busy: false,
          needsInit: false,
          error: '服务器已完成初始化，请直接输入账号和密码登录',
        );
        return;
      }
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
      final probe = await _probeHealthAndVersion(session, base);
      final host = probe.origin;
      state = state.copyWith(resolvedHost: host);

      final initialized = await checkBootstrap();
      if (!initialized) {
        state = state.copyWith(busy: false, needsInit: true, error: null);
        return;
      }

      final cleanUser = username.trim();
      if (cleanUser.isEmpty || password.isEmpty) {
        state = state.copyWith(busy: false, error: '请输入账号与密码');
        return;
      }

      final (kind, defaultName, platformLabel) = _platformMeta();
      final Map<String, dynamic> body;
      try {
        body = await _client!.unwrap<Map<String, dynamic>>(
          Channel.general,
          'POST',
          '/api/v1/auth/device/login',
          body: {
            'username': cleanUser,
            'password': password,
            'client': {
              'kind': kind,
              'installation_id': await session.installationId(),
              'name': session.deviceName.isNotEmpty
                  ? session.deviceName
                  : defaultName,
              'platform': platformLabel,
              'client_version': McClient.appVersion,
            },
          },
        );
      } on ApiException catch (e) {
        if (e.httpStatus == 404 || e.httpStatus == 405) {
          state = state.copyWith(
            busy: false,
            error: '服务器版本过旧（不支持设备令牌登录，最低要求 v$minimumServerVersion），请先升级服务器',
          );
          return;
        }
        rethrow;
      }

      await _completeWithToken(
        session: session,
        host: host,
        token: body['token']?.toString() ?? '',
        fallbackUsername: cleanUser,
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

  /// `SessionPhase.unreachable` 时重试连接当前已保存的服务器与令牌。
  Future<bool> reconnect() async {
    final session = ref.read(sessionStoreProvider);
    final origin = session.baseUrl;
    final tok = session.token;
    if (origin == null || origin.isEmpty || tok == null || tok.isEmpty) {
      session.setPhase(SessionPhase.needsLogin);
      return false;
    }
    try {
      final client = McClient(session: session, baseUrlOverride: origin);
      final me = await client
          .unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/auth/me',
          )
          .timeout(const Duration(seconds: 8));
      await session.updateFromMeJson(me);
      session.setPhase(SessionPhase.ready);
      unawaited(
        ServerRoutes.instance.activate(
          origin,
          token: tok,
          fetchBook: () => fetchServerAddresses(client),
        ),
      );
      unawaited(PushCenter.instance.sync());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 免密配对码登录（供桌面 / iPad / TV 使用已登录手机一键扫码或输入配对码批准）。
  Future<void> startDevicePairing(String base) async {
    _pairTimer?.cancel();
    if (base.trim().isEmpty) {
      state = state.copyWith(error: '请先输入服务器地址');
      return;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      final session = ref.read(sessionStoreProvider);
      final probe = await _probeHealthAndVersion(session, base);
      final host = probe.origin;
      final (kind, defaultName, platformLabel) = _platformMeta();
      final body = await _client!.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/auth/device/authorize',
        body: {
          'client_type': kind,
          'client_name': defaultName,
          'platform': platformLabel,
          'client_version': McClient.appVersion,
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
        resolvedHost: host,
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
      ServerRoutes.instance.activate(
        host,
        token: token,
        fetchBook: () => fetchServerAddresses(authedClient),
      ),
    );
    try {
      final me = await authedClient.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/auth/me',
      );
      await session.updateFromMeJson(me);
    } catch (_) {}
    unawaited(PushCenter.instance.sync());
    state = state.copyWith(
      busy: false,
      done: true,
      needsInit: false,
      pairingUserCode: null,
      pairingVerifyUrl: null,
    );
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
