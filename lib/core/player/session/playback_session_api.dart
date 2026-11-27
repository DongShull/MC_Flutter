import 'package:dio/dio.dart';

import '../../api/api_exception.dart';
import '../../api/mc_client.dart';

/// 服务器侧播放会话协商与遥测协议（对齐 iOS `PlaybackAPI.swift` 与后端 `schemas/playback.py`）：
/// - 登录成员：`/api/v1/playback/*`
/// - 访客分享：`/api/v1/share/{slug}/playback/*`
/// - 如实按引擎申报 `ClientCapabilityIn`（全解码 libmpv vs 兜底 AVPlayer）
class PlaybackSessionApi {
  PlaybackSessionApi(this._client, {this.shareSlug});

  final McClient _client;
  final String? shareSlug;

  bool get isShare => shareSlug != null && shareSlug!.isNotEmpty;

  String _base(String? overrideSlug) {
    final slug = (overrideSlug != null && overrideSlug.isNotEmpty)
        ? overrideSlug
        : shareSlug;
    if (slug != null && slug.isNotEmpty) {
      return '/api/v1/share/$slug/playback';
    }
    return '/api/v1/playback';
  }

  static int? _tierToMaxHeight(String? tier) => switch (tier) {
        '1080p' => 1080,
        '720p' => 720,
        '480p' => 480,
        _ => null,
      };

  /// 如实构造客户端解码能力快照（对齐 `PlayerCapability.swift`）：
  /// - `universalEngine == true`：声明 `universal: true`、`disc_image: true`、`disc_folder: true` 及全格式编码；
  /// - `universalEngine == false`：省略 `universal`，仅声明 `mp4` / `hls-fmp4` 与系统原生音频编码。
  static Map<String, dynamic> buildCapability({
    required bool universalEngine,
    bool isMobile = false,
    bool hdrPassthrough = true,
    bool allowSoftwareTranscode = false,
  }) {
    if (universalEngine) {
      return <String, dynamic>{
        'video': [
          for (final codec in const [
            'h264',
            'hevc',
            'av1',
            'vp9',
            'vp8',
            'mpeg2video',
            'mpeg4',
            'vc1',
          ])
            {
              'codec': codec,
              'max_height': 2160,
              'smooth': true,
              'power_efficient': codec == 'h264' || codec == 'hevc',
            },
        ],
        'audio': [
          for (final codec in const [
            'aac',
            'ac3',
            'eac3',
            'dts',
            'flac',
            'alac',
            'opus',
            'mp3',
          ])
            {'codec': codec, 'max_channels': 8},
        ],
        'containers': const [
          'mp4',
          'hls-fmp4',
          'mkv',
          'webm',
          'ts',
          'm2ts',
          'avi',
        ],
        'hdr_passthrough': hdrPassthrough,
        'mse': 'full',
        'is_mobile': false,
        'native_hls': false,
        'universal': true,
        'disc_image': true,
        'disc_folder': true,
        'dolby_vision_record_audit': true,
        if (allowSoftwareTranscode) 'allow_software_transcode': true,
      };
    }

    return <String, dynamic>{
      'video': const [
        {
          'codec': 'h264',
          'max_height': 2160,
          'smooth': true,
          'power_efficient': true,
        },
        {
          'codec': 'hevc',
          'max_height': 2160,
          'smooth': true,
          'power_efficient': true,
        },
      ],
      'audio': const [
        {'codec': 'aac', 'max_channels': 8},
        {'codec': 'ac3', 'max_channels': 6},
        {'codec': 'eac3', 'max_channels': 8},
        {'codec': 'flac', 'max_channels': 8},
        {'codec': 'alac', 'max_channels': 8},
        {'codec': 'mp3', 'max_channels': 2},
      ],
      'containers': const ['mp4', 'hls-fmp4'],
      'hdr_passthrough': hdrPassthrough,
      'mse': 'none',
      'is_mobile': isMobile,
      'native_hls': true,
      if (allowSoftwareTranscode) 'allow_software_transcode': true,
    };
  }

