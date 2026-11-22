# feature/account

- 原 Kotlin 模块：apps/android .../feature/account（AccountSwitcherScreen.kt / AccountViewModel）
- 设计文档：docs/design/
- 状态：✅ 已实现（1:1）
  - pages/account_page.dart：用户信息卡、本机多账号分组（服务器 >1 台显示 origin 去协议头）、
    AccountRow 切换/移除、添加账号 -> /onboarding、退出全部账号两段确认（第二段问是否连本机下载一起删，
    删除文件走 TODO 平台通道）、底部提示「撤销凭证请到设置 → 设备管理」；设备管理按钮跳 /settings/devices。
  - 设备管理（P4 已合并）：本模块原有的 pages/devices_page.dart + widgets/device_row.dart
    与 state 里的 DeviceView/loadDevices/renameDevice/revokeDevice/cleanupDevices 已删除，
    唯一实现在 settings/pages/devices_page.dart（/settings/devices，含超管“显示全部”、清理预览）。
  - state/account_state.dart：AccountController（Riverpod Notifier）+ SavedServer/SavedAccount 快照
    （flutter_secure_storage 键 mc_servers）、GET auth/me、GET auth/devices；登出 =
    sessionStore.logout() 清 token 后导航意图跳 /onboarding。
  - routes.dart：routeAccount='/account' 主路由（P4 起不再有 /account/devices 子路由）。
  - TODO：多账号令牌快照（mc_token:<origin>:<user>）落地后切换账号免重输密码；本机下载清理平台通道。
- 实现要求：页面放 pages/，私有组件放 widgets/，状态放 state/（Riverpod），路由只从 routes.dart 导出；
  禁止 import 其他 feature 目录；播放相关一律走 core/player PlayerService。
- M6 多设备：非 compact 内容限宽 720 居中，设备管理/添加账号/退出全部包 McFocusRing。
