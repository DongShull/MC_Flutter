import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

final activityApiProvider =
    Provider<ActivityApi>((ref) => ActivityApi(ref.watch(sessionStoreProvider)));

/// 活动域 API 封装（1:1 对齐 iOS `Endpoints.swift` + `NowPlayingRows.swift` + `ActivityStores.swift`）。
class ActivityApi {
  ActivityApi(this._session);

  final SessionStore _session;
  McClient? _client;

  McClient get client => _client ??= McClient(session: _session);

  static const _prefix = '/api/v1';

  /// GET /jobs（后台任务快照）。
  Future<List<JobView>> jobs({bool? activeOnly, int? limit}) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/jobs',
      query: {
        if (activeOnly != null) 'active_only': activeOnly,
        if (limit != null) 'limit': limit,
      },
    );
    return ((body['items'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((e) => JobView.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 并行拉取 `active_only=true&limit=200` + `limit=50` 并按 id 去重合并、按 updated_at 倒序排，
  /// 防止长耗时任务被大量近期完成的记录挤出视野（对齐 iOS `TaskActivityStore.refreshJobs`）。
  Future<List<JobView>> jobsMerged() async {
    final results = await Future.wait([
      jobs(activeOnly: true, limit: 200),
      jobs(limit: 50),
    ]);
    final merged = <String, JobView>{};
    for (final job in results[1]) {
      merged[job.id] = job;
    }
    for (final job in results[0]) {
      merged[job.id] = job;
    }
    final list = merged.values.toList();
    list.sort((a, b) {
      final ta = DateTime.tryParse(a.updatedAt ?? a.finishedAt ?? a.createdAt ?? '');
      final tb = DateTime.tryParse(b.updatedAt ?? b.finishedAt ?? b.createdAt ?? '');
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return list;
  }

  /// GET /downloaders/tasks（下载器实时快照，含下载器健康 sources）。
  Future<DownloadTaskListView> downloadTaskSnapshot() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/downloaders/tasks',
    );
    return DownloadTaskListView.fromJson(body);
  }

  /// 向后兼容：只取下载任务条目列表。
  Future<List<DownloadTask>> downloadTasks() async {
    final snapshot = await downloadTaskSnapshot();
    return snapshot.items;
  }

  /// GET /playback/activity（正在播放 + 整文件下载，8s 轮询）。
  Future<PlaybackActivityView> playbackActivity({String? scope}) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/playback/activity',
      query: {
        if (scope != null && scope.isNotEmpty) 'scope': scope,
      },
    );
    return PlaybackActivityView.fromJson(body);
  }

  /// GET /playback/stats/watch（管理员专属；非管理员 403 时抛错由调用方静默跳过）。
  Future<PlaybackWatchStatsView> playbackWatchStats({
    required int days,
    int? memberId,
    String? scope,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/playback/stats/watch',
      query: {
        'days': days,
        // 本机时区相对 UTC 的分钟偏移（对齐 iOS `Endpoints.swift: tz_offset`）。
        'tz_offset': DateTime.now().timeZoneOffset.inMinutes,
        if (memberId != null) 'member_id': memberId,
        if (scope != null && scope.isNotEmpty) 'scope': scope,
      },
    );
    return PlaybackWatchStatsView.fromJson(body);
  }

  /// GET /playback/history（支持游标分页 `before`、成员筛选与范围切换）。
  Future<PlaybackHistoryView> playbackHistory({
    int limit = 20,
    int? before,
    int? memberId,
    String? scope,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/playback/history',
      query: {
        'limit': limit,
        if (before != null) 'before': before,
        if (memberId != null) 'member_id': memberId,
        if (scope != null && scope.isNotEmpty) 'scope': scope,
      },
    );
    return PlaybackHistoryView.fromJson(body);
  }

  /// GET /members（成员列表，供观看历史与观看统计筛选）。
  Future<List<ActivityMemberOption>> members() async {
    final raw = await client.unwrap<dynamic>(
      Channel.general,
      'GET',
      '$_prefix/members',
    );
    final list = raw is List
        ? raw
        : (raw is Map && raw['items'] is List ? raw['items'] as List : const []);
    return list
        .whereType<Map>()
        .map((e) => ActivityMemberOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /sites/boost-pool（刷流在池概况；旧服务端无此接口时回退 /sites 仅拿站点开关状态）。
  Future<({BoostPoolView pool, bool supportsCleanup})?> loadBoostPool() async {
    try {
      final body = await client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '$_prefix/sites/boost-pool',
      );
      return (pool: BoostPoolView.fromJson(body), supportsCleanup: true);
    } catch (_) {
      try {
        final raw = await client.unwrap<dynamic>(
          Channel.general,
          'GET',
          '$_prefix/sites',
        );
        final list = raw is List
            ? raw
            : (raw is Map && raw['items'] is List ? raw['items'] as List : const []);
        final sites = list.whereType<Map>().map((m) {
          final map = Map<String, dynamic>.from(m);
          final id = (map['site_id'] ?? map['id'] ?? '').toString();
          return BoostPoolSiteView(
            siteId: id,
            siteName: (map['site_name'] ?? map['name'] ?? id).toString(),
            boostEnabled: map['boost_enabled'] == true,
            boostPaused: map['boost_paused'] == true,
          );
        }).toList();
        return (
          pool: BoostPoolView(sites: sites, tasks: const []),
          supportsCleanup: false,
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// GET /sites/boost-pool（强制刷新最新概况，用于清理确认前）。
  Future<BoostPoolView> boostPoolShow() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/sites/boost-pool',
    );
    return BoostPoolView.fromJson(body);
  }

  /// POST /sites/boost-pool/cleanup（清理刷流种子）。
  Future<BoostCleanupResult> cleanupBoostPool({
    List<String>? siteIds,
    bool disableBoost = true,
    bool force = false,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/sites/boost-pool/cleanup',
      body: {
        if (siteIds != null) 'site_ids': siteIds,
        'disable_boost': disableBoost,
        'force': force,
      },
    );
    return BoostCleanupResult.fromJson(body);
  }

  /// POST /jobs/{id}/cancel。
  Future<JobView?> cancelJob(String id) async {
    final res = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/jobs/${Uri.encodeComponent(id)}/cancel',
    );
    return res['job'] is Map
        ? JobView.fromJson(Map<String, dynamic>.from(res['job'] as Map))
        : null;
  }

  /// POST /jobs/{id}/retry。
  Future<JobView?> retryJob(String id) async {
    final res = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/jobs/${Uri.encodeComponent(id)}/retry',
    );
    return res['job'] is Map
        ? JobView.fromJson(Map<String, dynamic>.from(res['job'] as Map))
        : null;
  }

  /// POST /jobs/{id}/dismiss（支持 `mute_source` 同时静音自动来源）。
  Future<JobView?> dismissJob(String id, {bool? muteSource}) async {
    final res = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/jobs/${Uri.encodeComponent(id)}/dismiss',
      body: muteSource != null ? {'mute_source': muteSource} : null,
    );
    return res['job'] is Map
        ? JobView.fromJson(Map<String, dynamic>.from(res['job'] as Map))
        : null;
  }

  /// POST /jobs/{id}/undismiss（从「已结束」放回「需要处理」）。
  Future<JobView?> undismissJob(String id) async {
    final res = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/jobs/${Uri.encodeComponent(id)}/undismiss',
    );
    return res['job'] is Map
        ? JobView.fromJson(Map<String, dynamic>.from(res['job'] as Map))
        : null;
  }

  /// POST /jobs/dismiss-all（一次忽略所有失败任务）。
  Future<List<JobView>> dismissAllJobs() async {
    final res = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '$_prefix/jobs/dismiss-all',
    );
    return ((res['jobs'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((e) => JobView.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// DELETE /downloaders/{id}/torrents/{hash}?delete_files=...
  Future<void> deleteDownloadTask(
    int downloaderId,
    String infoHash, {
    bool deleteFiles = false,
  }) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'DELETE',
        '$_prefix/downloaders/$downloaderId/torrents/${Uri.encodeComponent(infoHash)}',
        query: {'delete_files': deleteFiles},
      );

  /// POST /downloaders/{id}/torrents/{hash}/replace（立即换种）。
  Future<void> replaceDownloadTask(int downloaderId, String infoHash) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '$_prefix/downloaders/$downloaderId/torrents/${Uri.encodeComponent(infoHash)}/replace',
      );

  /// POST /playback/activity/sessions/{deviceId}/end（结束一台设备的播放；必须整段编码 deviceId，防止 Base64 `/` 触发 404）。
  Future<String> endPlaybackSession(String deviceId) async {
    final encoded = Uri.encodeComponent(deviceId);
    final res = await client.post(
      Channel.general,
      '$_prefix/playback/activity/sessions/$encoded/end',
    );
    final data = res.data;
    if (res.statusCode != null && res.statusCode! >= 400) {
      throw ApiException.fromResponseBody(
        data ?? const <String, dynamic>{},
        httpStatus: res.statusCode,
      );
    }
    if (data != null && data['success'] == false) {
      throw ApiException.fromResponseBody(data, httpStatus: res.statusCode);
    }
    final msg = data?['message']?.toString().trim();
    return (msg != null && msg.isNotEmpty) ? msg : '已结束该设备的播放';
  }

  /// DELETE /playback/devices/{deviceId}（注销设备，凭据立即失效；同样整段编码 deviceId）。
  Future<String> revokePlaybackDevice(String deviceId) async {
    final encoded = Uri.encodeComponent(deviceId);
    final res = await client.delete(
      Channel.general,
      '$_prefix/playback/devices/$encoded',
    );
    final data = res.data;
    if (res.statusCode != null && res.statusCode! >= 400) {
      throw ApiException.fromResponseBody(
        data ?? const <String, dynamic>{},
        httpStatus: res.statusCode,
      );
    }
    if (data != null && data['success'] == false) {
      throw ApiException.fromResponseBody(data, httpStatus: res.statusCode);
    }
    final msg = data?['message']?.toString().trim();
    return (msg != null && msg.isNotEmpty) ? msg : '已注销该设备';
  }
}
