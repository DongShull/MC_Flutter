# 04 · 浏览功能（媒体库 / 发现 / 搜索 / 详情 / 订阅 / 活动 / 刷片）

> 状态：设计稿 v1。本篇把 MovieClaw 浏览类设计的十份源文档（`library.md`、`library-home-perspective.md`、`library-filtering.md`、`library-search.md`、`genre-cinematic-cards.md`、`reels.md`、`subscription.md`、`subscription-plan.md`、`activity.md`、`metadata.md`）转译为 Flutter 客户端（mc_flutter）的实现设计。架构总则见 `01-architecture.md`，播放器见 `03-player-avplayer.md`。
>
> 模块目录约定（全文适用）：每个功能域一个 `lib/features/<name>/`，内含 `pages/`（整页级组件，路由直挂）、`widgets/`（可复用子组件）、`state/`（ViewModel / 状态通知器 / API client 封装）、`routes.dart`（本域路由表）。对应 Kotlin 侧 `apps/android/.../feature/<x>/` 下的同职责文件。

---

## 0. 模块映射总表

| Kotlin（feature/<x>/） | Flutter（features/<name>/） | 职责 |
|---|---|---|
| `library/LibraryScreen.kt` | `library/pages/library_home_page.dart` | 媒体库首页（行清单透视） |
| `library/LibraryDetailScreen.kt` | `library/pages/library_detail_page.dart` | 单库海报墙 + 筛选 + 排序 |
| `library/LibraryCollectionScreen.kt` | `library/pages/collection_detail_page.dart` | 合集详情 |
| `library/LibraryCustomizeScreen.kt` | `library/pages/library_customize_page.dart` | 自定义首页 |
| `library/KindWallScreen.kt` | `library/pages/kind_wall_page.dart` | 跨库类型墙 |
| `library/LibraryPersonScreen.kt` | `library/pages/library_person_page.dart` | 库内人物作品页 |
| `library/ReelsFloor.kt` | `library/widgets/reels_floor.dart` | 首页下拉二楼（刷片入口） |
| `library/LibraryScrapeOverrides.kt`、`LibraryFormScreen.kt`、`LibraryExtraScreens.kt` | `library/pages/library_manage_page.dart` 等 | 库管理/刮削（管理侧，二期） |
| `discover/DiscoverScreen.kt`、`DiscoverFilteredGrid.kt`、`DiscoveryMenus.kt` | `discover/pages/discover_page.dart`、`discover_grid.dart` | TMDB/豆瓣 发现 |
| `discover/TitleDetailScreen.kt` | `discover/pages/title_detail_page.dart` | 发现侧条目详情（订阅入口） |
| `discover/PersonScreen.kt` | `discover/pages/person_page.dart` | 发现侧人物页 |
| `search/SearchScreen.kt`、`SearchViewModel.kt`、`SearchModeMemory.kt` | `search/pages/search_page.dart`、`state/search_view_model.dart` | 全局搜索（本地库 + 站点） |
| `detail/ItemDetailScreen.kt` 及同目录其余文件 | `detail/pages/item_detail_page.dart` + `detail/widgets/*` | 库内条目详情 |
| `subscriptions/*.kt` | `subscriptions/pages/*`、`subscriptions/widgets/*` | 订阅列表/详情/弹层 |
| `activity/*.kt` | `activity/pages/*`、`activity/widgets/*` | 活动页（观看/任务） |
| `reels/ReelsScreen.kt`、`ReelsPlayers.kt`、`DeferredReelReleases.kt` | `reels/pages/reels_page.dart`、`reels/widgets/*` | 刷片信息流 |
| `core/discovery/`、`core/api/`、`core/model/` | `lib/core/api/`、`lib/core/models/` | API client 与模型（域外共享） |

路由总挂载点：`lib/features/root/`（对应 `root/MainTabScreen.kt`）；每域 `routes.dart` 只注册自己域内的路径，由 root 聚合。

---

## 1. 媒体库（features/library）

### 1.1 媒体库首页（library_home_page）

**布局结构**（对应源设计 library-home-perspective.md）：

