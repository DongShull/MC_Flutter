# feature/detail

- 原 Kotlin 模块：apps/android .../feature/detail（ItemDetailScreen.kt 等）
- 设计文档：docs/design/04-browsing-features.md 第 4 节
- 状态：✅ 已实现（骨架 → 真实页面）

## 页面进度

| 页面 / 组件 | 对应安卓源 | 状态 |
| --- | --- | --- |
| 媒体详情页 pages/detail_page.dart | ItemDetailScreen.kt | ✅ 已实现 |
| 头部（backdrop 模糊 + poster + 元信息 + 评分 + tagline）widgets/detail_header.dart | ItemDetailScreen.kt 头部区 | ✅ 已实现 |
| 元信息行组（音轨/字幕/系列/合集，链接 + 「还有 N 个」）widgets/meta_links.dart | ItemDetailScreen.kt 标签行组 | ✅ 已实现 |
| 简介区（可展开）pages/detail_page.dart _Overview | ItemDetailScreen.kt | ✅ 已实现 |
| 演职员横滚（前 40，人物卡 → 人物页 TODO）widgets/cast_row.dart | ItemDetailScreen.kt cast 区 | ✅ 已实现 |
| 剧集（季选择器 + 分集列表 + still 缩略）widgets/episode_list.dart | ItemDetailScreen.kt / SeasonEpisodesView | ✅ 已实现 |
| 缺集区间提示 widgets/episode_ranges.dart | EpisodeRanges.kt / EpisodeRangeUi.kt | ✅ 已实现 |
| 在播档期横幅 widgets/air_schedule.dart | AirSchedule.kt（字段子集） | ✅ 已实现 |
| 动作菜单（订阅/下载/分享/字幕生成/刷新元数据/删除入口）widgets/item_actions_menu.dart | ItemActionsMenu.kt / ItemActionSheets.kt | ✅ 已实现（子任务域 TODO） |
| 系列行 + 相似推荐横滚 widgets/similar_row.dart | ItemDetailScreen.kt Related | ✅ 已实现 |
| 字幕生成 SubtitleGen.kt / SubtitleGenText.kt | — | ⏳ 任务域接入（入口已留） |
| 下载 ItemDownloadHost.kt | — | ⏳ offline 域接入（入口已留） |
| 管理向功能（删除预览 / 重新识别 / 换源转移 / 海报锁） | ItemActionSheets.kt 其余 | ⏳ 管理侧（未实现） |

## 数据接口（state/detail_controller.dart，McClient · Channel.general）

- GET /api/v1/libraries/{libraryId}/items/{itemId} 详情
- GET /api/v1/libraries/{libraryId}/items/{itemId}/episodes?season_number= 分集
- GET /api/v1/libraries/{libraryId}/items/{itemId}/similar（exclude_series）相似推荐
- GET /api/v1/collections/{collectionId}/series 系列一行
- GET/POST /api/v1/playback/marks 收藏 / 已看
- GET /api/v1/playback/resume 续播点
- POST /api/v1/items/{itemId}/metadata/refresh 元数据刷新

## 约定

- 播放按钮 / 分集点击只做导航意图（/player 路由 + TODO），不自己播视频。
- 订阅入口暂跳 /subscriptions，创建弹层（title-preview → 季勾选）待 subscriptions 域。
- 路由：/detail 占位保留；/detail/:libraryId/:itemId 为深链落点。

> 审核重构：已下沉 core 复用（poster_card / state_views / session_providers）。
- 多设备适配：expanded（平板/TV）新增双栏详情（左海报/操作/元信息，右简介/演职员/季集/相似），compact 保持原单列；动作按钮 TV 形态包 McFocusRing。
