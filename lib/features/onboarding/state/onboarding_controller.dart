import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/mc_error.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/api/session_providers.dart';

/// 登录流程状态（对齐原 feature/onboarding：探测→bootstrap→device/login）。
class OnboardingState {
  const OnboardingState({
    this.busy = false,
    this.error,
    this.done = false,
    this.needsInit = false,
  });

  final bool busy;
  final String? error;
  final bool done;
  final bool needsInit;

  OnboardingState copyWith({
    bool? busy,
    Object? error = _sentinel,
    bool? done,
    bool? needsInit,
  }) =>
      OnboardingState(
        busy: busy ?? this.busy,
        error: identical(error, _sentinel) ? this.error : error as String?,
        done: done ?? this.done,
        needsInit: needsInit ?? this.needsInit,
      );

  static const _sentinel = Object();
}

class OnboardingController extends Notifier<OnboardingState> {
  McClient? _client;

  @override
  OnboardingState build() => const OnboardingState();

  /// 1) GET /health 探测（确认服务器基址可用）
  Future<bool> probeHealth(String base) async {
    final res = await _client!
        .get(Channel.general, '/api/v1/health')
        .timeout(const Duration(seconds: 8));
    return res.statusCode == 200;
  }

  /// 2) bootstrap：检查服务器是否已初始化
  Future<bool> checkBootstrap() async {
    final body = await _client!.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/auth/bootstrap',
    );
    return body['initialized'] == true;
  }

  /// 3) POST /auth/device/login 换会话令牌
  /// 归一化用户输入：补 scheme、去尾部斜杠。
  String _normalizeBase(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Future<void> login(String base, String username, String password) async {
    if (state.busy) return;
    state = state.copyWith(busy: true, error: null, done: false);
    try {
      final session = ref.read(sessionStoreProvider);
      // 首次登录：session 里还没有 baseUrl，必须用输入框地址建客户端。
      final host = _normalizeBase(base);
      _client = McClient(session: session, baseUrlOverride: host);
      final ok = await probeHealth(host);
      if (!ok) {
        state = state.copyWith(busy: false, error: '服务器不可达');
        return;
      }
      final initialized = await checkBootstrap();
      if (!initialized) {
        state = state.copyWith(busy: false, needsInit: true);
        return;
      }
      final body = await _client!.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/auth/device/login',
        body: {
          'username': username,
          'password': password,
          'client': {
            'kind': 'android',
            'installation_id': await session.installationId(),
            'name': session.deviceName.isNotEmpty
                ? session.deviceName
                : 'Android Device',
            'platform': 'Android · Flutter',
            'client_version': '1.0.0',
          },
        },
      );
      // DeviceLoginView: {token, device, session}。
      final token = body['token']?.toString() ?? '';
      if (token.isEmpty) {
        state = state.copyWith(busy: false, error: '登录响应缺少令牌');
        return;
      }
      final deviceName =
          ((body['device'] as Map<String, dynamic>?)?['name'] ?? '').toString();
      await session.login(baseUrl: host, token: token, deviceName: deviceName);
      // 登录成功：拉地址簿并选路（内网先探、外网晚 250ms，鸿蒙 ServerRoutes.configure 对应）。
      unawaited(ServerRoutes.instance.configure(host, () async {
        final loginClient = McClient(session: session, baseUrlOverride: host);
        // 既有 bug 修复（P1）：旧路径 '/server/addresses' 缺 /api/v1 前缀恒 404。
        final res = await loginClient.get(Channel.general, '/api/v1/server/addresses');
        if (res.statusCode != 200 || res.data == null) return null;
        return ServerAddressesView.fromJson(res.data!);
      }));
      // 登录身份（启动页展示用）：GET /auth/me → username/nickname。
      try {
        final me = await _client!.unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/auth/me',
        );
        final name = (me['nickname']?.toString().isNotEmpty == true)
            ? me['nickname'].toString()
            : (me['username'] ?? '').toString();
        await session.saveProfile(
            username: name, avatarUrl: me['avatar_url']?.toString());
      } catch (e) {
        // 拿不到身份不阻断登录（记日志，不静默）。
        McErrorLog.log(e, context: 'onboarding.me');
      }
      state = state.copyWith(busy: false, done: true);
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(busy: false, error: '网络错误，请检查地址后重试');
    }
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
        OnboardingController.new);