- 页头：左「媒体库」标题 + 「自定义首页」图标钮；右「首页 / 合集」分段控件（`LibrarySectionSwitcher`，常驻）；右上搜索入口。
- 正文为**每成员有序行清单**，行类型由 `member.ui_prefs.home.rows` JSON 驱动：
  - `up-next` 接下来继续（固定最近播放语义）；
  - `libraries` 我的媒体库（库卡片横滚，固定库顺序）；
  - `favorites` 我的收藏（sort 可为 `unwatched_first` / `rating` / `title` / `favorited_at`）;
  - `lib:<id>` / `row:<uuid>` 库行（排序 = 指标 × 方向）；
  - `row:<uuid>` + `media_kind` 跨库类型行（`GET /libraries/kinds/{kind}` 口径）；
  - 合集行（collection id）。
- 行组件：`widgets/home_row.dart` 统一「标题 + 查看全部 › + 横滚内容」；海报卡共用 `widgets/poster_card.dart`。随机排序档按天固定（服务端种子），客户端不自行洗牌。

**数据接口**：

- `GET /ui/preferences` / `PUT /ui/preferences`（home.rows，上限 128；合并规则在客户端 `state/home_rows.dart` 的 `buildHomeRows()`：存过的按存序 + 内置补齐 + 可见新库追加默认行，`row:` 指向不可见来源的丢弃）。
- 逐行取数：`listUpNext(20)`、`listFavorites(20)`、`listLibraryItems(id, {sort, order, limit:20, w})`、`listCollectionItems(id, {limit:20, sort})`、`GET /libraries/kinds/{kind}/items`。隐藏行不发请求；同一库同一排序只请求一次（结果缓存于 `state`）。
- 类型行计数：`GET /libraries/kinds/{kind}`。

**交互要点**：

- 首页本身**没有任何排序控件**——唯一入口「自定义首页」独立页；页头只有分段控件与搜索。
- 「查看全部」携带 `w` / `sort` / `order` 进查询串跳对应墙页（单库 → 库页，类型行 → `kind_wall_page`，合集行 → 合集页）。
- 下拉二楼（刷片入口）见 §7.4：`widgets/reels_floor.dart` 接在本页滚动容器上（刷新触发点之后 +20 胶片入画、+35 过线；183 点为刷新触发基准）。
- 空态：全部行隐藏时渲染指回自定义页的 `EmptyState`。

### 1.2 单库页（library_detail_page）

**布局结构**（library-filtering.md）：

- 吸顶标题行：库名 + 统计（N 部 · X TB，取 `library.stats_*` 快照）+ 作品/合集 分段开关 + 右上「搜索 · ⋯」两颗（`⋯` 内含库管理动作与图床/瀑布流形态开关）。
- 墙控件组一行：合集文字行（静止态安静文字、选中实心、30px 高、装不下换行）+ 排序显值下拉（无边框，如「按标题」「评分」）+ 唯一带框按钮「筛选」。
- 条件生效行：已选条件 chip（可见、单个可撤）+ 「且/或」连接词 + 筛出 N 部 + ⊕存为合集。
- 海报墙：`widgets/poster_wall.dart`（2:3 网格 / 瀑布流两形态；A-Z 首字母索引条仅在按标题排序时出现）；卡片悬停放大 1.045、画质角标悬停显示、收藏心与在看进度条常驻（状态不藏）。
- 待识别 / 缺失 / 回收站等运维分区在「⋯」内，不占浏览主墙。

**数据接口**（三个接口筛选参数完全同形）：

- `GET /libraries/{id}/items?g=&d=&c=&w=&rating_gte=&rt=&res=&hdr=&sort=&order=&limit=&offset=`
- `GET /libraries/{id}/facets?<同一组参数>` → 每维取值带「排除本维自身条件后的剩余计数」；为 0 置灰不可点。
- `GET /ui/libraries/{id}/index?<同一组参数>&sort=title`（索引条）。
- 排序档：`title` / `added_at` / `release_date` / `rating` / `runtime` / `size` / `last_played` / `random`，`order=asc|desc` 可反转。

**交互要点**：

