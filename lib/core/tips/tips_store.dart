import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/mc_client.dart';
import '../api/session_providers.dart';

/// 单条提示的展示与作废记录（字段严格对齐 `API.TipRecordView`）。
class TipRecord {
  const TipRecord({
    required this.tipId,
    this.displayCount = 0,
    this.firstDisplayedAt,
    this.lastDisplayedAt,
    this.invalidatedAt,
    this.invalidatedReason,
  });

  final String tipId;
  final int displayCount;
  final String? firstDisplayedAt;
  final String? lastDisplayedAt;
  final String? invalidatedAt;
  final String? invalidatedReason;

  bool get isInvalidated => invalidatedAt != null && invalidatedAt!.isNotEmpty;

  TipRecord copyWith({
    int? displayCount,
    String? firstDisplayedAt,
    String? lastDisplayedAt,
    String? invalidatedAt,
    String? invalidatedReason,
  }) =>
      TipRecord(
        tipId: tipId,
        displayCount: displayCount ?? this.displayCount,
        firstDisplayedAt: firstDisplayedAt ?? this.firstDisplayedAt,
        lastDisplayedAt: lastDisplayedAt ?? this.lastDisplayedAt,
        invalidatedAt: invalidatedAt ?? this.invalidatedAt,
        invalidatedReason: invalidatedReason ?? this.invalidatedReason,
      );

  factory TipRecord.fromJson(Map<String, dynamic> j) => TipRecord(
        tipId: (j['tip_id'] ?? j['tipId'] ?? '').toString(),
        displayCount: (j['display_count'] ?? j['displayCount'] ?? 0) is num
            ? ((j['display_count'] ?? j['displayCount'] ?? 0) as num).toInt()
            : 0,
        firstDisplayedAt:
            (j['first_displayed_at'] ?? j['firstDisplayedAt'])?.toString(),
        lastDisplayedAt:
            (j['last_displayed_at'] ?? j['lastDisplayedAt'])?.toString(),
        invalidatedAt:
            (j['invalidated_at'] ?? j['invalidatedAt'])?.toString(),
        invalidatedReason:
            (j['invalidated_reason'] ?? j['invalidatedReason'])?.toString(),
      );
}

/// 提示触发事件计数（字段严格对齐 `API.TipEventView`）。
class TipEvent {
  const TipEvent({
    required this.eventId,
    this.count = 0,
    this.firstAt,
    this.lastAt,
  });

  final String eventId;
  final int count;
  final String? firstAt;
  final String? lastAt;

  TipEvent copyWith({int? count, String? firstAt, String? lastAt}) => TipEvent(
        eventId: eventId,
        count: count ?? this.count,
        firstAt: firstAt ?? this.firstAt,
        lastAt: lastAt ?? this.lastAt,
      );

  factory TipEvent.fromJson(Map<String, dynamic> j) => TipEvent(
        eventId: (j['event_id'] ?? j['eventId'] ?? '').toString(),
        count: (j['count'] ?? 0) is num ? (j['count'] as num).toInt() : 0,
        firstAt: (j['first_at'] ?? j['firstAt'])?.toString(),
        lastAt: (j['last_at'] ?? j['lastAt'])?.toString(),
      );
}

/// 提示作废原因常量（对齐 `TipsStore.swift`）。
abstract final class TipInvalidationReason {
  static const actionPerformed = 'action_performed';
  static const closed = 'closed';
}

/// 账号级提示状态快照。
class TipsState {
  const TipsState({
    this.loaded = false,
    this.ownerKey,
    this.records = const {},
    this.events = const {},
  });

  final bool loaded;
  final String? ownerKey;
  final Map<String, TipRecord> records;
  final Map<String, TipEvent> events;

  /// 这条提示现在能否出现（快照未返回前不出任何提示；已作废永不出现）。
  bool eligible(String tipId) =>
      loaded && !(records[tipId]?.isInvalidated ?? false);

  /// 某事件累计触发次数。
  int eventCount(String eventId) => events[eventId]?.count ?? 0;

  /// 某提示已展示次数。
  int displayCount(String tipId) => records[tipId]?.displayCount ?? 0;

  TipsState copyWith({
    bool? loaded,
    String? ownerKey,
    Map<String, TipRecord>? records,
    Map<String, TipEvent>? events,
  }) =>
      TipsState(
        loaded: loaded ?? this.loaded,
        ownerKey: ownerKey ?? this.ownerKey,
        records: records ?? this.records,
        events: events ?? this.events,
      );
}

/// 使用提示状态引擎（1:1 对齐 iOS `Shared/Tips/TipsStore.swift`）。
///
/// - 快照拉回前不出任何提示；已作废的永不出现；
/// - 换账号后作废旧状态并重新拉取；
/// - 展示/作废/事件上报均采用乐观更新 + 服务端返回行回写，网络失败静默处理。
class TipsStore extends Notifier<TipsState> {
  Future<void>? _inFlight;

  @override
  TipsState build() => const TipsState();

  McClient get _client => ref.read(mcClientProvider);

  String _currentOwnerKey() {
    final session = ref.read(sessionStoreProvider);
    final base = session.baseUrl ?? '';
    final user = session.username.toLowerCase();
    return '$base#$user';
  }

