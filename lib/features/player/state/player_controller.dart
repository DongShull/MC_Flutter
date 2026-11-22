import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/player/player_page_args.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/session/playback_session_api.dart';

// PlayerPageArgs / EpisodeItem 已下沉 core（detail 等入口可构造，禁跨 feature import）。
export '../../../core/player/player_page_args.dart';

enum PlayerStatus { idle, opening, ready, failed }

/// 服务器协商结果（decision != plan 时挂在状态上等 UI 弹窗）。
enum SessionDecision { plan, consent, rejected }

/// 播放页可观察状态（对应 Android PlaybackSessionHolder.State + 引擎 state 的 UI 子集）。
@immutable
class PlayerPlayback {
  const PlayerPlayback({
    this.status = PlayerStatus.idle,
    this.error,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
    this.pendingDecision,
    this.skipSegments = const [],
  });

  final PlayerStatus status;
  final String? error;
  final bool playing;
  final Duration position;
  final Duration? duration;
  final double speed;

  /// consent：需用户确认转码；rejected：服务器拒绝。null = 无待处理协商结果。
  final SessionDecision? pendingDecision;

  /// 服务器会话下发的可跳区间（片头/片尾；进度条琥珀色标出）。
  final List<PlaybackSkipSegment> skipSegments;

  PlayerPlayback copyWith({
    PlayerStatus? status,
    String? error,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? speed,
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
      pendingDecision: clearDecision ? null : (pendingDecision ?? this.pendingDecision),
      skipSegments: clearSkipSegments ? const [] : (skipSegments ?? this.skipSegments),
    );
  }
}

/// 全 App 唯一播放器实例（docs/design/03 §2.1：provider 挂全局单例）。
final playerServiceProvider = Provider<PlayerService>((ref) {
  final service = PlayerService.create();
  ref.onDispose(service.close);
  return service;
});

/// 播放页控制器：只做「服务调用 + 状态搬运」，UI 全在 widgets/。
/// 对应 Android PlayerViewModel / PlaybackSessionHolder 的播放控制部分。
class PlayerController extends Notifier<PlayerPlayback> {
  static const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  PlayerService get _service => ref.read(playerServiceProvider);

  PlaybackSessionApi? _sessionApi;
  String? _serverSessionId;
  Timer? _pingTimer;
  DateTime _lastProgressReport = DateTime.fromMillisecondsSinceEpoch(0);
  PlayerPageArgs? _currentArgs;

  /// 服务器会话给出的可选轨道（open 时刷新；空 = 服务器未提供轨道信息）。
  List<PlaybackAudioTrack> _audioTracks = const [];
  List<PlaybackSubtitleTrack> _subtitles = const [];
  String? _selectedAudioTrack;
  String? _selectedSubtitleTrack;

  List<PlaybackAudioTrack> get audioTracks => _audioTracks;
  List<PlaybackSubtitleTrack> get subtitles => _subtitles;
  String? get selectedAudioTrack => _selectedAudioTrack;
  String? get selectedSubtitleTrack => _selectedSubtitleTrack;

  /// 30s 心跳（服务器口径；本地协调器心跳独立 5s）。
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

  /// 当前后端的能力开关（画质/诊断等是否支持，先查这里再调对应方法）。
  PlayerCapability get capabilities => _service.capabilities;

  /// 采集诊断快照（引擎可读字段；拿不到的字段为 null = 缺失）。
  /// 诊断面板 UI 未实现，本方法先供调试/后续面板使用。
  Future<PlayerDiagnostics> collectDiagnostics() =>
      _service.collectDiagnostics(sessionId: _serverSessionId);

  /// 当前/最近一次播放的流地址（cast 投屏复用；DLNA 直连不走会话）。
  String? get lastStreamUrl => _lastUrl;
  String? _lastUrl;

