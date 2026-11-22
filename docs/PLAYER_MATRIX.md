# 播放器能力矩阵（P1）

> 依据：安卓 `apps/android-core/playback/`（`UnifiedExo.kt`、`PlaybackController`、
> `PlaybackBackend`、`PlaybackConnection`、`FrameRateMatch`、`DecoderDenylist`、
> `DiagnosticsReport`、`PlaybackWatchdogs`、`disc/BluRay*`、`WebVtt`，约 6100 行主代码 +
> 约 3200 行测试）；iOS `apps/apple/Shared/Player/AVPlayerEngine.swift` 等；
> 鸿蒙 `apps/harmonyos/entry/src/main/ets/common/AvPlayerEngine.ets` 等；
> web `apps/web/components/player/video-player.tsx`、`lib/player/qoe.ts`；
> Flutter 现状 `lib/core/player/player_service.dart`（141 行，video_player 薄包装）、
> `lib/features/player/state/player_controller.dart`、
> `lib/features/player/pages/player_page.dart`。
>
> 图例：✅ 已实现（本次核实过源码） · ⚠️ 部分实现 · ❌ 缺失/未实现 ·
> ❓ 未核实（本次未在该端源码中确认，不等于没有） · — 不适用/平台无此能力。
>
> 2026-11-22 制作。Flutter 列是写矩阵时的实测现状，不是目标。

## 事实澄清（先说清楚，再谈选型）

- **AVPlayer 只在 Apple 平台可用**（iOS / macOS / tvOS）。“播放器核心用 AVPlayer 体系”
  只能理解为“Apple 端用 AVPlayer”，不能作为四端统一引擎。
- **鸿蒙的 `media.AVPlayer` 与 Apple 的 AVPlayer 只是同名**，是 ArkTS
  `ohos.multimedia.media` 的播放器，与 Apple AVPlayer 没有任何共用代码。
  鸿蒙原生端用的是它（`AvPlayerEngine.ets`）。
- **web 没有 AVPlayer**，只有 HTML5 `<video>`（本项目另用 hls.js 做 HLS）。
- **安卓是 Media3 ExoPlayer**（`video_player_android` 底层即 ExoPlayer）。
- 因此四端只能是：**统一 Dart 接口 `PlayerService` + 每平台一个后端**。
  本次 P1 已建立该接口与四个后端文件（见“目标后端”列与 `lib/core/player/backends/`）。

## 矩阵

