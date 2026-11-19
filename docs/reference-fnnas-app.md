# 参考分析：飞牛 App v1.37.3（用户上传 APK 逆向速览）

> 样本：fnos_1.37.3_1910221535.apk（131 MB，MD5 7a8d03f526d54d9e64142acb475f5024）
> 包名空间 com.teiron.*（广州铁刃）。用途：为 mc_flutter 提供工程架构参照。

## 核心结论：飞牛 App 就是 Flutter 写的
lib/arm64-v8a/ 含 libflutter.so + libapp.so（AOT）+ dartjni——与 mc_flutter 同技术栈。
它的架构选择验证了本项目的多个决策：

| 飞牛的做法 | mc_flutter 对应 | 状态 |
|---|---|---|
| 官方 video_player 插件（AVFoundation/Android 实现） | core/player PlayerService 封装 video_player | ✅ 同选型 |
| trim_playback_session_plugin（独立播放会话插件） | core/player TODO(playback-session) | 参照实现 |
| trim_native_download（原生下载插件） | features/offline TODO 平台通道 | 参照实现 |
| trim_cast_plugin 投屏 | 未规划 | 可选新增 |
| trim_ui 自有设计系统 + TrimIcons 字体 | core/designsystem | ✅ 同思路（非平台默认风） |
| mmkv（含 mmkv_ohos） | shared_preferences/secure_storage | 它也做了鸿蒙，佐证 07-platforms.md 路线 |
| flutter_app_update 应用内更新 | features/update | ✅ 已实现 |

## 播放器引擎
libijkplayer + libijkffmpeg + libijksdl：飞牛用 ijkplayer(bilibili) 做播放内核
（不是 ExoPlayer）——印证「统一 AV Player 抽象、内核可换」原则；
mc_flutter 现用 video_player(ExoPlayer)，后续可无损换 ijk 内核。

## 依赖清单摘录（NOTICES.Z 解出 334 个 dart 包）
- UI：flutter_staggered_grid_view / flutter_slidable / extended_text / lottie /
  fl_chart / liquid_glass_widgets / spring_animation / modal_bottom_sheet
- 媒体：just_audio + audio_service（音乐）、camera、image_picker、video_player
- 基建：dio 系、sqflite、mmkv、flutter_downloader、flutter_inappwebview、
  connectivity_plus、device_info_plus、flutter_zxing（扫码登录）、event_bus
- 生态：wechat_kit / tencent_kit（微信/QQ 登录分享）、flutter_oss_aliyun（OSS 直传）、
  flutter_reactive_ble（蓝牙）、grpc

## 对 mc_flutter 的可借鉴项（按优先级）
1. 播放会话插件化（trim_playback_session 对应物）——当前最大 TODO
2. 原生下载通道（trim_native_download）——offline 字节搬运
3. trim_cast 投屏——未来可加 cast feature
4. mmkv 替代/补充 SharedPreferences（性能+多端一致，含 ohos）
5. 自有图标字体（TrimIcons 模式）替代散落 icon
