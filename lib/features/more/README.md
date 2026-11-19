# feature/more

- 原 Kotlin 模块：apps/android .../feature/more（我的页）
- 设计文档：docs/design/05-misc-features.md；04-browsing-features.md §6-7
- 状态：✅ 已实现（会话跳转传参除外，见 TODO）

## 页面
- pages/more_page.dart — 用户卡片（头像/昵称/角色，点按进个人信息）/ 提醒组（通知与提醒、检查更新，带角标计数）/ 对话会话列表（滚动分页 GET /sessions?limit&offset；打开 / 重命名 PATCH / 重命名后刷新 / 删除 DELETE / 创建分叉 POST /sessions/{id}/fork）/ 设置入口

## 状态
- state/models.dart — McNotice（payload.group_key / grouped_under 折叠规则）、SessionSummary
- state/mc_api.dart — MoreApi（auth/me、system/notices(+dismiss)、app/update/pending、sessions 增删改分叉），sessionStoreProvider 本域自持
- state/controllers.dart — MoreController（提醒计数 = 可见公告数 + 待更新 1；分页去重加载）
- widgets/more_cards.dart — MoreUserCard / MoreSectionLabel / MoreEntryRow

## 路由
/routes.dart 导出 /more（主路由名不变，builder 已指真实页）

## TODO
- 打开/分叉会话后跳入 agent 具体会话（agent 路由暂不支持会话参数，只能 push /agent）
- 通知角标未做 dismiss 持久化（接口已封：MoreApi.dismissNotice）
