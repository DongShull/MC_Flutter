import '../player_service.dart';
import 'video_player_backend.dart';

/// 安卓后端：Media3 ExoPlayer。
///
/// 实现方式：`video_player` + `video_player_android`，
/// 底层是 Media3 ExoPlayer（与 MovieClaw 安卓原生 `UnifiedExo.kt`
/// 同一个引擎家族，但**不是同一份代码**：原生侧是手写的
/// `PlaybackController` + `PlaybackBackend`，这里是 Flutter 官方插件
/// 对 ExoPlayer 的薄封装）。当前 P1 阶段直接复用插件能力，不做原生扩展。
///
/// video_player 是否够用？——**不够**（评估见 `docs/PLAYER_MATRIX.md`
/// 与小结）。插件已覆盖播放控制与位置/缓冲状态，以及 iOS/Android 的
/// 音轨切换与视频轨（画质变体）选择；但拿不到：
/// 字幕轨切换、外挂字幕、解码器信息与黑名单、
/// 掉帧/码率、帧率匹配切模式、预取。对应方法继承 [VideoPlayerBackend]，
/// 抛 [UnsupportedError]，不冒充。
///
/// 未决选型（停在方案阶段，不要在未决定时硬上）：
/// - **media_kit**：内置 FFmpeg/libass，轨切换/外挂字幕/解码器信息
///   有现成 API；代价是引入 native 依赖与包体积，API 与 video_player
///   不兼容，需再包一层适配器；且与“AVPlayer 体系”的目标表述无关，
///   它只解决安卓（+桌面）侧。
/// - **自写平台通道**：在 `android/` 写 Kotlin 通道直调 Media3，
///   复用 MovieClaw 安卓原生 `PlaybackController` 的能力
///   （轨选择、诊断采样、解码器黑名单、帧率匹配、重连退避）；
///   代价是维护两份原生代码，工作量最大，但能力天花板最高，
///   且与原生安卓端同源。
/// 建议见小结 `hidden_files/P1-player.md`。在决定之前，
/// 本后端保持为 video_player 薄封装，不引入新依赖。
class ExoPlayerBackend extends VideoPlayerBackend {
  @override
  PlayerBackendKind get kind => PlayerBackendKind.exoPlayer;

  @override
  bool get supportsEngineAudioTracks => true;

  @override
  bool get supportsEngineVideoTracks => true;

  @override
  String get engineName => 'ExoPlayer / Media3 (video_player_android)';
}
