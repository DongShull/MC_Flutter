import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../player_service.dart';

/// video_player 共享实现：iOS / Android / web 三个后端都继承它，
/// 区别只在底层引擎（见各后端文件头注释）与 [PlayerService.kind]。
///
/// 覆盖的能力（解析到的 video_player 2.14.1 实测 API 面，
/// 见 `docs/PLAYER_MATRIX.md` 与小结）：
/// 开流、播放/暂停、seek、倍速、音量、画面、position/duration/isPlaying/
/// isBuffering/buffered，以及 iOS/Android 上的引擎内音轨切换与
/// 视频轨（画质变体）选择。以下能力 video_player **不提供**，本类
/// 对应方法一律抛 [UnsupportedError] 并写明原因，不静默假装成功：
/// 字幕轨切换与轨列表、外挂字幕、解码器信息、掉帧/码率、
/// 帧率匹配、预取；web 上连音轨/视频轨选择也没有。
/// 当前 Flutter 的切轨/跳过/进度上报能工作，是因为它们走服务端会话，
/// 不是引擎能力（见 `PlayerController.switchTrack`）。
class VideoPlayerBackend implements PlayerService {
  /// 该后端是否通常支持引擎内音轨切换（子类按平台覆盖；
  /// 调用时仍以 `VideoPlayerController.isAudioTrackSupportAvailable`
  /// 为准，iOS 15 以下、非自适应流等情况会抛错）。
  @protected
  bool get supportsEngineAudioTracks => false;

  /// 该后端是否通常支持视频轨（画质变体）选择（子类按平台覆盖）。
  @protected
  bool get supportsEngineVideoTracks => false;

  @override
  PlayerCapability get capabilities => PlayerCapability(
        inEngineAudioTrackSwitch: supportsEngineAudioTracks,
        inEngineSubtitleTrackSwitch: false,
        externalSubtitle: false,
        qualitySelection: supportsEngineVideoTracks,
        decoderInfo: false,
        droppedFrames: false,
        bitrate: false,
        frameRateMatch: false,
        prefetch: false,
      );

  VideoPlayerController? _controller;
  final _position = ValueNotifier<Duration>(Duration.zero);
  final _playing = ValueNotifier<bool>(false);
  final _duration = ValueNotifier<Duration?>(null);
  final _stateController = StreamController<PlaybackState>.broadcast();
  PlaybackState _state = const PlaybackState();
  VoidCallback? _sync;
  String? _sessionId;

  VideoPlayerController get _c => _controller!;