| 能力 | 安卓（MovieClaw 原生） | iOS（Apple 原生） | 鸿蒙（ArkTS 原生） | web | Flutter 现状 | 目标后端 |
|---|---|---|---|---|---|---|
| 音轨切换 | ✅ `PlaybackController` + `PlayerTracks`：Exo 轨内切换，可烧录/取消烧录 | ❓ 未核实（引擎为 AVPlayer） | ❓ 未核实（引擎为 `media.AVPlayer`） | ✅ 有音轨测试 `player-audio-tracks.test.mjs` | ⚠️ 服务端会话重开续播已实现；引擎内切轨 API 已有（video_player 2.14.1 的 `selectAudioTrack`，iOS/Android 支持、web 不支持），但 Flutter 代码未接入，控制器仍走服务端重开（原因见“目标后端”列） | 后端方法已实现（`VideoPlayerBackend.selectAudioTrack`）；控制器何时改走引擎切轨待 P2 决策——会话转码档与轨绑定，引擎切轨可能与服务端转码档不一致 |
| 字幕轨切换 | ✅ 内嵌轨 + 外挂字幕（见“外挂字幕”行），可开关 | ❓ 未核实 | ❓ 未核实 | ❓ 未核实 | ⚠️ 服务端重开续播已实现，`''` 表示关闭；引擎内切轨 ❌（video_player 6.9.0 平台接口**无字幕 API**） | 保持服务端重开；引擎内切字幕轨需 media_kit/自写通道 |
| 倍速 0.5–2.0 | ✅ | ❓ 未核实（AVPlayer `rate` 本身支持，项目内未核查） | ❓ 未核实 | ❓ 未核实 | ✅ 0.5/0.75/1.0/1.25/1.5/2.0 + 长按 2×，已实现 | video_player 各后端均支持，保留 |
| 跳过片头片尾 | ✅ `SkipSegments`：自动跳过（可学习/遗忘）、UpNext、片尾自动下一集 | ❓ 未核实 | ❓ 未核实 | ❓ 未核实 | ⚠️ 服务端下发 `skipSegments`，进度条琥珀色标注 + 手动跳过入口；自动跳过 ❌、UpNext ❌ | 移植 `SkipSegments` 纯 Dart 规则（`active`/`autoSkips`/`autoNextArmed`），接在控制器层 |
| 帧率匹配 | ✅ `FrameRateMatch.pick`：同分辨率、刷新率为帧率整数倍、误差 ≤0.15%，配合系统“匹配内容帧率”偏好 | ⚠️ 有 `PlayerDisplayMode` 及 `PlayerDisplayModeTests`；按片源帧率切模式的规则本次未核实 | ❓ 未核实 | — 缺失：浏览器无权改显示器刷新率 | ❌ 缺失（无任何帧率/显示模式代码） | 规则层移植 `FrameRateMatch.pick` 为纯 Dart（可单测）；切模式走安卓/iOS 平台通道；web 明确缺失 |
| 解码器黑名单 / 兜底 | ✅ `DecoderDenylist`（30 天过期、App 升级清空）+ `CapabilityProbe`（上报解码器能力，坏解码器走服务端流） | ❓ 未核实 | ❓ 未核实 | — 缺失：浏览器解码器不可见、不可选 | ❌ 缺失（video_player 不暴露解码器信息） | video_player 下缺失；media_kit/自写通道能否拿到解码器信息待定（见小结） |
| 诊断报告 | ✅ `DiagnosticsReport` + `PlaybackDiagnostics`：引擎每秒采样（掉帧/码率/缓冲/解码器/会话 id/处理方式），面板分“源是什么→做了什么”两节 | ✅ 有 `PlayerDiagnosticsPanel`（`DiagnosticsReport.kt` 注释对照提及） | ❓ 未核实 | ✅ `diagnostics-panel.tsx` + `lib/player/qoe.ts`（卡顿口径：不含跳转等待） | ❌ 缺失。设置面板“播放诊断”行此前是假入口（已改为“未实现”文案）；引擎只暴露位置/时长/播放态 | 先落地 Dart 侧 `PlayerDiagnostics` 模型 + 引擎可读字段（缓冲/状态/会话 id）；掉帧/码率/解码器待后端选型 |
| 进度上报 | ✅ | ❓ 未核实 | ❓ 未核实 | ❓ 未核实 | ✅ 15s 节流 `POST /playback/progress` + 30s 会话 ping，已实现 | 保留，不回归 |
| 断线重连 | ✅ `ReconnectBackoff`（退避）+ `NetworkRestartBudget` + `StallWatch`（卡死判定）+ `NativeRetryBudget` + 看门狗 `FrameDropTracker`/`PrematureEndGuard` | ⚠️ 有 `PlaybackWatchdogsTests`，看门狗类机制存在；重连退避细节未核实 | ❓ 未核实 | ⚠️ `video-player.tsx` 注释：取流断了原地重开；退避策略未核实 | ❌ 缺失：失败即 `failed` 态 + 手动“重试”，无自动重连、无退避、无卡死看门狗 | 移植 `ReconnectBackoff`/`StallWatch` 纯 Dart 规则 + 引擎错误回调；P1 只定义接口，不实现重连 |
| 下一集 | ✅ `playNext`/`playPrevious`、自动连播、UpNext 倒计时 | ❓ 未核实 | ❓ 未核实 | ❓ 未核实 | ⚠️ 手动下一集已实现（按季/集找下一集，切集重开会话）；自动连播 UpNext ❌ | 保留手动；UpNext 待 `SkipSegments.autoNextArmed` 移植后实现 |
| BluRay | ✅ `disc/`：`BluRaySource`、`BluRayClipExtractor`、`M2tsDataSource`、`BluRayStreamReaders`（M2TS 解复用，带测试） | ❓ 未核实（未见 BluRay 代码） | ❓ 未核实 | — 缺失：浏览器无法读取光盘结构 | ❌ 缺失 | 远期/缺失：需原生 M2TS 解复用或服务端转码兜底，不在 P1 |
| 外挂字幕 | ✅ `externalSubtitles` + ASS 覆盖层（`AssSubtitleView`）+ `WebVtt.parse`；FFmpeg 在 `android-core/ffmpeg` | ❓ 未核实 | ❓ 未核实 | ❓ 未核实 | ❌ 缺失：会话已下发 `subtitleUrls`，但未接入渲染；无 WebVtt/ASS 渲染 | 短期：Flutter 侧纯 Dart 移植 `WebVtt.parse` + 覆盖层渲染；ASS（libass）待后端选型（media_kit 内置 FFmpeg 是候选） |
| 画质选择 | ✅ `QualityOption`：原画/1080p/720p/480p，上限语义（源不超档就直通） | ❓ 未核实 | ❓ 未核实 | ✅ 有 `lib/player/quality.ts`（`PlayerPreferences.kt` 注释对照提及） | ⚠️ 两部分：① 引擎侧视频轨（HLS/DASH 变体）选择 API 已有（video_player 2.14.1 的 `getVideoTracks`/`selectVideoTrack`，iOS 15+/Android 支持、web 不支持），后端方法已实现但控制器未接入；② 服务端 quality 参数仍 ❌ 缺失（会话 `start` 无 quality 参数），设置面板此前显示“原画”是假值（已改为“未实现”） | 先接引擎侧变体选择（P2）；再补服务端 quality 参数 + 移植 `QualityMemory`（注意两者语义不同：变体选择 ≠ 转码上限） |
| 预连接 / 预取 | ✅ `SourceByteCache.prefetch` + `ClipPlayer` 预取数据源（与播放同一连接池/UA） | ❓ 未核实 | ❓ 未核实 | ❓ 未核实 | ❌ 缺失（video_player 无预取 API） | 待定，依赖后端选型 |
| 画质记忆 | ✅ `QualityMemory`（按影片 × 网络记忆）+ `SpeedMemory`（只记非正常速度，最多 N 条） | ❓ 未核实 | ❓ 未核实（`PlayerPrefs.ets` 存在，内容未核查） | ❓ 未核实 | ❌ 缺失（无任何记忆代码） | 移植为纯 Dart（`shared_preferences` 存储），与画质选择同批实现 |

