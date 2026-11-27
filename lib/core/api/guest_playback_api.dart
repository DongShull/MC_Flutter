import 'dart:io';

import 'package:dio/dio.dart';

import 'api_exception.dart';

/// 访客播放会话 API（对齐 iOS `Endpoints.swift` `/share/{slug}/playback/*` 接口族）：
/// - 携带解锁后下发的访客会话 Cookie，避免加密分享播放报 401/403；
/// - 准确上报客户端能力矩阵（避免降级引擎盲传 `universal: true` 导致不支持容器强行直连失败）；
/// - 完整解析 `decision`（含 `consent` / `reject`）、`session_id`、`stream_url`、`start_ms`、`duration_ms`；
/// - 支持会话保活 ping、访客实时活动心跳 progress（绝不落成员观看进度）与 stop 回收。
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

  String get _normalizedOrigin => origin.trim().replaceAll(RegExp(r'/+$'), '');

  /// 默认客户端播放能力声明（不使用盲目硬编码的 `universal: true`）：
  /// - [useUniversalEngine] = true 表示 media_kit / libmpv 等全能解码器可用；
  /// - [useUniversalEngine] = false 表示仅靠平台原生 AVPlayer / MediaCodec 兜底（声明真实支持的容器与编解码器）。
  static Map<String, dynamic> buildCapability({
    bool useUniversalEngine = false,
    bool nativeHls = true,
  }) {
    final isMobile = Platform.isIOS || Platform.isAndroid;
    if (useUniversalEngine) {
      return {
        'is_mobile': isMobile,
        'native_hls': nativeHls,
        'universal': true,
        'direct_play': true,
        'containers': ['mp4', 'mkv', 'mov', 'm4v', 'webm', 'ts'],
        'video_codecs': ['h264', 'hevc', 'av1', 'vp9'],
        'audio_codecs': ['aac', 'ac3', 'eac3', 'dts', 'flac', 'opus', 'mp3'],
      };
    }
    return {
      'is_mobile': isMobile,
      'native_hls': nativeHls,
      'universal': false,
      'direct_play': true,
      'containers': Platform.isIOS || Platform.isMacOS
          ? ['mp4', 'mov', 'm4v']
          : ['mp4', 'mkv', 'webm'],
      'video_codecs': ['h264', 'hevc'],
      'audio_codecs': ['aac', 'ac3', 'eac3', 'mp3', 'flac'],
    };
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final res = await _dio.request<dynamic>(
      '$_normalizedOrigin$_prefix$path',
      data: body,
      queryParameters: query,
      options: Options(
        method: method,
        headers: {
          if (cookieHeader != null && cookieHeader!.isNotEmpty)
            'Cookie': cookieHeader!,
        },
      ),
    );
    final raw = res.data;
    if (raw == null) {
      if ((res.statusCode ?? 0) >= 200 && (res.statusCode ?? 0) < 300) {
        return <String, dynamic>{};
      }
      throw ApiException(
        'network.empty',
        '服务器返回为空',
        httpStatus: res.statusCode,
      );
    }
    if (raw is Map<String, dynamic>) {
      final unwrapped = unwrapEnvelope<dynamic>(raw);
      if (unwrapped is Map) return unwrapped.cast<String, dynamic>();
      return <String, dynamic>{};
    }
    if ((res.statusCode ?? 0) >= 400) {
      throw ApiException(
        'http.${res.statusCode}',
        '请求失败（HTTP ${res.statusCode}）',
        httpStatus: res.statusCode,
      );
    }
    return <String, dynamic>{};
  }

  /// 发起访客播放会话：`POST /api/v1/share/{slug}/playback/sessions`。
  Future<GuestPlaybackSession> start({
    required String slug,
    required int mediaItemId,
    int? seasonNumber,
    int? episodeNumber,
    int? fileId,
    int? startMs,
    String? audioTrack,
    String? subtitleTrack,
    int? maxHeight,
    bool force = false,
    bool useUniversalEngine = false,
    Map<String, dynamic>? capability,
  }) async {
    final data = await _send(
      'POST',
      '/share/$slug/playback/sessions',
      body: {
        'media_item_id': mediaItemId,
        if (fileId != null) 'file_id': fileId,
        if (seasonNumber != null) 'season_number': seasonNumber,
        if (episodeNumber != null) 'episode_number': episodeNumber,
        if (startMs != null && startMs > 0) 'start_ms': startMs,
        if (audioTrack != null && audioTrack.isNotEmpty)
          'audio_track': audioTrack,
        if (subtitleTrack != null && subtitleTrack.isNotEmpty)
          'subtitle_track': subtitleTrack,
        if (maxHeight != null && maxHeight > 0) 'max_height': maxHeight,
        if (force) 'force': true,
        'capability': capability ??
            buildCapability(useUniversalEngine: useUniversalEngine),
        'client': 'mc-flutter',
      },
    );
    return GuestPlaybackSession.fromJson(data);
  }

  /// 访客播放会话保活心跳：`POST /api/v1/share/{slug}/playback/sessions/{sessionId}/ping`。
  Future<void> ping(String slug, String sessionId) async {
    await _send('POST', '/share/$slug/playback/sessions/$sessionId/ping');
  }

  /// 访客活动心跳（仅刷新活动页实时播放状态，服务端绝不写成员观看进度）：
  /// `POST /api/v1/share/{slug}/playback/progress`。
  Future<void> reportProgress({
    required String slug,
    required int mediaItemId,
    required int positionMs,
    int? durationMs,
    int? seasonNumber,
    int? episodeNumber,
    String? sessionId,
  }) async {
    await _send(
      'POST',
      '/share/$slug/playback/progress',
      body: {
        'media_item_id': mediaItemId,
        'position_ms': positionMs,
        if (durationMs != null) 'duration_ms': durationMs,
        if (seasonNumber != null) 'season_number': seasonNumber,
        if (episodeNumber != null) 'episode_number': episodeNumber,
        if (sessionId != null) 'session_id': sessionId,
      },
    );
  }

  /// 访客结束播放回收转码会话：`DELETE /api/v1/share/{slug}/playback/sessions/{sessionId}`。
  Future<void> stop(String slug, String sessionId) async {
    await _send('DELETE', '/share/$slug/playback/sessions/$sessionId');
  }
}

