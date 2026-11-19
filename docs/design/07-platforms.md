# 07 平台扩展：iOS 与 HarmonyOS（鸿蒙）

> 原则：**同一套 UI**。MovieClaw 的视觉是自有深色 Material 设计（非苹果风、非鸿蒙风），
> 三端共用 lib/ 全部代码与 core/designsystem 主题、多设备适配层（06-multi-device.md）。
> 现状审计：lib/ 中 Cupertino 引用 = 0，直接 MethodChannel / dart:io Platform 使用 = 0，
> 业务代码平台中立，具备直接多端条件。

## 1. iOS（已在仓库内）
- 已生成 ios/ Runner（flutter create --org io.movieclaw，Xcode 工程 + RunnerTests）。
- 构建需 macOS + Xcode（本仓库在 Linux 服务器上开发，CI/本地打包在 mac 侧进行）：
  flutter build ipa 或 flutter run。
- 插件 iOS 支持全部现成：video_player（AVPlayer）、flutter_secure_storage（Keychain）、
  shared_preferences（NSUserDefaults）、cached_network_image、dio（纯 dart）。
- UI 注意：组件全用 Material 3，无 Cupertino 依赖；iOS 上表现为同一深色品牌风格，
  这正是"不是苹果风格"的预期。

## 2. HarmonyOS（鸿蒙 NEXT / OpenHarmony）
官方 Flutter 不带 ohos 目标，走 OpenHarmony-SIG 社区方案：
- SDK：gitee.com/openharmony-sig/flutter_flutter（fork，ohos 版本分支）；
  配 DEVECO_SDK_HOME 后 flutter devices 可见 ohos 设备，flutter build hap。
- 插件：openharmony-sig 维护常用插件的 ohos 分支（flutter_packages 等）。
  本项目 4 个原生插件均需切 ohos 分支，业务零改动，仅 pubspec.yaml 增 dependency_overrides：

  | 插件 | iOS/Android | ohos 方案 |
  |---|---|---|
  | video_player | 官方 | SIG ohos 分支（底层视频能力对齐 AV Player 原则） |
  | flutter_secure_storage | 官方 | SIG ohos 分支（对应 iOS Keychain / Android vault） |
  | shared_preferences | 官方 | SIG ohos 分支 |
  | cached_network_image | 官方 | 依赖 flutter_cache_manager/sqflite，同样用 SIG ohos 分支 |

  dio/riverpod/go_router/intl 为纯 dart，无需处理。
- 代码侧无需 fork：PlayerService 抽象层已隔离 video_player（换引擎只动 core/player）。

## 3. 落地步骤（Windows/mac/Linux 任一 + DevEco Studio）
1. 装 OpenHarmony Flutter SDK（flutter_flutter ohos 分支）+ DevEco Studio + 签名。
2. pubspec.yaml 加 dependency_overrides 指向 4 个插件的 ohos git 分支。
3. flutter create --platforms ohos . 补 ohos/ 目录，flutter build hap。
4. 多设备适配层已平台无关（形态判定按屏幕尺寸而非平台），手机/折叠屏/平板/智慧屏直接生效。

## 4. 验收口径
- iOS：mac 侧 flutter analyze/build ios 无错；真机冒烟播放/登录/离线。
- ohos：SIG SDK 下 build hap 通过；video_player ohos 分支播放冒烟。
- 三端 UI 与 Android 一致（同一 lib/，无平台分支 UI 代码）。
