
# feature/offline

- 原 Kotlin 模块：apps/android .../feature/offline（DownloadsScreen.kt / DownloadProfileSheet.kt / OfflineViewModel）
- 设计文档：docs/design/05-misc-features.md
- 状态：✅ 已实现（页面与状态机 1:1；真实字节搬运为 TODO 平台通道）
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
    StorageInfo/OfflineManifest + formatBytes/formatSpeed。
  - routes.dart：routeOffline='/offline' 主路由不变。
  - TODO：真实下载字节搬运（平台通道 DownloadManager）、本机存储容量探测、
    其他账号离线扫描（OfflineOwners）、建议区「已看完」判定接观看进度。
- 实现要求：页面放 pages/，私有组件放 widgets/，状态放 state/（Riverpod），路由只从 routes.dart 导出；
  禁止 import 其他 feature 目录；播放相关一律走 core/player PlayerService。
