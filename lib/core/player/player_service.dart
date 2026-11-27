import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:video_player/video_player.dart';

import '../image/image_urls.dart';
import '../network/server_routes.dart';
import '../session/session_store.dart';

/// 统一 AV Player：全 App 唯一播放入口（对应原 core:playback）。
/// 所有页面（正片播放页 / Reels / 离线 / 分享）只允许通过本服务播放，
/// 禁止在功能模块里直接 import 底层播放引擎包。
abstract class PlayerService {
  /// 全 5 大原生平台（iOS / macOS / Android / Linux / Windows）默认走全格式 `MediaKitPlayerService`
  /// （基于 libmpv + libass，支持 MKV / HEVC / HDR10 / EAC3 / DTS / ASS 原盘直通）；
  /// Web 或单元测试环境回退 `VideoPlayerService`。
  factory PlayerService.createDefault() {
    if (!kIsWeb &&
        !Platform.environment.containsKey('FLUTTER_TEST') &&
        (Platform.isIOS ||
            Platform.isMacOS ||
            Platform.isAndroid ||
            Platform.isLinux ||
            Platform.isWindows)) {
      return MediaKitPlayerService();
    }
    return VideoPlayerService();
  }

  /// 兜底引擎（AVPlayer / ExoPlayer），当 `MediaKitPlayerService` 解码失败或需走系统 HLS 时切换。
  factory PlayerService.createFallback() => VideoPlayerService();

  /// 是否为全解码通用引擎（true = libmpv / media_kit；false = AVPlayer / ExoPlayer 兜底）。
  bool get isUniversalEngine;

  Future<void> open(PlayerRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> close();

  ValueListenable<Duration> get position;
  ValueListenable<bool> get playing;

  /// 媒体总时长；未开会话/未知时为 null。
  ValueListenable<Duration?> get duration;

  /// 当前已缓冲到的时间位置。
  ValueListenable<Duration> get bufferedEnd;

  /// 是否处于缓冲中。
  ValueListenable<bool> get buffering;

  /// 引擎报出的最新致命/解码错误（正常时为 null）。
  ValueListenable<String?> get engineError;

  /// 是否到达流末尾（EOF）。
  ValueListenable<bool> get completed;

  /// 估算的实时拉流带宽（bps）；不可用时返回 null。
  double? get estimatedBandwidthBps;

  /// 播放器内音量（0.0–1.0）：竖滑调节与键盘上下键调节走这里。
  Future<void> setVolume(double volume);

  /// 原地切换音轨（支持 `embedded:N` 或引擎轨道 id）。
  Future<void> setAudioTrack(String? id);

  /// 加载或关闭外挂字幕（传 null 或空串关闭引擎内字幕渲染）。
  Future<void> setExternalSubtitle(String? url);

  /// 当前画面视图。UI 层不得 import 引擎包，只能拿这个 Widget 叠进页面。
  Widget buildView({
    BoxFit fit = BoxFit.contain,
    double? aspectRatioOverride,
  });
}

class PlayerRequest {
  const PlayerRequest({
    required this.url,
    this.title,
    this.startPosition,
    this.headers = const {},
    this.autoplay = true,
  });

  final String url;
  final String? title;
  final Duration? startPosition;
  final Map<String, String> headers;
  final bool autoplay;
}

String resolvePlayableResource(String rawUrl) {
  final raw = rawUrl.trim();
  if (raw.startsWith('file://')) {
    return Uri.parse(raw).toFilePath();
  }
  if (raw.startsWith('/') &&
      !raw.startsWith('/api/') &&
      !raw.startsWith('/s/')) {
    if (File(raw).existsSync()) return raw;
  }
  if (raw.startsWith('/')) {
    final origin = ServerRoutes.instance.currentOrigin(
      appSession.baseUrl ?? '',
    );
    if (origin.isNotEmpty) return '$origin$raw';
  }
  return raw;
}

/// 基于 `media_kit`（`libmpv` + `libass`）的跨平台全格式硬解播放器实现
/// （支持 iOS / macOS / Android / Linux / Windows 4K MKV / HEVC / HDR10 / EAC3 / DTS 原盘直通）。
class MediaKitPlayerService implements PlayerService {
  mk.Player? _player;
  mkv.VideoController? _videoController;
  final List<StreamSubscription<dynamic>> _subs = [];

