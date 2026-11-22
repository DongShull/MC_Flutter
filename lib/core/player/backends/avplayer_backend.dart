import '../player_service.dart';
import 'video_player_backend.dart';

/// iOS / macOS 后端：AVPlayer 体系。
///
/// 实现方式：`video_player` + `video_player_avfoundation`，
/// 底层就是 Apple AVPlayer（`AVPlayer` + `AVPlayerItem`），
/// 由 Flutter 官方插件维护，不需要本项目自写 Swift 通道。
/// 当前 P1 阶段：直接复用该插件的全部能力（开流/播放/暂停/seek/
/// 倍速/音量/画面/缓冲状态），不做任何原生扩展。
///
/// AVPlayer 原生能做到、但 video_player 插件没暴露的能力
/// （字幕轨选择、掉帧/码率/解码器读数、显示模式切换），
/// 本后端目前**不提供**：对应方法继承 [VideoPlayerBackend]，
/// 抛 [UnsupportedError]（见 `docs/PLAYER_MATRIX.md`）。
/// 如需这些能力，下一步是自写 MethodChannel 直调 AVPlayer
/// （`AVPlayerItem.tracks` 选轨、`accessLog`/`errorLog` 读诊断、
/// `CADisplayLink` 统计掉帧），而不是换掉 AVPlayer 本身。
/// 该通道工作未开始，停在方案阶段。
///
/// 例外：音轨切换与视频轨（画质变体）选择 video_player 2.14.1 已提供，
/// 本后端直接委托插件（`getAudioTracks`/`selectAudioTrack`、
/// `getVideoTracks`/`selectVideoTrack`；iOS 15+ 才有视频轨列表）。
/// 但控制器目前仍走服务端会话重开切轨，原因见
/// `PlayerCapability.inEngineAudioTrackSwitch` 注释。
class AvPlayerBackend extends VideoPlayerBackend {
  @override
  PlayerBackendKind get kind => PlayerBackendKind.avPlayer;

  @override
  bool get supportsEngineAudioTracks => true;

  @override
  bool get supportsEngineVideoTracks => true;

  @override
  String get engineName => 'AVPlayer (video_player_avfoundation)';
}
