# feature/more

- 原 Kotlin 模块：apps/android .../feature/more（我的页）
- 参照原型：apps/harmonyos .../pages/MorePage.ets（结构对齐）
- 设计文档：docs/design/05-misc-features.md；04-browsing-features.md §6-7

## 结构（自上而下，对齐鸿蒙 MorePage）
- pages/more_page.dart — ProfileCard → SectionPicker（会话/下载/服务器，>1 段才显示）→ 分段内容；手机单列，平板/TV 限宽 720 居中
- widgets/profile_card.dart — 80 渐变圆头像（昵称首字）+ 铅笔角标（进 /settings/profile）、昵称、身份小字、整宽「切换账号」（底部弹层）
- widgets/account_switcher_sheet.dart — 账号切换弹层：读 mc_servers 本机快照，snapshotAccountToken → switchAccount 后整页刷新
- widgets/section_picker.dart — 圆角 27 三段胶囊选择器（服务器段可带提醒红点）
- widgets/conversations_section.dart — 会话段（管理员）：按 今天/昨天/更早 分组；行点击 /agent/session/{id}；续接（fork 跳新会话）/ 重命名（截 80 字去空白）/ 删除（确认「彻底删除」）；滚到底自动翻页
- widgets/downloads_section.dart — 下载段：离线下载入口卡 → /offline（数据属 offline 域，禁跨 feature import）
- widgets/server_section.dart — 服务器段：当前服务器卡（服务器设置 → /settings）+ 管理员「待处理/可用更新」瓷砖（→ /notices、/update）+ SettingsCatalog 分组入口（设备/播放/更新与维护/Web，只列有真实路由项）

## 状态
- state/models.dart — McNotice（group_key / grouped_under 折叠规则）、SessionSummary
- state/mc_api.dart — MoreApi（auth/me、system/notices、app/update/pending、sessions 增删改分叉）
- state/controllers.dart — MoreController（noticeCount 独立口径；轮询公告 30s / 待更新 10min，仅管理员，失败保留旧值；分页去重）

## 路由
- /routes.dart 导出 /more（主路由名不变）

## TODO
- 下载段可考虑 core 下沉 OfflineState 摘要（现经 /offline 跳转）
- 通知角标未做 dismiss 持久化（接口已封：MoreApi.dismissNotice）