  final _position = ValueNotifier<Duration>(Duration.zero);
  final _playing = ValueNotifier<bool>(false);
  final _duration = ValueNotifier<Duration?>(null);
  final _bufferedEnd = ValueNotifier<Duration>(Duration.zero);
  final _buffering = ValueNotifier<bool>(false);
  final _engineError = ValueNotifier<String?>(null);
  final _completed = ValueNotifier<bool>(false);

  double? _estimatedBandwidthBps;
  Duration _lastBufferSample = Duration.zero;
  DateTime? _lastBufferAt;
  double? _cachedAudioBitrate;

  @override
  bool get isUniversalEngine => true;

  @override
  double? get estimatedBandwidthBps => _estimatedBandwidthBps;

  @override
  Future<void> open(PlayerRequest request) async {
    await close();
    mk.MediaKit.ensureInitialized();
    final player = mk.Player(
      configuration: const mk.PlayerConfiguration(
        title: 'MovieClaw',
        bufferSize: 64 * 1024 * 1024,
      ),
    );
    final vc = mkv.VideoController(player);
    _player = player;
    _videoController = vc;
    _engineError.value = null;
    _completed.value = false;
    _bufferedEnd.value = Duration.zero;
    _buffering.value = true;
    _lastBufferSample = Duration.zero;
    _lastBufferAt = null;
    _estimatedBandwidthBps = null;

    _subs.add(player.stream.position.listen((pos) {
      _position.value = pos;
    }));
    _subs.add(player.stream.playing.listen((pl) {
      _playing.value = pl;
    }));
    _subs.add(player.stream.duration.listen((dur) {
      if (dur > Duration.zero) _duration.value = dur;
    }));
    _subs.add(player.stream.buffer.listen((buf) {
      _bufferedEnd.value = buf;
      _updateBandwidthEstimate(buf);
    }));
    _subs.add(player.stream.buffering.listen((b) {
      _buffering.value = b;
    }));
    _subs.add(player.stream.completed.listen((c) {
      _completed.value = c;
    }));
    _subs.add(player.stream.audioBitrate.listen((br) {
      if (br != null && br > 0) _cachedAudioBitrate = br;
    }));
    _subs.add(player.stream.error.listen((err) {
      final msg = err.trim();
      if (msg.isEmpty) return;
      // 忽略非致命探测噪声，仅记录真正影响播放的错误
      final lower = msg.toLowerCase();
      if (lower.contains('failed to open') ||
          lower.contains('error') ||
          lower.contains('unable') ||
          lower.contains('cannot') ||
          lower.contains('timeout') ||
          lower.contains('404') ||
          lower.contains('403') ||
          lower.contains('500') ||
          lower.contains('502') ||
          lower.contains('503')) {
        _engineError.value = msg;
      }
    }));

    final resource = resolvePlayableResource(request.url);
    final isLocal =
        !resource.startsWith('http://') && !resource.startsWith('https://');
    final mergedHeaders = <String, String>{
      if (!isLocal) ...mcImageHeaders(),
      ...request.headers,
    };

    await player.open(
      mk.Media(
        resource,
        httpHeaders: mergedHeaders,
        start: request.startPosition,
      ),
      play: request.autoplay,
    );
  }

  void _updateBandwidthEstimate(Duration buf) {
    final now = DateTime.now();
    final prevAt = _lastBufferAt;
    if (prevAt != null) {
      final elapsedSec = now.difference(prevAt).inMilliseconds / 1000.0;
      final deltaSec = (buf - _lastBufferSample).inMilliseconds / 1000.0;
      if (elapsedSec >= 0.4) {
        if (deltaSec > 0.05) {
          // 按经验视频+音频码率换算缓冲增长对应的吞吐估算（供看门狗区分「慢网」与「0 字节死链」）
          final baseBps = (_cachedAudioBitrate ?? 192000.0) + 4500000.0;
          final ratio = (deltaSec / elapsedSec).clamp(0.05, 25.0);
          _estimatedBandwidthBps = baseBps * ratio;
        } else if (!_buffering.value) {
          _estimatedBandwidthBps = 0;
        }
        _lastBufferSample = buf;
        _lastBufferAt = now;
      }
    } else {
      _lastBufferSample = buf;
      _lastBufferAt = now;
    }
  }

