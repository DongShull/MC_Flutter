import '../../api/mc_client.dart';

/// 服务器侧播放会话协商（全路径严格对齐 `/api/v1/playback/*`）：
/// - `POST /api/v1/playback/sessions`（支持清晰度档位上限 `max_tier` 与软解确认 `allow_software_transcode`）
/// - `POST /api/v1/playback/sessions/{id}/ping`
/// - `DELETE /api/v1/playback/sessions/{id}`
/// - `GET /api/v1/playback/sessions/{id}/diagnostics`（实时技术 HUD）
/// - `POST /api/v1/playback/progress`
/// - `GET /api/v1/playback/resume`
class PlaybackSessionApi {
  PlaybackSessionApi(this._client);

  final McClient _client;

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
    String? maxTier,
    bool allowSoftwareTranscode = false,
    String? audioTrack,
    String? subtitleTrack,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'POST',
      '/api/v1/playback/sessions',
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
        if (maxTier != null && maxTier != 'original') 'max_tier': maxTier,
        if (allowSoftwareTranscode) 'allow_software_transcode': true,
        if (audioTrack != null) 'audio_track': audioTrack,
        if (subtitleTrack != null) 'subtitle_track': subtitleTrack,
        if (deviceId != null) 'device_id': deviceId,
        if (startMs != null) 'start_ms': startMs,
        if (client != null) 'client': client,
      },
    );
    return PlaybackSession.fromJson(body);
  }

  Future<void> ping(String sessionId) async {
    await _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'POST',
      '/api/v1/playback/sessions/$sessionId/ping',
    );
  }

  Future<void> stop(String sessionId) async {
    await _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'DELETE',
      '/api/v1/playback/sessions/$sessionId',
    );
  }

  Future<Map<String, dynamic>> diagnostics(String sessionId) async {
    return _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'GET',
      '/api/v1/playback/sessions/$sessionId/diagnostics',
    );
  }

  Future<void> reportProgress({
    required int mediaItemId,
    int? seasonNumber,
    int? episodeNumber,
    String? event,
    int? positionMs,
    bool? paused,
    int? fileId,
    String? audioTrack,
    String? subtitleTrack,
    String? deviceId,
  }) async {
    await _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'POST',
      '/api/v1/playback/progress',
      body: {
        'media_item_id': mediaItemId,
        if (seasonNumber != null) 'season_number': seasonNumber,
        if (episodeNumber != null) 'episode_number': episodeNumber,
        if (event != null) 'event': event,
        if (positionMs != null) 'position_ms': positionMs,
        if (paused != null) 'paused': paused,
        if (fileId != null) 'file_id': fileId,
        if (audioTrack != null) 'audio_track': audioTrack,
        if (subtitleTrack != null) 'subtitle_track': subtitleTrack,
        if (deviceId != null) 'device_id': deviceId,
      },
    );
  }

  Future<Map<String, dynamic>> resume({
    required int mediaItemId,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    return _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'GET',
      '/api/v1/playback/resume',
      query: {
        'media_item_id': mediaItemId,
        if (seasonNumber != null) 'season_number': seasonNumber,
        if (episodeNumber != null) 'episode_number': episodeNumber,
      },
    );
  }
}

class PlaybackAudioTrack {
  const PlaybackAudioTrack({
    required this.ref,
    this.codec,
    this.channels,
    this.language,
    this.isDefault = false,
  });

