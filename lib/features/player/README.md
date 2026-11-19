# feature/player

- 原 Kotlin 模块：apps/android .../feature/player
- 设计文档：docs/design/03-player-avplayer.md
- 状态：
  - ✅ pages/player_page.dart —— 播放页（PlayerScreen）：强制横屏+沉浸式、黑底画面、打开/失败/就绪三态、锁屏（锁定后只留解锁钮+提示）、亮度遮罩调层、顶部提示胶囊、拖动预览浮层、倍速角标
  - ✅ widgets/player_gesture_layer.dart —— 手势层（PlayerGestureLayer.kt 1:1）：单击立即生效/双击 0.3s 窗口推断、横向定位满屏 90s、纵向亮度(左)/音量(右)、长按 0.5s 2× 变速、12px 激活、32px 边缘守卫、调节带 12%~76%
  - ✅ widgets/player_progress_bar.dart —— 进度条：点按直跳、拖动跟手预览松手才跳（实测参数：左右 35dp、轨 3dp、句柄 11dp）；可跳区间琥珀色标注待 segments 下发（占位）
  - ✅ widgets/player_bottom_controls.dart —— 工具行：左胶囊 音轨/字幕（占位菜单，待会话轨接口）、右胶囊 下一集(占位)/选集/倍速
  - ✅ widgets/player_settings_panel.dart —— ⋮ 右侧滑出面板（PlayerSettingsPanel.kt）：画质（占位）、倍速（真实 0.5–2）、画面缩放 fit/fill/stretch（真实）、播放诊断（占位）
  - ✅ widgets/player_episode_picker.dart —— 选集面板（PlayerEpisodePicker.kt）：季 chips + 集网格，数据由入口经 PlayerPageArgs 传入（McClient 会话接口占位）
  - ✅ state/player_controller.dart —— Riverpod 控制器 + 全局 PlayerService 单例 provider；播放全部经 core/player/player_service.dart
- ⏳ TODO（依赖 core/playback 会话协议，见设计文档 03 §4）：
  - 会话协商/进度上报/心跳/stop（McClient Channel.playback）
  - 字幕/音轨轨列表与选择、跳过片头片尾 segments、章节、画质档位、播放诊断面板
  - 系统亮度/系统音量通道（当前：亮度用黑色遮罩模拟、音量用播放器内音量）
- 播放相关能力扩展：core/player/player_service.dart 增补 duration / setVolume / buildView（未破坏既有 API）。

> 重构注记：已下沉 core 复用（session/McClient provider、格式化、状态视图、防抖/序号守卫）。
