
# feature/offline

- 原 Kotlin 模块：apps/android .../feature/offline（DownloadsScreen.kt / DownloadProfileSheet.kt / OfflineViewModel）
- 设计文档：docs/design/05-misc-features.md
- 状态：✅ 已实现（页面与状态机 1:1；真实字节搬运接 core/platform/download_channel.dart ——
  原生 MethodChannel mc/native/download 未实现时自动降级纯 Dart http 分块下载保底，
  Range 断点续传跨重启：.part 半成品 + .part.meta 续传元数据，任务清单持久化在
  shared_preferences 键 offline_tasks_v2，重启后未完成任务自动续传/重下）
  - pages/offline_page.dart：sections 1:1 —— 下载中（活动单元行 + waitingForWiFi 提示条 +
    「使用蜂窝网络下载」一键开）→ 建议（已看完 + 删除确认「只删本机副本，观看进度会保留」）→
    已下载 → 其他账号 → 容量条（StorageCard，扣 2GB 预留）最后；右上角设置菜单蜂窝开关
    （shared_preferences 键 offline_allow_cellular）；下载中 ReorderableListView 拖动 = 优先级排序。
  - pages/profile_sheet.dart：DownloadProfileSheet 1:1 —— 取消/标题/下载三栏、多 scope 分段、
    画质行选中打勾（原画准数其余 ≈、转码档说明）、空间不够 footer 禁用下载。
  - widgets/downloading_row.dart：DownloadingRow（海报 60x90 + 片名 + 季集·档位 + 状态 + 速度 +
    4dp 进度条；长按菜单 优先下载/暂停|继续/取消）+ StorageCard。
  - state/offline_state.dart：OfflineController（Riverpod Notifier）状态机
    queued/running/paused/waitingWifi/done/failed + 优先级；GET /api/v1/offline/manifest?file_id=、
    POST /api/v1/offline/profiles（500 一批分 chunk）；开始下载反馈「已开始下载 N 集」。
  - state/models.dart：DownloadUnit/OfflineUnitStatus/DownloadProfile/DownloadCandidate/
    StorageInfo/OfflineManifest（P3：manifest 补全 Kotlin 字段：mediaItemId/durationMs/
    container/resumePositionMs/item/library/season/chapters/segments/audioTracks/
    defaultAudio/subtitles）+ formatBytes/formatSpeed。
  - routes.dart：routeOffline='/offline' 主路由不变。
  - P3（2026-11-22）：容量去占位（`refreshStorage` 拿不到时写
    `storageUnavailableReason` 并在页内展示；安卓原生 StatFs 已有，
    iOS 新增 `ios/Runner/McDownloadPlugin.swift`，未编译验证）；
    后台下载 WorkManager 对等实现（`state/background_download.dart`，
    workmanager 插件 + 前台通知 + Wi-Fi/蜂窝约束；iOS 走 BGTaskScheduler，
    不保证时机与时长；web 不支持）；转码档下完跑 fmp4 修复
    （`core/offline/fmp4_fixup.dart`：负 tfdt 原地改 0 + 补 sidx）与打包
    （`core/offline/offline_packager.dart`：字幕/playback.json/图片，
    sidecar 落在媒体文件旁）；归档目录（owner.json/summary.json/
    progress.json/viewings）与准备态对账未移植，见小结。
  - TODO：其他账号离线扫描（OfflineOwners）、建议区「已看完」判定接观看进度、
    打包“准备态”对账（打包失败下次重跑）、离线本地播放（playback.json
    的消费方）、归档目录完整移植。
- 实现要求：页面放 pages/，私有组件放 widgets/，状态放 state/（Riverpod），路由只从 routes.dart 导出；
  禁止 import 其他 feature 目录；播放相关一律走 core/player PlayerService。
- M6 多设备：expanded 内容限宽 720 居中，设置菜单/蜂窝按钮包 McFocusRing。
