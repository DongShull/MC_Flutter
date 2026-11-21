import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_store.dart';
import 'mc_api.dart';
import 'models.dart';

/// 「我的」页状态：用户 / 提醒组计数 / 会话列表分页。
class MoreState {
  const MoreState({
    this.session,
    this.noticeCount = 0,
    this.reminderCount = 0,
    this.pendingUpdateLabel,
    this.sessions = const [],
    this.hasMore = false,
    this.loadingMore = false,
  });

  final Map<String, dynamic>?
      session; // SessionView 原始 JSON（username/nickname/role…）
  final int noticeCount; // 可见公告数（待处理瓷砖口径，不含待更新）
  final int reminderCount;
  final String? pendingUpdateLabel;
  final List<SessionSummary> sessions;
  final bool hasMore;
  final bool loadingMore;

  MoreState copyWith({
    Map<String, dynamic>? session,
    int? noticeCount,
    int? reminderCount,
    String? pendingUpdateLabel,
    List<SessionSummary>? sessions,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      MoreState(
        session: session ?? this.session,
        noticeCount: noticeCount ?? this.noticeCount,
        reminderCount: reminderCount ?? this.reminderCount,
        pendingUpdateLabel: pendingUpdateLabel ?? this.pendingUpdateLabel,
        sessions: sessions ?? this.sessions,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class MoreController extends Notifier<AsyncValue<MoreState>> {
  static const _pageSize = 20;

  @override
  AsyncValue<MoreState> build() {
    Future.microtask(load);
    _startPolling();
    return const AsyncValue.loading();
  }

  /// 轮询（对齐鸿蒙 MorePage）：公告 30s、待更新 10min，仅管理员；
  /// 失败保留旧值（我的页不因公告挂掉而整体报错）。
  void _startPolling() {
    final notices =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshNotices());
    final updates = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _refreshPendingUpdate(),
    );
    ref.onDispose(() {
      notices.cancel();
      updates.cancel();
    });
  }

  bool get _isAdmin =>
      (state.valueOrNull?.session?['role'] ?? '').toString() == 'admin';

  /// 待更新文案：'新版本 v<app_version>' 优先，否则 '新识别模型 <model_tag>'。
  String? _pendingLabel(Map<String, dynamic>? pending) {
    if (pending == null) return null;
    final appVersion =
        (pending['appVersion'] ?? pending['app_version'])?.toString();
    if (appVersion != null) return '新版本 v$appVersion';
    final modelTag = (pending['modelTag'] ?? pending['model_tag'])?.toString();
    if (modelTag != null) return '新识别模型 $modelTag';
    return null;
  }

  Future<void> _refreshNotices() async {
    if (!_isAdmin) return;
    try {
      final notices = await _api.notices();
      final cur = state.valueOrNull;
      if (cur == null) return;
      final count = _visibleCount(notices);
      state = AsyncValue.data(cur.copyWith(
        noticeCount: count,
        reminderCount: count + (cur.pendingUpdateLabel != null ? 1 : 0),
      ));
    } catch (_) {
      // 失败保留旧值。
    }
  }

  Future<void> _refreshPendingUpdate() async {
    if (!_isAdmin) return;
    try {
      final pending = await _api.pendingUpdate();
      final cur = state.valueOrNull;
      if (cur == null) return;
      state = AsyncValue.data(
          cur.copyWith(pendingUpdateLabel: _pendingLabel(pending)));
    } catch (_) {
      // 失败保留旧值。
    }
  }

  MoreApi get _api => ref.read(moreApiProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final session = await _api.me();
      // 头像实时回写（根 Tab / 启动页共用会话快照），改头像无需重登。
      final liveAvatar = session?['avatar_url']?.toString() ?? '';
      if (liveAvatar.isNotEmpty && liveAvatar != appSession.avatarUrl) {
        await appSession.saveProfile(avatarUrl: liveAvatar);
      }
      final results = await Future.wait<Object?>([
        _safeNotices(),
        _api.pendingUpdate(),
        _api.sessions(limit: _pageSize, offset: 0),
      ]);
      final notices = results[0] as List<McNotice>;
      final pending = results[1] as Map<String, dynamic>?;
      final sessions = results[2] as List<SessionSummary>;
      final pendingLabel = _pendingLabel(pending);
      final noticeCount = _visibleCount(notices);
      state = AsyncValue.data(MoreState(
        session: session,
        noticeCount: noticeCount,
        reminderCount: noticeCount + (pendingLabel != null ? 1 : 0),
        pendingUpdateLabel: pendingLabel,
        sessions: sessions,
        hasMore: sessions.length >= _pageSize,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 网络细节失败时提醒组静默为 0（我的页不因公告挂掉而整体报错）。
  Future<List<McNotice>> _safeNotices() async {
    try {
      return await _api.notices();
    } catch (_) {
      return const [];
    }
  }

  /// visibleNotices：grouped_under 指向某条 group_key 的告警折叠不显示。
  int _visibleCount(List<McNotice> notices) {
    final groupKeys =
        notices.map((n) => n.groupKey).whereType<String>().toSet();
    return notices
        .where((n) =>
            n.groupKey != null ||
            n.groupedUnder == null ||
            !groupKeys.contains(n.groupedUnder))
        .length;
  }

  Future<void> loadMoreSessions() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.loadingMore || !cur.hasMore) return;
    state = AsyncValue.data(cur.copyWith(loadingMore: true));
    try {
      final more =
          await _api.sessions(limit: _pageSize, offset: cur.sessions.length);
      final known = cur.sessions.map((s) => s.id).toSet();
      final merged = [
        ...cur.sessions,
        ...more.where((s) => !known.contains(s.id))
      ];
      state = AsyncValue.data(cur.copyWith(
        sessions: merged,
        hasMore: more.length >= _pageSize,
        loadingMore: false,
      ));
    } catch (_) {
      state = AsyncValue.data(cur.copyWith(loadingMore: false));
    }
  }

  Future<String?> renameSession(String id, String title) async {
    try {
      await _api.renameSession(id, title);
      await _refreshSessions();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteSession(String id) async {
    try {
      await _api.deleteSession(id);
      await _refreshSessions();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 分叉会话；成功返回新会话 id（页面直接跳入），失败返回 null。
  Future<String?> forkSession(String id) async {
    try {
      final newId = await _api.forkSession(id);
      await _refreshSessions();
      return newId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshSessions() async {
    try {
      final sessions = await _api.sessions(limit: _pageSize, offset: 0);
      final cur = state.valueOrNull ?? const MoreState();
      state = AsyncValue.data(cur.copyWith(
        sessions: sessions,
        hasMore: sessions.length >= _pageSize,
        loadingMore: false,
      ));
    } catch (_) {}
  }
}

final moreProvider =
    NotifierProvider<MoreController, AsyncValue<MoreState>>(MoreController.new);
