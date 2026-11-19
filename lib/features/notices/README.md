# feature/notices

- 原 Kotlin 模块：apps/android .../feature/notices（NoticeCenterScreen.kt / NoticeCenterViewModel）
- 设计文档：docs/design/05-misc-features.md §6.1（通知中心，30s 轮询，无推送基础设施）
- 状态：✅ 已实现
  - `state/models.dart`：Notice 模型 + visibleNotices 折叠口径（group_key / grouped_under）
  - `state/mc_api.dart`：NoticeApi（GET /api/v1/system/notices、POST /api/v1/system/notices/{id}/dismiss，Channel.general）
  - `state/notices_controller.dart`：NoticesController（30s 轮询、乐观忽略 + 失败回滚、全部忽略、Loadable 三态）
  - `pages/notices_page.dart`：列表卡片、severity 配色、空态、错误重试、全部忽略
  - `routes.dart`：`/notices`（主路由名不变，builder 指真实页）
- 播放相关：无（纯通知列表）

> 重构注记：已下沉 core 复用（session/McClient provider、格式化、状态视图、防抖/序号守卫）。
