import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/session_providers.dart';
import '../../../core/storage/page_snapshots.dart';
import 'mc_api.dart';
import 'models.dart';
import 'subscription_events.dart';

/// 全站订阅索引（1:1 对齐 iOS `SubscriptionIndex.swift`）：
/// - `GET /subscriptions` 建三张查表索引：`byDouban`、`byTmdbTyped`（`tmdb:{kind}:{id}`）、`byTmdb`；
/// - 按 `origin|username` 账号隔离，并持久化到 `PageSnapshots` 实现冷启动首帧恢复；
/// - 30s 缓存 + 订阅事件代次失效 + 并发请求合并。
class SubscriptionIndex {
  SubscriptionIndex(this._ref);

  final Ref _ref;

  static const _snapshotName = 'subscriptions';

  List<SubscriptionView>? _list;
  Map<String, SubscriptionView>? _byTmdbTyped;
  Map<String, SubscriptionView> _byTmdb = {};
  Map<String, SubscriptionView> _byDouban = {};

  String? _ownerKey;
  DateTime? _loadedAt;
  int _loadedRevision = -1;
  int _generation = 0;
  Future<Map<String, SubscriptionView>>? _inFlight;

  static String keyOf(String kind, int tmdbId) => 'tmdb:$kind:$tmdbId';

  List<SubscriptionView>? get subscriptions => _list;

  ({String origin, String username, String ownerKey}) _currentOwner() {
    final session = _ref.read(sessionStoreProvider);
    final origin = session.baseUrl ?? '';
    final username = session.accountUsername;
    return (
      origin: origin,
      username: username,
      ownerKey: PageSnapshots.ownerKey(origin: origin, username: username),
    );
  }

  void _adoptOwnerIfNeeded() {
    final cur = _currentOwner();
    if (_ownerKey == cur.ownerKey) return;
    _ownerKey = cur.ownerKey;
    _list = null;
    _byTmdbTyped = null;
    _byTmdb = {};
    _byDouban = {};
    _loadedAt = null;
    _loadedRevision = -1;
    _inFlight = null;
    _generation++;
  }

  /// 尝试从磁盘快照预热（不计作刚拉过网络）。
  Future<void> restoreSnapshot() async {
    _adoptOwnerIfNeeded();
    if (_list != null) return;
    final cur = _currentOwner();
    if (cur.origin.isEmpty || cur.username.isEmpty) return;
    final snap = await PageSnapshots.read<List<SubscriptionView>>(
      _snapshotName,
      origin: cur.origin,
      username: cur.username,
      fromJson: (json) {
        if (json is! List) return const [];
        return json
            .whereType<Map>()
            .map((e) => SubscriptionView.fromJson(e.cast<String, dynamic>()))
            .toList();
      },
    );
    if (snap != null && _ownerKey == cur.ownerKey && _list == null) {
      _apply(snap, fresh: false, revision: _loadedRevision);
    }
  }

  void _apply(
    List<SubscriptionView> subs, {
    required bool fresh,
    required int revision,
  }) {
    final typed = <String, SubscriptionView>{};
    final plain = <String, SubscriptionView>{};
    final douban = <String, SubscriptionView>{};
    for (final s in subs) {
      final did = s.media.doubanId;
      if (did != null && did.isNotEmpty) {
        douban.putIfAbsent(did, () => s);
      }
      final tid = s.media.tmdbId;
      if (tid != null) {
        typed.putIfAbsent(keyOf(s.media.kind, tid), () => s);
        plain.putIfAbsent('$tid', () => s);
      }
    }
    _list = subs;
    _byTmdbTyped = typed;
    _byTmdb = plain;
    _byDouban = douban;
    if (fresh) {
      _loadedAt = DateTime.now();
      _loadedRevision = revision;
    }
  }

