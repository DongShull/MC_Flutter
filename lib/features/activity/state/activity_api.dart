import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

final activityApiProvider =
    Provider<ActivityApi>((ref) => ActivityApi(ref.watch(sessionStoreProvider)));

/// 活动域 API 封装：统一走 McClient（Channel.general），对应 Kotlin McApi.kt 的
/// jobs / downloaders / playback 段。
class ActivityApi {
  ActivityApi(this._session);

  final SessionStore _session;
  McClient? _client;

  McClient get client => _client ??= McClient(session: _session);

  static const _prefix = '/api/v1';

  /// GET /jobs（后台任务快照）。
  Future<List<JobView>> jobs() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/jobs',
    );
    return ((body['items'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(JobView.fromJson)
        .toList();
  }

  /// GET /downloaders/tasks（下载器快照，10s 轮询）。
  Future<List<DownloadTask>> downloadTasks() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/downloaders/tasks',
    );
    return ((body['items'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DownloadTask.fromJson)
        .toList();
  }

  /// GET /playback/activity（正在播放 + 整文件下载，8s 轮询）。
  Future<PlaybackActivityView> playbackActivity() async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/playback/activity',
    );
    return PlaybackActivityView.fromJson(body);
  }

  /// GET /playback/stats/watch（管理员专属；非管理员 403 时抛错由调用方静默跳过）。
  Future<PlaybackWatchStatsView> playbackWatchStats({
    required int days,
    int? memberId,
  }) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/playback/stats/watch',
      query: {
        'days': days,
        // 本机时区偏移（分钟），统计按设备时区分桶。
        'tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
        if (memberId != null) 'member_id': memberId,
      },
    );
    return PlaybackWatchStatsView.fromJson(body);
  }

  /// GET /playback/history（管理员专属；403 静默跳过）。
  Future<PlaybackHistoryView> playbackHistory({int limit = 20}) async {
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general, 'GET', '$_prefix/playback/history',
      query: {'limit': limit},
    );
    return PlaybackHistoryView.fromJson(body);
  }

  /// POST /jobs/{id}/cancel。
  Future<void> cancelJob(String id) => client.unwrap<Map<String, dynamic>>(
        Channel.general, 'POST', '$_prefix/jobs/$id/cancel',
      );

  /// POST /jobs/{id}/retry。
  Future<void> retryJob(String id) => client.unwrap<Map<String, dynamic>>(
        Channel.general, 'POST', '$_prefix/jobs/$id/retry',
      );

  /// POST /jobs/{id}/dismiss（记 dismissed_at，可撤销）。
  Future<void> dismissJob(String id) => client.unwrap<Map<String, dynamic>>(
        Channel.general, 'POST', '$_prefix/jobs/$id/dismiss',
      );

  /// POST /jobs/{id}/undismiss（从「已结束」放回「需要处理」）。
  Future<void> undismissJob(String id) => client.unwrap<Map<String, dynamic>>(
        Channel.general, 'POST', '$_prefix/jobs/$id/undismiss',
      );

  /// POST /jobs/dismiss-all（一次忽略所有失败任务）。
  Future<void> dismissAllJobs() => client.unwrap<Map<String, dynamic>>(
        Channel.general, 'POST', '$_prefix/jobs/dismiss-all',
      );

  /// DELETE /downloaders/{id}/torrents/{hash}（默认不删已下载文件）。
  Future<void> deleteDownloadTask(int downloaderId, String infoHash) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'DELETE',
        '$_prefix/downloaders/$downloaderId/torrents/$infoHash',
      );

  /// POST /downloaders/{id}/torrents/{hash}/replace（立即换种）。
  Future<void> replaceDownloadTask(int downloaderId, String infoHash) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '$_prefix/downloaders/$downloaderId/torrents/$infoHash/replace',
      );

  /// POST /playback/sessions/{deviceId}/end（结束一台设备的播放）。
  Future<void> endPlaybackSession(String deviceId) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general, 'POST', '$_prefix/playback/sessions/$deviceId/end',
      );

  /// POST /playback/devices/{deviceId}/revoke（注销设备，凭据立即失效）。
  Future<void> revokePlaybackDevice(String deviceId) =>
      client.unwrap<Map<String, dynamic>>(
        Channel.general, 'POST', '$_prefix/playback/devices/$deviceId/revoke',
      );
}
