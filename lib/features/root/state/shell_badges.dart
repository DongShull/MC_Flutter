import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/agent_sse_client.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/auth/session_watch.dart';

/// 底栏与侧边栏状态点数据（对齐 iOS `ShellBadges`）：
/// - 活动页签（管理员）：attentionTotal>0 红 / livePlayback>0 绿 / activeTotal>0 蓝
/// - 我的页签（管理员）：pendingUpdate → 蓝点「有可用更新」
class ShellBadges {
  const ShellBadges({
    this.attentionTotal = 0,
    this.activeTotal = 0,
    this.livePlayback = 0,
    this.pendingUpdate = false,
    this.pendingUpdateLabel,
  });

  /// 需要人工处理的任务数（红点）。
  final int attentionTotal;

  /// 正在进行中的任务数（蓝点）。
  final int activeTotal;

  /// 正在观看的人数（绿点）。
  final int livePlayback;

  /// 有可用更新（appVersion 或 modelTag，蓝点）。
  final bool pendingUpdate;

  /// 待更新展示文案（优先 `新版本 v...`，其次 `新识别模型 ...`）。
  final String? pendingUpdateLabel;

  bool get showActivityDot =>
      attentionTotal > 0 || livePlayback > 0 || activeTotal > 0;

  ShellBadges copyWith({
    int? attentionTotal,
    int? activeTotal,
    int? livePlayback,
    bool? pendingUpdate,
    Object? pendingUpdateLabel = _sentinel,
  }) =>
      ShellBadges(
        attentionTotal: attentionTotal ?? this.attentionTotal,
        activeTotal: activeTotal ?? this.activeTotal,
        livePlayback: livePlayback ?? this.livePlayback,
        pendingUpdate: pendingUpdate ?? this.pendingUpdate,
        pendingUpdateLabel: identical(pendingUpdateLabel, _sentinel)
            ? this.pendingUpdateLabel
            : pendingUpdateLabel as String?,
      );

  static const _sentinel = Object();
}

/// 底栏徽标控制器（对齐 iOS `ShellBadges`）：
/// - 非管理员完全跳过 `/jobs`、`/jobs/stream`、`/playback/activity`、`/app/update/pending`；
/// - 管理员优先走 `McSseClient` 订阅 `/api/v1/jobs/stream`，服务端不支持或断连时自动回退轮询；
/// - 切到后台时自动暂停 SSE 与轮询定时器，回到前台立刻恢复。
class ShellBadgesController extends Notifier<ShellBadges> {
  Timer? _jobsFallbackTimer;
  Timer? _playbackTimer;
  Timer? _updateTimer;
  StreamSubscription<SseEvent>? _sseSub;
  AppLifecycleListener? _lifecycle;
  bool _paused = false;
  bool _active = false;
  int _runEpoch = 0;

  McClient get _client => ref.read(mcClientProvider);

  @override
  ShellBadges build() {
    final perms = ref.watch(mcPermissionsProvider);
    ref.watch(mcSessionGenerationProvider);
    final session = ref.read(sessionStoreProvider);

    ref.onDispose(_stopAll);

    if (!session.isReady ||
        !perms.isAdmin ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      _stopAll();
      return const ShellBadges();
    }

    _lifecycle ??= AppLifecycleListener(
      onPause: _onBackground,
      onHide: _onBackground,
      onResume: _onForeground,
    );

    _startAll();
    return const ShellBadges();
  }

  void _onBackground() {
    if (_paused) return;
    _paused = true;
    _stopStreamsAndTimers();
  }

  void _onForeground() {
    if (!_paused) return;
    _paused = false;
    final session = ref.read(sessionStoreProvider);
    final perms = ref.read(mcPermissionsProvider);
    if (session.isReady && perms.isAdmin) {
      _startAll();
    }
  }

  void _startAll() {
    _stopStreamsAndTimers();
    _active = true;
    final epoch = ++_runEpoch;

    _startJobsStream(epoch);

    _playbackTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollPlayback(epoch),
    );
    unawaited(_pollPlayback(epoch));