- **铁律落地**：筛选即时生效（点一下就变）；永不空货架（0 计数置灰 + 真筛空时渲染放宽建议：逐条剔除已选条件重算，只列命中数 > 0 的前三条，附「去掉/放宽」动作按钮）。
- 筛选态是 **URL 查询串的唯一事实源**（GoRouter query parameters），刷新/分享/回退均一致；localStorage（Flutter 侧为本地偏好存储）只记排序与方向，**不记筛选**。
- 滚动位置记忆按「库 + 筛选指纹」分 scope（`wallRecallScope("library:12:g16_cJP")`），返回时恢复。
- 按 kind 降级：`video` 库只保留查库维度（画质/体积/来源/年月）；`photo` 库走相册时间线，不加类型/评分——**没有事实就不摆控件**。
- 移动端：点「筛选」拉起**非全屏底部抽屉**（上方留一截墙可见实时变化），一二级维度全部平铺胶囊，每次勾选立即生效，底部固定「查看 N 部」主按钮 + 清空。
- 「筛完存为合集」弹层（`widgets/save_collection_sheet.dart`）：自动拟名 + 规则预览 + 智能/固定快照二选一 + 可见性；「固定这 N 部」把当前命中快照成手动名单。

### 1.3 合集（collection_detail_page / 合集总览）

**布局结构**：

- 单库页「作品 / 合集」切换的合集视图：纵向 2:3 网格（与作品同形，封面从成员海报借取，`cover_item_id` 未指定取第一成员），卡片背后露两片边示意「一叠」。
- 合集详情页：顶部**只读规则条**（一排条件 chip 文案 + N 部 · 本周新增 N 部，回答"为什么收了这些片"）+ 成员海报墙；手动合集明示「名单固定，没有规则——筛选条对它不适用」。
- 跨库合集总览 `/library/collections`：页头「首页/合集」分段切换进入，不挂 PageNav；顶部两维筛选（类型：全部/剧集/电影，取所属库 kind；来源：全部/自建/自动），faceted 口径计数，数为 0 压暗不消失；库内次序自建在前、内置居中、系列在后。

**数据接口**：`GET/POST/PUT/DELETE /collections`、`GET /collections/{id}/items?sort=&order=`、`POST /collections/{id}/items`（仅手动）、`PUT /collections/{id}/order`（拖拽排序，`collection_item.position`）、合集分享 `share.collection`（成员每次访问重算，不固化名单）。规则求值只在服务端 `resolve_members()` 一处，客户端不做本地过滤。

**交互要点**：库页合集 chip 点击 = 把当前墙筛成它（已选条件行标出 ＝ 合集「X」，用户改动任一条即消失）；跨库合集只能手动名单（服务端对「跨库+规则」返回 400）；合集详情页「⋯」含「显示在首页 / 从首页移除」（写同一份 ui_prefs）。

### 1.4 自定义首页（library_customize_page）

- 纯列表页（不放大海报）：行头 = 名字 + 可见性眼睛 + 拖拽把手；点名字就地展开紧凑设置行：排序下拉（按来源裁剪的预设表）、库行「只显示我没看过的」开关、名字输入（onBlur 才写入）。
- 「＋ 添加一行」：候选依次为类型行（「全部电影 · N 个库」）→ 可见库 → 可见合集；新行 id `row:` + 6 位 base36 随机串，添加后自动展开。
- 「恢复默认」带确认 = 写空列表。
- 改动进本地草稿立即呈现，**400ms 去抖后整体 PUT** /ui/preferences；换位只留把手拖拽（指针事件，触屏可用）。

### 1.5 人物页（library_person_page）

- `GET /search/library?person_id=<本地人物主键>` 复用搜索接口取其全部可见库内作品，海报墙 + 相关度原顺序平铺。

---

## 2. 发现（features/discover）

**布局结构**：来源切换（TMDB / 豆瓣分段控件，这份控件形态全 App 复用：活动页视角切换、库页作品/合集切换同款）+ 类型/年代/地区/评分筛选菜单（`DiscoveryMenus.kt` → `widgets/discovery_menus.dart`）+ 过滤后网格（`DiscoverFilteredGrid`）。片单为站外发现条目，不属于本地图库。

**数据接口**：发现服务实时接口（TMDB 热门/搜索/详情 + TTL 缓存）；豆瓣条目详情富化。展示类信息（长简介、演职员、剧照、评分）一律实时拉取不落本地缓存表——与服务端「media_item 只存订阅最小闭包」的立场对齐。

**交互要点**：

- 发现条目详情页（`title_detail_page.dart`）承载**订阅入口**：把 Discover `title_ref` 原样交给订阅弹层（§5.2），本页不预先建档。
- 人物页与库内人物页分流：发现侧走 TMDB id，库侧走本地人物主键，两者不做混用。
- 点「进入媒体库」类落点跳 `detail` 域（库内条目详情）。