## video_player 是否够用？（评估结论，详见小结）

本次核查的是实际解析到的版本：`video_player` **2.14.1**（pubspec 写的是
`^2.9.1`，`dart pub get` 解析到 2.14.1）、`video_player_platform_interface`
6.9.0、`video_player_android` 2.12.4、`video_player_avfoundation` 2.12.4、
`video_player_web` 2.4.0。结论与直觉相反的部分要单列：

**已覆盖（此前低估了它）：**开流、播放/暂停、seek、倍速、音量、画面、
`position`/`duration`/`isPlaying`/`isBuffering`/`buffered`，以及
**引擎内音轨切换**（`getAudioTracks`/`selectAudioTrack`，Android 与
AVFoundation 均已实现）与**视频轨（画质变体）选择**
（`getVideoTracks`/`selectVideoTrack`，Android 为 ExoPlayer 轨选择覆盖、
iOS 为 `preferredPeakBitRate`、需 iOS 15+；web 2.4.0 无实现）。
P1 已把这两项接进 `VideoPlayerBackend`（`selectAudioTrack`/
`getAudioTracks`/`setQuality`），控制器暂不改用，原因见矩阵“音轨切换”行。

**仍不够覆盖：**字幕轨切换与字幕轨列表（平台接口 6.9.0 **无字幕 API**）、
外挂字幕（WebVtt/ASS）渲染、解码器信息/黑名单、掉帧与码率等诊断读数、
帧率匹配切模式、预取；web 上连音轨/视频轨选择也没有。
当前 Flutter 的切轨/跳过/进度上报之所以能工作，是因为它们走的是
**服务端会话**（重开会话续播），不是引擎能力——这条路可以继续用，
但天花板就是上面列出的缺失项。

未决：**media_kit 还是自写平台通道**，见
`~/workspace/goals/flutter-mc-flutter/hidden_files/P1-player.md`（小结）。

## 本次 P1 交付的接口（与矩阵对应）

- `lib/core/player/player_service.dart`：统一接口 `PlayerService`（抽象类 +
  工厂 `PlayerService.create()`）与类型 `PlayerRequest` / `PlayerTrack` /
  `SubtitleTrack` / `PlaybackState` / `PlayerDiagnostics` / `QualityOption` /
  `PlayerCapability` / `PlayerBackendKind`。
- `lib/core/player/backends/video_player_backend.dart`：video_player 共享实现
  （三个平台后端都继承它；video_player 不支持的能力一律抛 `UnsupportedError`
  并写明原因，不静默假装成功）。
- `lib/core/player/backends/avplayer_backend.dart`：iOS/macOS，
  video_player_avfoundation（AVPlayer），已实现方式写明。
- `lib/core/player/backends/exoplayer_backend.dart`：安卓，
  video_player_android（Media3 ExoPlayer）；评估结论写在文件头注释里。
- `lib/core/player/backends/web_backend.dart`：web，
  video_player_web（HTML5 video；HLS 靠服务端 HLS 或 hls.js，同 web 端）。
- `lib/core/player/backends/harmony_backend.dart`：**未实现**。`open()` 直接抛
  `UnsupportedError`：Flutter 鸿蒙目标在本仓库 SDK 中未确认，
  `flutter_ohos` 社区方案未验证；原生鸿蒙用的是 ArkTS `media.AVPlayer`，
  与 Apple AVPlayer 同名不同物。不要把这个文件当成“已支持鸿蒙”。