    _updateTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _pollPendingUpdate(epoch),
    );
    unawaited(_pollPendingUpdate(epoch));
  }

  void _stopStreamsAndTimers() {
    _active = false;
    _runEpoch++;
    _jobsFallbackTimer?.cancel();
    _jobsFallbackTimer = null;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    _sseSub?.cancel();
    _sseSub = null;
  }

  void _stopAll() {
    _stopStreamsAndTimers();
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  void _startJobsStream(int epoch) {
    final session = ref.read(sessionStoreProvider);
    if (!session.isReady || !_active || epoch != _runEpoch) return;

    // 先拉一次快照避免等待首帧 SSE 期间无角标。
    unawaited(_pollJobs(epoch));

    final sse = McSseClient(session);
    _sseSub?.cancel();
    _sseSub = sse
        .stream(
          '/api/v1/jobs/stream',
          autoReconnect: true,
          maxAttempts: 4,
          connectTimeout: const Duration(seconds: 10),
        )
        .listen(
          (event) {
            if (!_active || epoch != _runEpoch) return;
            final payload = event.decodeJson();
            if (payload != null) {
              _applyJobsPayload(payload);
            }
          },
          onError: (_) {
            if (!_active || epoch != _runEpoch) return;
            _enableJobsPollingFallback(epoch);
          },
          onDone: () {
            if (!_active || epoch != _runEpoch) return;
            _enableJobsPollingFallback(epoch);
          },
          cancelOnError: true,
        );
  }

  void _enableJobsPollingFallback(int epoch) {
    if (_jobsFallbackTimer != null || !_active || epoch != _runEpoch) return;
    _jobsFallbackTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _pollJobs(epoch),
    );
  }

  void _applyJobsPayload(Map<String, dynamic> payload) {
    // 支持后端摘要字段（attention_total / active_total）或完整列表（items / jobs）。
    if (payload.containsKey('attention_total') ||
        payload.containsKey('active_total')) {
      final attention = (payload['attention_total'] as num?)?.toInt() ??
          state.attentionTotal;
      final active =
          (payload['active_total'] as num?)?.toInt() ?? state.activeTotal;
      state = state.copyWith(attentionTotal: attention, activeTotal: active);
      return;
    }

    final nested = payload['activity'] ?? payload['summary'];
    if (nested is Map) {
      final map = nested.cast<String, dynamic>();
      if (map.containsKey('attention_total') ||
          map.containsKey('active_total')) {
        state = state.copyWith(
          attentionTotal: (map['attention_total'] as num?)?.toInt() ??
              state.attentionTotal,
          activeTotal:
              (map['active_total'] as num?)?.toInt() ?? state.activeTotal,
        );
        return;
      }
    }

    final list = payload['items'] ?? payload['jobs'];
    if (list is List) {
      _countAndApplyJobList(list);
    }
  }

  void _countAndApplyJobList(List<dynamic> jobs) {
    var attention = 0;
    var active = 0;
    for (final j in jobs.whereType<Map>()) {
      final needs = j['needs_attention'] == true || j['status'] == 'attention';
      if (needs) {
        attention++;
      } else if (j['status'] == 'running' || j['status'] == 'active') {
        active++;
      }
    }
    state = state.copyWith(attentionTotal: attention, activeTotal: active);
  }

  Future<void> _pollJobs(int epoch) async {
    if (!_active || epoch != _runEpoch) return;
    final perms = ref.read(mcPermissionsProvider);
    if (!perms.isAdmin || !ref.read(sessionStoreProvider).isReady) return;
    try {
      final rawJobs = await _client
          .unwrap<dynamic>(Channel.general, 'GET', '/api/v1/jobs')
          .timeout(const Duration(seconds: 8));
      if (!_active || epoch != _runEpoch) return;
      if (rawJobs is List) {
        _countAndApplyJobList(rawJobs);
      } else if (rawJobs is Map) {
        _applyJobsPayload(rawJobs.cast<String, dynamic>());
      }
    } catch (_) {}
  }

  Future<void> _pollPlayback(int epoch) async {
    if (!_active || epoch != _runEpoch) return;
    final perms = ref.read(mcPermissionsProvider);
    if (!perms.isAdmin || !ref.read(sessionStoreProvider).isReady) return;
    try {
      final pb = await _client
          .unwrap<Map<String, dynamic>>(
            Channel.live,
            'GET',
            '/api/v1/playback/activity',
          )
          .timeout(const Duration(seconds: 8));
      if (!_active || epoch != _runEpoch) return;
      final sessions = pb['sessions'];
      final live = sessions is List ? sessions.length : 0;
      state = state.copyWith(livePlayback: live);
    } catch (_) {}
  }

  Future<void> _pollPendingUpdate(int epoch) async {
    if (!_active || epoch != _runEpoch) return;
    final perms = ref.read(mcPermissionsProvider);
    if (!perms.isAdmin || !ref.read(sessionStoreProvider).isReady) return;
    try {
      final up = await _client
          .unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/app/update/pending',
          )
          .timeout(const Duration(seconds: 8));
      if (!_active || epoch != _runEpoch) return;
      final appVer = (up['app_version'] ?? up['appVersion'])?.toString().trim();
      final modelTag = (up['model_tag'] ?? up['modelTag'])?.toString().trim();
      final hasApp = appVer != null && appVer.isNotEmpty;
      final hasModel = modelTag != null && modelTag.isNotEmpty;
      final hasUpdate = up['available'] == true || hasApp || hasModel;
      final label = hasApp
          ? '新版本 v$appVer'
          : (hasModel ? '新识别模型 $modelTag' : null);
      state = state.copyWith(
        pendingUpdate: hasUpdate,
        pendingUpdateLabel: label,
      );
    } catch (_) {}
  }

  /// 手动刷新（切到活动/我的页签或回到前台时调用）。
  Future<void> refresh() async {
    final perms = ref.read(mcPermissionsProvider);
    if (!perms.isAdmin || !ref.read(sessionStoreProvider).isReady) return;
    final epoch = _runEpoch;
    await Future.wait([
      _pollJobs(epoch),
      _pollPlayback(epoch),
      _pollPendingUpdate(epoch),
    ]);
  }
}

final shellBadgesProvider =
    NotifierProvider<ShellBadgesController, ShellBadges>(
  ShellBadgesController.new,
);