---

## 3. 搜索（features/search）

**布局结构**（library-search.md）：

- 顶栏搜索框（防抖 350ms，旧请求取消 + 请求序号校验）+ 结果区：**按相关度原顺序平铺**，命中人物单独成行（≤8 人，带头像与可见作品数）；`suggestions` 渲染为输入建议。
- 结果卡带匹配原因（`match`：命中类型/字段/说明）；点击进详情（`item` 为 `LibraryItemView`，跨库去重附 `library_ids` 落点）。
- 搜索模式记忆（站点/本地，`SearchModeMemory.kt` → `state/search_mode_memory.dart`）；站点搜索属下载域，本节只覆盖**本地库搜索**。

**数据接口**：

- `GET /api/v1/search/library?q=&limit=24`、`GET /api/v1/search/library?person_id=&limit=`（q 与 person_id 至少一个）。
- 分页：响应 `next_cursor`，翻页携带相同 q/person_id + 游标；游标绑定账号与权限，过期/权限变化返回 400 → 客户端自动重新搜索；`index_pending=true` 时不提示重试（结果已合并最新业务名称）。

**交互要点**：

- 支持拼音/首字母/前缀/子串/混输与繁简全角归一，客户端只透传 q，**不做本地二次过滤或重排**（服务端相关度：文字匹配 > 全拼 > 首字母 > 前缀 > 包含 > 词组，人物命中档位偏移）。
- 人物行点击 → 库内人物页；`w` 未确认/缺失/回收站文件不出现在结果（服务端保证）。
- 结果页滚动位置在返回时恢复；去详情返回复用已加载结果，不重新搜索（防焦点跳动）。

---

## 4. 详情（features/detail）

**布局结构**（`ItemDetailScreen.kt` → `detail/pages/item_detail_page.dart`）：

- 头部：backdrop 模糊底 + poster + 标题/年份/元信息行（`年份 · 片长 · 画质 · HDR`）；评分、tagline。
- 元信息行组（标签列 + 值列，逐字同款布局）：音轨行 / 字幕行 / **系列行** / **合集行**——系列与合集是两行带标签的**文字链接**（归属用文字，推荐才用卡片；最多 3 个，多收「还有 N 个」；系列合集与「我的收藏」不进合集行）。
- 简介区（可展开）；演职员横滚（cast 前 40，人物卡点进人物页）。
- 剧集：季选择器 + 分集列表（`media_episode`：名称/简介/播出日/时长/评分/still 缩略）；`EpisodeRanges.kt` → `widgets/episode_ranges.dart`（缺集区间提示）；`AirSchedule.kt` → `widgets/air_schedule.dart`（在播档期横幅）。
- 动作区：播放/续播（播放决策 → player 域）、收藏、已看、下载（离线）、分享、字幕生成（`SubtitleGen.kt`）、`ItemActionsMenu.kt` → `widgets/item_actions_menu.dart` 与 `ItemActionSheets.kt` → `widgets/item_action_sheets.dart`；订阅态时入口变「管理订阅」。
- 图片资产走 `/images/assets/{id}/...`（poster/backdrop/logo/season），带版本参数防陈图；选图锁（`*_locked`）只在管理界面露出。

**数据接口**：

- `GET /items/{id}`（LibraryItemView + media_metadata 读路径：NFO 吸收 → media_metadata → TMDB 兜底，客户端无感）。
- 单条目元数据刷新：`POST /items/{id}/metadata/refresh`；整库刷新（管理侧）：`POST /libraries/{id}/metadata/refresh(+stop)`，长任务状态轮询。
- 标记/进度：`/playback/marks`、`/playback/resume`；字幕生成任务走任务域。

**交互要点**：

- 剧集落点支持深链到具体季集（刷片「详情」返回时直接落在该集）。
- 分级受限（ContentLimit）条目：详情接口对不可见成员 404，客户端渲染统一无权态，不做本地预判绕过。

---

## 5. 订阅（features/subscriptions）

### 5.1 订阅列表页（subscriptions_page）

