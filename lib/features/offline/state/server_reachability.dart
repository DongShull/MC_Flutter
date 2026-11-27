import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/network/server_routes.dart';

/// 一次网络请求对「服务器是否可达」的证据分类（对齐 iOS ReachabilityOutcome）。
enum ReachabilityOutcome {
  /// 收到带 `x-movieclaw-spec-hash` 头部的响应（任意状态码含 401/500）。
  success,

  /// 明确不可达：拒绝连接、无网络、TLS/证书错误、缺少 spec 指纹头（门户页/反代错误页）。
  hard,

  /// 可能只是慢：超时、连接中断、DNS 抖动。
  soft,

  /// 主动取消，不计入证据。
  ignored,
}

enum ReachabilityStatus { reachable, suspect, unreachable }

enum ReachabilityMode { online, offline }

/// 判不可达的两条规则（对齐 iOS ReachabilityJudge）：
/// 1. 连续硬失败 >= 2 次且跨度 >= 3 秒；
/// 2. 连续失败（含软失败）>= 3 次且从首条失败请求发出起 >= 30 秒。
class ReachabilityJudge {
  static const Duration hardGap = Duration(seconds: 3);
  static const Duration softSpan = Duration(seconds: 30);
  static const int softCount = 3;

  DateTime? _streakStart;
  int _streakCount = 0;
  DateTime? _hardStart;
  int _hardCount = 0;

  void reset() {
    _streakStart = null;
    _streakCount = 0;
    _hardStart = null;
    _hardCount = 0;
  }

  bool recordFailure({
    required bool hard,
    DateTime? now,
    DateTime? startedAt,
  }) {
    final ts = now ?? DateTime.now();
    final sent = (startedAt != null && startedAt.isBefore(ts)) ? startedAt : ts;
    if (_streakStart == null || sent.isBefore(_streakStart!)) {
      _streakStart = sent;
    }
    _streakCount += 1;
    if (hard) {
      _hardStart ??= ts;
      _hardCount += 1;
    } else {
      _hardStart = null;
      _hardCount = 0;
    }
    final twoHard =
        _hardCount >= 2 && ts.difference(_hardStart!) >= hardGap;
    final longSoft =
        _streakCount >= softCount && ts.difference(_streakStart!) >= softSpan;
    return twoHard || longSoft;
  }
}

class ServerReachabilityState {
  const ServerReachabilityState({
    this.status = ReachabilityStatus.reachable,
    this.mode = ReachabilityMode.online,
    this.reconnects = 0,
    this.probing = false,
    this.lastSpecHash,
  });

  final ReachabilityStatus status;
  final ReachabilityMode mode;
  final int reconnects;
  final bool probing;
  final String? lastSpecHash;

  bool get isReachable => status == ReachabilityStatus.reachable;
  bool get isOffline => mode == ReachabilityMode.offline;

  ServerReachabilityState copyWith({
    ReachabilityStatus? status,
    ReachabilityMode? mode,
    int? reconnects,
    bool? probing,
    String? lastSpecHash,
  }) =>
      ServerReachabilityState(
        status: status ?? this.status,
        mode: mode ?? this.mode,
        reconnects: reconnects ?? this.reconnects,
        probing: probing ?? this.probing,
        lastSpecHash: lastSpecHash ?? this.lastSpecHash,
      );
}

/// 服务器连通性与离线模式状态机（对齐 iOS ServerReachability.swift）。
/// - 通过探测 `GET /health` 并校验 `x-movieclaw-spec-hash` 响应头判别是否真正连上自家服务器；
/// - 区分「可达性」与「在线/离线模式」：网慢不误切，离线时支持手动一键重连与指数退避自动重探。
class ServerReachabilityController extends Notifier<ServerReachabilityState> {
  static const _backoffSeconds = [30, 60, 120, 300];

  final ReachabilityJudge _judge = ReachabilityJudge();
  Timer? _probeTimer;
  int _backoffIndex = 0;
  DateTime _lastForegroundAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _autoWindowUntil = DateTime.now().add(const Duration(seconds: 60));
  DateTime? _backgroundedAt;

  @override
  ServerReachabilityState build() {
    ref.onDispose(() {
      _probeTimer?.cancel();
      _probeTimer = null;
    });
    return const ServerReachabilityState();
  }

