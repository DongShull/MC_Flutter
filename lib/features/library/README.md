# feature/library

- 原 Kotlin 模块：apps/android .../feature/library
- 设计文档：docs/design/（见 01–05 号）
- 状态：✅ 一期浏览类页面已实现（骨架已挂路由）；管理/刮削类（建库、扫描管理、手动刮削）⏳ 属二期

## 已实现页面 ✅

| 页面 | 安卓源文件 | Flutter 文件 |
|------|-----------|--------------|
| 媒体库首页（鸿蒙 1:1，Round 24） | LibraryHomeView.ets / LibraryNavHost.ets | pages/library_home_page.dart |
| 我的收藏（全部） | FavoritesPage.ets（浏览部分） | pages/favorites_page.dart |
| 单库筛选墙 | LibraryDetailScreen.kt | pages/library_detail_page.dart |
| 合集详情 / 合集清单 | LibraryCollectionScreen.kt | pages/collection_pages.dart |
| 自定义首页 | LibraryCustomizeScreen.kt | pages/library_customize_page.dart |
| 人物下钻 | LibraryPersonScreen.kt | pages/person_kind_pages.dart |
| 类型墙 | KindWallScreen.kt | pages/person_kind_pages.dart |

## 状态 / 数据

- state/models.dart：手写 fromJson 模型（LibraryView / LibraryItemView / UpNextItem / CollectionView / LibraryFacets / HomeRowPref 等）
- state/home_rows.dart：HomeRows.kt 合并规则移植（出厂布局、存序合并、行排序/方向档案）
- state/mc_api.dart：McClient 封装（libraries/collections/playback/kinds/ui/search 段）
- state/*_controller.dart：Riverpod Notifier（首页 / 单库 / 合集 / 自定义 / 人物 / 类型墙）

## 路由

- /library（首页）、/library/detail/:libraryId、/library/collections、/library/collection/:collectionId、/library/customize、/library/person/:personId、/library/kind/:kind

## 未实现 ⏳

- 建库 / 扫描管理 / 手动刮削（Android 端 LibraryManage 相关流程）
- 单库页字母索引条点击跳转交互的细节打磨
- 播放导航：条目点击目前只留 TODO，待 core/player 路由接通

> 审核重构：已下沉 core 复用（poster_card / state_views / session_providers / format / debounce_guard）。
- 多设备适配：库墙/合集/人物网格改用 mcGridCrossAxisCount（phone 保持原 2 列/密度不变）；库卡、upNext、横滑行与类型色块 TV 形态包 McFocusRing。
