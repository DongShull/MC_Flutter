import '../player_service.dart';
import 'video_player_backend.dart';

/// web 后端：HTML5 `<video>`。
///
/// 实现方式：`video_player` + `video_player_web`，底层是浏览器
/// HTML5 video 元素。HLS 播放靠服务端下发 HLS 流（浏览器原生支持
/// HLS 的走原生；其余走 hls.js，同 web 端 `video-player.tsx`
/// 的做法——video_player_web 自身不带 hls.js，打包时需确认
/// HLS 在目标浏览器上是否可播，见能力矩阵）。
///
/// 浏览器先天缺失的能力：改显示器刷新率（帧率匹配）、
/// 解码器可见性与黑名单、读取光盘结构（BluRay）。
/// 另：video_player_web 2.4.0 **没有音轨/视频轨选择实现**
/// （调对应方法抛 `UnimplementedError`，本后端转为 [UnsupportedError]）。
/// 这些在 [PlayerCapability] 中均为 false，
/// 对应方法继承 [VideoPlayerBackend]，抛 [UnsupportedError]。
/// 注意 iOS Safari 上 `video.volume` 赋值会被系统忽略
/// （web 端 `video-player.tsx` 已有同样注释），音量竖滑在 web 上
/// 只能尽力而为。
class WebBackend extends VideoPlayerBackend {
  @override
  PlayerBackendKind get kind => PlayerBackendKind.web;

  @override
  String get engineName => 'HTML5 video (video_player_web)';
}
