import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
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
/// 30s 轮询 + 忽略（乐观更新，失败回滚，下次轮询带回）；
/// 服务端无推送基础设施，故用轮询（设计方案 05 §6.1）。
class NoticesController extends Notifier<NoticesLoadable>
    with WidgetsBindingObserver {
  Timer? _poll;

  static const _pollInterval = Duration(seconds: 30);

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => refresh(silent: true));
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _stopPolling();
      case AppLifecycleState.resumed:
        _startPolling();
        unawaited(refresh(silent: true));
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  NoticesLoadable build() {
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _stopPolling();
    });
    refresh();
    return const NoticesLoading();
  }

  Future<void> refresh({bool silent = false}) async {
    final api = ref.read(noticeApiProvider);
    if (!silent) state = const NoticesLoading();
    try {
      final notices = visibleNotices(await api.notices());
      state = NoticesReady(notices);
    } on ApiException catch (e) {
      if (state is! NoticesReady) state = NoticesFailed(e.friendlyMessage);
    } catch (_) {
      if (state is! NoticesReady) state = const NoticesFailed('网络不可达，请稍后重试');
    }
  }

  /// 乐观忽略：先从列表移除，失败则回滚（下次轮询会带回）。
  Future<void> dismiss(Notice notice) async {
    final current = state;
    if (current is! NoticesReady) return;
    final before = current.value;
    state = NoticesReady(before.where((n) => n.id != notice.id).toList());
    try {
      await ref.read(noticeApiProvider).dismissNotice(notice.id);
    } catch (_) {
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
      } catch (_) {
        // 单条失败不中断，全部试完再刷新（轮询也会带回漏网条目）。
      }
    }
    await refresh(silent: true);
  }
}

final noticesControllerProvider =
    NotifierProvider<NoticesController, NoticesLoadable>(NoticesController.new);
