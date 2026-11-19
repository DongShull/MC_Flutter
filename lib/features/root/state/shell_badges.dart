import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';

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

  bool get showActivityDot => attentionTotal > 0 || livePlayback > 0 || activeTotal > 0;
}

/// 底栏徽标轮询器（前台活动 30s / 更新 600s 简化为统一 30s；离线或失败保持上次值）。
class ShellBadgesController extends Notifier<ShellBadges> {
  Timer? _timer;
  McClient? _client;

  McClient get client =>
      _client ??= McClient(session: ref.read(sessionStoreProvider));

  @override
  ShellBadges build() {
    ref.onDispose(() => _timer?.cancel());
    _start();
    return const ShellBadges();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
    _poll();
  }

  Future<void> _poll() async {
    if (!ref.read(sessionStoreProvider).isReady) return;
    var attention = 0, active = 0, live = 0, update = false;
    try {
      final jobs = await client.unwrap<List<dynamic>>(
        Channel.general, 'GET', '/api/v1/jobs',
      ).timeout(const Duration(seconds: 8));
      for (final j in jobs.whereType<Map<String, dynamic>>()) {
        final needs = j['needs_attention'] == true || j['status'] == 'attention';
        if (needs) {
          attention++;
        } else if (j['status'] == 'running' || j['status'] == 'active') {
          active++;
        }
      }
    } catch (_) {}
    try {
      final pb = await client.unwrap<Map<String, dynamic>>(
        Channel.live, 'GET', '/api/v1/playback/activity',
      ).timeout(const Duration(seconds: 8));
      final sessions = pb['sessions'];
      live = sessions is List ? sessions.length : 0;
    } catch (_) {}
    try {
      final up = await client.unwrap<Map<String, dynamic>>(
        Channel.general, 'GET', '/api/v1/pending-update',
      ).timeout(const Duration(seconds: 8));
      update = up['available'] == true || up['app_version'] != null || up['model_tag'] != null;
    } catch (_) {}
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
    NotifierProvider<ShellBadgesController, ShellBadges>(ShellBadgesController.new);