- 海报墙 + 状态徽标（`tracking` 追更中 / `waiting` 缺失 / `completed` 已收齐，三态与后端派生状态一致）+ 进度（缺 x 集）；按 `last_activity_at` 倒序（服务端固定字段索引）。
- 卡片点击进订阅详情页。

### 5.2 订阅创建弹层（subscribe_sheet）

- 入口：发现条目详情页「订阅」。流程：`POST /api/subscriptions/title-preview`（幂等，返回条目摘要 + 每季 {已播/总集数, air_date}）→ 弹层：季勾选（默认全选已播季）+「自动续订」开关 + 规则组选择（默认系统默认组）→ `POST /api/subscriptions`。
- 豆瓣入口收敛到 TMDB 锚：搜索兜底通路返回多候选时弹层让用户点选确认；收敛失败提示「该条目暂无法订阅」。
- 重复订阅幂等返回已有订阅，入口按钮变「管理」。
- `SubscribeSheetHost.kt` → `widgets/subscribe_sheet.dart`；`RuleSetSpec.kt` / `SmartSubscription.kt` → `state/rule_set_spec.dart`（规则组展示与选择；规则编辑在管理侧）。

### 5.3 订阅详情页（subscription_detail_page）

- 追踪明细：按季分组，每工单一行 = 状态徽标 + 调度解释一句中文（排队搜索 / 待播出 / 未定档 / 冷却中 / 已提交下载 / 换源试用中——与三类调度语义一一对应）。
- 活动时间线：`subscription_activity` 流水（message 为服务端渲染好的完整中文句子，客户端原样展示；`payload` 结构化细节按需展开）。
- 操作：暂停/恢复、取消订阅、修改季选择、手动「立即搜索」（电影为强制语义：未上映也搜一次）；删除订阅不动已下载内容与下载器任务。
- `SubscriptionDetailContent.kt` / `SubscriptionEvents.kt` → `widgets/tracking_list.dart` / `widgets/activity_timeline.dart`。

### 5.4 订阅墙（subscription_wall）

- `SubscriptionWallScreen.kt` / `SubscriptionIndex.kt` → `pages/subscription_wall_page.dart`：订阅内容聚合浏览墙，走 `GET /subscriptions/{id}/items`（或站点资源索引），供从活动页/详情页反查资源。

---

## 6. 活动（features/activity）

**布局结构**（activity.md）：

- 一级视角：**观看 / 任务** 分段控件（URL `?view=` 唯一参数；默认「观看」，但侧栏角标亮时落点跟随角标深链到任务对应切片）。切换器：移动端挂全局顶栏行内，桌面留页头右上。
- 侧栏入口角标与页内切片共用一份计数口径（`state/task_activity.dart`）：一个下载任务与其触发的入库 Job 只算一件。
- 观看视角绿点（呼吸）表示"此刻有人在播"；任务角标数字表示"有几件等着我"——两枚提示语义刻意不同。

### 6.1 任务视角

- 四状态切片：全部 / 需处理 / 进行中 / 历史（胶囊切片行 + 工具栏右侧筛选下拉）。
- 布局规则：需处理任务置顶（带边框操作卡，容纳错误说明与动作）；进行中走"现在"时间线（无外框 Feed 行，主标题答"处理谁"，正文答"做到哪里" + 进度条 + 取消）；历史按本地日期分组，最近一组展开、较早折叠；历史行固定「时间 + 图标 + 标题 + 一行结果」。
- 下载任务按稳定 `media_item_id` 合并成作品卡（海报层 + 资源层）；`download:<infohash>` 关联的入库 Job 投影为「已投递 → 下载 → 入库」**竖排时间线**，不重复展示。未识别资源独立卡片，不按相似标题合并。
- **忽略是计数的一部分**：仅对失败任务开放、记 `job.dismissed_at`、可逆（历史里「撤销忽略」）、可批量（分区头「全部忽略」一次事务）；忽略弹层对自动来源任务默认勾选「不再自动生成」（`subtitle_auto_mute`）。
- 每条待办的第二出口「交给 AI 分析」（六段工单；第一个按钮永远是确定性出口）。
- 红灯展示遵循「粒度=修复粒度」：路径体检给唯一结论与动作；目录级红灯折叠子任务告警（子告警保持活跃挂"无法入库"红标）；红灯活跃期自动换源刹车时卡片注明原因。
- 数据节奏：下载快照每 10s 轮询（`GET /downloaders/tasks`；单源失败标 `error` 不白屏）、Job 走 SSE + 15s 低频轮询；页面隐藏暂停，恢复立即校准。不提供手动刷新按钮，以最近更新时间作轻量反馈。
- 顶部轻量状态栏：进行中 / 需处理 / 下载器可用性；底部来源区列各下载器状态与任务数。