  factory PlaybackAudioTrack.fromJson(Map<String, dynamic> json) {
    return PlaybackAudioTrack(
      ref: (json['ref'] ?? '').toString(),
      codec: json['codec']?.toString(),
      channels: (json['channels'] as num?)?.toInt(),
      language: json['language']?.toString(),
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  final String ref;
  final String? codec;
  final int? channels;
  final String? language;
  final bool isDefault;

  String get label {
    const labels = <String, String>{
      'chs': '简体中文',
      'cht': '繁体中文',
      'chi': '中文',
      'zho': '中文',
      'cmn': '中文',
      'yue': '粤语',
      'eng': '英语',
      'jpn': '日语',
      'kor': '韩语',
      'fre': '法语',
      'fra': '法语',
      'ger': '德语',
      'deu': '德语',
      'spa': '西班牙语',
      'rus': '俄语',
      'ita': '意大利语',
      'por': '葡萄牙语',
      'tha': '泰语',
      'hin': '印地语',
    };
    final lang = language;
    final langLabel = (lang == null || lang.isEmpty || lang == 'und')
        ? null
        : labels[lang.toLowerCase()] ?? lang;
    final parts = <String>[langLabel ?? '未知语言'];
    if (codec != null && codec!.isNotEmpty) parts.add(codec!);
    if (channels != null) parts.add('$channels 声道');
    return parts.join(' · ');
  }
}

class PlaybackSubtitleTrack {
  const PlaybackSubtitleTrack({
    required this.trackRef,
    this.kind = '',
    this.language,
    this.isDefault = false,
    this.isAi = false,
    this.title,
    this.isForced = false,
    this.url,
  });

  factory PlaybackSubtitleTrack.fromJson(Map<String, dynamic> json) {
    return PlaybackSubtitleTrack(
      trackRef: (json['track_ref'] ?? '').toString(),
      kind: json['kind']?.toString() ?? '',
      language: json['language']?.toString(),
      isDefault: json['is_default'] as bool? ?? false,
      isAi: json['is_ai'] as bool? ?? false,
      title: json['title']?.toString(),
      isForced: json['is_forced'] as bool? ?? false,
      url: json['url']?.toString(),
    );
  }

  final String trackRef;
  final String kind;
  final String? language;
  final bool isDefault;
  final bool isAi;
  final String? title;
  final bool isForced;
  final String? url;

  String get label {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    const externalPrefix = 'external:';
    if (trackRef.startsWith(externalPrefix)) {
      return trackRef.substring(externalPrefix.length);
    }
    return trackRef;
  }

  String get detail {
    const kindLabels = {
      'vtt': 'WebVTT',
      'ass': 'ASS 特效',
      'ssa': 'SSA 特效',
      'pgs': 'PGS 图形',
      'srt': 'SRT 文本',
      'text': '文本',
    };
    final parts = <String>[if (kind.isNotEmpty) kindLabels[kind] ?? kind];
    if (isAi) parts.add('AI 生成');
    if (isForced) parts.add('强制');
    if (isDefault) parts.add('默认');
    return parts.join(' · ');
  }
}

class PlaybackSkipSegment {
  const PlaybackSkipSegment({
    required this.type,
    required this.startMs,
    required this.endMs,
  });

  factory PlaybackSkipSegment.fromJson(Map<String, dynamic> json) {
    return PlaybackSkipSegment(
      type: (json['type'] ?? 'other').toString(),
      startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
      endMs: (json['end_ms'] as num?)?.toInt() ?? 0,
    );
  }

  final String type;
  final int startMs;
  final int endMs;
}

class PlaybackSession {
  const PlaybackSession({
    required this.decision,
    this.sessionId,
    this.streamUrl,
    this.startMs = 0,
    this.subtitleUrls = const [],
    this.masterUrl,
    this.hwBackend,
    this.deliveryMode,
    this.transcodeReason,
    this.videoCodec,
    this.audioCodec,
    this.resolution,
    this.container,
    this.audioTracks = const [],
    this.subtitles = const [],
    this.skipSegments = const [],
  });

  final String decision; // plan | consent | rejected
  final String? sessionId;
  final String? streamUrl;
  final int startMs;
  final List<String> subtitleUrls;
  final String? masterUrl;
  final String? hwBackend;
  final String? deliveryMode;
  final String? transcodeReason;
  final String? videoCodec;
  final String? audioCodec;
  final String? resolution;
  final String? container;
  final List<PlaybackAudioTrack> audioTracks;
  final List<PlaybackSubtitleTrack> subtitles;
  final List<PlaybackSkipSegment> skipSegments;

  bool get playable => decision == 'plan' && streamUrl != null;

  factory PlaybackSession.fromJson(Map<String, dynamic> json) {
    final d = json['decision'];
    final dMap = d is Map<String, dynamic>
        ? d
        : (d is Map ? d.cast<String, dynamic>() : null);
    final segList =
        json['segments'] as List? ?? dMap?['segments'] as List? ?? const [];
    return PlaybackSession(
      decision: (dMap?['outcome'] ?? json['decision'] ?? '').toString(),
      deliveryMode:
          (dMap?['mode'] ?? dMap?['delivery'] ?? json['mode'])?.toString(),
      transcodeReason:
          (dMap?['reason'] ?? dMap?['transcode_reason'])?.toString(),
      videoCodec: (dMap?['video_codec'] ?? json['video_codec'])?.toString(),
      audioCodec: (dMap?['audio_codec'] ?? json['audio_codec'])?.toString(),
      resolution: (dMap?['resolution'] ?? json['resolution'])?.toString(),
      container: (dMap?['container'] ?? json['container'])?.toString(),
      audioTracks: [
        for (final t in (dMap?['audio_tracks'] as List? ?? []))
          if (t is Map) PlaybackAudioTrack.fromJson(t.cast<String, dynamic>()),
      ],
      subtitles: [
        for (final t in (dMap?['subtitles'] as List? ?? []))
          if (t is Map)
            PlaybackSubtitleTrack.fromJson(t.cast<String, dynamic>()),
      ],
      sessionId: json['session_id']?.toString(),
      streamUrl: json['stream_url']?.toString(),
      startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
      subtitleUrls: [
        for (final u in (json['subtitle_urls'] as List? ?? [])) u.toString(),
      ],
      masterUrl: json['master_url']?.toString(),
      hwBackend: json['hw_backend']?.toString(),
      skipSegments: [
        for (final s in segList)
          if (s is Map) PlaybackSkipSegment.fromJson(s.cast<String, dynamic>()),
      ],
    );
  }
}