  /// 按当前（或指定）账号拉取提示快照；已拉过则直接返回，失败留待下次重试。
  Future<void> ensureLoaded({String? ownerKey}) async {
    final key = ownerKey ?? _currentOwnerKey();
    if (key != state.ownerKey) {
      _inFlight = null;
      state = TipsState(loaded: false, ownerKey: key);
    }
    if (state.loaded) return;
    if (_inFlight != null) {
      await _inFlight;
      return;
    }

    final future = () async {
      try {
        final raw = await _client.unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/tips/state',
        );
        if (state.ownerKey != key) return;
        final records = <String, TipRecord>{};
        final rawTips = raw['tips'];
        if (rawTips is List) {
          for (final item in rawTips) {
            if (item is Map) {
              final rec = TipRecord.fromJson(item.cast<String, dynamic>());
              if (rec.tipId.isNotEmpty) records[rec.tipId] = rec;
            }
          }
        }
        final events = <String, TipEvent>{};
        final rawEvents = raw['events'];
        if (rawEvents is List) {
          for (final item in rawEvents) {
            if (item is Map) {
              final ev = TipEvent.fromJson(item.cast<String, dynamic>());
              if (ev.eventId.isNotEmpty) events[ev.eventId] = ev;
            }
          }
        }
        state = TipsState(
          loaded: true,
          ownerKey: key,
          records: Map.unmodifiable(records),
          events: Map.unmodifiable(events),
        );
      } catch (_) {
        // 旧服务器未实现接口或网络异常时静默：保持 loaded=false，不出提示。
      } finally {
        if (state.ownerKey == key) {
          _inFlight = null;
        }
      }
    }();
    _inFlight = future;
    await future;
  }

  /// 这条提示现在能不能出现。
  bool eligible(String tipId) => state.eligible(tipId);

  /// 记一次提示上屏展示（`POST /api/v1/tips/{tipId}/displays`）。
  Future<void> recordDisplay(String tipId) async {
    final key = state.ownerKey;
    final prev = state.records[tipId] ?? TipRecord(tipId: tipId);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final optimistic = prev.copyWith(
      displayCount: prev.displayCount + 1,
      firstDisplayedAt: prev.firstDisplayedAt ?? nowIso,
      lastDisplayedAt: nowIso,
    );
    _upsertRecord(optimistic);

    try {
      final raw = await _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/tips/${Uri.encodeComponent(tipId)}/displays',
      );
      if (state.ownerKey != key) return;
      final serverRow = TipRecord.fromJson(raw);
      if (serverRow.tipId.isNotEmpty) {
        _upsertRecord(serverRow);
      }
    } catch (_) {}
  }

  /// 作废提示（`POST /api/v1/tips/{tipId}/invalidate`）。
  ///
  /// [reason] 取值：`'action_performed'`（用户使用了功能）或 `'closed'`（用户手动关闭）。
  Future<void> invalidate(
    String tipId, {
    String reason = TipInvalidationReason.closed,
  }) async {
    final key = state.ownerKey;
    final prev = state.records[tipId] ?? TipRecord(tipId: tipId);
    if (prev.isInvalidated) return;

    final optimistic = prev.copyWith(
      invalidatedAt: DateTime.now().toUtc().toIso8601String(),
      invalidatedReason: reason,
    );
    _upsertRecord(optimistic);

    try {
      final raw = await _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/tips/${Uri.encodeComponent(tipId)}/invalidate',
        body: {'reason': reason},
      );
      if (state.ownerKey != key) return;
      final serverRow = TipRecord.fromJson(raw);
      if (serverRow.tipId.isNotEmpty) {
        _upsertRecord(serverRow);
      }
    } catch (_) {}
  }

  /// 上报一个提示事件（`POST /api/v1/tips/events/{eventId}`）。
  Future<void> donateEvent(String eventId) async {
    final key = state.ownerKey;
    final prev = state.events[eventId] ?? TipEvent(eventId: eventId);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final optimistic = prev.copyWith(
      count: prev.count + 1,
      firstAt: prev.firstAt ?? nowIso,
      lastAt: nowIso,
    );
    _upsertEvent(optimistic);

    try {
      final raw = await _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/tips/events/${Uri.encodeComponent(eventId)}',
      );
      if (state.ownerKey != key) return;
      final serverRow = TipEvent.fromJson(raw);
      if (serverRow.eventId.isNotEmpty) {
        _upsertEvent(serverRow);
      }
    } catch (_) {}
  }

  /// 重置全部提示状态（`DELETE /api/v1/tips/state`），所有提示恢复按条件出现。
  Future<bool> resetState() async {
    try {
      final res = await _client.delete(Channel.general, '/api/v1/tips/state');
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        state = TipsState(
          loaded: true,
          ownerKey: state.ownerKey ?? _currentOwnerKey(),
          records: const {},
          events: const {},
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _upsertRecord(TipRecord record) {
    final next = Map<String, TipRecord>.from(state.records);
    next[record.tipId] = record;
    state = state.copyWith(records: Map.unmodifiable(next));
  }

  void _upsertEvent(TipEvent event) {
    final next = Map<String, TipEvent>.from(state.events);
    next[event.eventId] = event;
    state = state.copyWith(events: Map.unmodifiable(next));
  }
}

final tipsStoreProvider =
    NotifierProvider<TipsStore, TipsState>(TipsStore.new);
