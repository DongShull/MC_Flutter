import 'package:dio/dio.dart';

import 'api_exception.dart';

/// 访客播放会话 API（携带解锁后下发的访客会话 Cookie，避免加密分享播放报 401/403）。
class GuestPlaybackApi {
  GuestPlaybackApi(this.origin, {this.cookieHeader})
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 20),
            validateStatus: (_) => true,
          ),
        );

  final String origin;
  final String? cookieHeader;
  final Dio _dio;

  static const _prefix = '/api/v1';

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
  }) async {
    final res = await _dio.request<Map<String, dynamic>>(
      '$origin$_prefix$path',
      data: body,
      options: Options(
        method: method,
        headers: {
          if (cookieHeader != null && cookieHeader!.isNotEmpty)
            'Cookie': cookieHeader!,
        },
      ),
    );
    final data = res.data;
    if (data == null) {
      throw ApiException(
        'network.empty',
        '服务器返回为空',
        httpStatus: res.statusCode,
      );
    }
    final unwrapped = unwrapEnvelope<dynamic>(data);
    if (unwrapped is Map) return unwrapped.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  Future<GuestPlaybackSession> start({
    required String slug,
    required int mediaItemId,
    int? seasonNumber,
    int? episodeNumber,
    int? fileId,
  }) async {
    final data = await _send(
      'POST',
      '/share/$slug/playback/sessions',
      body: {
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
      },
    );
    return GuestPlaybackSession.fromJson(data);
  }

  Future<void> stop(String slug, String sessionId) async {
    await _send('DELETE', '/share/$slug/playback/sessions/$sessionId');
  }
}

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

  factory GuestPlaybackSession.fromJson(Map<String, dynamic> j) =>
      GuestPlaybackSession(
        decision: j['decision']?.toString() ?? '',
        sessionId: (j['sessionId'] ?? j['session_id'])?.toString(),
        streamUrl: (j['streamUrl'] ?? j['stream_url'])?.toString(),
        startMs: j['startMs'] is num
            ? (j['startMs'] as num).toInt()
            : int.tryParse((j['startMs'] ?? j['start_ms'])?.toString() ?? '') ??
                0,
      );
}
