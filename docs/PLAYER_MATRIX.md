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
| 音轨切换 | ✅ `PlaybackController` + `PlayerTracks`：Exo 轨内切换，可烧录/取消烧录 | ❓ 未核实（引擎为 AVPlayer） | ❓ 未核实（引擎为 `media.AVPlayer`） | ✅ 有音轨测试 `player-audio-tracks.test.mjs` | ✅ 服务端会话重开续播已实现；引擎内切轨 API 仍在后端层（video_player 2.14.1 的 `selectAudioTrack`，iOS/Android 支持、web 不支持），但控制器**不改走引擎切轨**——P2 已决策，见下「P2 决策」 | P2 决策：控制器保持服务端重开；后端 `VideoPlayerBackend.selectAudioTrack` 保留，仅供无服务端会话的直连播放使用 |
| 字幕轨切换 | ✅ 内嵌轨 + 外挂字幕（见“外挂字幕”行），可开关 | ❓ 未核实 | ❓ 未核实 | ❓ 未核实 | ✅ 服务端重开续播已实现，`''` 表示关闭；引擎内切轨 ❌（video_player 6.9.0 平台接口**无字幕 API**）——P2 已决策保持服务端重开 | 保持服务端重开；引擎内切字幕轨需 media_kit/自写通道 |
| 倍速 0.5–2.0 | ✅ | ❓ 未核实（AVPlayer `rate` 本身支持，项目内未核查） | ❓ 未核实 | ❓ 未核实 | ✅ 0.5/0.75/1.0/1.25/1.5/2.0 + 长按 2×，已实现 | video_player 各后端均支持，保留 |
| 跳过片头片尾 | ✅ `SkipSegments`：自动跳过（可学习/遗忘）、UpNext、片尾自动下一集 | ❓ 未核实 | ❓ 未核实 | ❓ 未核实 | ⚠️ 服务端下发 `skipSegments`，进度条琥珀色标注 + 手动跳过入口；自动跳过 ❌、UpNext ❌ | 移植 `SkipSegments` 纯 Dart 规则（`active`/`autoSkips`/`autoNextArmed`），接在控制器层 |
| 帧率匹配 | ✅ `FrameRateMatch.pick`：同分辨率、刷新率为帧率整数倍、误差 ≤0.15%，配合系统“匹配内容帧率”偏好 | ⚠️ 有 `PlayerDisplayMode` 及 `PlayerDisplayModeTests`；按片源帧率切模式的规则本次未核实 | ❓ 未核实 | — 缺失：浏览器无权改显示器刷新率 | ❌ 缺失（无任何帧率/显示模式代码） | 规则层移植 `FrameRateMatch.pick` 为纯 Dart（可单测）；切模式走安卓/iOS 平台通道；web 明确缺失 |
| 解码器黑名单 / 兜底 | ✅ `DecoderDenylist`（30 天过期、App 升级清空）+ `CapabilityProbe`（上报解码器能力，坏解码器走服务端流） | ❓ 未核实 | ❓ 未核实 | — 缺失：浏览器解码器不可见、不可选 | ❌ 缺失（video_player 不暴露解码器信息） | video_player 下缺失；media_kit/自写通道能否拿到解码器信息待定（见小结） |
| 诊断报告 | ✅ `DiagnosticsReport` + `PlaybackDiagnostics`：引擎每秒采样（掉帧/码率/缓冲/解码器/会话 id/处理方式），面板分“源是什么→做了什么”两节 | ✅ 有 `PlayerDiagnosticsPanel`（`DiagnosticsReport.kt` 注释对照提及） | ❓ 未核实 | ✅ `diagnostics-panel.tsx` + `lib/player/qoe.ts`（卡顿口径：不含跳转等待） | ⚠️ P2 最小版面板已实现：显示 `collectDiagnostics()` 已有字段（引擎/会话/位置/时长/播放中/缓冲中/已缓冲秒数/卡顿次数与时长），拿不到的字段（掉帧/总帧数/码率/解码器/硬件加速）明确标“未实现”，不编数字 | 掉帧/码率/解码器待后端选型（media_kit 候选） |
| 进度上报 | ✅ | ❓ 未核实 | ❓ 未核实 | ❓ 未核实 | ✅ 15s 节流 `POST /playback/progress` + 30s 会话 ping，已实现 | 保留，不回归 |
| 断线重连 | ✅ `ReconnectBackoff`（退避）+ `NetworkRestartBudget` + `StallWatch`（卡死判定）+ `NativeRetryBudget` + 看门狗 `FrameDropTracker`/`PrematureEndGuard` | ⚠️ 有 `PlaybackWatchdogsTests`，看门狗类机制存在；重连退避细节未核实 | ❓ 未核实 | ⚠️ `video-player.tsx` 注释：取流断了原地重开；退避策略未核实 | ❌ 缺失：失败即 `failed` 态 + 手动“重试”，无自动重连、无退避、无卡死看门狗 | 移植 `ReconnectBackoff`/`StallWatch` 纯 Dart 规则 + 引擎错误回调；P1 只定义接口，不实现重连 |
| 下一集 | ✅ `playNext`/`playPrevious`、自动连播、UpNext 倒计时 | ❓ 未核实 | ❓ 未核实 | ❓ 未核实 | ⚠️ 手动下一集已实现（按季/集找下一集，切集重开会话）；自动连播 UpNext ❌ | 保留手动；UpNext 待 `SkipSegments.autoNextArmed` 移植后实现 |
| BluRay | ✅ `disc/`：`BluRaySource`、`BluRayClipExtractor`、`M2tsDataSource`、`BluRayStreamReaders`（M2TS 解复用，带测试） | ❓ 未核实（未见 BluRay 代码） | ❓ 未核实 | — 缺失：浏览器无法读取光盘结构 | ❌ 缺失 | 远期/缺失：需原生 M2TS 解复用或服务端转码兜底，不在 P1 |
| 外挂字幕 | ✅ `externalSubtitles` + ASS 覆盖层（`AssSubtitleView`）+ `WebVtt.parse`；FFmpeg 在 `android-core/ffmpeg` | ❓ 未核实 | ❓ 未核实 | ❓ 未核实 | ❌ 缺失：会话已下发 `subtitleUrls`，但未接入渲染；无 WebVtt/ASS 渲染 | 短期：Flutter 侧纯 Dart 移植 `WebVtt.parse` + 覆盖层渲染；ASS（libass）待后端选型（media_kit 内置 FFmpeg 是候选） |
| 画质选择 | ✅ `QualityOption`：原画/1080p/720p/480p，上限语义（源不超档就直通） | ❓ 未核实 | ❓ 未核实 | ✅ 有 `lib/player/quality.ts`（`PlayerPreferences.kt` 注释对照提及） | ✅ P2 已实现：服务端会话 `start` 接 `max_height`（`PlaybackSessionApi.start(maxHeight)` → `POST /playback/sessions`，字段名是 `max_height` 不是 `quality`）；设置面板画质页真实可用（4 档 + 安卓 hint 文案）；改档一律服务端重开续播（Flutter 拿不到片源高度，不做安卓“直通不超上限免重开”优化）；无服务端会话的直连播放退到引擎变体选择（`VideoPlayerBackend.setQuality`，后端不支持时抛 `UnsupportedError`） | 保留；画质上限语义与引擎变体选择不是同一语义，不要混用 |
| 预连接 / 预取 | ✅ `SourceByteCache.prefetch` + `ClipPlayer` 预取数据源（与播放同一连接池/UA） | ❓ 未核实 | ❓ 未核实 | ❓ 未核实 | ❌ 缺失（video_player 无预取 API） | 待定，依赖后端选型 |
| 画质记忆 | ✅ `QualityMemory`（按影片 × 网络记忆）+ `SpeedMemory`（只记非正常速度，最多 N 条） | ❓ 未核实 | ❓ 未核实（`PlayerPrefs.ets` 存在，内容未核查） | ❓ 未核实 | ✅ P2 已移植（`lib/core/player/playback_memory.dart`，与安卓 `android-core/playback/PlayerPreferences.kt` 逐字节同口径：画质键 `player.quality-by-title`、倍速键 `player.speed-by-title`，上限 300 条；起播自动沿用并提示“已沿用上次的选择”） | 已实现；已知偏差：网络判定不做 DNS 解析（web 上 `dart:io` 不可用），IP 字面量按私网段判局域网，域名一律按外网算，局域网主机名会被误记到外网那份记忆 |

