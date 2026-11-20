import '../../api/mc_client.dart';

/// 服务器侧播放会话协商（1:1 对齐 MovieClaw McApi.kt：
/// POST /playback/sessions → POST /playback/sessions/{id}/ping → DELETE /playback/sessions/{id}，
/// 续播点 GET /playback/resume）。飞牛对应协议见 docs/design/08。
///
/// 协商三态：decision = plan（真起会话，streamUrl 可播）/ consent（需用户确认）/ rejected。
class PlaybackSessionApi {
  PlaybackSessionApi(this._client);

  final McClient _client;

  /// 开会话（PlaybackSessionRequest）。
  Future<PlaybackSession> start({
    int? fileId,
    int? mediaItemId,
    int? seasonNumber,
    int? episodeNumber,
    Map<String, dynamic>? capability,
    String? deviceId,
    String? client = 'MovieClaw-Flutter',
    int? startMs,
    List<int>? failedTiers,
    String? audioTrack,
    String? subtitleTrack,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'POST',
      '/playback/sessions',
      body: {
        if (fileId != null) 'file_id': fileId,
        if (mediaItemId != null) 'media_item_id': mediaItemId,
        if (seasonNumber != null) 'season_number': seasonNumber,
        if (episodeNumber != null) 'episode_number': episodeNumber,
        'capability': capability ??
            {
              'is_mobile': true,
              'native_hls': true,
              'universal': true,
            },
        if (failedTiers != null) 'failed_tiers': failedTiers,
        if (audioTrack != null) 'audio_track': audioTrack,
        if (subtitleTrack != null) 'subtitle_track': subtitleTrack,
        if (deviceId != null) 'device_id': deviceId,
        if (startMs != null) 'start_ms': startMs,
        if (client != null) 'client': client,
      },
    );
    return PlaybackSession.fromJson(body);
  }

  /// 播放心跳（保活会话；服务器可据此判定僵尸会话）。
  Future<void> ping(String sessionId) async {
    await _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'POST',
      '/playback/sessions/$sessionId/ping',
    );
  }

  /// 结束播放。
  Future<void> stop(String sessionId) async {
    await _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'DELETE',
      '/playback/sessions/$sessionId',
    );
  }

  /// 续播点与记忆轨（PlaybackStateView）。
  Future<Map<String, dynamic>> resume({
    required int mediaItemId,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    return _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'GET',
      '/playback/resume',
      query: {
        'media_item_id': mediaItemId,
        if (seasonNumber != null) 'season_number': seasonNumber,
        if (episodeNumber != null) 'episode_number': episodeNumber,
      },
    );
  }
}

/// 开会话结果（PlaybackSessionView 的 Flutter 侧子集）。
class PlaybackSession {
  const PlaybackSession({
    required this.decision,
    this.sessionId,
    this.streamUrl,
    this.startMs = 0,
    this.subtitleUrls = const [],
    this.masterUrl,
    this.hwBackend,
  });

  final String decision; // plan | consent | rejected
  final String? sessionId;
  final String? streamUrl;
  final int startMs;
  final List<String> subtitleUrls;
  final String? masterUrl;
  final String? hwBackend;

  bool get playable => decision == 'plan' && streamUrl != null;

  factory PlaybackSession.fromJson(Map<String, dynamic> json) {
    return PlaybackSession(
      decision: (json['decision'] ?? '').toString(),
      sessionId: json['session_id']?.toString(),
      streamUrl: json['stream_url']?.toString(),
      startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
      subtitleUrls: [
        for (final u in (json['subtitle_urls'] as List? ?? [])) u.toString(),
      ],
      masterUrl: json['master_url']?.toString(),
      hwBackend: json['hw_backend']?.toString(),
    );
  }
}