  @override
  Future<void> play() async {
    _completed.value = false;
    await _player?.play();
  }

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> seekTo(Duration position) async {
    _completed.value = false;
    await _player?.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) async => _player?.setRate(speed);

  @override
  Future<void> setVolume(double volume) async =>
      _player?.setVolume(volume.clamp(0.0, 1.0) * 100.0);

  @override
  Future<void> setAudioTrack(String? id) async {
    final p = _player;
    if (p == null) return;
    if (id == null || id.isEmpty || id == 'auto') {
      await p.setAudioTrack(mk.AudioTrack.auto());
      return;
    }
    final tracks = p.state.tracks.audio
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList();
    if (tracks.isEmpty) return;

    if (id.startsWith('embedded:')) {
      final idx = int.tryParse(id.substring('embedded:'.length));
      if (idx != null && idx >= 0 && idx < tracks.length) {
        await p.setAudioTrack(tracks[idx]);
        return;
      }
    }
    for (final t in tracks) {
      if (t.id == id || t.language == id) {
        await p.setAudioTrack(t);
        return;
      }
    }
  }

  @override
  Future<void> setExternalSubtitle(String? url) async {
    final p = _player;
    if (p == null) return;
    if (url == null || url.trim().isEmpty || url == 'off') {
      await p.setSubtitleTrack(mk.SubtitleTrack.no());
      return;
    }
    if (url.startsWith('embedded:')) {
      final tracks = p.state.tracks.subtitle
          .where((t) => t.id != 'auto' && t.id != 'no')
          .toList();
      final idx = int.tryParse(url.substring('embedded:'.length));
      if (idx != null && idx >= 0 && idx < tracks.length) {
        await p.setSubtitleTrack(tracks[idx]);
      }
      return;
    }
    final resolved = resolvePlayableResource(url);
    await p.setSubtitleTrack(mk.SubtitleTrack.uri(resolved));
  }

  @override
  Widget buildView({
    BoxFit fit = BoxFit.contain,
    double? aspectRatioOverride,
  }) {
    final vc = _videoController;
    if (vc == null) return const SizedBox.expand();
    return IgnorePointer(
      child: mkv.Video(
        key: ValueKey(vc),
        controller: vc,
        fit: fit,
        aspectRatio: aspectRatioOverride,
        fill: const Color(0xFF000000),
        controls: (_) => const SizedBox.shrink(),
        subtitleViewConfiguration: const mkv.SubtitleViewConfiguration(
          visible: false,
        ),
        wakelock: false,
        pauseUponEnteringBackgroundMode: false,
        resumeUponEnteringForegroundMode: false,
      ),
    );
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final p = _player;
    _player = null;
    _videoController = null;
    await p?.dispose();
    _position.value = Duration.zero;
    _playing.value = false;
    _duration.value = null;
    _bufferedEnd.value = Duration.zero;
    _buffering.value = false;
    _engineError.value = null;
    _completed.value = false;
    _estimatedBandwidthBps = null;
  }

  @override
  ValueListenable<Duration> get position => _position;

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  ValueListenable<Duration?> get duration => _duration;

  @override
  ValueListenable<Duration> get bufferedEnd => _bufferedEnd;

  @override
  ValueListenable<bool> get buffering => _buffering;

  @override
  ValueListenable<String?> get engineError => _engineError;

  @override
  ValueListenable<bool> get completed => _completed;
}

/// 基于 `video_player`（AVPlayer / ExoPlayer）的系统原生兜底播放实现。
class VideoPlayerService implements PlayerService {
  VideoPlayerController? _controller;
  final _position = ValueNotifier<Duration>(Duration.zero);
  final _playing = ValueNotifier<bool>(false);
  final _duration = ValueNotifier<Duration?>(null);
  final _bufferedEnd = ValueNotifier<Duration>(Duration.zero);
  final _buffering = ValueNotifier<bool>(false);
  final _engineError = ValueNotifier<String?>(null);
  final _completed = ValueNotifier<bool>(false);
  VoidCallback? _sync;

