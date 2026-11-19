# feature/update

- 原 Kotlin 模块：apps/android .../feature/update（AppUpdateController.kt / AppUpdateDialog.kt）
- 设计文档：docs/design/05-misc-features.md §5.2 客户端自更新
- 状态：✅ 已实现（页面+弹窗+状态机+检查 API；下载安装为发布页意图+TODO）

## 已完成
- `state/models.dart`：ClientReleaseView（snake_case/camelCase 双兼容 fromJson）；UpdatePolicy
  （isNewer / shouldPrompt 排除跳过版本 / summary 取「## 简体中文」节 ≤4 行 200 字；currentBuild=1
  TODO 注入真实 build）。
- `state/mc_api.dart`：UpdateApi.latest()=先官网 GitHub Release（matching-refs/tags/android-v
  → 最新正式 release 的 android-release.json 附件）再服务器
  GET /api/v1/app/clients/{product}/latest（McClient, Channel.general）兜底；返回来源标记。
- `state/update_controller.dart`：UpdateController 状态机 Idle/Checking/UpToDate/Available/Failed；
  手动检查忽略跳过记录，自动检查 24h 一次且排除跳过版本（shared_preferences）。
- `pages/update_page.dart`：检查入口+各态弹窗（检查中/已最新/发现新版含 changelog 摘要与
  跳过/失败重试）；「打开发布页」以 SnackBar 展示 URL（TODO: 引入 url_launcher 后跳转；
  禁改 pubspec）。
- `routes.dart`：主名 `/update` 不变，builder 指向真实页。

## 未做（占位说明）
- APK 下载与签名校验安装：Flutter 客户端安装流程依赖平台通道，先以发布页意图+TODO 占位
  （对齐 Android 端「签名不符→打开发布页」的降级路径）。

> 重构注记：已下沉 core 复用（session/McClient provider、格式化、状态视图、防抖/序号守卫）。
