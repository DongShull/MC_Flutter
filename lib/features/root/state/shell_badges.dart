import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/mc_error.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/api/sse_client.dart';

/// 底栏状态点数据（对齐 ShellBadges.kt）：
/// - 活动页签：attentionTotal>0 红 / live>0 绿 / activeTotal>0 蓝
/// - 我的页签：pendingUpdate → 蓝点「有可用更新」
class ShellBadges {
  const ShellBadges({
    this.attentionTotal = 0,
    this.activeTotal = 0,
    this.livePlayback = 0,
    this.pendingUpdate = false,
  });

  /// 需要人工处理的任务数（红点）。
  final int attentionTotal;

  /// 正在进行中的任务数（蓝点）。
  final int activeTotal;

  /// 正在观看的人数（绿点）。
  final int livePlayback;

  /// 有可用更新（appVersion 或 modelTag，蓝点）。
  final bool pendingUpdate;

  bool get showActivityDot =>
      attentionTotal > 0 || livePlayback > 0 || activeTotal > 0;
}

/// 底栏徽标刷新器：
/// 首选服务端推送流（/api/v1/jobs/stream 的 ready/job 事件、
/// /api/v1/push/me/stream 的 notification/status 事件）触发刷新；
/// 流不可用（未登录/旧服务端 404/非管理员 403/重试耗尽）时回退 30s 轮询。
/// 播放活动与待更新没有对应的服务端流端点，故仍靠刷新带回（不单独轮询）。
class ShellBadgesController extends Notifier<ShellBadges> {
  Timer? _timer;
  Timer? _debounce;
  StreamSubscription<SseEvent>? _jobsSub;
  StreamSubscription<SseEvent>? _pushSub;
  McClient? _client;
  bool _disposed = false;

  McClient get client =>
      _client ??= McClient(session: ref.read(sessionStoreProvider));

  @override
  ShellBadges build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      _debounce?.cancel();
      unawaited(_jobsSub?.cancel());
      unawaited(_pushSub?.cancel());
    });
    _poll();
    unawaited(_observeStreams());
    return const ShellBadges();
  }

  Future<void> _observeStreams() async {
    final sse = ref.read(sseClientProvider);
    await Future.wait([
      _observeOne(sse, '/api/v1/jobs/stream'),
      _observeOne(sse, '/api/v1/push/me/stream'),
    ]);
  }

  /// 订阅一条流：任意事件触发（防抖后）刷新；流结束/失败 → 确保轮询在跑。
  Future<void> _observeOne(SseClient sse, String path) async {
    try {
      final sub = sse.events(path, terminalEvents: const {}).listen((_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 1), () {
          unawaited(_poll());
        });
      });
      if (path.contains('/jobs/')) {
        _jobsSub = sub;
      } else {
        _pushSub = sub;
      }
      await sub.asFuture<void>();
      McErrorLog.log('角标推送流 $path 结束，回退轮询', context: 'shellBadges.sse');
    } on SseUnsupportedException catch (e) {
      McErrorLog.log(e, context: 'shellBadges.sse');
    } catch (e) {
      McErrorLog.log(e, context: 'shellBadges.sse');
    }
    _ensureFallbackPolling();
  }

  void _ensureFallbackPolling() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!ref.read(sessionStoreProvider).isReady) return;
    var attention = 0, active = 0, live = 0, update = false;
    try {
      final jobs = await client
          .unwrap<List<dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/jobs',
          )
          .timeout(const Duration(seconds: 8));
      for (final j in jobs.whereType<Map<String, dynamic>>()) {
        final needs =
            j['needs_attention'] == true || j['status'] == 'attention';
        if (needs) {
          attention++;
        } else if (j['status'] == 'running' || j['status'] == 'active') {
          active++;
        }
      }
    } catch (e) {
      McErrorLog.log(e, context: 'shellBadges.jobs');
    }
    try {
      final pb = await client
          .unwrap<Map<String, dynamic>>(
            Channel.live,
            'GET',
            '/api/v1/playback/activity',
          )
          .timeout(const Duration(seconds: 8));
      final sessions = pb['sessions'];
      live = sessions is List ? sessions.length : 0;
    } catch (e) {
      McErrorLog.log(e, context: 'shellBadges.playback');
    }
    try {
      final up = await client
          .unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/pending-update',
          )
          .timeout(const Duration(seconds: 8));
      update = up['available'] == true ||
          up['app_version'] != null ||
          up['model_tag'] != null;
    } catch (e) {
      McErrorLog.log(e, context: 'shellBadges.pendingUpdate');
    }
    state = ShellBadges(
      attentionTotal: attention,
      activeTotal: active,
      livePlayback: live,
      pendingUpdate: update,
    );
  }

  /// 手动刷新（切到活动页签时调用）。
  Future<void> refresh() => _poll();
}

final shellBadgesProvider =
    NotifierProvider<ShellBadgesController, ShellBadges>(
        ShellBadgesController.new);
