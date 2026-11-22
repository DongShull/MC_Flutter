import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'backends/avplayer_backend.dart';
import 'backends/exoplayer_backend.dart';
import 'backends/harmony_backend.dart';
import 'backends/video_player_backend.dart';
import 'backends/web_backend.dart';

/// 统一播放器接口（P1 重写）。
///
/// 事实前提：AVPlayer 只在 Apple 平台（iOS/macOS）可用，安卓跑不了，
/// 鸿蒙没有 Apple AVPlayer（ArkTS 的 `media.AVPlayer` 只是同名），
/// web 也没有 AVPlayer。所以不存在“一个 AVPlayer 核心跑四端”，
/// 只能是：**统一 Dart 接口 + 每平台一个后端**。
///
/// 结构：
/// - 本文件：类型 + 抽象接口 [PlayerService] + 工厂 [PlayerService.create]。
/// - `backends/video_player_backend.dart`：video_player 共享实现
///   （iOS/Android/web 三个后端都继承它）。
/// - `backends/avplayer_backend.dart` / `exoplayer_backend.dart` /
///   `web_backend.dart` / `harmony_backend.dart`：各平台后端。
///   鸿蒙后端目前是未实现桩（见该文件头注释），不要当成已支持。
///
/// 能力诚实原则：video_player 支撑不了的能力（字幕轨切换、外挂字幕、
/// 解码器信息、掉帧/码率诊断、帧率匹配、预取），接口上照常声明，
/// 但实现一律抛 [UnsupportedError] 并写明原因，绝不静默假装成功。
/// 音轨切换与画质档（视频轨）选择是例外：video_player 2.14.1
/// （由 pubspec `^2.9.1` 解析得到）已在 iOS/Android 上提供
/// `getAudioTracks`/`selectAudioTrack` 与 `getVideoTracks`/
/// `selectVideoTrack`，web 不支持；见 `docs/PLAYER_MATRIX.md`。
/// 能力清单见 `docs/PLAYER_MATRIX.md`。

/// 后端种类。注意鸿蒙 ≠ Apple：[harmony] 对应 ArkTS `media.AVPlayer`，
/// 不是 Apple AVPlayer；且 Flutter 鸿蒙目标在本仓库未确认，
/// [HarmonyBackend] 目前只是抛错的桩。
enum PlayerBackendKind {
  /// iOS / macOS：video_player_avfoundation，底层是 Apple AVPlayer。
  avPlayer,

  /// 安卓：video_player_android，底层是 Media3 ExoPlayer。
  exoPlayer,

  /// web：video_player_web，底层是 HTML5 `<video>`。
  web,

  /// 鸿蒙：未实现（见 [HarmonyBackend]）。
  harmony,

  /// 通用 video_player 实现（桌面/测试兜底，不代表任何一端已验证）。
  generic,
}

/// 引擎能力开关：调用方先查 [PlayerService.capabilities]，
/// 再决定调不调对应方法；不支持时实现抛 [UnsupportedError]。
@immutable
class PlayerCapability {
  const PlayerCapability({
    this.inEngineAudioTrackSwitch = false,
    this.inEngineSubtitleTrackSwitch = false,
    this.externalSubtitle = false,
    this.qualitySelection = false,
    this.decoderInfo = false,
    this.droppedFrames = false,
    this.bitrate = false,
    this.frameRateMatch = false,
    this.prefetch = false,
  });

  /// video_player 三个后端共同的能力基线。
  static const videoPlayer = PlayerCapability();

  /// 引擎内切音轨（不重开会话）。video_player 2.14.1 已提供该 API，
  /// iOS（AVPlayer）与安卓（ExoPlayer）支持，web 不支持。
  /// 注意控制器目前仍走服务端会话重开（见 `PlayerController.switchTrack`
  /// 注释：会话转码档与轨绑定，引擎切轨可能与服务端转码档不一致，
  /// 切换策略待 P2 决策）。本方法供后续直接切轨时使用。
  final bool inEngineAudioTrackSwitch;

  /// 引擎内切字幕轨。video_player **无字幕 API**，全部后端均为 false。
  final bool inEngineSubtitleTrackSwitch;

  /// 外挂字幕文件渲染（WebVtt / ASS）。video_player：不支持。
  final bool externalSubtitle;

  /// 画质档切换。video_player 2.14.1 已提供视频轨（HLS/DASH 变体）
  /// 选择，iOS 15+ 与安卓支持，web 不支持；非自适应 MP4 可能无轨可切。
  /// 这与服务端 `QualityOption`（转码上限）不是同一语义，
  /// 见 `setQuality` 注释。
  final bool qualitySelection;

  /// 解码器名/硬件加速等信息。video_player：不支持。
  final bool decoderInfo;

  /// 掉帧统计。video_player：不支持。
  final bool droppedFrames;

