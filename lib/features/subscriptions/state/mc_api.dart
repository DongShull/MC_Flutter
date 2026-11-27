import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/api/subscriptions_api.dart' as core_api;
import '../../../core/session/session_store.dart';
import 'models.dart';

/// 订阅域 API 单例。
final subscriptionsApiProvider = Provider<SubscriptionsApi>(
  (ref) => SubscriptionsApi(ref.watch(sessionStoreProvider)),
);

/// 订阅域完整 API 封装（1:1 对齐 iOS `Endpoints.swift` 与 `SubscriptionsAPI.swift`）。
class SubscriptionsApi {
  SubscriptionsApi(this._session);

  final SessionStore _session;
  McClient? _client;
  core_api.SubscriptionsApi? _core;

  McClient get client => _client ??= McClient(session: _session);
  core_api.SubscriptionsApi get core =>
      _core ??= core_api.SubscriptionsApi(client);

  static const _prefix = '/api/v1';

  /// `GET /subscriptions`（`?kind=movie|tv` 可收窄）
  Future<List<SubscriptionView>> subscriptions({String? kind}) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/subscriptions',
      query: {if (kind != null) 'kind': kind},
    );
    return body
        .whereType<Map>()
        .map((e) => SubscriptionView.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// `GET /subscriptions/{id}`（详情，含 wanted 工单、smart 策略与 forecast_pending）
  Future<SubscriptionView> subscription(int id) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/subscriptions/$id',
    );
    return SubscriptionView.fromJson(body);
  }

  /// `GET /subscriptions/{id}/active-downloads`（实时下载进度，兼容旧版 `/downloads` 回退）
  Future<List<SubscriptionDownloadView>> activeDownloads(int id) async {
    try {
      final body = await client.unwrap<List<dynamic>>(
        Channel.live,
        'GET',
        '$_prefix/subscriptions/$id/active-downloads',
      );
      return body
          .whereType<Map>()
          .map(
            (e) =>
                SubscriptionDownloadView.fromJson(e.cast<String, dynamic>()),
          )
          .toList();
    } on ApiException catch (e) {
      if (e.httpStatus != 404) rethrow;
      final body = await client.unwrap<List<dynamic>>(
        Channel.live,
        'GET',
        '$_prefix/subscriptions/$id/downloads',
      );
      return body
          .whereType<Map>()
          .map(
            (e) =>
                SubscriptionDownloadView.fromJson(e.cast<String, dynamic>()),
          )
          .toList();
    }
  }

  /// `POST /subscriptions/title-preview`（幂等预检）
  Future<PrepareView> titlePreview(String titleRef) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/subscriptions/title-preview',
      body: {'title_ref': titleRef},
    );
    return PrepareView.fromJson(body);
  }

  /// `PATCH /subscriptions/{id}`：支持显式传 `{'library_id': null}` 清除指定库！
  Future<void> update(int id, Map<String, dynamic> patch) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PATCH',
        '$_prefix/subscriptions/$id',
        body: patch,
      );

  /// `PATCH /subscriptions/{id}/tracking-state`：`paused` / `active`
  Future<void> setTrackingState(int id, {required bool paused}) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PATCH',
        '$_prefix/subscriptions/$id/tracking-state',
        body: {'state': paused ? 'paused' : 'active'},
      );

  /// `PATCH /subscriptions/{id}/follow-future`：`{'enabled': bool}`
  Future<void> setFollowFuture(int id, {required bool enabled}) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PATCH',
        '$_prefix/subscriptions/$id/follow-future',
        body: {'enabled': enabled},
      );

  /// 管理员永久删除：`DELETE /subscriptions/{id}?delete_torrents=&delete_library_files=`
  Future<core_api.SubscriptionDeleteView> delete(
    int id, {
    bool deleteTorrents = false,
    bool deleteLibraryFiles = false,
  }) =>
      core.deleteSubscription(
        id,
        deleteTorrents: deleteTorrents,
        deleteLibraryFiles: deleteLibraryFiles,
      );

  /// 成员取消关注：`DELETE /subscriptions/{id}/following`（自动兼容旧版）
  Future<void> unsubscribeFollowing(int id) => core.unsubscribeFollowing(id);

  /// 移除/减季清理预览：`GET /subscriptions/{id}/removal-preview`
  Future<core_api.SubscriptionRemovalPreviewView> removalPreview(
    int id, {
    List<int>? seasons,
  }) =>
      core.removalPreview(id, seasons: seasons);

  /// 减季清理：`POST /subscriptions/{id}/season-cleanup`
  Future<core_api.SubscriptionDeleteView> cleanupSeasons(
    int id, {
    required List<int> seasons,
    bool deleteTorrents = false,
    bool deleteLibraryFiles = false,
  }) =>
      core.cleanupSeasons(
        id,
        seasons: seasons,
        deleteTorrents: deleteTorrents,
        deleteLibraryFiles: deleteLibraryFiles,
      );

  /// `POST /subscriptions/{id}/missing-resource-searches`（返回 `reset_count`）
  Future<int> searchNow(int id) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/subscriptions/$id/missing-resource-searches',
    );
    return (body['reset_count'] as num?)?.toInt() ?? 0;
  }

  /// `POST /subscriptions/{id}/upgrade-runs`（返回完整体检报告 `UpgradeRunView`）
  Future<core_api.UpgradeRunView> upgradeRun(int id, {int? ruleSetId}) =>
      core.upgradeRun(id, ruleSetId: ruleSetId);

  /// `GET /subscriptions/{id}/activities?limit=100`
  Future<List<SubActivityView>> activities(int id, {int limit = 100}) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/subscriptions/$id/activities',
      query: {'limit': limit},
    );
    return body
        .whereType<Map>()
        .map((e) => SubActivityView.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// `GET /rule-sets`（超管专属）
  Future<List<RuleSetView>> ruleSets() async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/rule-sets',
    );
    return body
        .whereType<Map>()
        .map((e) => RuleSetView.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// `POST /subscriptions/{id}/wanted/{wantedId}/smart-wait`
  Future<void> changeSmartWait({
    required int subscriptionId,
    required int wantedId,
    required core_api.SmartWaitPayload payload,
  }) =>
      core.changeSmartWait(
        subscriptionId: subscriptionId,
        wantedId: wantedId,
        payload: payload,
      );

  /// `GET /subscriptions/smart-memory` & `PATCH /subscriptions/smart-memory`
  Future<core_api.SmartMemoryView?> getSmartMemory() => core.getSmartMemory();
  Future<core_api.SmartMemoryView> updateSmartMemory(
    core_api.SmartMemoryPatch patch,
  ) =>
      core.updateSmartMemory(patch);

  /// 投递路由预检
  Future<core_api.DispatchPreviewView> downloadRoutingPreview({
    required String kind,
    int? libraryId,
    int? tmdbId,
    String? title,
    int? year,
  }) =>
      core.downloadRoutingPreview(
        kind: kind,
        libraryId: libraryId,
        tmdbId: tmdbId,
        title: title,
        year: year,
      );

  /// 片源标注候选与提交
  Future<List<core_api.MediaSourceAnnotationCandidateView>>
      mediaSourceAnnotationCandidates({
    required int mediaItemId,
    required int seasonNumber,
  }) =>
          core.mediaSourceAnnotationCandidates(
            mediaItemId: mediaItemId,
            seasonNumber: seasonNumber,
          );

  Future<int> annotateMediaSource({
    required int mediaItemId,
    required int seasonNumber,
    required String mediaSource,
  }) =>
      core.annotateMediaSource(
        mediaItemId: mediaItemId,
        seasonNumber: seasonNumber,
        mediaSource: mediaSource,
      );

  // ── 订阅首页 ──

  /// `GET /subscriptions/today-arrivals?window=week`
  Future<List<TodayArrivalView>> todayArrivals({String window = 'week'}) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/subscriptions/today-arrivals',
      query: {'window': window},
    );
    return body
        .whereType<Map>()
        .map((e) => TodayArrivalView.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// `GET /subscriptions/recent-arrivals?days=7&limit=20`
  Future<List<RecentArrivalView>> recentArrivals({
    int days = 7,
    int limit = 20,
  }) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/subscriptions/recent-arrivals',
      query: {'days': days, 'limit': limit},
    );
    return body
        .whereType<Map>()
        .map((e) => RecentArrivalView.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// `GET /downloaders/tasks`（仅管理员）
  Future<List<DownloadTaskView>> downloadTasks() async {
    final body = await client.unwrap<dynamic>(
      Channel.live,
      'GET',
      '$_prefix/downloaders/tasks',
    );
    final items = body is List<dynamic>
        ? body
        : (body as Map)['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map>()
        .map((e) => DownloadTaskView.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// `GET /libraries?kind=&scope=all`
  Future<List<LibraryBrief>> libraries({String? kind}) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/libraries',
      query: {if (kind != null) 'kind': kind, 'scope': 'all'},
    );
    return body
        .whereType<Map>()
        .map((e) => LibraryBrief.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 兼容保留：`GET /subscriptions/{id}/items`
  Future<List<WallItem>> subscriptionItems(int id) async {
    final body = await client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/subscriptions/$id/items',
    );
    return body
        .whereType<Map>()
        .map((e) => WallItem(e.cast<String, dynamic>()))
        .toList();
  }
}