  String _currentOrigin() {
    final session = ref.read(sessionStoreProvider);
    final raw =
        ServerRoutes.instance.currentOrigin(session.baseUrl ?? '').trim();
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  /// 上报单次请求结果（供调用方或网络拦截器旁听）。
  void reportOutcome(
    ReachabilityOutcome outcome, {
    DateTime? startedAt,
    bool hasLocalDownloads = false,
  }) {
    if (outcome == ReachabilityOutcome.ignored) return;
    if (outcome == ReachabilityOutcome.success) {
      _markReachable();
      return;
    }
    if (startedAt != null && startedAt.isBefore(_lastForegroundAt)) return;
    final conclusive = _judge.recordFailure(
      hard: outcome == ReachabilityOutcome.hard,
      startedAt: startedAt,
    );
    if (state.status == ReachabilityStatus.reachable) {
      state = state.copyWith(status: ReachabilityStatus.suspect);
      _scheduleProbe(Duration.zero);
    }
    if (conclusive && state.status != ReachabilityStatus.unreachable) {
      _setUnreachable(hasLocalDownloads: hasLocalDownloads);
    }
  }

  void _markReachable({String? specHash}) {
    _judge.reset();
    _backoffIndex = 0;
    _probeTimer?.cancel();
    _probeTimer = null;
    final wasOffline = state.mode == ReachabilityMode.offline;
    state = state.copyWith(
      status: ReachabilityStatus.reachable,
      mode: ReachabilityMode.online,
      reconnects: wasOffline ? state.reconnects + 1 : state.reconnects,
      probing: false,
      lastSpecHash: specHash ?? state.lastSpecHash,
    );
  }

  void _setUnreachable({bool hasLocalDownloads = false}) {
    _backoffIndex = 0;
    final shouldAutoOffline = hasLocalDownloads &&
        state.mode == ReachabilityMode.online &&
        DateTime.now().isBefore(_autoWindowUntil);
    state = state.copyWith(
      status: ReachabilityStatus.unreachable,
      mode: shouldAutoOffline ? ReachabilityMode.offline : state.mode,
      probing: false,
    );
    _scheduleProbe(Duration(seconds: _nextBackoffSeconds()));
  }

  int _nextBackoffSeconds() {
    final idx = _backoffIndex.clamp(0, _backoffSeconds.length - 1);
    _backoffIndex += 1;
    return _backoffSeconds[idx];
  }

  /// 手动进入离线模式浏览本机已下载媒体库。
  void enterOffline() {
    state = state.copyWith(
      mode: ReachabilityMode.offline,
      status: state.status == ReachabilityStatus.reachable
          ? ReachabilityStatus.suspect
          : state.status,
    );
    _scheduleProbe(Duration(seconds: _nextBackoffSeconds()));
  }

  /// 手动退出离线模式 / 立即重新探测服务器健康检查。
  Future<bool> reconnect() async {
    _backoffIndex = 0;
    return probeNow();
  }

  void noteForeground() {
    _lastForegroundAt = DateTime.now();
    if (_backgroundedAt != null &&
        DateTime.now().difference(_backgroundedAt!).inMinutes >= 10) {
      _autoWindowUntil = DateTime.now().add(const Duration(seconds: 60));
    }
    _backgroundedAt = null;
    if (state.status != ReachabilityStatus.reachable) {
      _scheduleProbe(Duration.zero);
    }
  }

  void noteBackground() {
    _backgroundedAt = DateTime.now();
    _probeTimer?.cancel();
    _probeTimer = null;
  }

  void _scheduleProbe(Duration delay) {
    _probeTimer?.cancel();
    _probeTimer = Timer(delay, () {
      unawaited(probeNow());
    });
  }

  /// 探测 `GET <origin>/api/v1/health` 或 `GET <origin>/health` 并校验 `x-movieclaw-spec-hash`。
  Future<bool> probeNow({bool hasLocalDownloads = false}) async {
    final origin = _currentOrigin();
    if (origin.isEmpty) return false;
    state = state.copyWith(probing: true);
    final startedAt = DateTime.now();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse('$origin/api/v1/health');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      req.headers.set(HttpHeaders.userAgentHeader, McClient.defaultUserAgent);
      final res = await req.close().timeout(const Duration(seconds: 5));
      final specHash = res.headers.value('x-movieclaw-spec-hash');
      final statusCode = res.statusCode;
      await res.drain<void>();
      if (specHash != null && specHash.isNotEmpty) {
        _markReachable(specHash: specHash);
        return true;
      }
      // 兼容不返回 spec-hash 的开发/代理环境：明确 2xx JSON 健康检查也可视为可达。
      if (statusCode >= 200 && statusCode < 300) {
        _markReachable();
        return true;
      }
      reportOutcome(
        ReachabilityOutcome.hard,
        startedAt: startedAt,
        hasLocalDownloads: hasLocalDownloads,
      );
      return false;
    } on TimeoutException {
      reportOutcome(
        ReachabilityOutcome.soft,
        startedAt: startedAt,
        hasLocalDownloads: hasLocalDownloads,
      );
      return false;
    } on HandshakeException {
      reportOutcome(
        ReachabilityOutcome.hard,
        startedAt: startedAt,
        hasLocalDownloads: hasLocalDownloads,
      );
      return false;
    } on SocketException {
      reportOutcome(
        ReachabilityOutcome.hard,
        startedAt: startedAt,
        hasLocalDownloads: hasLocalDownloads,
      );
      return false;
    } catch (_) {
      reportOutcome(
        ReachabilityOutcome.soft,
        startedAt: startedAt,
        hasLocalDownloads: hasLocalDownloads,
      );
      return false;
    } finally {
      client.close(force: true);
      if (state.probing) {
        state = state.copyWith(probing: false);
      }
      if (state.status == ReachabilityStatus.suspect) {
        _scheduleProbe(const Duration(seconds: 2));
      } else if (state.status == ReachabilityStatus.unreachable) {
        _scheduleProbe(Duration(seconds: _nextBackoffSeconds()));
      }
    }
  }
}

final serverReachabilityProvider =
    NotifierProvider<ServerReachabilityController, ServerReachabilityState>(
  ServerReachabilityController.new,
);

/// 服务器当前是否可达（`true` = 可达，`false` = 存疑/不可达）。
final serverReachableProvider = Provider<bool>(
  (ref) => ref.watch(serverReachabilityProvider).isReachable,
);

/// 当前是否处于离线浏览模式。
final offlineModeProvider = Provider<bool>(
  (ref) => ref.watch(serverReachabilityProvider).isOffline,
);
