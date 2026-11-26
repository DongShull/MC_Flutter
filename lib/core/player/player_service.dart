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
/// 所有页面（详情/reels/离线/继续观看）只允许通过本服务播放，
/// 禁止在功能模块里直接持有播放引擎实例。
abstract class PlayerService {
  factory PlayerService.createDefault() {
    if ((Platform.isLinux || Platform.isWindows) &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      return MediaKitPlayerService();
    }
    return VideoPlayerService();
  }

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

  /// 播放器内音量（0.0–1.0）：竖滑调节与键盘上下键调节走这里。
  Future<void> setVolume(double volume);

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
  });

  final String url;
  final String? title;
  final Duration? startPosition;
  final Map<String, String> headers;
}

String _resolvePlayableResource(String rawUrl) {
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

/// 基于 `media_kit`（`libmpv` + `libass`）的桌面级全格式硬解播放器实现（支持 4K MKV / HEVC / HDR10 / EAC3 / DTS 原盘直通）。
class MediaKitPlayerService implements PlayerService {
  mk.Player? _player;
  mkv.VideoController? _videoController;
  final List<StreamSubscription<dynamic>> _subs = [];

  final _position = ValueNotifier<Duration>(Duration.zero);
  final _playing = ValueNotifier<bool>(false);
  final _duration = ValueNotifier<Duration?>(null);

  @override
  Future<void> open(PlayerRequest request) async {
    await close();
    mk.MediaKit.ensureInitialized();
    final player = mk.Player(
      configuration: const mk.PlayerConfiguration(
        title: 'MovieClaw',
      ),
    );
    final vc = mkv.VideoController(player);
    _player = player;
    _videoController = vc;

    _subs.add(player.stream.position.listen((pos) => _position.value = pos));
    _subs.add(player.stream.playing.listen((pl) => _playing.value = pl));
    _subs.add(
      player.stream.duration.listen((dur) {
        if (dur > Duration.zero) _duration.value = dur;
      }),
    );

    final resource = _resolvePlayableResource(request.url);
    final isLocal = !resource.startsWith('http://') &&
        !resource.startsWith('https://');
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
      play: true,
    );
  }

  @override
  Future<void> play() async => _player?.play();

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> seekTo(Duration position) async => _player?.seek(position);

  @override
  Future<void> setSpeed(double speed) async => _player?.setRate(speed);

  @override
  Future<void> setVolume(double volume) async =>
      _player?.setVolume(volume.clamp(0.0, 1.0) * 100.0);

  @override
  Widget buildView({
    BoxFit fit = BoxFit.contain,
    double? aspectRatioOverride,
  }) {
    final vc = _videoController;
    if (vc == null) return const SizedBox.expand();
    return mkv.Video(
      key: ValueKey(vc),
      controller: vc,
      fit: fit,
      aspectRatio: aspectRatioOverride,
      fill: const Color(0xFF000000),
      controls: (_) => const SizedBox.shrink(),
      wakelock: false,
      pauseUponEnteringBackgroundMode: false,
      resumeUponEnteringForegroundMode: false,
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
  }

  @override
  ValueListenable<Duration> get position => _position;

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  ValueListenable<Duration?> get duration => _duration;
}

/// 基于 `video_player`（AVPlayer / ExoPlayer）的移动端原生播放实现。
class VideoPlayerService implements PlayerService {
  VideoPlayerController? _controller;
  final _position = ValueNotifier<Duration>(Duration.zero);
  final _playing = ValueNotifier<bool>(false);
  final _duration = ValueNotifier<Duration?>(null);
  VoidCallback? _sync;

  VideoPlayerController get _c => _controller!;

  void _attachSync() {
    _sync = () {
      final c = _controller;
      if (c == null) return;
      final v = c.value;
      _position.value = v.position;
      _playing.value = v.isPlaying;
      final d = v.duration;
      _duration.value = (d == Duration.zero) ? null : d;
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
    final resolvedUrl = _resolvePlayableResource(raw);
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
    final controller = await _createController(request);
    _controller = controller;
    _attachSync();
    await controller.initialize();
    if (request.startPosition != null &&
        request.startPosition! > Duration.zero) {
      await controller.seekTo(request.startPosition!);
    }
    await controller.play();
  }

  @override
  Future<void> play() async {
    if (_controller == null) return;
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
        return ClipRect(
          child: FittedBox(
            fit: fit,
            child: SizedBox(
              width: 1024,
              height: 1024 / ratio,
              child: VideoPlayer(controller),
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
  }

  @override
  ValueListenable<Duration> get position => _position;

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  ValueListenable<Duration?> get duration => _duration;
}