### 6.2 观看视角

- 三切片（同一 `view` 参数族，与任务切片不撞名）：`playing` 正在播放（8s 轮询，切片带在播数）/`plays` 最近播放（按天分组、游标 `before` 翻页、不轮询、哨兵提前半屏触发）/ `stats` 观看统计（周期切换）。
- 正在播放卡：成员 · 客户端 · 设备 · 版本元信息行；速率如实（strm 标"网盘直链"、无字节流时 null 显示"本地直连"）；整文件下载独立「正在下载」分区；进度条贴卡底 3px 细条；右上角菜单 =「结束播放」/「注销此设备」（注销三件事由服务端一次完成）。
- 观看统计（管理员）：指标卡（时长/场次/看完率/活跃成员，带涨跌标签与上期参照）→ 主图（逐日柱图 + 上期虚线，内联绘制不引图表库）→ TOP3 最受欢迎（大描边数字压海报、背景环境光，口径=看过的成员最多，带"蝉联/上期第 n/新上榜"对照）→ 四分解面板（成员/客户端/看得最多/播放方式，各封顶 5 行、"其他 N 个"合计）→ 星期×小时热力图。点成员名整页钻取。
- 范围切换（`GET /playback/activity?scope=visible|all`）：默认折叠范围外记录只报个数；`all` 时范围外条目标「仅管理」不给详情链接。选过的档记本机。

---

## 7. 刷片（features/reels）

### 7.1 数据与接口

- `GET /api/v1/reels?seed=&offset=&limit=&modes=seek[,clip]`：第一页 5 条、后续每页 10 条；`seed+offset` 无状态翻页，同 seed 顺序固定。条目结构：`items[{id, title{...}, cover_url, segment{file_id,start_ms,end_ms,method}, play{mode, stream_url|clip_url, size_bytes, subtitle?, prefetch[]}}]`。
- `GET /reels/facets`：多维筛选计数（同媒体库筛选参数 + `kind`），每维排除自身条件；「其他」（`kind=video`）分池不混默认、只认观看状态、`filterable=false` 时收起其余五个菜单。
- `POST /reels/events`（impression/first_frame/leave/complete/detail/fail，攒批上报；位置毫秒取整）；**只写事件表不写观看记录**，取流 token 无 device_id。
- `GET /reels/preview/{id}`：电视首页大图预告（`highlight`=片段 / `resume`=续播点前 30s）；切好预切片段时一律返回 clip。
- 片段模式接口兼容：`modes` 声明客户端会放的形态，老响应永不带 `clip`；`segment` 永远是原片时间轴（「接着看」= start_ms + 已播时长）。

### 7.2 信息流页（reels_page）

**布局结构**（对齐 iOS 版式）：

- 纯黑底、横带居中（中心 46% 高）；顶栏：左=在播条目的片名粗体 + 年份弱档（换播放器才换），右=玻璃胶囊筛选键（摘要文案：全部 / 单条件值 / 已筛选 N 项；取值带剩余部数、0 置灰）。
- 右下无底色白色图标列：收藏（落整部）/ 详情 / 已看（电影整部、剧集这一集；按真实进度画圈，看完绿实心）/ 分享。
- 左下：导演（剧集主创）小头像行 + 三行简介（剧集以粗体「第 N 季第 N 集「集名」」开头；展开最多八行）。
- 底部细进度线（按片段算），暂停时淡入；横带下方「画质 ⌄」「全屏观看」。

**交互要点**：

