import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_watch.dart';
import '../../../core/session/session_store.dart';
import 'mc_api.dart';
import 'models.dart';

/// 「我的」页状态：用户 / 提醒组计数 / 会话列表分页 / 离线态。
class MoreState {
  const MoreState({
    this.session,
    this.noticeCount = 0,
    this.reminderCount = 0,
    this.pendingUpdateLabel,
    this.sessions = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.isOffline = false,
  });

  final Map<String, dynamic>? session;
  final int noticeCount;
  final int reminderCount;
  final String? pendingUpdateLabel;
  final List<SessionSummary> sessions;
  final bool hasMore;
  final bool loadingMore;
  final bool isOffline;

  bool get updatePending => pendingUpdateLabel != null;

  MoreState copyWith({
    Map<String, dynamic>? session,
    int? noticeCount,
    int? reminderCount,
    Object? pendingUpdateLabel = _sentinel,
    List<SessionSummary>? sessions,
    bool? hasMore,
    bool? loadingMore,
    bool? isOffline,
  }) =>
      MoreState(
        session: session ?? this.session,
        noticeCount: noticeCount ?? this.noticeCount,
        reminderCount: reminderCount ?? this.reminderCount,
        pendingUpdateLabel: identical(pendingUpdateLabel, _sentinel)
            ? this.pendingUpdateLabel
            : pendingUpdateLabel as String?,
        sessions: sessions ?? this.sessions,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        isOffline: isOffline ?? this.isOffline,
      );

  static const _sentinel = Object();
}

class MoreController extends Notifier<AsyncValue<MoreState>> {
  static const _pageSize = 20;

  @override
  AsyncValue<MoreState> build() {
    ref.watch(mcSessionGenerationProvider);
    Future.microtask(load);
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _startPolling();
    }
    return const AsyncValue.loading();
  }

  /// 轮询：公告 30s、待更新 10min，仅管理员执行；失败保留旧值。
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

  bool get _isAdmin => ref.read(mcPermissionsProvider).isAdmin;

  /// 待更新文案：'新版本 v<app_version>' 优先，否则 '新识别模型 <model_tag>'。
  String? _pendingLabel(Map<String, dynamic>? pending) {
    if (pending == null) return null;
    final appVersion =
        (pending['appVersion'] ?? pending['app_version'])?.toString().trim();
    if (appVersion != null && appVersion.isNotEmpty) return '新版本 v$appVersion';
    final modelTag =
        (pending['modelTag'] ?? pending['model_tag'])?.toString().trim();
    if (modelTag != null && modelTag.isNotEmpty) return '新识别模型 $modelTag';
    return null;
  }

  Future<void> _refreshNotices() async {
    if (!_isAdmin || !appSession.isReady) return;
    try {
      final notices = await _api.notices();
      final cur = state.valueOrNull;
      if (cur == null) return;
      final count = _visibleCount(notices);
      state = AsyncValue.data(
        cur.copyWith(
          noticeCount: count,
          reminderCount: count + (cur.pendingUpdateLabel != null ? 1 : 0),
          isOffline: false,
        ),
      );
    } catch (_) {
      // 失败保留旧值。
    }
  }

  Future<void> _refreshPendingUpdate() async {
    if (!_isAdmin || !appSession.isReady) return;
    try {
      final pending = await _api.pendingUpdate();
      final cur = state.valueOrNull;
      if (cur == null) return;
      final label = _pendingLabel(pending);
      state = AsyncValue.data(
        cur.copyWith(
          pendingUpdateLabel: label,
          reminderCount: cur.noticeCount + (label != null ? 1 : 0),
          isOffline: false,
        ),
      );
    } catch (_) {
      // 失败保留旧值。
    }
  }

  MoreApi get _api => ref.read(moreApiProvider);

  Future<void> load() async {
    if (!appSession.isReady) {
      state = const AsyncValue.data(MoreState());
      return;
    }
    if (state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    try {
      final session = await _api.me();
      if (session == null) {
        // `/auth/me` 拉取失败：进入离线降级态，允许用户直接管理离线下载。
        final fallback = appSession.permissions.toJson();
        state = AsyncValue.data(
          MoreState(
            session: fallback,
            isOffline: true,
          ),
        );
        return;
      }

      final perms = await appSession.updateFromMeJson(session);

      if (!perms.isAdmin) {
        state = AsyncValue.data(
          MoreState(
            session: session,
            noticeCount: 0,
            reminderCount: 0,
            pendingUpdateLabel: null,
            sessions: const [],
            hasMore: false,
            isOffline: false,
          ),
        );
        return;
      }

      final results = await Future.wait<Object?>([
        _safeNotices(),
        _api.pendingUpdate(),
        _safeSessions(limit: _pageSize, offset: 0),
      ]);
      final notices = results[0] as List<McNotice>;
      final pending = results[1] as Map<String, dynamic>?;
      final sessions = results[2] as List<SessionSummary>;
      final pendingLabel = _pendingLabel(pending);
      final noticeCount = _visibleCount(notices);
      state = AsyncValue.data(
        MoreState(
          session: session,
          noticeCount: noticeCount,
          reminderCount: noticeCount + (pendingLabel != null ? 1 : 0),
          pendingUpdateLabel: pendingLabel,
          sessions: sessions,
          hasMore: sessions.length >= _pageSize,
          isOffline: false,
        ),
      );
    } catch (e, st) {
      if (state.valueOrNull != null) {
        state = AsyncValue.data(state.valueOrNull!.copyWith(isOffline: true));
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<List<McNotice>> _safeNotices() async {
    try {
      return await _api.notices();
    } catch (_) {
      return const [];
    }
  }

  Future<List<SessionSummary>> _safeSessions({
    required int limit,
    required int offset,
  }) async {
    try {
      return await _api.sessions(limit: limit, offset: offset);
    } catch (_) {
      return const [];
    }
  }

  /// visibleNotices：grouped_under 指向某条非空 group_key 的告警折叠不显示。
  int _visibleCount(List<McNotice> notices) {
    final groupKeys = notices
        .map((n) => n.groupKey)
        .whereType<String>()
        .where((k) => k.isNotEmpty)
        .toSet();
    return notices.where((n) {
      final parent = n.groupedUnder;
      return parent == null || parent.isEmpty || !groupKeys.contains(parent);
    }).length;
  }

  Future<void> loadMoreSessions() async {
    if (!_isAdmin) return;
    final cur = state.valueOrNull;
    if (cur == null || cur.loadingMore || !cur.hasMore) return;
    state = AsyncValue.data(cur.copyWith(loadingMore: true));
    try {
      final more =
          await _api.sessions(limit: _pageSize, offset: cur.sessions.length);
      final known = cur.sessions.map((s) => s.id).toSet();
      final merged = [
        ...cur.sessions,
        ...more.where((s) => !known.contains(s.id)),
      ];
      state = AsyncValue.data(
        cur.copyWith(
          sessions: merged,
          hasMore: more.length >= _pageSize,
          loadingMore: false,
        ),
      );
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
    if (!_isAdmin) return;
    try {
      final sessions = await _api.sessions(limit: _pageSize, offset: 0);
      final cur = state.valueOrNull ?? const MoreState();
      state = AsyncValue.data(
        cur.copyWith(
          sessions: sessions,
          hasMore: sessions.length >= _pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {}
  }
}

final moreProvider =
    NotifierProvider<MoreController, AsyncValue<MoreState>>(MoreController.new);