  Future<PlaybackSession> start({
    int? fileId,
    int? mediaItemId,
    int? seasonNumber,
    int? episodeNumber,
    Map<String, dynamic>? capability,
    bool universalEngine = true,
    bool isMobile = false,
    String? deviceId,
    String? client = 'mc-flutter',
    int? startMs,
    List<int>? failedTiers,
    String? maxTier,
    int? maxHeightOverride,
    bool allowSoftwareTranscode = false,
    String? audioTrack,
    String? subtitleTrack,
    int? downlinkBps,
    String? attemptId,
    String? shareSlug,
  }) async {
    final maxHeight = maxHeightOverride ?? _tierToMaxHeight(maxTier);
    final safeClient = (client != null && client.length > 16)
        ? client.substring(0, 16)
        : client;
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'POST',
      '${_base(shareSlug)}/sessions',
      body: {
        if (fileId != null) 'file_id': fileId,
        if (mediaItemId != null) 'media_item_id': mediaItemId,
        if (seasonNumber != null) 'season_number': seasonNumber,
        if (episodeNumber != null) 'episode_number': episodeNumber,
        'capability': capability ??
            buildCapability(
              universalEngine: universalEngine,
              isMobile: isMobile,
              allowSoftwareTranscode: allowSoftwareTranscode,
            ),
        if (failedTiers != null && failedTiers.isNotEmpty)
          'failed_tiers': failedTiers,
        if (maxHeight != null) 'max_height': maxHeight,
        if (audioTrack != null) 'audio_track': audioTrack,
        if (subtitleTrack != null) 'subtitle_track': subtitleTrack,
        if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
        if (startMs != null) 'start_ms': startMs,
        if (downlinkBps != null && downlinkBps > 0) 'downlink_bps': downlinkBps,
        if (attemptId != null && attemptId.isNotEmpty) 'attempt_id': attemptId,
        if (safeClient != null) 'client': safeClient,
      },
    );
    return PlaybackSession.fromJson(body);
  }

  /// 开启软件转码全局策略：优先走 canonical `PUT /api/v1/playback/policy`，
  /// 若旧版/代理路由返回 405 则自动降级 `POST /api/v1/playback/policy`。
  Future<bool> enableSoftwareTranscode() async {
    const payload = <String, dynamic>{'software_transcode_enabled': true};
    try {
      final res = await _client.unwrap<Map<String, dynamic>>(
        Channel.playback,
        'PUT',
        '/api/v1/playback/policy',
        body: payload,
      );
      return res['software_transcode_enabled'] != false;
    } on ApiException catch (e) {
      if (e.httpStatus == 405) {
        final res = await _client.unwrap<Map<String, dynamic>>(
          Channel.playback,
          'POST',
          '/api/v1/playback/policy',
          body: payload,
        );
        return res['software_transcode_enabled'] != false;
      }
      rethrow;
    }
  }

  /// 三态心跳探活（对齐 `PlaybackAPI.ping`）：
  /// - `true`：会话仍存活（2xx）；
  /// - `false`：服务端明确返回 404（会话已失效，需原地重开）；
  /// - `null`：网络瞬断或 5xx（不可误判为死会话）。
  Future<bool?> ping(String sessionId, {String? shareSlug}) async {
    try {
      await _client.unwrap<dynamic>(
        Channel.playback,
        'POST',
        '${_base(shareSlug)}/sessions/$sessionId/ping',
      );
      return true;
    } on ApiException catch (e) {
      if (e.httpStatus == 404) return false;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> stop(String sessionId, {String? shareSlug}) async {
    await _client.unwrap<dynamic>(
      Channel.playback,
      'DELETE',
      '${_base(shareSlug)}/sessions/$sessionId',
    );
  }

  Future<Map<String, dynamic>> diagnostics(
    String sessionId, {
    String? token,
    String? shareSlug,
  }) async {
    return _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'GET',
      '${_base(shareSlug)}/sessions/$sessionId/diagnostics',
      query: {
        if (token != null && token.isNotEmpty) 'token': token,
      },
    );
  }

  /// 严格遵循生命周期 `event: 'start' | 'progress' | 'stop'`（绝不传 `'finished'`），
  /// 并解析服务端下发的 `ended_by_admin` 标记。
  Future<PlaybackProgressResult?> reportProgress({
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
    String? shareSlug,
  }) async {
    final safeEvent = switch (event) {
      'start' || 'progress' || 'stop' => event,
      'finished' => 'stop',
      _ => event,
    };
    final res = await _client.unwrap<dynamic>(
      Channel.playback,
      'POST',
      '${_base(shareSlug)}/progress',
      body: {
        'media_item_id': mediaItemId,
        'season_number': seasonNumber ?? 0,
        'episode_number': episodeNumber ?? 0,
        if (safeEvent != null) 'event': safeEvent,
        if (positionMs != null) 'position_ms': positionMs,
        if (paused != null) 'paused': paused,
        if (fileId != null) 'file_id': fileId,
        if (audioTrack != null) 'audio_track': audioTrack,
        if (subtitleTrack != null) 'subtitle_track': subtitleTrack,
        if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
      },
    );
    if (res is Map) {
      return PlaybackProgressResult.fromJson(res.cast<String, dynamic>());
    }
    return null;
  }

  Future<Map<String, dynamic>> resume({
    required int mediaItemId,
    int? seasonNumber,
    int? episodeNumber,
    String? shareSlug,
  }) async {
    return _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'GET',
      '${_base(shareSlug)}/resume',
      query: {
        'media_item_id': mediaItemId,
        'season_number': seasonNumber ?? 0,
        'episode_number': episodeNumber ?? 0,
      },
    );
  }

  /// 获取进度条雪碧图缩略图索引：`GET /api/v1/playback/files/{fileId}/trickplay?token=...`
  Future<PlaybackTrickplay?> trickplay(
    int fileId, {
    String? token,
    String? shareSlug,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'GET',
      '${_base(shareSlug)}/files/$fileId/trickplay',
      query: {
        if (token != null && token.isNotEmpty) 'token': token,
      },
    );
    return PlaybackTrickplay.fromJson(body);
  }

  /// 设置本剧自动跳过片头偏好：优先走 canonical `PUT /api/v1/playback/auto-skip/intro/{id}`，
  /// 404/405 兜底 `POST /api/v1/playback/items/{id}/auto-skip-intro`。
  Future<void> setAutoSkipIntro(int mediaItemId, bool enabled) async {
    final payload = <String, dynamic>{'enabled': enabled};
    try {
      await _client.unwrap<dynamic>(
        Channel.playback,
        'PUT',
        '/api/v1/playback/auto-skip/intro/$mediaItemId',
        body: payload,
      );
    } on ApiException catch (e) {
      if (e.httpStatus == 404 || e.httpStatus == 405) {
        await _client.unwrap<dynamic>(
          Channel.playback,
          'POST',
          '/api/v1/playback/items/$mediaItemId/auto-skip-intro',
          body: payload,
        );
        return;
      }
      rethrow;
    }
  }

  /// 上报单次播放 QoE 指标：`POST /api/v1/playback/metrics`
  Future<void> submitMetrics(Map<String, dynamic> payload) async {
    await _client.unwrap<dynamic>(
      Channel.playback,
      'POST',
      '/api/v1/playback/metrics',
      body: payload,
    );
  }

  /// 上报客户端诊断事件日志：`POST /api/v1/playback/client-log`
  Future<void> submitClientLog(Map<String, dynamic> payload) async {
    await _client.unwrap<dynamic>(
      Channel.playback,
      'POST',
      '/api/v1/playback/client-log',
      body: payload,
    );
  }

  /// 片源单字节可达性探测（`Range: bytes=0-0`，5 秒超时，对应 `SourceProbe.swift`）。
  Future<SourceProbeResult> probeSourceHead(
    String streamUrl, {
    Map<String, String>? headers,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        validateStatus: (_) => true,
      ),
    );
    try {
      final res = await dio.get<dynamic>(
        streamUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: <String, String>{
            'Range': 'bytes=0-0',
            if (headers != null) ...headers,
          },
        ),
      );
      final status = res.statusCode ?? 0;
      if ((status >= 200 && status < 300) || status == 401 || status == 403) {
        return const SourceProbeResult(SourceProbeVerdict.reachable);
      }
      if (status == 404) {
        return const SourceProbeResult(SourceProbeVerdict.missing);
      }
      return SourceProbeResult(
        SourceProbeVerdict.unreachable,
        detail: 'HTTP $status',
      );
    } catch (e) {
      return SourceProbeResult(
        SourceProbeVerdict.unreachable,
        detail: e.toString(),
      );
    } finally {
      dio.close();
    }
  }
}