  void _emit(PlaybackState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  /// 引擎名（子类覆盖，诊断用）。
  @protected
  String get engineName => 'video_player';

  @override
  PlayerBackendKind get kind => PlayerBackendKind.generic;

  @override
  Stream<PlaybackState> get stateStream => _stateController.stream;

  @override
  PlaybackState get state => _state;

  /// 把底层控制器的 value 同步进稳定可监听的通知器与状态流。
  void _attachSync() {
    _sync = () {
      final v = _c.value;
      _position.value = v.position;
      _playing.value = v.isPlaying;
      final d = v.duration;
      _duration.value = (d == Duration.zero) ? null : d;
      final buffered = v.buffered.isEmpty
          ? Duration.zero
          : v.buffered
              .map((r) => r.end)
              .reduce((a, b) => a > b ? a : b);
      _emit(_state.copyWith(
        status: PlayerStatus.ready,
        playing: v.isPlaying,
        position: v.position,
        duration: _duration.value,
        buffered: buffered,
        clearError: true,
      ));
    };
    _c.addListener(_sync!);
  }

  @override
  Future<void> open(PlayerRequest request) async {
    await close();
    _sessionId = request.sessionId;
    _emit(_state.copyWith(status: PlayerStatus.opening, clearError: true));
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(request.url),
        httpHeaders: request.headers,
      );
      _controller = controller;
      _attachSync();
      await controller.initialize();
      if (request.startPosition != null) {
        await controller.seekTo(request.startPosition!);
      }
      await controller.play();
      _emit(_state.copyWith(
        status: PlayerStatus.ready,
        playing: true,
        position: request.startPosition ?? Duration.zero,
        duration: _duration.value,
      ));
    } catch (e) {
      _emit(_state.copyWith(status: PlayerStatus.failed, error: '$e'));
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    await _c.play();
    _emit(_state.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    await _c.pause();
    _emit(_state.copyWith(playing: false));
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _c.seekTo(position);
    _emit(_state.copyWith(position: position));
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _c.setPlaybackSpeed(speed);
    _emit(_state.copyWith(speed: speed));
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_controller == null) return;
    await _c.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    final ratio = controller.value.aspectRatio;
    return ClipRect(
      child: FittedBox(
        fit: fit,
        child: SizedBox(
          width: 1024,
          height: ratio <= 0 ? 576 : 1024 / ratio,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    if (_sync != null && _controller != null) {
      _controller!.removeListener(_sync!);
    }
    _sync = null;
    await _controller?.dispose();
    _controller = null;
    _sessionId = null;
    _position.value = Duration.zero;
    _playing.value = false;
    _duration.value = null;
    _emit(const PlaybackState(status: PlayerStatus.idle));
  }

  @override
  ValueListenable<Duration> get position => _position;

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  ValueListenable<Duration?> get duration => _duration;

  // —— 引擎内音轨 / 视频轨（画质变体）：video_player 2.14.1 已提供，
  // iOS/Android 支持，web 不支持。未开会话/不支持时抛错，不冒充 ——

  @override
  Future<void> selectAudioTrack(String trackId) async {
    final controller = _controller;
    if (controller == null) {
      throw UnsupportedError('未打开播放会话，无法切换音轨。');
    }
    if (!controller.isAudioTrackSupportAvailable()) {
      throw UnsupportedError(
        '该后端不支持引擎内切音轨（$engineName，web 无此 API）。'
        '当前由 PlayerController.switchTrack 走服务端会话重开续播。',
      );
    }
    await controller.selectAudioTrack(trackId);
  }

  @override
  Future<List<PlayerTrack>> getAudioTracks() async {
    final controller = _controller;
    if (controller == null ||
        !controller.isAudioTrackSupportAvailable()) {
      return const [];
    }
    final tracks = await controller.getAudioTracks();
    return [
      for (final t in tracks)
        PlayerTrack(
          id: t.id,
          label: t.label ?? t.id,
          language: t.language,
          isSelected: t.isSelected,
        ),
    ];
  }

  @override
  Future<void> setQuality(QualityOption quality) async {
    final controller = _controller;
    if (controller == null) {
      throw UnsupportedError('未打开播放会话，无法切换画质。');
    }
    if (!controller.isVideoTrackSupportAvailable()) {
      throw UnsupportedError(
        '该后端不支持视频轨（画质变体）选择（$engineName，web 无此 API）。'
        '画质目前由服务端会话决定，见 docs/PLAYER_MATRIX.md「画质选择」行。',
      );
    }
    final tracks = await controller.getVideoTracks();
    if (tracks.isEmpty) {
      throw UnsupportedError(
        '当前片源无可选视频轨（$engineName：非自适应 MP4 可能只含单轨）。',
      );
    }
    // 原画 = 清除手动选择，恢复自适应。
    if (quality.maxHeight == null) {
      await controller.selectVideoTrack(null);
      return;
    }
    final cap = quality.maxHeight!;
    final withHeight = [
      for (final t in tracks)
        if (t.height != null && t.height! <= cap) t,
    ];
    final byLabel = [
      for (final t in tracks)
        if (t.label != null && t.label!.contains('$cap')) t,
    ];
    final candidates = withHeight.isNotEmpty ? withHeight : byLabel;
    if (candidates.isEmpty) {
      throw UnsupportedError(
        '当前片源没有 ${cap}p 及以下视频轨（$engineName：'
        '可用轨 ${tracks.map((t) => t.label ?? t.height?.toString() ?? t.id).join('、')}）。',
      );
    }
    candidates.sort((a, b) =>
        (b.height ?? 0).compareTo(a.height ?? 0));
    await controller.selectVideoTrack(candidates.first);
  }

  // —— video_player 不支持的能力：抛错，不冒充 ——

  @override
  Future<void> selectSubtitleTrack(String trackId) async {
    throw UnsupportedError(
      'video_player 无字幕轨 API（$engineName：平台接口无 subtitle 相关方法）。'
      '当前由 PlayerController.switchTrack 走服务端会话重开续播。',
    );
  }

  @override
  Future<List<SubtitleTrack>> getSubtitleTracks() async => const [];

  @override
  Future<void> loadExternalSubtitle(Uri url) async {
    throw UnsupportedError(
      'video_player 不支持外挂字幕（$engineName）：无 WebVtt/ASS 渲染。'
      '外挂字幕需 Flutter 侧自渲染或等后端选型（media_kit/自写通道）。',
    );
  }

  @override
  Future<PlayerDiagnostics> collectDiagnostics({String? sessionId}) async {
    final v = _controller?.value;
    final bufferedSeconds = v == null || v.buffered.isEmpty
        ? 0.0
        : v.buffered
            .map((r) => r.end.inMilliseconds / 1000.0)
            .reduce((a, b) => a > b ? a : b);
    return PlayerDiagnostics(
      engine: engineName,
      position: _position.value,
      duration: _duration.value,
      playing: _playing.value,
      buffering: v?.isBuffering ?? false,
      bufferedSeconds: bufferedSeconds,
      // 以下字段 video_player 拿不到，null = 缺失，不是 0：
      droppedFrames: null,
      totalFrames: null,
      bitrateBps: null,
      decoderName: null,
      hardwareAccelerated: null,
      sessionId: sessionId ?? _sessionId,
      rebufferCount: 0,
      rebufferMs: 0,
    );
  }
}
