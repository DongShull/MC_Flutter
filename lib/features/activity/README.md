# feature/activity

- 原 Kotlin 模块：apps/android .../feature/activity（ActivityViewModel.kt / ActivityDerive.kt / ActivityScreen.kt / ActivityDetailScreen.kt / WatchStatsPanel.kt）
- 设计文档：docs/design/04-browsing-features.md §6 活动中心
- 状态：✅ 已实现（基础 1:1）

## 文件
- state/models.dart — 活动域模型（对齐 core/model/Activity.kt，手写 fromJson）
- state/activity_api.dart — McClient 域 API：jobs / downloaders/tasks / playback/activity / stats/watch / history / 任务与下载动作 / 结束播放 / 注销设备
- state/activity_derive.dart — 派生口径（需要处理/进行中/已结束分流、下载按 media_item_id 合并、历史按天分组）
- state/controllers.dart — ActivitySnapshot + ActivityController（任务 15s / 下载 10s / 播放 8s 轮询；统计与历史 403 静默跳过）
- widgets/activity_cards.dart — 摘要行、分区标签、任务卡、下载组卡、播放会话卡、设备下载卡、历史行
- widgets/watch_stats_panel.dart — 观看统计：7/30/90 天、指标卡、TOP 作品、成员/客户端分解、逐日柱状、成员钻取
- pages/activity_page.dart — 观看/任务双视角

## 与 Android 的差异
- Android 任务流走 SSE jobs/stream（120ms 防抖）；Flutter 端暂以 15s 低频轮询代替（TODO: SSE）。
- 统计面板的 7×24 热力图暂以逐日柱条 + 分解列表代替（TODO: 热力图）。
- 任务详情页（ActivityDetailScreen 的「交给 AI」handoff 两步跳转）TODO：当前动作直接收敛在任务卡上。

> 重构注记：已下沉 core 复用（session/McClient provider、格式化、状态视图、防抖/序号守卫）。
- M6 多设备：非 compact 内容限宽 720 居中，刷新按钮包 McFocusRing。