enum SourceProbeVerdict { reachable, missing, unreachable }

class SourceProbeResult {
  const SourceProbeResult(this.verdict, {this.detail});

  final SourceProbeVerdict verdict;
  final String? detail;
}

class PlaybackProgressResult {
  const PlaybackProgressResult({
    this.positionMs = 0,
    this.played = false,
    this.playCount = 0,
    this.durationMs,
    this.audioTrack,
    this.subtitleTrack,
    this.endedByAdmin = false,
  });

  factory PlaybackProgressResult.fromJson(Map<String, dynamic> json) {
    return PlaybackProgressResult(
      positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
      played: json['played'] == true,
      playCount: (json['play_count'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      audioTrack: json['audio_track']?.toString(),
      subtitleTrack: json['subtitle_track']?.toString(),
      endedByAdmin: json['ended_by_admin'] == true,
    );
  }

  final int positionMs;
  final bool played;
  final int playCount;
  final int? durationMs;
  final String? audioTrack;
  final String? subtitleTrack;
  final bool endedByAdmin;
}

class PlaybackAutoSkip {
  const PlaybackAutoSkip({
    this.enabled = true,
    this.intro = false,
    this.ad = true,
    this.preview = true,
  });

  factory PlaybackAutoSkip.fromJson(Map<String, dynamic> json) {
    return PlaybackAutoSkip(
      enabled: json['enabled'] != false,
      intro: json['intro'] == true,
      ad: json['ad'] != false,
      preview: json['preview'] != false,
    );
  }

  final bool enabled;
  final bool intro;
  final bool ad;
  final bool preview;
}

class PlaybackTrickplay {
  const PlaybackTrickplay({
    this.ready = false,
    this.intervalMs = 0,
    this.tileWidth = 0,
    this.tileHeight = 0,
    this.columns = 0,
    this.rows = 0,
    this.count = 0,
    this.sheets = const [],
  });

  factory PlaybackTrickplay.fromJson(Map<String, dynamic> json) {
    return PlaybackTrickplay(
      ready: json['ready'] == true,
      intervalMs: (json['interval_ms'] as num?)?.toInt() ?? 0,
      tileWidth: (json['tile_width'] as num?)?.toInt() ?? 0,
      tileHeight: (json['tile_height'] as num?)?.toInt() ?? 0,
      columns: (json['columns'] as num?)?.toInt() ?? 0,
      rows: (json['rows'] as num?)?.toInt() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      sheets: [
        for (final s in (json['sheets'] as List? ?? const [])) s.toString(),
      ],
    );
  }

  final bool ready;
  final int intervalMs;
  final int tileWidth;
  final int tileHeight;
  final int columns;
  final int rows;
  final int count;
  final List<String> sheets;

  bool get usable =>
      ready &&
      count > 0 &&
      intervalMs > 0 &&
      tileWidth > 0 &&
      tileHeight > 0 &&
      columns > 0 &&
      rows > 0 &&
      sheets.isNotEmpty;
}

class PlaybackAudioTrack {
  const PlaybackAudioTrack({
    required this.ref,
    this.codec,
    this.channels,
    this.language,
    this.isDefault = false,
    this.unavailableReason,
  });

  factory PlaybackAudioTrack.fromJson(Map<String, dynamic> json) {
    return PlaybackAudioTrack(
      ref: (json['ref'] ?? json['track_ref'] ?? '').toString(),
      codec: json['codec']?.toString(),
      channels: (json['channels'] as num?)?.toInt(),
      language: json['language']?.toString(),
      isDefault: json['is_default'] as bool? ?? false,
      unavailableReason: json['unavailable_reason']?.toString(),
    );
  }

  final String ref;
  final String? codec;
  final int? channels;
  final String? language;
  final bool isDefault;
  final String? unavailableReason;

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
    if (codec != null && codec!.isNotEmpty) parts.add(codec!.toUpperCase());
    if (channels != null) parts.add('$channels 声道');
    return parts.join(' · ');
  }
}

class PlaybackSubtitleTrack {
  const PlaybackSubtitleTrack({
    required this.trackRef,
    this.kind = '',
    this.codec,
    this.language,
    this.isDefault = false,
    this.isAi = false,
    this.title,
    this.isForced = false,
    this.url,
    this.unavailableReason,
  });

