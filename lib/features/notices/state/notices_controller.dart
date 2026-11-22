import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_error.dart';
import '../../../core/api/sse_client.dart';
import 'mc_api.dart';
import 'models.dart';

/// 可加载状态（对齐原 core/designsystem 的 Loadable 三态）。
sealed class NoticesLoadable {
  const NoticesLoadable();
}

class NoticesLoading extends NoticesLoadable {
  const NoticesLoading();
}

class NoticesFailed extends NoticesLoadable {
  const NoticesFailed(this.message);
  final String message;
}

class NoticesReady extends NoticesLoadable {
  const NoticesReady(this.value);
  final List<Notice> value;
}

/// 通知中心控制器（对齐 Kotlin NoticeCenterViewModel）：
/// 首选服务端推送流 `/api/v1/push/me/stream`（notification/status 事件触发刷新），
/// 流不可用（未登录/旧服务端 404/重试耗尽）时回退 30s 轮询；忽略（乐观更新，
/// 失败回滚，下次刷新带回）。
class NoticesController extends Notifier<NoticesLoadable> {
  Timer? _poll;
  StreamSubscription<SseEvent>? _streamSub;
  bool _disposed = false;

  static const _pollInterval = Duration(seconds: 30);

  @override
  NoticesLoadable build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _poll?.cancel();
      unawaited(_streamSub?.cancel());
    });
    refresh();
    unawaited(_observePushStream());
    return const NoticesLoading();
  }

  /// 推送流：notification（新通知入箱）或 status（状态快照）事件 → 静默刷新。
  /// 流结束/失败 → 回退 30s 轮询（仅降级）。
  Future<void> _observePushStream() async {
    final sse = ref.read(sseClientProvider);
    try {
      final sub = sse
          .events('/api/v1/push/me/stream', terminalEvents: const {})
          .listen((event) {
        if (event.name == 'notification' || event.name == 'status') {
          unawaited(refresh(silent: true));
        }
      });
      _streamSub = sub;
      await sub.asFuture<void>();
      McErrorLog.log('通知推送流结束，回退 30s 轮询', context: 'notices.sse');
      _fallbackPolling();
    } on SseUnsupportedException catch (e) {
      McErrorLog.log(e, context: 'notices.sse');
      _fallbackPolling();
    } catch (e) {
      McErrorLog.log(e, context: 'notices.sse');
      _fallbackPolling();
    }
  }

  void _fallbackPolling() {
    if (_disposed || _poll != null) return;
    _poll = Timer.periodic(_pollInterval, (_) => refresh(silent: true));
  }

  Future<void> refresh({bool silent = false}) async {
    final api = ref.read(noticeApiProvider);
    if (!silent) state = const NoticesLoading();
    try {
      final notices = visibleNotices(await api.notices());
      state = NoticesReady(notices);
    } on ApiException catch (e) {
      McErrorLog.log(e, context: 'notices.refresh');
      if (state is! NoticesReady) state = NoticesFailed(e.friendlyMessage);
    } catch (e) {
      McErrorLog.log(e, context: 'notices.refresh');
      if (state is! NoticesReady) state = const NoticesFailed('网络不可达，请稍后重试');
    }
  }

  /// 乐观忽略：先从列表移除，失败则回滚（下次刷新会带回）。
  Future<void> dismiss(Notice notice) async {
    final current = state;
    if (current is! NoticesReady) return;
    final before = current.value;
    state = NoticesReady(before.where((n) => n.id != notice.id).toList());
    try {
      await ref.read(noticeApiProvider).dismissNotice(notice.id);
    } catch (e) {
      McErrorLog.log(e, context: 'notices.dismiss');
      state = NoticesReady(before);
    }
  }

  Future<void> dismissAll() async {
    final current = state;
    if (current is! NoticesReady || current.value.isEmpty) return;
    final before = current.value;
    state = const NoticesReady([]);
    final api = ref.read(noticeApiProvider);
    for (final n in before) {
      try {
        await api.dismissNotice(n.id);
      } catch (e) {
        // 单条失败不中断，全部试完再刷新（刷新也会带回漏网条目）。
        McErrorLog.log(e, context: 'notices.dismissAll');
      }
    }
    await refresh(silent: true);
  }
}

final noticesControllerProvider =
    NotifierProvider<NoticesController, NoticesLoadable>(NoticesController.new);
