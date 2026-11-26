import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/player/player_page_args.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/session/playback_session_api.dart';

export '../../../core/player/player_page_args.dart';

enum PlayerStatus { idle, opening, ready, failed }

/// 服务器协商结果（decision != plan 时挂在状态上等 UI 弹窗）。
enum SessionDecision { plan, consent, rejected }

/// 解析后的外挂 / AI 字幕时间轴条目（支持 WebVTT 与 SRT）。
class SubtitleCue {
  const SubtitleCue({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final int startMs;
  final int endMs;
  final String text;
}

/// 轻量级 WebVTT / SRT 字幕解析器。
List<SubtitleCue> parseSubtitleText(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final cues = <SubtitleCue>[];
  final timeRe = RegExp(
    r'(?:(\d{1,2}):)?(\d{2}):(\d{2})[.,](\d{3})\s*-->\s*(?:(\d{1,2}):)?(\d{2}):(\d{2})[.,](\d{3})',
  );
  int toMs(String? h, String m, String s, String ms) {
    final hh = int.tryParse(h ?? '0') ?? 0;
    final mm = int.tryParse(m) ?? 0;
    final ss = int.tryParse(s) ?? 0;
    final mmm = int.tryParse(ms) ?? 0;
    return (((hh * 60 + mm) * 60) + ss) * 1000 + mmm;
  }

  var i = 0;
  while (i < lines.length) {
    final line = lines[i].trim();
    final match = timeRe.firstMatch(line);
    if (match != null) {
      final start = toMs(
        match.group(1),
        match.group(2)!,
        match.group(3)!,
        match.group(4)!,
      );
      final end = toMs(
        match.group(5),
        match.group(6)!,
        match.group(7)!,
        match.group(8)!,
      );
      i++;
      final buf = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        final cleaned = lines[i]
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll(RegExp(r'\{\\[^}]+\}'), '')
            .trim();
        if (cleaned.isNotEmpty) buf.add(cleaned);
        i++;
      }
      if (buf.isNotEmpty && end > start) {
        cues.add(
          SubtitleCue(startMs: start, endMs: end, text: buf.join('\n')),
        );
      }
    } else {
      i++;
    }
  }
  return cues;
}

/// 播放页可观察状态。
@immutable
class PlayerPlayback {
  const PlayerPlayback({
    this.status = PlayerStatus.idle,
    this.error,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
    this.qualityTier = 'original',
    this.subtitleScale = 1.0,
    this.subtitleOffsetMs = 0,
    this.activeSubtitleText,
    this.completed = false,
    this.pendingDecision,
    this.skipSegments = const [],
  });

  final PlayerStatus status;
  final String? error;
  final bool playing;
  final Duration position;
  final Duration? duration;
  final double speed;
  final String qualityTier;
  final double subtitleScale;
  final int subtitleOffsetMs;
  final String? activeSubtitleText;
  final bool completed;
  final SessionDecision? pendingDecision;
  final List<PlaybackSkipSegment> skipSegments;

  PlayerPlayback copyWith({
    PlayerStatus? status,
    String? error,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? speed,
    String? qualityTier,
    double? subtitleScale,
    int? subtitleOffsetMs,
    String? activeSubtitleText,
    bool clearActiveSubtitle = false,
    bool? completed,
    SessionDecision? pendingDecision,
    bool clearError = false,
    bool clearDecision = false,
    List<PlaybackSkipSegment>? skipSegments,
    bool clearSkipSegments = false,
  }) {
    return PlayerPlayback(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      qualityTier: qualityTier ?? this.qualityTier,
      subtitleScale: subtitleScale ?? this.subtitleScale,
      subtitleOffsetMs: subtitleOffsetMs ?? this.subtitleOffsetMs,
      activeSubtitleText: clearActiveSubtitle
          ? null
          : (activeSubtitleText ?? this.activeSubtitleText),
      completed: completed ?? this.completed,
      pendingDecision:
          clearDecision ? null : (pendingDecision ?? this.pendingDecision),
      skipSegments:
          clearSkipSegments ? const [] : (skipSegments ?? this.skipSegments),
    );
  }
}

/// 全 App 唯一播放器实例（桌面端自动走 `libmpv` 硬解引擎，移动端走 `AVPlayer / ExoPlayer`）。
final playerServiceProvider = Provider<PlayerService>((ref) {
  final service = PlayerService.createDefault();
  ref.onDispose(service.close);
  return service;
});

/// 影院级播放控制器：会话协商、画质切换、外挂/AI 字幕时间轴同步、软解授权重连、完播上报与实时技术诊断。
class PlayerController extends Notifier<PlayerPlayback> {
  static const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  PlayerService get _service => ref.read(playerServiceProvider);

