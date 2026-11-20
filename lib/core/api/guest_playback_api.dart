import 'package:dio/dio.dart';

import 'api_exception.dart';

/// 访客播放会话 API（对齐 Kotlin McApi.kt 访客段 sharePlayback*：
/// POST /share/{slug}/playback/sessions 等，见 PlaybackBackend.kt ShareBackend）。
///
/// 与 features/share 的 GuestShareApi 同一套直连 origin 策略：访客接口带显式
/// origin（分享深链可来自任意服务器），McClient 的 baseUrl 绑定会话服务器不可注入，
/// 故复用统一信封协议（unwrapEnvelope）直连 origin，且不带成员令牌（访客通道语义）。
class GuestPlaybackApi {
  GuestPlaybackApi(this.origin) : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (_) => true,
        ));

  final String origin;
  final Dio _dio;

  static const _prefix = '/api/v1';

  Future<Map<String, dynamic>> _send(String method, String path, {Object? body}) async {
    final res = await _dio.request<Map<String, dynamic>>(
      '$origin$_prefix$path',
      data: body,
      options: Options(method: method),
    );
    final data = res.data;
    if (data == null) {
      throw ApiException('network.empty', '服务器返回为空', httpStatus: res.statusCode);
    }
    final unwrapped = unwrapEnvelope<dynamic>(data);
    if (unwrapped is Map) return unwrapped.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// POST /share/{slug}/playback/sessions 开访客播放会话。
  /// body 口径对齐 PlaybackSessionRequest（file_id / media_item_id / season_number /
  /// episode_number / capability …）；decision=plan 时 streamUrl 可播。
  Future<GuestPlaybackSession> start({
    required String slug,
    required int mediaItemId,
    int? seasonNumber,
    int? episodeNumber,
    int? fileId,
  }) async {
    final data = await _send('POST', '/share/$slug/playback/sessions', body: {
      'media_item_id': mediaItemId,
      if (fileId != null) 'file_id': fileId,
      if (seasonNumber != null) 'season_number': seasonNumber,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      'capability': {
        'is_mobile': true,
        'native_hls': true,
        'universal': true,
      },
      'client': 'MovieClaw-Flutter',
    });
    return GuestPlaybackSession.fromJson(data);
  }

  /// DELETE /share/{slug}/playback/sessions/{sessionId} 结束会话。
  Future<void> stop(String slug, String sessionId) async {
    await _send('DELETE', '/share/$slug/playback/sessions/$sessionId');
  }
}

/// 开会话结果的最小切片（对齐 Kotlin PlaybackSessionView）：
/// decision=plan 才有 streamUrl；startMs 为服务端定的续播点（原片时间轴毫秒）。
class GuestPlaybackSession {
  const GuestPlaybackSession({
    this.decision = '',
    this.sessionId,
    this.streamUrl,
    this.startMs = 0,
  });

  final String decision;
  final String? sessionId;
  final String? streamUrl;
  final int startMs;

  factory GuestPlaybackSession.fromJson(Map<String, dynamic> j) => GuestPlaybackSession(
        decision: j['decision']?.toString() ?? '',
        sessionId: (j['sessionId'] ?? j['session_id'])?.toString(),
        streamUrl: (j['streamUrl'] ?? j['stream_url'])?.toString(),
        startMs: j['startMs'] is num
            ? (j['startMs'] as num).toInt()
            : int.tryParse((j['startMs'] ?? j['start_ms'])?.toString() ?? '') ?? 0,
      );
}
