# feature/root

- 原 Kotlin 模块：apps/android .../feature/root（MainTabScreen.kt / MainTabBus.kt / ShellBadges.kt / SidebarViewModel.kt / KeepAliveTabs.kt）
- 状态：✅ 已实现主壳（骨架 → 真实壳；各 tab 真实页由各自 feature 域挂载）

## 页面进度

| 页面 / 组件 | 对应安卓源 | 状态 |
| --- | --- | --- |
| 主壳 pages/root_page.dart（五 tab + 悬浮胶囊底栏 + IndexedStack 保活） | MainTabScreen.kt | ✅ 已实现 |
| 底栏（348×54 圆角 999、图标-only、当前格白 15% 药丸、末格账号头像、再点回根） | MainTabScreen.kt 底栏区 | ✅ 已实现 |
| 页签结构（发现/媒体库/订阅/活动/我的，对齐 MainTab 枚举顺序） | MainTab.kt | ✅ 已实现 |
| 切页签总线 state/main_tab_bus.dart（open/consume 单例） | MainTabBus.kt | ✅ 已实现 |
| 底栏状态点 state/shell_badges.dart（活动红/绿/蓝、我的更新蓝点、30s 前台轮询） | ShellBadges.kt | ✅ 已实现（接口字段宽松解析，失败保持上次值） |
| 页签面板（自包含摘要 + 「打开」入口 → 各 feature 路由） | —（受禁跨 feature import 约束的自包含方案） | ✅ 已实现 |
| 页签权限裁剪（订阅需 canSubscribe、活动需 isAdmin 后隐藏） | MainTabScreen.kt 权限段 | ⏳ 待 session 权限层（默认全显） |
| 宽屏左侧栏（逐库 + 用户合集 + 账号行） | SidebarViewModel.kt | ⏳ 未实现 |
| KeepAliveTabs「后台页签不测量不摆放」 | KeepAliveTabs.kt | ⏳ 以 IndexedStack 近似保活（未做按需测量） |

## 数据接口（state/shell_badges.dart，McClient）

- GET /api/v1/jobs（Channel.general）活动任务计数（needs_attention / running）
- GET /api/v1/playback/activity（Channel.live）正在观看人数
- GET /api/v1/pending-update（Channel.general）可用更新

## 约定

- 禁止跨 feature import：壳内面板不引用其他 feature 页面，只通过路由字符串 context.push/go。
- 路由主名 /home 不变，builder 指向真实 RootPage。
- 本域自持 sessionStoreProvider（state/shell_badges.dart），不依赖其他 feature。
- 其他域请求切页签：MainTabBus.instance.open(MainTab.x)。

> 重构注记：已下沉 core 复用（session/McClient provider、格式化、状态视图、防抖/序号守卫）。
