import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// 统一 AV Player：全 App 唯一播放入口（对应原 core:playback）。
/// 所有页面（详情/reels/离线/继续观看）只允许通过本服务播放，
/// 禁止在功能模块里直接持有播放引擎实例。
abstract class PlayerService {
  Future<void> open(PlayerRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> close();
  ValueListenable<Duration> get position;
  ValueListenable<bool> get playing;

  /// —— UI 层需要的最小扩展（不破坏既有 API，均为增量）——

  /// 媒体总时长；未开会话/未知时为 null。
  ValueListenable<Duration?> get duration;

  /// 播放器内音量（0.0–1.0）：竖滑调节走这里，不动系统音量。
  Future<void> setVolume(double volume);

  /// 当前画面视图。UI 层不得 import 引擎包，只能拿这个 Widget 叠进页面。
  /// [fit] 对应 iOS VideoDisplayMode：contain=完整显示 / cover=铺满裁切 / fill=拉伸铺满。
  Widget buildView({BoxFit fit = BoxFit.contain});
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

/// 基于 video_player（Android 底层 ExoPlayer）的默认实现。
class VideoPlayerService implements PlayerService {
  VideoPlayerController? _controller;
  final _position = ValueNotifier<Duration>(Duration.zero);
  final _playing = ValueNotifier<bool>(false);
  final _duration = ValueNotifier<Duration?>(null);
  VoidCallback? _sync;

  VideoPlayerController get _c => _controller!;

  /// 把底层控制器的 value 同步进三个稳定可监听的通知器。
  void _attachSync() {
    _sync = () {
      final v = _c.value;
      _position.value = v.position;
      _playing.value = v.isPlaying;
      final d = v.duration;
      _duration.value = (d == Duration.zero) ? null : d;
    };
    _c.addListener(_sync!);
  }

  @override
  Future<void> open(PlayerRequest request) async {
    await close();
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
  }

  @override
  Future<void> play() async => _c.play();

  @override
  Future<void> pause() async => _c.pause();

  @override
  Future<void> seekTo(Duration position) async => _c.seekTo(position);

  @override
  Future<void> setSpeed(double speed) async => _c.setPlaybackSpeed(speed);

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
