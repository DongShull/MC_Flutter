# reels

刷片 / 片段流（1:1 重写自 Android `feature/reels/`，规格见 docs/design/04-browsing-features.md §7）。

## 状态

- ✅ 数据接口：`GET /api/v1/reels`（首页 limit=5、翻页 limit=10、modes=seek,clip、seed 翻页）与 `GET /api/v1/reels/facets`（候选值与计数，为 0 的档置灰）
- ✅ 信息流：PageView 竖滑整页；同一种子顺序固定、服务端无状态，滑到末尾前 3 条预取下一页（去重合并）
- ✅ 筛选：顶栏筛选胶囊 + 底部筛选面板（类型 / 观看状态 / 题材 / 地区 / 年代 / 评分 / 片长，维内 OR、维间 AND）；换筛选整个信息流重来（新种子）
- ✅ 收藏 / 已看：`POST /api/v1/playback/marks`，乐观更新失败回滚；收藏记整部、已看剧集记这一集 / 电影记整部
- ✅ 事件上报：`POST /api/v1/reels/events` 攒批，满 10 条 flush（失败即丢），离开页面 flush；上报 detail / open 意图
- ✅ 页面结构：纯黑底；16:9 横带满宽、中心在屏高 46%；顶栏返回键 + 片名年份胶囊（点击跳详情）+ 筛选胶囊；右下四图标（收藏 / 详情 / 已看 / 分享）；左下导演（剧集为主创）+ 三行简介；底部 2dp 细进度线（续播进度）
- ✅ /reels 404 → 「服务器版本较旧」升级提示（serverOutdated），不报加载失败
- ✅ 播放意图：封面 + 播放按钮 / 「全屏观看」跳 `/player`（导航意图 + TODO），片段起播 / 字幕 / 预取由 player 域负责

## 待办

- ⏳ 片段播放引擎（seek / clip 选路、字幕、预取、暂停控制）——依赖 player 域
- ⏳ 画质档位记忆（按网络环境记原画 / 720p）
- ⏳ 全屏片段模式（横屏整屏 + 控制层）
- ⏳ 分享（share_plus）

## 文件

- `routes.dart` — `/reels` 主路由
- `state/models.dart` — 域模型（1:1 对应 core/model/Reels.kt，snake_case）
- `state/reels_api.dart` — ReelsApi（McClient，Channel.general）
- `state/controllers.dart` — ReelsController（信息流 / 筛选 / 事件 / 标记）
- `pages/reels_page.dart` — 主页面（PageView + 顶栏 + 空态）
- `widgets/reel_page.dart` — 单页片段（横带 / 图标列 / 信息 / 进度线）
- `widgets/reel_filter_sheet.dart` — 筛选面板

> 重构注记：已下沉 core 复用（session/McClient provider、格式化、状态视图、防抖/序号守卫）。
- M6 多设备：顶栏返回/片名胶囊/筛选胶囊包 McFocusRing（TV 聚焦环，非 TV 原样透传）。
