import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
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
      '/api/v1/bootstrap',
    );
    return body['initialized'] == true;
  }

  /// 3) POST /auth/device/login 换会话令牌
  Future<void> login(String base) async {
    if (state.busy) return;
    state = state.copyWith(busy: true, error: null, done: false);
    try {
      final session = ref.read(sessionStoreProvider);
      _client = McClient(session: session);
      final ok = await probeHealth(base);
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
        body: {'client': 'flutter-phone'},
      );
      await session.login(
        baseUrl: base,
        token: body['token'].toString(),
        deviceName: ((body['device'] as Map<String, dynamic>?)?['name'] ?? '').toString(),
      );
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
        await session.saveProfile(username: name);
      } catch (_) {
        // 拿不到身份不阻断登录。
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