class GuestPlaybackSession {
  const GuestPlaybackSession({
    this.decision = '',
    this.decisionReason,
    this.decisionMessage,
    this.sessionId,
    this.streamUrl,
    this.startMs = 0,
    this.durationMs,
    this.audioTrack,
    this.subtitleTrack,
    this.fileId,
  });

  final String decision;
  final String? decisionReason;
  final String? decisionMessage;
  final String? sessionId;
  final String? streamUrl;
  final int startMs;
  final int? durationMs;
  final String? audioTrack;
  final String? subtitleTrack;
  final int? fileId;

  bool get needsConsent => decision.toLowerCase() == 'consent';
  bool get rejected =>
      decision.toLowerCase() == 'reject' ||
      decision.toLowerCase() == 'rejected' ||
      decision.toLowerCase() == 'denied';

  bool get playable =>
      !needsConsent &&
      !rejected &&
      streamUrl != null &&
      streamUrl!.isNotEmpty;

  factory GuestPlaybackSession.fromJson(Map<String, dynamic> j) {
    final rawDec = j['decision'];
    String decStr = '';
    String? decReason;
    String? decMessage;
    if (rawDec is Map) {
      decStr = (rawDec['outcome'] ?? rawDec['decision'] ?? '').toString();
      decReason = (rawDec['reason'] ?? rawDec['code'])?.toString();
      decMessage = (rawDec['message'] ?? rawDec['detail'])?.toString();
    } else if (rawDec != null) {
      decStr = rawDec.toString();
    }
    decMessage ??= (j['message'] ?? j['reason'])?.toString();

    int? parseInt(Object? v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '');
    }

    return GuestPlaybackSession(
      decision: decStr,
      decisionReason: decReason,
      decisionMessage: decMessage,
      sessionId: (j['sessionId'] ?? j['session_id'])?.toString(),
      streamUrl: (j['streamUrl'] ?? j['stream_url'])?.toString(),
      startMs: parseInt(j['startMs'] ?? j['start_ms']) ?? 0,
      durationMs: parseInt(j['durationMs'] ?? j['duration_ms']),
      audioTrack: (j['audioTrack'] ?? j['audio_track'])?.toString(),
      subtitleTrack: (j['subtitleTrack'] ?? j['subtitle_track'])?.toString(),
      fileId: parseInt(j['fileId'] ?? j['file_id']),
    );
  }
}
