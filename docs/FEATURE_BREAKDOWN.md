# mc_flutter — MovieClaw Android 功能拆解（Flutter 重写目标）

源项目：`/ds/dsh_github/MovieClaw/apps/android`（手机版）+ `apps/android-core`（与 TV/iOS 共用的核心模块）。
本项目用 Flutter 重写 Android 客户端，播放统一走一个自研播放器服务（对应原 `core:playback`，Android 端底层为 ExoPlayer，通过 `video_player` / `media_kit` 统一封装为唯一播放入口，即「AV Player」统一播放器）。

## 功能目标列表（每个功能 = 一个重写目标）

| # | 目标 | 原模块 | 说明 | 状态 |
|---|------|--------|------|------|
| 1 | onboarding — 首次引导/登录绑定服务器 | feature/onboarding | 服务器地址输入、登录、会话建立 | ⬜ |
| 2 | root — 主框架与底部导航 | feature/root | Tab：媒体库/发现/订阅/更多，路由骨架 | ⬜ |
| 3 | library — 媒体库海报墙 | feature/library | 海报墙、分类、继续观看、最近入库 | ⬜ |
| 4 | discover — 发现页 | feature/discover | 推荐列表、热门、分类浏览 | ⬜ |
| 5 | search — 搜索 | feature/search | 全库搜索、历史、结果分组 | ⬜ |
| 6 | detail — 详情页 | feature/detail | 元数据、演员、剧集列表、播放/标记已看 | ⬜ |
| 7 | player — 统一 AV Player 播放器 | feature/player + core:playback | 全局唯一播放服务：进度、倍速、字幕、音轨、投屏接口 | ⬜ |
| 8 | subscriptions — 订阅追剧 | feature/subscriptions | 订阅列表、追剧状态 | ⬜ |
| 9 | activity — 动态/下载活动 | feature/activity | 活动流水、任务进度 | ⬜ |
| 10 | offline — 离线下载 | feature/offline + core:offline | 下载队列、本地存储、离线播放 | ⬜ |
| 11 | reels — 短剧/快刷流 | feature/reels | 竖屏快滑播放流（复用统一播放器） | ⬜ |
| 12 | account — 账户与成员 | feature/account | 个人资料、多成员切换 | ⬜ |
| 13 | notices — 通知中心 | feature/notices | 站内通知列表 | ⬜ |
| 14 | agent — AI 助手 | feature/agent | 对话式操作媒体库 | ⬜ |
| 15 | settings — 设置 | feature/settings | 播放设置、外观、缓存 | ⬜ |
| 16 | share — 分享 | feature/share | 分享链接/影片 | ⬜ |
| 17 | update — 应用内更新 | feature/update + core:update | 版本检查、下载更新包 | ⬜ |
| 18 | more — 更多页聚合 | feature/more | 设置/通知/离线等入口聚合 | ⬜ |

## 核心层（对应 android-core）

- core/model：领域模型（Movie, Episode, Subscription, Member…）→ `lib/core/models/`
- core/network：API 客户端 → `lib/core/api/`（dio）
- core/session：会话/Token → `lib/core/session/`
- core/playback：统一播放器抽象 **AV Player** → `lib/core/player/`（唯一播放入口，所有页面复用）
- core/offline：下载与本地库 → `lib/core/offline/`
- core/notify + push：通知与推送 → `lib/core/notify/`
- core/designsystem：主题与组件 → `lib/core/designsystem/`

## 播放器统一原则（AV Player）

1. 所有播放（详情页、继续观看、reels、离线）只调用 `PlayerService`（lib/core/player/player_service.dart）。
2. `PlayerService` 封装单一底层引擎：Android 用 ExoPlayer（video_player），必要时 media_kit 兜底；对外接口统一。
3. 统一能力：播放/暂停、seek、倍速、音轨/字幕切换、后台音频、进度上报服务器。

## 目录规划（强制模块化）

**模块化原则：每个功能 = features/ 下一个独立目录，自包含全部实现，功能之间不互相 import 页面代码，只允许依赖 core/。新增/删除一个功能目录不影响其他功能。**

lib/
  main.dart, app.dart
  core/                       # 跨功能的公共层（对应 android-core）
    models/                   #   领域模型
    api/                      #   三通道网络层（General/Live/Playback）
    session/                  #   会话与凭证
    player/                   #   ★ 统一 AV Player（PlayerService，唯一播放入口）
    offline/                  #   下载与本地库
    notify/                   #   通知与推送
    designsystem/             #   主题令牌与基础组件
  features/                   # ★ 功能模块，一个功能一个目录，结构统一
    onboarding/  library/  discover/  search/  detail/  player/
    subscriptions/  activity/  offline/  reels/  account/  notices/
    agent/  settings/  share/  update/  more/  root/
  每个功能目录内部统一为：
    features/<name>/
      pages/        # 页面（Screen）
      widgets/      # 本功能私有组件
      state/        # 本功能的 controller/provider（Riverpod）
      routes.dart   # 本功能路由注册（导出给 app.dart 统一挂载）
      README.md     # 本功能说明：对应原 Kotlin 模块、接口、进度状态

## 里程碑

- M1：项目骨架 + core(models/api/player) + onboarding + root 导航 ✅目标
- M2：library / discover / search / detail（只读浏览闭环）
- M3：统一 AV Player 播放闭环（在线播放 + 进度上报）
- M4：subscriptions / activity / notices / account / settings / more
- M5：offline 下载 + reels + agent + share + update