  /// 当前码率。video_player：不支持。
  final bool bitrate;

  /// 按片源帧率切显示模式。video_player：不支持（需平台通道）。
  final bool frameRateMatch;

  /// 起播前预取/预连接。video_player：不支持。
  final bool prefetch;
}

/// 音轨（引擎内轨；与服务端会话的 `PlaybackAudioTrack` 不同，
/// 后者是会话协商下发的轨引用，走重开会话切换）。
@immutable
class PlayerTrack {
  const PlayerTrack({
    required this.id,
    required this.label,
    this.language,
    this.isDefault = false,
    this.isSelected = false,
  });

  final String id;
  final String label;
  final String? language;
  final bool isDefault;
  final bool isSelected;
}

/// 字幕轨（引擎内轨；同上，与会话的 `PlaybackSubtitleTrack` 不同）。
@immutable
class SubtitleTrack {
  const SubtitleTrack({
    required this.id,
    required this.label,
    this.language,
    this.isDefault = false,
    this.isSelected = false,
    this.isExternal = false,
  });

  final String id;
  final String label;
  final String? language;
  final bool isDefault;
  final bool isSelected;

  /// true = 外挂字幕文件（WebVtt/ASS），false = 内嵌轨。
  final bool isExternal;
}

/// 画质档（对应安卓 `QualityOption`：上限语义——源不超所选档就照常直通）。
@immutable
class QualityOption {
  const QualityOption({required this.maxHeight, required this.label});

  /// 原画：不限画质。
  static const original = QualityOption(maxHeight: null, label: '原画');
  static const p1080 = QualityOption(maxHeight: 1080, label: '1080p');
  static const p720 = QualityOption(maxHeight: 720, label: '720p');
  static const p480 = QualityOption(maxHeight: 480, label: '480p');

  static const all = [original, p1080, p720, p480];

  /// 最大高度（像素）；null = 原画，不限。
  final int? maxHeight;
  final String label;
}

/// 播放状态快照（状态机唯一事实来源；UI 只读这个，不轮询引擎）。
enum PlayerStatus { idle, opening, ready, failed }

@immutable
class PlaybackState {
  const PlaybackState({
    this.status = PlayerStatus.idle,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.buffered = Duration.zero,
    this.speed = 1.0,
    this.error,
  });

  final PlayerStatus status;
  final bool playing;
  final Duration position;
  final Duration? duration;

  /// 已缓冲到的位置；引擎不提供时为 [Duration.zero]。
  final Duration buffered;
  final double speed;
  final String? error;

