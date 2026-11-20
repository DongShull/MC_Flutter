# 10 - 平台适配：抄飞牛的 Android / iOS / 鸿蒙策略（1:1 还原 + MC 执行方案）

> 逆向证据源：fnos_reference/blutter_out/pp.txt（trim_base_plugin Pigeon 通道面）、
> reference-fnnas-app.md（插件清单）、07-platforms.md（先行路线）。本文是「飞牛怎么适配三端」
> 的完整答案与 mc_flutter 的落地对照。

## 一、飞牛的证据（逆向所得）

### 1.1 核心思想：一套 Dart 代码，三端只在「边缘」分叉
- pp.txt 铁证：`dev.flutter.pigeon.trim_base_plugin.HarmonyUtilApi.isHarmonyOS` 与
  `...harmonyOSVersion` —— Dart 侧**运行时问原生**「当前是不是鸿蒙、什么版本」，
  业务代码不做任何编译期平台分叉（无 import 'dart:io' 判平台散落业务里）。
- mmkv 依赖含 **mmkv_ohos**（第三方库的 ohos 分支直接吃进来）——佐证「用 ohos 分支插件
  而不是重写插件」。
- 本 APK（安卓产物）不含 ohos so——鸿蒙是**独立 CI 产物**（build hap），不是同一 APK 兼容。
- trim_* 内部插件全部 Pigeon 化（134 条通道），接口面与平台实现解耦：Dart 调
  `trim_playback_session_plugin`，安卓/iOS/鸿蒙各给实现。

### 1.2 Android 端
- Flutter 官方 engine + ijkplayer（libijkplayer/libijkffmpeg）做播放内核（不是 ExoPlayer，
  为的是格式兼容与软解可控）；trim_native_download 做离线字节搬运；trim_cast 投屏；
  trim_http_client 传输层；trim_ui 纯 Dart 无平台依赖。
- keep-alive：HostKeepAliveApi.startKeepAlive（前台服务保活播放会话）。
- 存储：secure storage 等价物 + mmkv。

### 1.3 iOS 端
- 同一份 Dart；NOTICES.Z 可见 iOS 系包（wechat_kit/tencent_kit 等 iOS 分支）。
- 播放内核 iOS 侧换 AVPlayer 系（MC 主项目同思路），插件接口不变。

### 1.4 鸿蒙端
- OpenHarmony-SIG flutter_flutter SDK（华为维护的 Flutter 官方 fork，产 hap）。
- 四个三方插件的 ohos 分支：video_player_ohos / flutter_secure_storage_ohos /
  shared_preferences_ohos / cached_network_image ohos——通过 dependency_overrides 指过去。
- 运行时探测 + 独立 CI；业务零改动。

## 二、mc_flutter 落地对照

| 飞牛 | mc_flutter | 状态 |
|---|---|---|
| HarmonyUtilApi.isHarmonyOS / harmonyOSVersion | lib/core/platform/mc_platform.dart（MethodChannel mc/base/platform，MissingPluginException 降级 android） | ✅ |
| GlobalEventBus（原生→Dart 广播） | McPlatform.eventBusSender（EventChannel mc/base/global_events 通道约定） | ✅ 通道位 |
| 插件 ohos 分支 dependency_overrides | 07-platforms.md §鸿蒙：video_player/secure_storage/shared_preferences/cached_network_image 四件套 | 📋 已规划 |
| 独立 CI 产物（apk/ipa/hap 三矩阵） | flutter build apk / mac 侧 build ipa / ohos SDK build hap | 📋 07 已规划 |
| ijkplayer 播放内核 | video_player（官方）；播放内核可插拔（PlayerService 抽象已留位） | ✅ 抽象位 |
| HostKeepAliveApi 前台保活 | wakelock_plus + AppLifecycleListener（屏幕常亮+中断恢复） | ✅ |
| trim_native_download | offline 功能（字节搬运平台通道 TODO） | 🟨 待做 |
| trim_cast_plugin 投屏 | 播放页 cast 入口占位（McIcons.cast） | 🟨 占位 |

## 三、铁律（抄飞牛思想）
1. **业务代码禁止编译期平台分叉**：一律走 McPlatform.target() 运行时探测 + provider 注入。
2. **平台差异全部 Pigeon/MethodChannel 化**，Dart 侧只见接口面。
3. **鸿蒙接入只动三处**：ohos SDK、dependency_overrides、CI 矩阵——lib/ 业务零改动。