  /// `ensureLoaded`：30s 缓存 + 订阅事件代次失效 + 账号切换自动隔离。
  Future<Map<String, SubscriptionView>> ensureLoaded() async {
    _adoptOwnerIfNeeded();
    final rev = SubscriptionEvents.revision;
    final cached = _byTmdbTyped;
    if (cached != null &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(seconds: 30) &&
        _loadedRevision == rev) {
      return cached;
    }
    if (_inFlight != null) return _inFlight!;

    final cur = _currentOwner();
    final gen = ++_generation;
    final Future<Map<String, SubscriptionView>> task = () async {
      try {
        final subs = await _ref.read(subscriptionsApiProvider).subscriptions();
        if (gen != _generation || _ownerKey != cur.ownerKey) {
          return _byTmdbTyped ?? const <String, SubscriptionView>{};
        }
        _apply(subs, fresh: true, revision: rev);
        if (cur.origin.isNotEmpty && cur.username.isNotEmpty) {
          unawaited(
            PageSnapshots.write(
              _snapshotName,
              subs.map((s) => s.toJson()).toList(),
              origin: cur.origin,
              username: cur.username,
            ),
          );
        }
        return _byTmdbTyped ?? const <String, SubscriptionView>{};
      } catch (_) {
        return _byTmdbTyped ?? const <String, SubscriptionView>{};
      } finally {
        _inFlight = null;
      }
    }();
    _inFlight = task;
    return task;
  }

  /// 按 `source` / `externalId` / `mediaType` O(1) 查询（支持豆瓣与 TMDB）。
  SubscriptionView? lookup({
    String? source,
    required String externalId,
    String? mediaType,
  }) {
    _adoptOwnerIfNeeded();
    if ((source ?? 'tmdb') == 'douban') {
      return _byDouban[externalId];
    }
    if (mediaType == 'movie' || mediaType == 'tv') {
      final id = int.tryParse(externalId);
      if (id != null) return _byTmdbTyped?[keyOf(mediaType!, id)];
    }
    return _byTmdb[externalId];
  }

  /// 按豆瓣 ID 精确查找已订阅条目。
  SubscriptionView? byDouban(String doubanId) {
    _adoptOwnerIfNeeded();
    return _byDouban[doubanId];
  }

  /// 同步外部拉取到的全量订阅列表（避免首页与索引重复请求）。
  void ingest(List<SubscriptionView> subs) {
    _adoptOwnerIfNeeded();
    final cur = _currentOwner();
    _apply(subs, fresh: true, revision: SubscriptionEvents.revision);
    if (cur.origin.isNotEmpty && cur.username.isNotEmpty) {
      unawaited(
        PageSnapshots.write(
          _snapshotName,
          subs.map((s) => s.toJson()).toList(),
          origin: cur.origin,
          username: cur.username,
        ),
      );
    }
  }

  /// 取消订阅成功后的精确摘除。
  void remove(int subscriptionId) {
    _list?.removeWhere((s) => s.id == subscriptionId);
    _byTmdbTyped?.removeWhere((_, s) => s.id == subscriptionId);
    _byTmdb.removeWhere((_, s) => s.id == subscriptionId);
    _byDouban.removeWhere((_, s) => s.id == subscriptionId);
    SubscriptionEvents.notifyChanged();
  }

  /// 全量失效（新建或修改订阅后调用）。
  void invalidate() {
    _byTmdbTyped = null;
    _loadedAt = null;
    _inFlight = null;
    SubscriptionEvents.notifyChanged();
  }

  /// `findIn`：按 tmdb id + kind 查询（保持既有静态调用兼容）。
  static SubscriptionView? findIn(
    Map<String, SubscriptionView> map, {
    required String kind,
    required int tmdbId,
  }) =>
      map[keyOf(kind, tmdbId)];
}

/// 订阅索引 provider（应用级复用同一实例）。
final subscriptionIndexProvider = Provider<SubscriptionIndex>(
  (ref) => SubscriptionIndex(ref),
);
