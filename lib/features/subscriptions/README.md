# feature/subscriptions

- 原 Kotlin 模块：apps/android .../feature/subscriptions（SubsHomeScreen.kt / SubscriptionDetailScreen.kt / SubscribeSheetHost.kt / SubscriptionEvents.kt / SubscriptionIndex.kt / SmartSubscription.kt / RuleSetSpec.kt 等）
- 设计文档：docs/design/04-browsing-features.md 第 5 节
- 状态：✅ 已实现（骨架 → 真实页面）

## 页面进度

| 页面 / 组件 | 对应安卓源 | 状态 |
| --- | --- | --- |
| 订阅列表页 pages/subscriptions_page.dart（kind 筛选 + 海报卡片 + 状态徽标 + 进度） | SubsHomeScreen.kt 订阅墙区 + SubCard | ✅ 已实现（hero 轮播 / 刚刚入库 / 日程条 ⏳ 待 home 域联动） |
| 订阅卡片 widgets/sub_card.dart（126×189 海报 + 状态小签 + 进度线 + meta） | SubCard / tvShelfMeta | ✅ 已实现 |
| 订阅详情页 pages/subscription_detail_page.dart（摘要卡四段进度条 + 立即搜索 + 更多菜单 + 取消订阅确认） | SubscriptionDetailScreen.kt | ✅ 已实现 |
| 追踪明细 widgets/tracking_list.dart（按季分组，状态徽标 + 中文调度解释） | SubscriptionDetailContent.kt downloadNote | ✅ 已实现 |
| 活动时间线 widgets/activity_timeline.dart（message 服务端渲染原样展示） | SubscriptionEvents.kt / activity 接口 | ✅ 已实现 |
| 订阅创建弹层 widgets/subscribe_sheet.dart（Seed 先显海报 → title-preview → 季勾选 + 自动续订 + 规则组 → POST） | SubscribeSheetHost.kt → SubscribeScreen | ✅ 已实现（底部抽屉非路由） |
| 订阅墙 pages/subscription_wall_page.dart（单订阅 /subscriptions/{id}/items + 全量按 kind 过滤） | SubscriptionWall | ✅ 已实现 |
| 订阅索引 state/subscription_index.dart（tmdb:{kind}:{id} 查表 + 30s 缓存 + remove 精确摘除） | SubscriptionIndex.kt | ✅ 已实现 |
| 订阅事件 state/subscription_events.dart（revision 计数 → 列表重拉） | SubscriptionEvents.kt | ✅ 已实现 |
| 规则组摘要 state/rule_set_spec.dart（specSummary 中文口径） | RuleSetSpec.kt | ✅ 已实现 |
| 智能订阅（管理员语言问答 / 画质 / 范围，SmartPlanView） | SmartSubscription.kt | ⏳ 未实现（创建弹层暂走规则组默认） |
| 手动选种（在途种子实时下载 5 秒轮询 active-downloads） | SubscriptionDetailContent.kt 选种区 | ⏳ 未实现 |
| 订阅首页 hero 轮播 / 刚刚入库 / 日程（today-arrivals window=week） | SubsHomeScreen.kt 首屏区 | ⏳ 待 home/发现域联动（入口在订阅列表页） |

## 数据接口（state/mc_api.dart，McClient · Channel.general）

- GET /api/v1/subscriptions（?kind=movie|tv）列表
- GET /api/v1/subscriptions/{id} 详情（含 wanted 工单明细）
- POST /api/v1/subscriptions/title-preview 幂等预检
- POST /api/v1/subscriptions 创建（重复订阅幂等返回已有订阅）
- PATCH /api/v1/subscriptions/{id}（只带 selected_seasons / rule_set_id）
- PATCH /api/v1/subscriptions/{id}/tracking-state（paused / active）
- PATCH /api/v1/subscriptions/{id}/follow-future（服务端字段名 enabled）
- DELETE /api/v1/subscriptions/{id}
- POST /api/v1/subscriptions/{id}/missing-resource-searches 立即搜索
- POST /api/v1/subscriptions/{id}/upgrade-runs 洗版
- GET /api/v1/subscriptions/{id}/activities?limit=50 活动时间线
- GET /api/v1/subscriptions/{id}/items 订阅墙资源
- GET /api/v1/rule-sets 规则组（超管专属；失败静默降级）

## 约定

- 状态唯一说法与配色（对齐 SubscriptionStatus.kt）：completed→已收齐/已入库·绿，paused→已暂停·黄，其余→追踪中·#6AA7FF。
- 取消订阅不删已下载内容；确认弹窗文案与安卓一致。
- 本域自持 sessionStoreProvider（state/mc_api.dart），不依赖其他 feature。
- 路由：/subscriptions 主名不变；新增 /subscriptions/wall?kind=、/subscriptions/wall/:id、/subscriptions/detail/:id。
- 多设备适配：订阅墙网格列数随宽度自适应（mcGridCrossAxisCount，cellExtent 150）；订阅卡 TV 形态包 McFocusRing；phone 布局零差异。

## P4（2026-11-22）
- 订阅首页底部增加规则集与订阅设置入口（跳 /settings/rule-sets、/settings/subscription，与设置分区同一页）。
- 规则集编辑器在 settings/pages/rule_sets_page.dart；智能默认/智能计划/智能记忆在
  settings/pages/subscription_settings_page.dart。