  Future<void> open(PlayerPageArgs args) async {
    _lastUrl = args.url;
    // 切集/重开时清掉上一集的可跳区间（新会话响应再刷新）。
    state = state.copyWith(
      status: PlayerStatus.opening,
      clearError: true,
      clearSkipSegments: true,
    );
    try {
      // 服务器会话协商（正式路径）：mediaItemId/fileId 在才走；演示路径直连 url。
      var url = args.url;
      var startPosition = args.startPosition;
      if (args.mediaItemId != null || args.fileId != null) {
        _currentArgs = args;
        _sessionApi = PlaybackSessionApi(McClient(session: ref.read(sessionStoreProvider)));
        final session = await _sessionApi!.start(
          fileId: args.fileId,
          mediaItemId: args.mediaItemId,
          seasonNumber: args.seasonNumber,
          episodeNumber: args.episodeNumber,
          startMs: args.startPosition?.inMilliseconds,
          audioTrack: _selectedAudioTrack,
          subtitleTrack: _selectedSubtitleTrack,
        );
        if (session.playable) {
          _serverSessionId = session.sessionId;
          url = session.streamUrl!;
          _audioTracks = session.audioTracks;
          _subtitles = session.subtitles;
          state = state.copyWith(skipSegments: session.skipSegments);
          _selectedAudioTrack ??= _firstDefault(
              [for (final t in session.audioTracks) if (t.isDefault) t.ref]);
          _selectedSubtitleTrack ??= _subtitles.isEmpty
              ? null
              : (_firstDefault(
                    [for (final t in _subtitles) if (t.isDefault) t.trackRef],
                  ) ??
                  _subtitles.first.trackRef);
          if (args.startPosition == null && session.startMs > 0) {
            startPosition = Duration(milliseconds: session.startMs);
          }
          _startPing();
        } else {
          // consent = 需用户确认转码；rejected = 服务器拒绝。挂状态给 UI 弹窗，
          // 同时先按原 url 兜底直播（不因协商失败黑屏）。
          debugPrint('playback session decision=${session.decision}');
          state = state.copyWith(
            pendingDecision: session.decision == 'rejected'
                ? SessionDecision.rejected
                : SessionDecision.consent,
          );
        }
      }
      await _service.open(PlayerRequest(
        url: url,
        title: args.title,
        startPosition: startPosition,
        headers: args.headers,
        sessionId: _serverSessionId,
      ));
      state = state.copyWith(status: PlayerStatus.ready);
      // 位置/时长/播放态直接消费服务的稳定通知器（UI 不轮询引擎）。
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

  void _onPosition() {
    state = state.copyWith(position: _service.position.value);
    // 观看进度上报：15s 节流（POST /playback/progress）。
    final args = _currentArgs;
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
            positionMs: state.position.inMilliseconds,
            paused: !state.playing,
          )
          .catchError((_) {});
    }
  }
  void _onPlaying() => state = state.copyWith(playing: _service.playing.value);
  void _onDuration() =>
      state = state.copyWith(duration: _service.duration.value);

  void detach() {
    _stopSession();
    _service.position.removeListener(_onPosition);
    _service.playing.removeListener(_onPlaying);
    _service.duration.removeListener(_onDuration);
  }

  /// 取第一个默认轨引用（不引 collection 包，手写 firstOrNull 口径）。
  String? _firstDefault(List<String> refs) =>
      refs.isEmpty ? null : refs.first;

  /// 换音轨/字幕轨：对齐切集路径（detach → 带轨参数重开会话 → 续播当前进度）。
  /// subtitleTrack 传 '' 表示关闭字幕；null 表示保持不变。
  Future<void> switchTrack({String? audioTrack, String? subtitleTrack}) async {
    final args = _currentArgs;
    if (args == null || _sessionApi == null) return;
    final pos = _service.position.value;
    detach();
    if (audioTrack != null) _selectedAudioTrack = audioTrack;
    if (subtitleTrack != null) _selectedSubtitleTrack = subtitleTrack;
    await open(_copyArgsAt(args, pos));
  }

  /// 以当前进度续播复制 args（换轨/换集共用口径：startPosition = 当前进度）。
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

  /// 用户在协商弹窗点了「继续播放」（consent 确认，或 rejected 仍要看）。
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

  /// 拖动条点按 / 拖动松手 / 章节跳播统一入口（钳制在 [0, duration]）。
  Future<void> seekTo(Duration target) async {
    final duration = state.duration;
    final clamped = duration == null
        ? (target.isNegative ? Duration.zero : target)
        : target < Duration.zero
            ? Duration.zero
            : (target > duration ? duration : target);
    await _service.seekTo(clamped);
    state = state.copyWith(position: clamped);
  }

  /// 手势横向滑动：满屏一划 = 90 秒（Android PlayerGestureMath）。
  Future<void> seekByRelative(int deltaMs) async {
    final base = _service.position.value;
    await seekTo(base + Duration(milliseconds: deltaMs));
  }

  Future<void> setSpeed(double speed) async {
    await _service.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  /// 长按 2× 变速（Android HOLD_SPEED = 2f）：按住升到 2×，松手回原速。
  Future<void> setHoldSpeed(bool holding) async {
    await setSpeed(holding ? 2.0 : 1.0);
  }

  Future<void> exit() async {
    detach();
    await _service.close();
    state = const PlayerPlayback(status: PlayerStatus.idle);
  }
}

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerPlayback>(PlayerController.new);
