import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

/// 订阅域 API 单例。
final subscriptionsApiProvider = Provider<SubscriptionsApi>(
    (ref) => SubscriptionsApi(ref.watch(sessionStoreProvider)));

/// 订阅域的 API 封装：统一走 McClient（Channel.general），对应 Kotlin McApi.kt
/// 的 subscriptions / rule-sets 段。
class SubscriptionsApi {
  SubscriptionsApi(this._session);

  final SessionStore _session;
  McClient? _client;

  McClient get client => _client ??= McClient(session: _session);

  static const _prefix = '/api/v1';

  /// GET /subscriptions（?kind=movie|tv 可收窄）
  Future<List<SubscriptionView>> subscriptions({String? kind}) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/subscriptions',
      query: {if (kind != null) 'kind': kind},
    );
    return (body as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionView.fromJson)
        .toList();
  }

  /// GET /subscriptions/{id}（详情，含 wanted 工单明细）
  Future<SubscriptionView> subscription(int id) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/subscriptions/$id',
    );
    return SubscriptionView.fromJson(body);
  }

  /// POST /subscriptions/title-preview（幂等预检）
  Future<PrepareView> titlePreview(String titleRef) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/subscriptions/title-preview',
      body: {'title_ref': titleRef},
    );
    return PrepareView.fromJson(body);
  }

  /// POST /subscriptions；重复订阅幂等返回已有订阅。
  Future<SubscriptionView> create({
    required String titleRef,
    required List<int> selectedSeasons,
    bool followFuture = false,
    int? ruleSetId,
    String? selectionMode,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/subscriptions',
      body: {
        'title_ref': titleRef,
        'selected_seasons': selectedSeasons,
        'follow_future': followFuture,
        if (ruleSetId != null) 'rule_set_id': ruleSetId,
        if (selectionMode != null) 'selection_mode': selectionMode,
      },
    );
    final sub = body['subscription'];
    return sub is Map<String, dynamic>
        ? SubscriptionView.fromJson(sub)
        : SubscriptionView.fromJson(body);
  }

  /// PATCH /subscriptions/{id}：只带改动字段（selected_seasons / rule_set_id…）。
  Future<void> update(int id, Map<String, dynamic> patch) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PATCH',
        '$_prefix/subscriptions/$id',
        body: patch,
      );

  /// PATCH /subscriptions/{id}/tracking-state：paused / active。
  Future<void> setTrackingState(int id, {required bool paused}) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PATCH',
        '$_prefix/subscriptions/$id/tracking-state',
        body: {'state': paused ? 'paused' : 'active'},
      );

  /// PATCH /subscriptions/{id}/follow-future：服务端字段名是 enabled。
  Future<void> setFollowFuture(int id, {required bool enabled}) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PATCH',
        '$_prefix/subscriptions/$id/follow-future',
        body: {'enabled': enabled},
      );

  /// DELETE /subscriptions/{id}（不动已下载内容）。
  Future<void> delete(int id) => client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'DELETE',
        '$_prefix/subscriptions/$id',
      );

  /// POST /subscriptions/{id}/missing-resource-searches（手动立即搜索）。
  Future<void> searchNow(int id) => client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '$_prefix/subscriptions/$id/missing-resource-searches',
      );

  /// POST /subscriptions/{id}/upgrade-runs（洗版；成员不带 rule_set_id 沿用当前组）。
  Future<void> upgradeRun(int id, {int? ruleSetId}) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '$_prefix/subscriptions/$id/upgrade-runs',
        body: {if (ruleSetId != null) 'rule_set_id': ruleSetId},
      );

  /// GET /subscriptions/{id}/activities?limit=50 → 活动时间线。
  Future<List<SubActivityView>> activities(int id, {int limit = 50}) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/subscriptions/$id/activities',
      query: {'limit': limit},
    );
    return (body as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SubActivityView.fromJson)
        .toList();
  }

  /// GET /rule-sets（超管专属；成员别打这一枪）。
  Future<List<RuleSetView>> ruleSets() async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/rule-sets',
    );
    return (body as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RuleSetView.fromJson)
        .toList();
  }

  // ── 订阅首页（对齐鸿蒙 SubscriptionsPage 的数据口径） ──

  /// GET /subscriptions/today-arrivals?window=week → 今天起一周的到达。
  Future<List<TodayArrivalView>> todayArrivals({String window = 'week'}) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/subscriptions/today-arrivals',
      query: {'window': window},
    );
    return (body as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TodayArrivalView.fromJson)
        .toList();
  }

  /// GET /subscriptions/recent-arrivals?days=7&limit=20 → 刚刚入库。
  Future<List<RecentArrivalView>> recentArrivals(
      {int days = 7, int limit = 20}) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/subscriptions/recent-arrivals',
      query: {'days': days, 'limit': limit},
    );
    return (body as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RecentArrivalView.fromJson)
        .toList();
  }

  /// GET /downloaders/tasks → 下载任务 ETA map（仅管理员；失败由调用方兜底）。
  Future<List<DownloadTaskView>> downloadTasks() async {
    final body = await client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/downloaders/tasks',
    );
    final items = body is List<dynamic>
        ? body
        : (body as Map<String, dynamic>)['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(DownloadTaskView.fromJson)
        .toList();
  }

  /// GET /libraries?kind=&scope=all → 媒体库（海报墙「规则组→媒体库」用）。
  Future<List<LibraryBrief>> libraries({String? kind}) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries',
      query: {if (kind != null) 'kind': kind, 'scope': 'all'},
    );
    return (body as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LibraryBrief.fromJson)
        .toList();
  }

  /// GET /subscriptions/{id}/items（订阅墙）。
  Future<List<WallItem>> subscriptionItems(int id) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/subscriptions/$id/items',
    );
    return (body as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WallItem.new)
        .toList();
  }
}
