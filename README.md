# MC_Flutter

MovieClaw（Movie Cloud）的 Flutter 客户端：一个代码库，替代 iOS、安卓、鸿蒙、web 四端。

目标是让用户只用这一个 app 就能完成全部操作，不用再打开浏览器去 web 端：app 要覆盖目前只能在 web 端做的功能。

## 现状（rewrite/flutter-unified 分支，2026-11-22）

- 四端 parity 清单：`docs/PARITY.md`（主表 50 项，设置 25 项，web-only 高优先级 11 组）
- 播放器能力矩阵：`docs/PLAYER_MATRIX.md`（14 项能力 × 四端）
- 核心层：类型化 `McApi`（309 个方法，生成模型 414 个）、统一错误分级、统一 SSE 客户端、会话单源头 `appSession`
- 播放器：统一 Dart 接口 `PlayerService` + 分平台后端；iOS/macOS 用 AVPlayer（`video_player_avfoundation`），安卓用 Media3/ExoPlayer，web 用 HTML5 video，鸿蒙是未实现的桩（`flutter_ohos` 未验证）
- 设置：25/25 分区已在 app 内实现，不再走浏览器托管页
- 测试：230 个，`flutter analyze` 零错误

## 播放器后端决策（未决，需用户拍板）

- `video_player` 2.14.1 已有引擎内音轨/视频轨选择，但无字幕 API、无解码器信息、无帧率匹配。
- media_kit 有字幕轨/外挂字幕/WebVTT，但 iOS 上用 libmpv 而非 AVPlayer，与“AVPlayer 体系”目标冲突。建议先做最小 media_kit 安卓原型验证，Apple 端保留 AVPlayer。
- 鸿蒙目标是否可达未验证；推送正式方案未定（见阶段小结 `hidden_files/P5.md`，在工作区，不在仓库内）。

## 开发

```sh
flutter pub get
flutter analyze
flutter test
```

CI：`.github/workflows/flutter-ci.yml`（push/PR 到 `main` 与 `rewrite/**` 跑 `pub get` + `analyze` + `test`）。

## 发布说明

- Android release 签名配置在 `android/app/build.gradle.kts`：设置了环境变量时用正式签名，缺失时回落 debug 签名，正式发布前必须配好密钥（密钥不在仓库里）。
- 本机无 Android SDK / Xcode，release 包未在本机验证过。

## 目录

- `lib/core/`：api / player / session / designsystem / network / cast / offline
- `lib/features/`：18 个功能目录，各自包含 pages / widgets / state / routes.dart / README.md
- `docs/`：`PARITY.md`（四端对照）、`PLAYER_MATRIX.md`（播放器能力矩阵）
