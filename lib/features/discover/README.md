# feature/discover

- 原 Kotlin 模块：apps/android .../feature/discover（DiscoverScreen.kt / DiscoverFilteredGrid.kt /
  DiscoveryFilter.kt / TitleDetailScreen.kt / PersonScreen.kt）
- 设计文档：docs/design/04-browsing-features.md §2
- 状态：✅ 已实现（对照 Kotlin 1:1）

## 已实现页面
- ✅ 发现页（DiscoverScreen → pages/discover_page.dart）：搜索入口、电影/剧集 + TMDB/豆瓣分段、
  六维筛选菜单（genres/country/year/rating/runtime/sort）、hero 轮播 + 横滚板块行、下拉刷新；
  切源/切类型清空筛选；筛选 300ms 防抖 + 请求序号守卫。
- ✅ 过滤结果网格（DiscoverFilteredGrid → widgets/discover_grid.dart +
  pages/discover_filtered_page.dart）：『找到 N 部，已加载 M 部』/『没有符合条件的影片』/
  『已加载全部 N 部影片』/『清空条件』文案、滚动近底自动翻页（ref 去重）、骨架/空态/错误重试。
- ✅ 条目详情（TitleDetailScreen → pages/title_detail_page.dart）：GET /discover/titles/{ref}、
  海报/年份/类型/评分/『在库』角标、简介、演职员横滚；『订阅影片』为导航意图（TODO subscriptions）。
- ✅ 影人页（PersonScreen → pages/person_page.dart）：GET /discover/people/{tmdbPersonId}、
  作品网格。

## 状态与路由
- state/discover_controller.dart（Riverpod Notifier，discoverProvider）
- routes.dart：/discover、/discover/title?ref=、/discover/person?id=（路由名不变）
- 组件：widgets/discovery_filter.dart、widgets/poster_card.dart（McDiscoverPosterCard）、
  widgets/discover_grid.dart（本 feature 自建，未改 core/designsystem/widgets.dart）

## 待办（依赖其他域）
- ⏳ 详情页『订阅影片』弹层（属 subscriptions feature，仅留导航意图）
- ⏳ 播放跳转（属 player 域，仅留 TODO 导航意图）

- 实现要求：页面放 pages/，私有组件放 widgets/，状态放 state/（Riverpod），路由只从 routes.dart 导出；
  禁止 import 其他 feature 目录；播放相关一律走 core/player PlayerService。

> 审核重构：已下沉 core 复用（poster_card / state_views / session_providers / debounce_guard）。
- 多设备适配：发现媒体墙平板/TV 列数随宽度自适应（mcGridCrossAxisCount，cellExtent 200）；hero 与板块行卡片 TV 形态包 McFocusRing；人物页网格同理自适应。
