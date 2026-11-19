import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playback_session.dart';

/// 全局唯一播放会话协调器（应用级单例，跨页面共享）。
/// 多端/多窗口接入时由平台层替换实现，接口形状不变。
final playbackCoordinatorProvider = Provider<PlaybackCoordinator>((ref) {
  return PlaybackCoordinator();
});