  PlaybackSessionApi? _sessionApi;
  PlaybackSession? _lastSession;
  String? _serverSessionId;
  Timer? _pingTimer;
  DateTime _lastProgressReport = DateTime.fromMillisecondsSinceEpoch(0);
  PlayerPageArgs? _currentArgs;
  double _speedBeforeHold = 1.0;
  bool _allowSoftwareTranscode = false;
  bool _reportedFinished = false;
  List<SubtitleCue> _subtitleCues = const [];

  List<PlaybackAudioTrack> _audioTracks = const [];
  List<PlaybackSubtitleTrack> _subtitles = const [];
  String? _selectedAudioTrack;
  String? _selectedSubtitleTrack;

  List<PlaybackAudioTrack> get audioTracks => _audioTracks;
  List<PlaybackSubtitleTrack> get subtitles => _subtitles;
  String? get selectedAudioTrack => _selectedAudioTrack;
  String? get selectedSubtitleTrack => _selectedSubtitleTrack;
  PlaybackSession? get sessionInfo => _lastSession;

  void _startPing() {
    _pingTimer?.cancel();
    final id = _serverSessionId;
    if (id == null) return;
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sessionApi?.ping(id).catchError((_) {});
    });
  }

  Future<void> _stopSession() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    final id = _serverSessionId;
    _serverSessionId = null;
    if (id != null) {
      await _sessionApi?.stop(id).catchError((_) {});
    }
  }

  @override
  PlayerPlayback build() => const PlayerPlayback(status: PlayerStatus.idle);

  String? get lastStreamUrl => _lastUrl;
  String? _lastUrl;

  String _resolveHttpUrl(String raw) {
    if (raw.startsWith('/')) {
      final base = ServerRoutes.instance.currentOrigin(
        ref.read(sessionStoreProvider).baseUrl ?? '',
      );
      if (base.isNotEmpty) return '$base$raw';
    }
    return raw;
  }

  Future<void> open(PlayerPageArgs args) async {
    _currentArgs = args;
    _reportedFinished = false;
    _subtitleCues = const [];
    state = state.copyWith(
      status: PlayerStatus.opening,
      completed: false,
      clearError: true,
      clearActiveSubtitle: true,
      clearSkipSegments: true,
    );
    try {
      var url = args.url;
      var startPosition = args.startPosition;
      final isLocalFile = url.startsWith('file://') ||
          (url.startsWith('/') &&
              !url.startsWith('/api/') &&
              !url.startsWith('/s/'));

      if (!isLocalFile && (args.mediaItemId != null || args.fileId != null)) {
        _sessionApi = PlaybackSessionApi(
          McClient(session: ref.read(sessionStoreProvider)),
        );
        final session = await _sessionApi!.start(
          fileId: args.fileId,
          mediaItemId: args.mediaItemId,
          seasonNumber: args.seasonNumber,
          episodeNumber: args.episodeNumber,
          startMs: args.startPosition?.inMilliseconds,
          maxTier: state.qualityTier,
          allowSoftwareTranscode: _allowSoftwareTranscode,
          audioTrack: _selectedAudioTrack,
          subtitleTrack: _selectedSubtitleTrack,
        );
        _lastSession = session;
        if (session.playable) {
          _serverSessionId = session.sessionId;
          url = _resolveHttpUrl(session.streamUrl!);
          _audioTracks = session.audioTracks;
          _subtitles = session.subtitles;
          state = state.copyWith(
            skipSegments: session.skipSegments,
            duration: (session.durationMs != null && session.durationMs! > 0)
                ? Duration(milliseconds: session.durationMs!)
                : state.duration,
          );
          _selectedAudioTrack ??= _firstDefault([
            for (final t in session.audioTracks)
              if (t.isDefault) t.ref,
          ]);
          _selectedSubtitleTrack ??= _subtitles.isEmpty
              ? null
              : (_firstDefault([
                    for (final t in _subtitles)
                      if (t.isDefault) t.trackRef,
                  ]) ??
                  _subtitles.first.trackRef);
          if (args.startPosition == null && session.startMs > 0) {
            startPosition = Duration(milliseconds: session.startMs);
          }
          _startPing();
          unawaited(_loadSelectedSubtitleCues(session));
        } else {
          state = state.copyWith(
            pendingDecision: session.decision == 'rejected'
                ? SessionDecision.rejected
                : SessionDecision.consent,
          );
          if (url.isEmpty) {
            state = state.copyWith(
              status: PlayerStatus.failed,
              error: session.transcodeReason ??
                  (session.decision == 'rejected'
                      ? '服务器策略拒绝此次转码会话'
                      : '当前片源需要开启软件转码后才能播放'),
            );
            return;
          }
        }
      }
      _lastUrl = _resolveHttpUrl(url);
      await _service.open(
        PlayerRequest(
          url: url,
          title: args.title,
          startPosition: startPosition,
          headers: args.headers,
        ),
      );
      if (state.speed != 1.0) {
        await _service.setSpeed(state.speed);
      }
      state = state.copyWith(status: PlayerStatus.ready);
      _service.position.addListener(_onPosition);
      _service.playing.addListener(_onPlaying);
      _service.duration.addListener(_onDuration);
      _onPosition();
      _onPlaying();
      _onDuration();
    } catch (e) {
      state = state.copyWith(
        status: PlayerStatus.failed,
        error: '播放失败：$e',
      );
    }
  }

  Future<void> _loadSelectedSubtitleCues(PlaybackSession session) async {
    final sel = _selectedSubtitleTrack;
    if (sel == null || sel.isEmpty) {
      _subtitleCues = const [];
      state = state.copyWith(clearActiveSubtitle: true);
      return;
    }
    String? subUrl;
    for (final t in session.subtitles) {
      if (t.trackRef == sel && t.url != null && t.url!.isNotEmpty) {
        subUrl = t.url;
        break;
      }
    }
    subUrl ??=
        session.subtitleUrls.isNotEmpty ? session.subtitleUrls.first : null;
    if (subUrl == null || subUrl.isEmpty) return;
    try {
      final full = _resolveHttpUrl(subUrl);
      final resp = await Dio().get<String>(
        full,
        options: Options(
          headers: mcImageHeaders(),
          responseType: ResponseType.plain,
        ),
      );
      final body = resp.data;
      if ((resp.statusCode ?? 0) >= 200 &&
          (resp.statusCode ?? 0) < 300 &&
          body != null) {
        _subtitleCues = parseSubtitleText(body);
        _syncSubtitleAt(state.position);
      }
    } catch (_) {}
  }

  void _syncSubtitleAt(Duration pos) {
    if (_subtitleCues.isEmpty) {
      if (state.activeSubtitleText != null) {
        state = state.copyWith(clearActiveSubtitle: true);
      }
      return;
    }
    final adjustedMs = pos.inMilliseconds - state.subtitleOffsetMs;
    String? matched;
    for (final cue in _subtitleCues) {
      if (adjustedMs >= cue.startMs && adjustedMs <= cue.endMs) {
        matched = cue.text;
        break;
      }
    }
    if (matched != state.activeSubtitleText) {
      state = matched == null
          ? state.copyWith(clearActiveSubtitle: true)
          : state.copyWith(activeSubtitleText: matched);
    }
  }

  void _onPosition() {
    final pos = _service.position.value;
    final dur = state.duration;
    final nearEnd = dur != null &&
        dur.inSeconds > 10 &&
        pos.inMilliseconds >= dur.inMilliseconds - 1500;
    state = state.copyWith(
      position: pos,
      completed: nearEnd ? true : state.completed,
    );
    _syncSubtitleAt(pos);

    final args = _currentArgs;
    if (nearEnd && !_reportedFinished && args?.mediaItemId != null) {
      _reportedFinished = true;
      _sessionApi
          ?.reportProgress(
            mediaItemId: args!.mediaItemId!,
            seasonNumber: args.seasonNumber,
            episodeNumber: args.episodeNumber,
            event: 'finished',
            positionMs: pos.inMilliseconds,
            paused: true,
          )
          .catchError((_) {});
    }

    final now = DateTime.now();
    if (args?.mediaItemId != null &&
        state.status == PlayerStatus.ready &&
        now.difference(_lastProgressReport) >= const Duration(seconds: 15)) {
      _lastProgressReport = now;
      _sessionApi
          ?.reportProgress(
            mediaItemId: args!.mediaItemId!,
            seasonNumber: args.seasonNumber,
            episodeNumber: args.episodeNumber,
            event: 'progress',
            positionMs: pos.inMilliseconds,
            paused: !state.playing,
          )
          .catchError((_) {});
    }
  }

  void _onPlaying() => state = state.copyWith(playing: _service.playing.value);
  void _onDuration() {
    final svcDur = _service.duration.value;
    if (svcDur != null && svcDur > Duration.zero) {
      state = state.copyWith(duration: svcDur);
    }
  }

  void detach() {
    _stopSession();
    _service.position.removeListener(_onPosition);
    _service.playing.removeListener(_onPlaying);
    _service.duration.removeListener(_onDuration);
  }

  String? _firstDefault(List<String> refs) => refs.isEmpty ? null : refs.first;

  Future<void> switchTrack({String? audioTrack, String? subtitleTrack}) async {
    final args = _currentArgs;
    if (args == null || _sessionApi == null) return;
    final pos = _service.position.value;
    detach();
    if (audioTrack != null) _selectedAudioTrack = audioTrack;
    if (subtitleTrack != null) _selectedSubtitleTrack = subtitleTrack;
    await open(_copyArgsAt(args, pos));
  }

  Future<void> setQualityTier(String tier) async {
    if (tier == state.qualityTier) return;
    state = state.copyWith(qualityTier: tier);
    final args = _currentArgs;
    if (args == null || _sessionApi == null) return;
    final pos = _service.position.value;
    detach();
    await open(_copyArgsAt(args, pos));
  }

  void setSubtitleScale(double scale) {
    state = state.copyWith(subtitleScale: scale.clamp(0.75, 1.6));
  }

  void adjustSubtitleOffset(int deltaMs) {
    final next = deltaMs == 0 ? 0 : state.subtitleOffsetMs + deltaMs;
    state = state.copyWith(subtitleOffsetMs: next);
    _syncSubtitleAt(state.position);
  }

  /// 用户确认允许软件转码后重新协商会话。
  Future<void> acceptTranscodeConsent() async {
    _allowSoftwareTranscode = true;
    state = state.copyWith(clearDecision: true);
    final args = _currentArgs;
    if (args != null) {
      detach();
      await open(args);
    }
  }

  Future<Map<String, dynamic>> fetchDiagnostics() async {
    final s = _lastSession;
    Map<String, dynamic> remote = const {};
    if (_serverSessionId != null && _sessionApi != null) {
      try {
        remote = await _sessionApi!.diagnostics(
          _serverSessionId!,
          token: s?.streamToken,
        );
      } catch (_) {}
    }
    final mbps = s?.bitRate != null && s!.bitRate! > 0
        ? '${(s.bitRate! / 1000000).toStringAsFixed(1)} Mbps'
        : null;
    final resHdr = [
      if (s?.resolution != null && s!.resolution!.isNotEmpty) s.resolution!,
      if (s?.hdr != null && s!.hdr!.isNotEmpty) s.hdr!,
    ].join(' · ');
    return {
      '交付模式': s?.deliveryMode == 'direct_play'
          ? 'Direct Play (原盘直连)'
          : (s?.deliveryMode ?? remote['processing_mode'] ?? 'Direct / Local'),
      '封装容器': (s?.container ?? remote['container'] ?? '-').toString().toUpperCase(),
      '视频规格': resHdr.isEmpty ? '-' : resHdr,
      '视频编码': (s?.videoCodec ?? remote['video_codec'] ?? '-').toString().toUpperCase(),
      '音频编码': (s?.audioCodec ?? remote['audio_codec'] ?? '-').toString().toUpperCase(),
      if (mbps != null) '源文件码率': mbps,
      if (s?.frameRate != null) '帧率': '${s!.frameRate} fps',
      '转码加速': s?.hwBackend ?? remote['backend'] ?? '无需转码 (直通)',
      '画质档位': state.qualityTier,
      if (remote['job_speed'] != null) '转码速度': remote['job_speed'],
    };
  }

  PlayerPageArgs _copyArgsAt(PlayerPageArgs args, Duration position) {
    return PlayerPageArgs(
      url: args.url,
      mediaItemId: args.mediaItemId,
      fileId: args.fileId,
      seasonNumber: args.seasonNumber,
      episodeNumber: args.episodeNumber,
      title: args.title,
      subtitle: args.subtitle,
      startPosition: position,
      headers: args.headers,
      isEpisode: args.isEpisode,
      seasons: args.seasons,
      episodes: args.episodes,
    );
  }

  Future<void> acknowledgeDecision() async {
    state = state.copyWith(clearDecision: true);
  }

  Future<void> togglePlay() async {
    if (state.playing) {
      await _service.pause();
    } else {
      await _service.play();
    }
  }

  Future<void> seekTo(Duration target) async {
    final duration = state.duration;
    final clamped = duration == null
        ? (target.isNegative ? Duration.zero : target)
        : target < Duration.zero
            ? Duration.zero
            : (target > duration ? duration : target);
    await _service.seekTo(clamped);
    state = state.copyWith(position: clamped, completed: false);
    _syncSubtitleAt(clamped);
  }

  Future<void> seekByRelative(int deltaMs) async {
    final base = _service.position.value;
    await seekTo(base + Duration(milliseconds: deltaMs));
  }

  Future<void> setSpeed(double speed) async {
    _speedBeforeHold = speed;
    await _service.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  /// 长按 2× 倍速，松手恢复长按前的倍速（而非硬编码回 1.0x）。
  Future<void> setHoldSpeed(bool holding) async {
    if (holding) {
      _speedBeforeHold = state.speed;
      await _service.setSpeed(2.0);
      state = state.copyWith(speed: 2.0);
    } else {
      await _service.setSpeed(_speedBeforeHold);
      state = state.copyWith(speed: _speedBeforeHold);
    }
  }

  Future<void> exit() async {
    detach();
    await _service.close();
    state = const PlayerPlayback(status: PlayerStatus.idle);
  }
}

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerPlayback>(PlayerController.new);