  PlaybackState copyWith({
    PlayerStatus? status,
    bool? playing,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    double? speed,
    String? error,
    bool clearError = false,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      speed: speed ?? this.speed,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 播放诊断（对应安卓 `DiagnosticsReport` / `EngineReading` 的 Dart 侧模型）。
///
/// video_player 后端只能填：引擎名、位置/时长/播放态、是否缓冲中、
/// 已缓冲秒数、会话 id（调用方传入）。掉帧/码率/解码器等字段为 null
/// 即表示**该后端拿不到**，不是“值为 0”。
@immutable
class PlayerDiagnostics {
  const PlayerDiagnostics({
    required this.engine,
    this.position = Duration.zero,
    this.duration,
    this.playing = false,
    this.buffering = false,
    this.bufferedSeconds = 0.0,
    this.droppedFrames,
    this.totalFrames,
    this.bitrateBps,
    this.decoderName,
    this.hardwareAccelerated,
    this.sessionId,
    this.rebufferCount = 0,
    this.rebufferMs = 0,
  });

  /// 引擎名，如 `AVPlayer (video_player_avfoundation)`。
  final String engine;
  final Duration position;
  final Duration? duration;
  final bool playing;
  final bool buffering;
  final double bufferedSeconds;

  /// null = 该后端拿不到（video_player 三个后端均为 null）。
  final int? droppedFrames;
  final int? totalFrames;
  final int? bitrateBps;
  final String? decoderName;
  final bool? hardwareAccelerated;

  /// 服务端会话 id（控制器传入；与引擎无关）。
  final String? sessionId;

  /// 本次播放累计卡顿（同 web qoe.ts 口径：不含跳转造成的等待）。
  /// video_player 后端目前不统计，恒为 0。
  final int rebufferCount;
  final int rebufferMs;
}

/// 起播请求。`audioTrack` / `subtitleTrack` / `quality` 是**期望值**：
/// 后端不支持时忽略并由控制器走服务端重开路径，绝不静默假装已应用。
class PlayerRequest {
  const PlayerRequest({
    required this.url,
    this.title,
    this.startPosition,
    this.headers = const {},
    this.audioTrack,
    this.subtitleTrack,
    this.quality,
    this.externalSubtitleUrl,
    this.sessionId,
  });

  final String url;
  final String? title;
  final Duration? startPosition;
  final Map<String, String> headers;

  /// 期望音轨 id（引擎内切轨不支持时由控制器走会话重开）。
  final String? audioTrack;

  /// 期望字幕轨 id；`''` 表示关闭字幕。
  final String? subtitleTrack;

  /// 期望画质档（上限语义）；后端不支持时忽略，画质由服务端会话决定。
  final QualityOption? quality;

  /// 外挂字幕地址（WebVtt/ASS）；后端不支持时忽略。
  final String? externalSubtitleUrl;

  /// 服务端会话 id（仅用于诊断上报，不参与起播）。
  final String? sessionId;
}

/// 全 App 唯一播放入口（对应原 core:playback）。
/// 所有页面（详情/reels/离线/继续观看）只允许通过本接口播放，
/// 禁止在功能模块里直接持有播放引擎实例。
abstract class PlayerService {
  /// 按当前平台选后端。测试/指定后端时传 [kind]。
  /// 未知桌面平台回落到通用 video_player 实现（不代表该平台已验证）。
  factory PlayerService.create({PlayerBackendKind? kind}) {
    final resolved = kind ?? _resolveKind();
    return switch (resolved) {
      PlayerBackendKind.avPlayer => AvPlayerBackend(),
      PlayerBackendKind.exoPlayer => ExoPlayerBackend(),
      PlayerBackendKind.web => WebBackend(),
      PlayerBackendKind.harmony => HarmonyBackend(),
      PlayerBackendKind.generic => VideoPlayerBackend(),
    };
  }

  static PlayerBackendKind _resolveKind() {
    if (kIsWeb) return PlayerBackendKind.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => PlayerBackendKind.avPlayer,
      TargetPlatform.android => PlayerBackendKind.exoPlayer,
      // 鸿蒙不是本仓库 Flutter SDK 的目标平台，无对应 TargetPlatform；
      // 不要把 Fuchsia/桌面平台冒充成鸿蒙。
      _ => PlayerBackendKind.generic,
    };
  }

  PlayerBackendKind get kind;

  /// 本后端的能力开关（见 [PlayerCapability]）。
  PlayerCapability get capabilities;

  /// 状态机快照流；[open]/[play]/[pause]/[seekTo]/[close] 都经由它发出。
  Stream<PlaybackState> get stateStream;

  /// 当前状态快照（与 [stateStream] 最新值一致）。
  PlaybackState get state;

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

  /// 播放器内音量（0.0–1.0）：竖滑调节走这里，不动系统音量。
  Future<void> setVolume(double volume);

  /// 当前画面视图。UI 层不得 import 引擎包，只能拿这个 Widget 叠进页面。
  /// [fit] 对应 iOS VideoDisplayMode：contain=完整显示 / cover=铺满裁切 / fill=拉伸铺满。
  Widget buildView({BoxFit fit = BoxFit.contain});

  // —— 能力门控方法：后端不支持时抛 UnsupportedError（不静默成功）——

  /// 引擎内切音轨（不重开会话）。iOS/Android 后端委托给
  /// video_player 的 `selectAudioTrack`；web/未开会话时抛
  /// [UnsupportedError]。控制器目前仍走服务端会话重开，
  /// 见 [PlayerCapability.inEngineAudioTrackSwitch] 注释。
  Future<void> selectAudioTrack(String trackId);

  /// 引擎内切字幕轨；`''` = 关闭字幕。video_player **无字幕 API**，
  /// 全部后端抛 [UnsupportedError]；当前由控制器走服务端会话重开。
  Future<void> selectSubtitleTrack(String trackId);

  /// 当前引擎内音轨（iOS/Android 走 video_player 的 `getAudioTracks`；
  /// web/未开会话返回空列表）。与会话的 `PlaybackAudioTrack` 不同。
  Future<List<PlayerTrack>> getAudioTracks();

  /// 当前引擎内字幕轨；video_player 无字幕 API，恒为空列表。
  Future<List<SubtitleTrack>> getSubtitleTracks();

  /// 画质档切换。iOS/Android 后端映射为 video_player 视频轨选择：
  /// `原画` = 清除手动选择（恢复自适应）；其余档选高度不超过上限的
  /// 最高轨；无可用轨/无高度信息时抛 [UnsupportedError]。
  /// 注意这只是 HLS/DASH 变体选择，**不等同**服务端 `QualityOption`
  /// 的转码上限语义；服务端 quality 参数仍缺失（见能力矩阵）。
  Future<void> setQuality(QualityOption quality);

  /// 加载外挂字幕（WebVtt/ASS）。video_player 后端：不支持。
  Future<void> loadExternalSubtitle(Uri url);

  /// 采集诊断快照。video_player 后端只填引擎可读字段，
  /// 拿不到的字段为 null（见 [PlayerDiagnostics]）。
  Future<PlayerDiagnostics> collectDiagnostics({String? sessionId});
}
