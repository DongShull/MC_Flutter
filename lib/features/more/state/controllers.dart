import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mc_api.dart';
import 'models.dart';

/// 「我的」页状态：用户 / 提醒组计数 / 会话列表分页。
class MoreState {
  const MoreState({
    this.session,
    this.reminderCount = 0,
    this.pendingUpdateLabel,
    this.sessions = const [],
    this.hasMore = false,
    this.loadingMore = false,
  });

  final Map<String, dynamic>? session; // SessionView 原始 JSON（username/nickname/role…）
  final int reminderCount;
  final String? pendingUpdateLabel;
  final List<SessionSummary> sessions;
  final bool hasMore;
  final bool loadingMore;

  MoreState copyWith({
    Map<String, dynamic>? session,
    int? reminderCount,
    String? pendingUpdateLabel,
    List<SessionSummary>? sessions,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      MoreState(
        session: session ?? this.session,
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
    return const AsyncValue.loading();
  }

  MoreApi get _api => ref.read(moreApiProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final session = await _api.me();
      final results = await Future.wait<Object?>([
        _safeNotices(),
        _api.pendingUpdate(),
        _api.sessions(limit: _pageSize, offset: 0),
      ]);
      final notices = results[0] as List<McNotice>;
      final pending = results[1] as Map<String, dynamic>?;
      final sessions = results[2] as List<SessionSummary>;
      final pendingLabel = pending == null
          ? null
          : (pending['appVersion']?.toString() ??
              pending['app_version']?.toString() ??
              pending['modelTag']?.toString() ??
              pending['model_tag']?.toString());
      state = AsyncValue.data(MoreState(
        session: session,
        reminderCount: _visibleCount(notices) + (pendingLabel != null ? 1 : 0),
        pendingUpdateLabel: pendingLabel == null ? null : '新版本 v$pendingLabel',
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
    final groupKeys = notices
        .map((n) => n.groupKey)
        .whereType<String>()
        .toSet();
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
      final more = await _api.sessions(
          limit: _pageSize, offset: cur.sessions.length);
      final known = cur.sessions.map((s) => s.id).toSet();
      final merged = [...cur.sessions, ...more.where((s) => !known.contains(s.id))];
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

  /// 分叉会话；成功返回 null（列表刷新，新会话在 agent 里可见）。
  Future<String?> forkSession(String id) async {
    try {
      await _api.forkSession(id);
      await _refreshSessions();
      return null;
    } catch (e) {
      return e.toString();
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

final moreProvider = NotifierProvider<MoreController, AsyncValue<MoreState>>(MoreController.new);
