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

  /// 上报观看进度（POST /playback/progress，PlaybackProgressRequest 口径）。
  /// event: started | progress | paused | resumed | finished 等（服务器宽松）。
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
      '/playback/progress',
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

/// 一条可选音轨（AudioTrackView 的 Flutter 侧子集）：菜单展示 + 换轨用。
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

  /// 中性轨引用（embedded:N），换轨时作为 audio_track 回传服务器。
  final String ref;
  final String? codec;
  final int? channels;
  final String? language;
  final bool isDefault;

  /// 菜单展示文案（同 Android PlayerTracks.LanguageLabel 的精简口径）。
  String get label {
    const labels = <String, String>{
      'chs': '简体中文', 'cht': '繁体中文', 'chi': '中文', 'zho': '中文',
      'cmn': '中文', 'yue': '粤语', 'eng': '英语', 'jpn': '日语', 'kor': '韩语',
      'fre': '法语', 'fra': '法语', 'ger': '德语', 'deu': '德语',
      'spa': '西班牙语', 'rus': '俄语', 'ita': '意大利语', 'por': '葡萄牙语',
      'tha': '泰语', 'hin': '印地语',
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

/// 一条可选字幕（SubtitlePlanView 的 Flutter 侧子集）。
class PlaybackSubtitleTrack {
  const PlaybackSubtitleTrack({
    required this.trackRef,
    this.kind = '',
    this.language,
    this.isDefault = false,
    this.isAi = false,
    this.title,
    this.isForced = false,
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
    );
  }


  /// 中性轨引用（embedded:N / external:文件名），换轨时作为 subtitle_track 回传。
  final String trackRef;

  /// vtt（文本）/ ass（特效）/ pgs（图形）。
  final String kind;
  final String? language;
  final bool isDefault;
  final bool isAi;
  final String? title;
  final bool isForced;

  /// 菜单展示文案（标题 > 外挂文件名 > ref）。
  String get label {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    const externalPrefix = 'external:';
    if (trackRef.startsWith(externalPrefix)) {
      return trackRef.substring(externalPrefix.length);
    }
    return trackRef;
  }


  /// 补充说明（格式 + AI/强制/默认标记）。
  String get detail {
    const kindLabels = {
      'vtt': 'WebVTT', 'ass': 'ASS 特效', 'ssa': 'SSA 特效',
      'pgs': 'PGS 图形', 'srt': 'SRT 文本', 'text': '文本',
    };
    final parts = <String>[if (kind.isNotEmpty) kindLabels[kind] ?? kind];
    if (isAi) parts.add('AI 生成');
    if (isForced) parts.add('强制');
    if (isDefault) parts.add('默认');
    return parts.join(' · ');
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
    this.audioTracks = const [],
    this.subtitles = const [],
  });

  final String decision; // plan | consent | rejected
  final String? sessionId;
  final String? streamUrl;
  final int startMs;
  final List<String> subtitleUrls;
  final String? masterUrl;
  final String? hwBackend;

  /// 服务器 decision 内给出的可选音轨/字幕轨（空 = 服务器未提供轨道信息）。
  final List<PlaybackAudioTrack> audioTracks;
  final List<PlaybackSubtitleTrack> subtitles;

  bool get playable => decision == 'plan' && streamUrl != null;

  factory PlaybackSession.fromJson(Map<String, dynamic> json) {
    final d = json['decision'];
    final dMap = d is Map<String, dynamic> ? d : null;
    return PlaybackSession(
      decision: (dMap?['outcome'] ?? json['decision'] ?? '').toString(),
      audioTracks: [
        for (final t in (dMap?['audio_tracks'] as List? ?? []))
          if (t is Map<String, dynamic>) PlaybackAudioTrack.fromJson(t),
      ],
      subtitles: [
        for (final t in (dMap?['subtitles'] as List? ?? []))
          if (t is Map<String, dynamic>) PlaybackSubtitleTrack.fromJson(t),
      ],
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