  factory PlaybackSubtitleTrack.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind']?.toString() ?? '';
    final rawCodec = json['codec']?.toString();
    return PlaybackSubtitleTrack(
      trackRef: (json['track_ref'] ?? json['ref'] ?? '').toString(),
      kind: rawKind,
      codec: rawCodec ?? (rawKind.isNotEmpty ? rawKind : null),
      language: json['language']?.toString(),
      isDefault: json['is_default'] as bool? ?? false,
      isAi: json['is_ai'] as bool? ?? false,
      title: json['title']?.toString(),
      isForced: json['is_forced'] as bool? ?? false,
      url: json['url']?.toString(),
      unavailableReason: json['unavailable_reason']?.toString(),
    );
  }

  final String trackRef;
  final String kind;
  final String? codec;
  final String? language;
  final bool isDefault;
  final bool isAi;
  final String? title;
  final bool isForced;
  final String? url;
  final String? unavailableReason;

  bool get isBitmap =>
      kind.toLowerCase() == 'pgs' ||
      (codec?.toLowerCase() == 'pgs') ||
      (codec?.toLowerCase().contains('hdmv_pgs') ?? false) ||
      (codec?.toLowerCase().contains('dvd_subtitle') ?? false);

  bool get isAvailable =>
      unavailableReason == null || unavailableReason!.trim().isEmpty;