## P2 决策（2026-11-22）：切轨走服务端重开续播，不走引擎内切轨

**决定：控制器 `switchTrack` / `setQuality` 保持服务端会话重开续播；P1 建在后端层的引擎切轨 API（`VideoPlayerBackend.selectAudioTrack` / `setQuality`）保留在后端层，仅供无服务端会话的直连播放（演示/本地直链）使用，不作为控制器策略。不要两边都留——控制器只有一条路。**

依据（实读安卓 `android-core/playback/PlaybackController.kt`）：安卓原生是**引擎优先**——`selectAudio` 在直连原文件且内嵌轨受支持时用 ExoPlayer `TrackSelectionOverride` 切轨，否则重开会话；`selectSubtitle` 在 `exoRenders` 时引擎切，否则重开/叠加层；`selectQuality` 在直通且源不超上限时不重开，否则重开会话。Flutter 不能照搬，原因：

1. video_player 的引擎轨 id 是不透明平台 id，与服务端轨引用（`embedded:N`）没有定义的映射关系，语言+编码启发式匹配可能选错轨（同语言多声道）；
2. 转码档/烧录字幕（`burnSubtitle`）只在服务端会话里，引擎切轨可能与服务端转码档不一致；
3. 字幕轨 video_player 根本没有 API（平台接口 6.9.0 无 subtitle 方法），字幕必须重开；
4. Flutter 会话模型拿不到 `playsOriginalFile` / `decision.video.action` / `burnSubtitle`，做不出安卓的引擎优先判定。

画质语义补充：服务端 `max_height` 是转码上限（安卓 `QualityOption` 上限语义）；引擎内视频轨选择只是 HLS/DASH 变体选择，两者不是同一语义；web 上引擎视频轨选择也没有。

**待重估：**用户 2026-11-22 16:38 已同意 P2 在安卓做 media_kit 原型（苹果继续 AVPlayer、web 继续 video_player_web）。若 media_kit 落地（它宣称有视频/音频/字幕轨选择 + 外挂音/字幕轨），上述决策应被重新评估——media_kit 的轨 id 若与服务端轨引用可映射，引擎优先才可能成立。

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
