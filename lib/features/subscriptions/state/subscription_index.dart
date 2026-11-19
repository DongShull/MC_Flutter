import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mc_api.dart';
import 'models.dart';
import 'subscription_events.dart';

/// 全站订阅索引（对齐 SubscriptionIndex.kt）：GET /subscriptions 建
/// tmdb:{kind}:{id} → SubscriptionView 查表；30s 缓存，代次防过期写回。
class SubscriptionIndex {
  SubscriptionIndex(this._ref);

  final Ref _ref;

  Map<String, SubscriptionView>? _map;
  DateTime? _loadedAt;
  int _loadedRevision = -1;
  int _generation = 0;

  static String keyOf(String kind, int tmdbId) => 'tmdb:$kind:$tmdbId';

  /// ensureLoaded：30s 缓存 + 订阅事件代次失效。
  Future<Map<String, SubscriptionView>> ensureLoaded() async {
    final rev = SubscriptionEvents.revision;
    final cached = _map;
    if (cached != null &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(seconds: 30) &&
        _loadedRevision == rev) {
      return cached;
    }
    final gen = ++_generation;
    try {
      final subs = await _ref.read(subscriptionsApiProvider).subscriptions();
      if (gen != _generation) return _map ?? const {}; // 已失效，丢弃过期写回
      final next = <String, SubscriptionView>{
        for (final s in subs)
          if (s.media.tmdbId != null) keyOf(s.media.kind, s.media.tmdbId!): s,
      };
      _map = next;
      _loadedAt = DateTime.now();
      _loadedRevision = rev;
      return next;
    } catch (_) {
      return _map ?? const {};
    }
  }

  /// 取消订阅成功后的精确摘除（比「重拉一次」更及时：DELETE 刚成功时列表接口
  /// 还可能返回刚删掉的那条，光重拉会把卡片画回「已订阅」）。
  void remove(int subscriptionId) {
    final map = _map;
    if (map == null) return;
    map.removeWhere((_, s) => s.id == subscriptionId);
    SubscriptionEvents.notifyChanged();
  }

  /// 全量失效（新建订阅后调用）。
  void invalidate() {
    _map = null;
    _loadedAt = null;
    SubscriptionEvents.notifyChanged();
  }

  /// findIn：按 tmdb id + kind 查询。
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