  String get label {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    const externalPrefix = 'external:';
    if (trackRef.startsWith(externalPrefix)) {
      return trackRef.substring(externalPrefix.length);
    }
    if (language != null && language!.isNotEmpty && language != 'und') {
      return language!.toUpperCase();
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
    final parts = <String>[
      if (kind.isNotEmpty) kindLabels[kind.toLowerCase()] ?? kind.toUpperCase(),
    ];
    if (isAi) parts.add('AI 生成');
    if (isForced) parts.add('强制');
    if (isDefault) parts.add('默认');
    if (!isAvailable) parts.add(unavailableReason!);
    return parts.join(' · ');
  }
}

class PlaybackSkipSegment {
  const PlaybackSkipSegment({
    required this.type,
    required this.startMs,
    required this.endMs,
    this.toEnd = false,
  });

  factory PlaybackSkipSegment.fromJson(Map<String, dynamic> json) {
    return PlaybackSkipSegment(
      type: (json['type'] ?? json['kind'] ?? 'other').toString(),
      startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
      endMs: (json['end_ms'] as num?)?.toInt() ?? 0,
      toEnd: json['to_end'] == true,
    );
  }

  /// `intro` | `outro` | `ad` | `preview` | `other`
  final String type;
  String get kind => type;
  final int startMs;
  final int endMs;
  final bool toEnd;
}

class PlaybackChapter {
  const PlaybackChapter({
    required this.startMs,
    required this.title,
  });

  factory PlaybackChapter.fromJson(Map<String, dynamic> json) {
    final ms = (json['start_ms'] as num?)?.toInt() ?? 0;
    final rawTitle = json['title']?.toString().trim() ?? '';
    return PlaybackChapter(
      startMs: ms,
      title: rawTitle.isEmpty ? '章节' : rawTitle,
    );
  }

