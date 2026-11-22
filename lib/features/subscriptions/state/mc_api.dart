import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_api.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/models.dart' as core;
import '../../../core/api/session_providers.dart';
import 'models.dart';

/// 订阅域 API 单例。
final subscriptionsApiProvider = Provider<SubscriptionsApi>((ref) =>
    SubscriptionsApi(ref.watch(mcApiProvider), ref.watch(mcClientProvider)));

/// 订阅域 API（P1 薄代理）：方法签名与返回的本域模型不变，调用全部委托给
/// 核心层 [McApi]（类型化端点 + freezed 模型），再经 `toJson/fromJson` 转回
/// 本域模型。本文件不再自建 McClient、不再拼路径、不再手写信封解包。
/// 例外（见 P1-core.md）：[subscriptionItems] 调用的
/// GET /subscriptions/{id}/items 在安卓接口表与服务端路由中均未找到，
/// McApi 无此方法，暂直调 [McClient] 保持原行为，待服务端确认。
class SubscriptionsApi {
  SubscriptionsApi(this._api, this._client);

  final McApi _api;
  final McClient _client;

  static List<T> _convList<T, C>(
    List<C> items,
    T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic> Function(C) toJson,
  ) =>
      items.map((e) => fromJson(toJson(e))).toList();

  /// GET /subscriptions（?kind=movie|tv 可收窄）
  Future<List<SubscriptionView>> subscriptions({String? kind}) async =>
      _convList(await _api.subscriptions(kind: kind),
          SubscriptionView.fromJson, (core.SubscriptionView e) => e.toJson());

  /// GET /subscriptions/{id}（详情，含 wanted 工单明细）
  Future<SubscriptionView> subscription(int id) async =>
      SubscriptionView.fromJson((await _api.subscription(id)).toJson());

  /// POST /subscriptions/title-preview（幂等预检）
  Future<PrepareView> titlePreview(String titleRef) async =>
      PrepareView.fromJson((await _api.titlePreview(
              body: core.TitlePreviewRequest(titleRef: titleRef)))
          .toJson());

  /// POST /subscriptions；重复订阅幂等返回已有订阅。
  Future<SubscriptionView> create({
    required String titleRef,
    required List<int> selectedSeasons,
    bool followFuture = false,
    int? ruleSetId,
    String? selectionMode,
  }) async {
    final result = await _api.createSubscription(
        body: core.SubscriptionCreateRequest(
            titleRef: titleRef,
            selectedSeasons: selectedSeasons,
            followFuture: followFuture,
            ruleSetId: ruleSetId,
            selectionMode: selectionMode));
    return SubscriptionView.fromJson(result.subscription.toJson());
  }

  /// PATCH /subscriptions/{id}：只带改动字段（selected_seasons / rule_set_id…）。
  Future<void> update(int id, Map<String, dynamic> patch) =>
      _api.updateSubscription(id, body: patch);

  /// PATCH /subscriptions/{id}/tracking-state：paused / active。
  Future<void> setTrackingState(int id, {required bool paused}) =>
      _api.setTrackingState(id,
          body: core.TrackingStateRequest(
              state: paused ? 'paused' : 'active'));

  /// PATCH /subscriptions/{id}/follow-future：服务端字段名是 enabled。
  Future<void> setFollowFuture(int id, {required bool enabled}) =>
      _api.setFollowFuture(id,
          body: core.FollowFutureRequest(enabled: enabled));

  /// DELETE /subscriptions/{id}（不动已下载内容）。
  Future<void> delete(int id) => _api.deleteSubscription(id);

  /// POST /subscriptions/{id}/missing-resource-searches（手动立即搜索）。
  Future<void> searchNow(int id) => _api.searchMissingResources(id);

  /// POST /subscriptions/{id}/upgrade-runs（洗版；成员不带 rule_set_id 沿用当前组）。
  Future<void> upgradeRun(int id, {int? ruleSetId}) => _api.upgradeRun(id,
      body: core.UpgradeRunPayload(ruleSetId: ruleSetId));

  /// GET /subscriptions/{id}/activities?limit=50 → 活动时间线。
  Future<List<SubActivityView>> activities(int id, {int limit = 50}) async =>
      _convList(await _api.subscriptionActivities(id, limit: limit),
          SubActivityView.fromJson, (core.SubActivityView e) => e.toJson());

  /// GET /rule-sets（超管专属；成员别打这一枪）。
  Future<List<RuleSetView>> ruleSets() async => _convList(
      await _api.ruleSets(),
      RuleSetView.fromJson,
      (core.RuleSetView e) => e.toJson());

  // ── 订阅首页（对齐鸿蒙 SubscriptionsPage 的数据口径） ──

  /// GET /subscriptions/today-arrivals?window=week → 今天起一周的到达。
  Future<List<TodayArrivalView>> todayArrivals(
          {String window = 'week'}) async =>
      _convList(await _api.todayArrivals(window: window),
          TodayArrivalView.fromJson, (core.TodayArrival e) => e.toJson());

  /// GET /subscriptions/recent-arrivals?days=7&limit=20 → 刚刚入库。
  Future<List<RecentArrivalView>> recentArrivals(
      {int days = 7, int limit = 20}) async {
    final items =
        await _api.recentArrivals(days: days, limit: limit);
    return _convList(items, RecentArrivalView.fromJson,
        (core.RecentArrivalView e) => e.toJson());
  }

  /// GET /downloaders/tasks → 下载任务 ETA map（仅管理员；失败由调用方兜底）。
  Future<List<DownloadTaskView>> downloadTasks() async {
    final list = await _api.downloadTasks();
    return _convList(list.items, DownloadTaskView.fromJson,
        (core.DownloadTask e) => e.toJson());
  }

  /// GET /libraries?kind=&scope=all → 媒体库（海报墙「规则组→媒体库」用）。
  Future<List<LibraryBrief>> libraries({String? kind}) async {
    final items = await _api.libraries(kind: kind, scope: 'all');
    return _convList(items, LibraryBrief.fromJson,
        (core.LibraryView e) => e.toJson());
  }

  /// GET /subscriptions/{id}/items（订阅墙）。
  /// 未确认端点：安卓 McApi.kt 与服务端路由均未见此路径，McApi 无对应方法；
  /// 暂直调 McClient 保持原行为（404 时由调用方处理），待服务端确认后再收敛。
  Future<List<WallItem>> subscriptionItems(int id) async {
    final body = await _client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/subscriptions/$id/items',
    );
    return (body as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WallItem.new)
        .toList();
  }
}