  VideoPlayerController get _c => _controller!;

  @override
  bool get isUniversalEngine => false;

  @override
  double? get estimatedBandwidthBps => null;

  void _attachSync() {
    _sync = () {
      final c = _controller;
      if (c == null) return;
      final v = c.value;
      _position.value = v.position;
      _playing.value = v.isPlaying;
      final d = v.duration;
      _duration.value = (d == Duration.zero) ? null : d;
      _bufferedEnd.value =
          v.buffered.isNotEmpty ? v.buffered.last.end : Duration.zero;
      _buffering.value = v.isBuffering;
      _engineError.value = v.hasError ? (v.errorDescription ?? '播放引擎错误') : null;
      _completed.value = v.isCompleted;
    };
    _c.addListener(_sync!);
  }

  Future<VideoPlayerController> _createController(PlayerRequest request) async {
    final raw = request.url.trim();
    if (raw.startsWith('file://')) {
      final file = File(Uri.parse(raw).toFilePath());
      return VideoPlayerController.file(file);
    }
    if (raw.startsWith('/') &&
        !raw.startsWith('/api/') &&
        !raw.startsWith('/s/')) {
      final localFile = File(raw);
      if (await localFile.exists()) {
        return VideoPlayerController.file(localFile);
      }
    }
    final resolvedUrl = resolvePlayableResource(raw);
    final mergedHeaders = <String, String>{
      ...mcImageHeaders(),
      ...request.headers,
    };
    return VideoPlayerController.networkUrl(
      Uri.parse(resolvedUrl),
      httpHeaders: mergedHeaders,
    );
  }

  @override
  Future<void> open(PlayerRequest request) async {
    await close();
    _buffering.value = true;
    final controller = await _createController(request);
    _controller = controller;
    _attachSync();
    await controller.initialize();
    if (request.startPosition != null &&
        request.startPosition! > Duration.zero) {
      await controller.seekTo(request.startPosition!);
    }
    if (request.autoplay) {
      await controller.play();
    }
  }

  @override
  Future<void> play() async {
    if (_controller == null) return;
    _completed.value = false;
    await _c.play();
  }

  @override
  Future<void> pause() async {
    if (_controller == null) return;
    await _c.pause();
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (_controller == null) return;
    _completed.value = false;
    await _c.seekTo(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_controller == null) return;
    await _c.setPlaybackSpeed(speed);
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_controller == null) return;
    await _c.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> setAudioTrack(String? id) async {
    // video_player 不支持运行时原地切换音轨，由上层控制器按服务端会话重协商处理。
  }

  @override
  Future<void> setExternalSubtitle(String? url) async {
    // video_player 文本字幕统一由 Flutter 字幕叠加层绘制。
  }

  @override
  Widget buildView({
    BoxFit fit = BoxFit.contain,
    double? aspectRatioOverride,
  }) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.expand();
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, val, _) {
        if (!val.isInitialized) return const SizedBox.expand();
        final naturalRatio = (val.size.width > 1 && val.size.height > 1)
            ? (val.size.width / val.size.height)
            : (val.aspectRatio > 0 ? val.aspectRatio : 16.0 / 9.0);
        final ratio = aspectRatioOverride ?? naturalRatio;
        return IgnorePointer(
          child: ClipRect(
            child: FittedBox(
              fit: fit,
              child: SizedBox(
                width: 1024,
                height: 1024 / ratio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        );
      },
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
    _position.value = Duration.zero;
    _playing.value = false;
    _duration.value = null;
    _bufferedEnd.value = Duration.zero;
    _buffering.value = false;
    _engineError.value = null;
    _completed.value = false;
  }

  @override
  ValueListenable<Duration> get position => _position;

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  ValueListenable<Duration?> get duration => _duration;

  @override
  ValueListenable<Duration> get bufferedEnd => _bufferedEnd;

  @override
  ValueListenable<bool> get buffering => _buffering;

  @override
  ValueListenable<String?> get engineError => _engineError;

  @override
  ValueListenable<bool> get completed => _completed;
}