  final int startMs;
  final String title;
}

class PlaybackSession {
  const PlaybackSession({
    required this.decision,
    this.sessionId,
    this.streamUrl,
    this.streamToken,
    this.startMs = 0,
    this.durationMs,
    this.timeline = 'full',
    this.fileId,
    this.tier,
    this.degradedFrom,
    this.disc,
    this.canSelfEnable,
    this.costHint,
    this.suggestion,
    this.onDrive = false,
    this.sizeBytes,
    this.cacheKey,
    this.burnSubtitle,
    this.autoSkip,
    this.watchPositionMs,
    this.watchAudioTrack,
    this.watchSubtitleTrack,
    this.subtitleUrls = const [],
    this.masterUrl,
    this.hwBackend,
    this.deliveryMode,
    this.transcodeReason,
    this.videoCodec,
    this.audioCodec,
    this.resolution,
    this.hdr,
    this.bitRate,
    this.frameRate,
    this.container,
    this.audioTracks = const [],
    this.subtitles = const [],
    this.skipSegments = const [],
    this.chapters = const [],
  });

  /// `plan` | `consent` | `rejected`
  final String decision;
  String get action => decision;
  final String? sessionId;
  final String? streamUrl;
  final String? streamToken;
  final int startMs;
  final int? durationMs;

  /// `'full'` / `'file'`（文件时间轴）或 `'session'`（会话起点相对时间轴）
  final String timeline;
  final int? fileId;
  final int? tier;
  final int? degradedFrom;
  final String? disc; // 'image' | 'folder' | null
  final bool? canSelfEnable;
  final String? costHint;
  final String? suggestion;
  final bool onDrive;
  final int? sizeBytes;
  final String? cacheKey;
  final String? burnSubtitle;
  final PlaybackAutoSkip? autoSkip;
  final int? watchPositionMs;
  final String? watchAudioTrack;
  final String? watchSubtitleTrack;
  final List<String> subtitleUrls;
  final String? masterUrl;
  final String? hwBackend;
  final String? deliveryMode;
  final String? transcodeReason;
  final String? videoCodec;
  final String? audioCodec;
  final String? resolution;
  final String? hdr;
  final int? bitRate;
  final double? frameRate;
  final String? container;
  final List<PlaybackAudioTrack> audioTracks;
  final List<PlaybackSubtitleTrack> subtitles;
  final List<PlaybackSkipSegment> skipSegments;
  final List<PlaybackChapter> chapters;

  bool get playable => decision == 'plan' && streamUrl != null;

  bool get isSessionTimeline => timeline == 'session';