- 竖滑翻页（PageView snap），横滑不拖进度；手势复用 player 域 `PlayerGestureLayer`（轻点暂停/继续、双击 ∓±10s、长按 2 倍速；竖滑亮度/音量关闭）。
- 点任意空白处暂停/继续；放到终点停下、点重播；本页锁竖屏。
- 片段画质 `ReelsQuality` 独立记忆（家/外网分档，默认外网 720p）；限画质开转码会话（不带播放记录编号、不报进度），源不超所选档释放会话直出。
- 字幕：文字轨用**片段字幕窗口**（起点前 10s ~ 终点后 5s），图形字幕由服务端转码压画。
- 预取：当前条出第一帧后按 `prefetch` 字节范围预取下一条；出画 1 秒且预取完成后预起下一条（装载到起点停住）。切 clip 模式时无需预起与预取。
- 全屏 = 正片播放器的**片段模式**（`PlayRequest.clip`）：时间轴只算片段（显示从片段起点换算）、底栏「看全片」原地退回片段模式回到信息流当前位置；不报进度、不留播放质量记录、无画中画。
- 「详情」：记下当前位置压栈条目详情页（剧集带季集直落该集），返回后该条接着放。
- 蜂窝网络进入前确认一次「可能很耗流量」；离线模式不出入口。
- `DeferredReelReleases.kt` → `state/deferred_releases.dart`（引擎延迟释放：换条时旧引擎先停声、半秒后拆）。

### 7.3 放映厅（≥768 宽度，平板/桌面）

- 左大画面（16:9）右信息（片名/年份·类型·评分/导演/简介 +「看全片」「详情」+ 收藏/已看/分享）；下方「接下来」4 条 + 自动连播开关（放完倒数 3s 接下一条）；筛选平铺顶栏（电影/剧集/其他分段 + 媒体库筛选同款下拉）。
- 换条：滚轮/触控板一次手势一条（累计 40px 翻条 + 220ms 锁）、键盘 ↑↓/J/K、右侧圆钮；空格暂停、M 静音、F 全屏、回车看全片；控制条停 2.5s 收起。

### 7.4 首页下拉二楼（library/widgets/reels_floor.dart）

- 挂在首页滚动容器：普通下拉 = 刷新（触发点记 183）；之后 +20 胶片入画、+35 过线（合计 218）；过线压片板合拢、文案换「松手，开始欣赏」，松手压栈进刷片页并把首页滚回顶端；推回线内松手只是刷新。
- 胶片位置只跟下拉量走（倒片可回退），画格用首页已取到的条目剧照（不另发请求）；只认手指拖拽越界，回弹不算。旁白/读屏开启时顶栏补一颗普通入口按钮。

---

## 8. 通用约定

- **API client**：`lib/core/api/` 统一封装（统一 `success/code/message/data` 信封解包；token 注入；错误映射中文文案）。分页游标（`next_cursor` / `before`）统一由 `state` 层持有，页面只消费列表。
- **图片**：所有海报/剧照/封面走派生图尺寸参数（如 `reel-still` 1280×720），列表位置不拉原图；缺图统一中性深灰渐变 + 胶片符号占位。
- **URL 即状态**：筛选、视角、分段全部进 GoRouter query；本地持久化只放"偏好"（排序、画质、连播开关、范围档），不放"意图"（筛选）。
- **空态**：统一 `EmptyState`（图标/标题/一句说明/动作），空不是故障，不用警告色；读取中用与最终布局同形的骨架。
- **计数口径单源**：侧栏角标、切换器、页内切片共用一个 notifier，禁止各算各的。
- **内容分级**：ContentLimit 由服务端在六处（墙/搜索/合集/Jellyfin/详情/播放决策）收口，客户端不做本地放宽，全部如实渲染服务端返回。

## 9. 验证清单

- 首页：无偏好用户渲染结果与出厂布局逐行一致；隐藏行不发请求；同一库同排序只请求一次。
- 筛选：1,000 部库勾「动画+日本」，墙/索引条/facet 计数三者一致；facet 排除自身维；筛空出放宽建议且只列命中数>0 的项；刷新后条件还在、排序在偏好里。
- 搜索：`xjcy`/`星际cy`/`诺兰`/`nl` 各命中预期；人物行 ≤8 且带作品数；游标 400 后自动重搜。
- 订阅：创建 → 弹层季勾选 → 列表出现 → 详情时间线出现搜索/拒绝/投递流水；重复订阅幂等。
- 活动：下载 10s 轮询恢复可见立即校准；忽略后角标数减少、撤销后恢复；范围切换折叠个数正确。
- 刷片：竖滑换条起播（预起后接近即时）；事件批量上报位置取整毫秒；clip 模式老接口兼容；下拉二楼阈值 183/+20/+35。
