# feature/search

- 原 Kotlin 模块：apps/android .../feature/search（SearchScreen.kt / SearchViewModel.kt /
  SearchModeMemory.kt，库内搜索分支）
- 设计文档：docs/design/04-browsing-features.md §3
- 状态：✅ 已实现（对照 Kotlin 1:1，库内搜索）

## 已实现页面
- ✅ 搜索页（SearchScreen → pages/search_page.dart）：
  - 搜索框 350ms 防抖 + 请求序号校验（只允许最后一次请求更新界面）；
  - 搜索历史：本机 SharedPreferences（mc_search_history，最新在前去重、封顶 20，可单删/清空）；
  - 输入联想（suggestions，点按直接搜索）与无结果建议词；
  - 结果列表按相关度平铺（不做本地重排），命中原因 match.label 展示；
  - 相关影人行 ≤8，点击下钻该人物库内作品（可取消）；
  - 游标分页（next_cursor，近底自动追加；400 自动整页重搜）；
  - index_pending 提示『部分内容仍在建立索引』；
  - 分区模式记忆本机（mc_search_mode）。
- ✅ 状态层：state/search_controller.dart（searchProvider）、state/search_mode_memory.dart。
- ✅ 路由：routes.dart /search（路由名不变）。

## 范围说明
- 本模块只做库内搜索（GET /api/v1/search/library）；站点/资源搜索属下载域，不在本模块实现。
- 库内条目点击为导航意图（TODO：接入 detail/player 路由）。

- 实现要求：页面放 pages/，私有组件放 widgets/，状态放 state/（Riverpod），路由只从 routes.dart 导出；
  禁止 import 其他 feature 目录；播放相关一律走 core/player PlayerService。

> 重构注记：已下沉 core 复用（session/McClient provider、格式化、状态视图、防抖/序号守卫）。
- 多设备适配：结果列表/人物横滚 TV 形态包 McFocusRing（无媒体墙网格，无列数改动）；phone 布局零差异。