  factory PlaybackSession.fromJson(Map<String, dynamic> json) {
    final d = json['decision'];
    final dMap = d is Map<String, dynamic>
        ? d
        : (d is Map ? Map<String, dynamic>.from(d) : null);
    final src = json['source'];
    final srcMap = src is Map<String, dynamic>
        ? src
        : (src is Map ? Map<String, dynamic>.from(src) : null);
    final watch = json['watch'];
    final watchMap = watch is Map<String, dynamic>
        ? watch
        : (watch is Map ? Map<String, dynamic>.from(watch) : null);
    final autoSkipRaw = json['auto_skip'];
    final autoSkipMap = autoSkipRaw is Map<String, dynamic>
        ? autoSkipRaw
        : (autoSkipRaw is Map ? Map<String, dynamic>.from(autoSkipRaw) : null);
    final videoMap = dMap?['video'] is Map
        ? Map<String, dynamic>.from(dMap!['video'] as Map)
        : null;
    final audioMap = dMap?['audio'] is Map
        ? Map<String, dynamic>.from(dMap!['audio'] as Map)
        : null;

    final videoAction = videoMap?['action']?.toString();
    final explicitMode =
        (dMap?['mode'] ?? dMap?['delivery'] ?? json['mode'])?.toString();
    final resolvedMode = explicitMode ??
        (videoAction == 'copy'
            ? 'direct_play'
            : (videoAction == 'transcode' ? 'transcode' : null));

    final rawStreamUrl = json['stream_url']?.toString();
    final extractedToken = rawStreamUrl != null
        ? Uri.tryParse(rawStreamUrl)?.queryParameters['token']
        : null;

    final rawSubtitleUrls = [
      for (final u in (json['subtitle_urls'] as List? ?? const []))
        u.toString(),
    ];
    final rawSubPlans = (dMap?['subtitles'] as List? ?? const []);
    final parsedSubtitles = <PlaybackSubtitleTrack>[];
    for (var i = 0; i < rawSubPlans.length; i++) {
      final item = rawSubPlans[i];
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if (map['url'] == null && i < rawSubtitleUrls.length) {
        map['url'] = rawSubtitleUrls[i];
      }
      parsedSubtitles.add(PlaybackSubtitleTrack.fromJson(map));
    }

    final segList =
        json['segments'] as List? ?? dMap?['segments'] as List? ?? const [];
    final chapList = json['chapters'] as List? ?? const [];
    final parsedFileId = (dMap?['file_id'] as num?)?.toInt();
    final parsedSize = (srcMap?['size_bytes'] as num?)?.toInt();
    final explicitCacheKey = srcMap?['cache_key']?.toString();
    final derivedCacheKey = explicitCacheKey ??
        (parsedFileId != null && parsedSize != null
            ? 'f$parsedFileId-$parsedSize'
            : null);

    return PlaybackSession(
      decision: (dMap?['outcome'] ?? json['action'] ?? json['decision'] ?? '')
          .toString(),
      deliveryMode: resolvedMode,
      transcodeReason:
          (dMap?['reason'] ?? dMap?['transcode_reason'])?.toString(),
      fileId: parsedFileId,
      tier: (dMap?['tier'] as num?)?.toInt(),
      degradedFrom: (dMap?['degraded_from'] as num?)?.toInt(),
      disc: dMap?['disc']?.toString(),
      canSelfEnable: dMap?['can_self_enable'] as bool?,
      costHint: dMap?['cost_hint']?.toString(),
      suggestion: dMap?['suggestion']?.toString(),
      onDrive: srcMap?['on_drive'] == true,
      sizeBytes: parsedSize,
      cacheKey: derivedCacheKey,
      burnSubtitle: videoMap?['burn_subtitle']?.toString(),
      autoSkip: autoSkipMap != null
          ? PlaybackAutoSkip.fromJson(autoSkipMap)
          : null,
      watchPositionMs: (watchMap?['position_ms'] as num?)?.toInt(),
      watchAudioTrack: watchMap?['audio_track']?.toString(),
      watchSubtitleTrack: watchMap?['subtitle_track']?.toString(),
      timeline: (json['timeline'] ?? 'full').toString(),
      videoCodec: (srcMap?['video_codec'] ??
              videoMap?['codec'] ??
              dMap?['video_codec'] ??
              json['video_codec'])
          ?.toString(),
      audioCodec: (audioMap?['codec'] ??
              dMap?['audio_codec'] ??
              json['audio_codec'])
          ?.toString(),
      resolution: (srcMap?['resolution'] ??
              dMap?['resolution'] ??
              json['resolution'])
          ?.toString(),
      hdr: srcMap?['hdr']?.toString(),
      bitRate: (srcMap?['bit_rate'] as num?)?.toInt(),
      frameRate: (srcMap?['frame_rate'] as num?)?.toDouble(),
      container: (srcMap?['container'] ??
              dMap?['container'] ??
              json['container'])
          ?.toString(),
      audioTracks: [
        for (final t in (dMap?['audio_tracks'] as List? ?? const []))
          if (t is Map)
            PlaybackAudioTrack.fromJson(Map<String, dynamic>.from(t)),
      ],
      subtitles: parsedSubtitles,
      sessionId: json['session_id']?.toString(),
      streamUrl: rawStreamUrl,
      streamToken: extractedToken,
      startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
      durationMs: (watchMap?['duration_ms'] as num?)?.toInt(),
      subtitleUrls: rawSubtitleUrls,
      masterUrl: json['master_url']?.toString(),
      hwBackend: json['hw_backend']?.toString(),
      skipSegments: [
        for (final s in segList)
          if (s is Map)
            PlaybackSkipSegment.fromJson(Map<String, dynamic>.from(s)),
      ],
      chapters: [
        for (final c in chapList)
          if (c is Map) PlaybackChapter.fromJson(Map<String, dynamic>.from(c)),
      ],
    );
  }
}
