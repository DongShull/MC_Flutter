# MC_Flutter 四端 Parity 清单（P0）

- 基线：MC_Flutter `main` HEAD `99f8ec2`（副本分支 `rewrite/flutter-unified`），2026-11-22。
- 参照：movieclaw/MovieClaw `apps/android`（227 个 .kt/.java）、`apps/android-core`（model/network/playback/update）、`apps/apple`（MovieClaw + Shared + Mac/TV）、`apps/harmonyos`（entry 254 个 .ets/.ts）、`apps/web`（Next.js 路由 + components + lib）。
- 方法：以四端源码的功能目录、页面/路由、设置分区为准逐项核对；**不以 MC_Flutter 的 PROGRESS.md 为准**。Flutter 现状按 `lib/` 页面/路由/状态文件逐项核查（关键词命中只作线索，页面级缺失才判 无/薄）。
- Flutter 现状标记：**有** = 页面与核心流程存在；**薄** = 部分存在（仅模型层提及、无独立页面/路由、或只有子集）；**无** = lib 内无对应页面与功能；**未确认** = 本次未查到，未敢断言。
- 优先级：**高** = 没有它用户仍须打开浏览器（违背“只用 app 完成全部操作”）；**中** = 部分可用、体验/深度不足；**低** = 已有，后续打磨。

## 1. 主功能 parity

| # | 功能/页面 | 安卓 | iOS | 鸿蒙 | web | Flutter 现状 | 优先级 |
|---|---|---|---|---|---|---|---|
| 1 | 主 Shell / 底部导航（发现/媒体库/订阅/活动/更多） | 有 | 有 | 有 | 有 | 有（root_page） | 低 |
| 2 | 启动/欢迎/登录/扫码配对/设备批准 | 有 | 有 | 有 | 有 | 薄（onboarding/qr-scan 有；设备批准仅 more 内提及 1 处） | 中 |
| 3 | 账号切换/多账号 | 有 | 有 | 有 | 有 | 有（account_page、account_switcher_sheet） | 低 |
| 4 | 发现首页/筛选 | 有 | 有 | 有 | 有 | 有（discover_page） | 低 |
| 5 | 标题详情 | 有 | 有 | 有 | 有 | 有（title_detail_page、detail_page） | 低 |
| 6 | 人物详情 | 有 | 有 | 有 | 有 | 有（person_page、/library/person/:personId） | 低 |
| 7 | 豆瓣详情 | 有 | 未确认 | 未确认 | 有 | 薄（discover 内提及，未见独立详情页） | 中 |
| 8 | 发现类型页/榜单（Top250/高分） | 未确认 | 未确认 | 未确认 | 有 | 薄（discover_filtered_page 有；榜单页未确认） | 中 |
| 9 | 搜索（站内） | 有 | 有 | 有 | 有 | 有（search_page） | 低 |
| 10 | 种子搜索 + 下载目标选择 | 未确认 | 有 | 未确认 | 有 | 薄（torrent 仅 activity_api 提及；无下载目标选择） | 中 |
| 11 | 媒体库首页/画廊墙/分类墙 | 有 | 有 | 有 | 有 | 有（library_home_page 等 15 文件） | 低 |
| 12 | 媒体详情/剧集/章节/字幕生成 | 有 | 有 | 有 | 有 | 薄（detail_page 有；章节/字幕生成仅模型层提及，未确认页面） | 中 |
| 13 | 收藏/合集管理/自定义 | 有 | 有 | 有 | 有 | 有（collection_pages、library_customize_page） | 低 |
| 14 | 收藏夹 favorites | 有 | 有 | 未确认 | 有 | 薄（无独立路由，仅模型/页面内提及） | 中 |
| 15 | 媒体库管理（回收站/重复文件/重新识别/刮削覆盖） | 未确认 | 有 | 未确认 | 有 | 无 | 高 |
| 16 | 播出时间表 AirSchedule | 有 | 有 | 未确认 | 有 | 有（air_schedule.dart） | 低 |
| 17 | 图片灯箱/照片墙 | 未确认 | 有 | 未确认 | 有 | 无 | 中 |
| 18 | 播放器页/控制/手势/选集 | 有 | 有 | 有 | 有 | 有（player_page + 6 控件；后端见 §4，属 P1） | 低 |
| 19 | 断点续播/观看进度/观看统计 | 有 | 有 | 有 | 有 | 薄（续播与统计有；观看历史无独立页） | 中 |
| 20 | 投屏 Cast（DLNA） | 有 | 有 | 未确认 | 有 | 有（cast_controller、dlna_renderer） | 低 |
| 21 | 外部播放器 | 未确认 | 未确认 | 未确认 | 有 | 无 | 高 |
| 22 | 章节预览图 trickplay | 未确认 | 未确认 | 未确认 | 有 | 薄（仅 playback_page/设置内提及） | 中 |
| 23 | AI 会话/新任务/会话列表 | 有 | 有 | 有 | 有 | 有（chat_page、sessions_page、/agent/new、/agent/session/:id） | 低 |
| 24 | Agent 技能/附件/媒体卡片 | 有 | 有 | 未确认 | 有 | 未确认 | 中 |
| 25 | Handoff 接力 | 未确认 | 未确认 | 有 | 有 | 薄（仅 agent models 提及） | 中 |
| 26 | 活动/任务中心/下载任务 | 有 | 有 | 未确认 | 有 | 薄（activity_page 有下载任务；任务中心视角未确认） | 中 |
| 27 | Reels 短视频流 | 有 | 有 | 有 | 有 | 有（reels_page） | 低 |
| 28 | 离线下载/本地文件/存储 | 有 | 有 | 有 | 有（下载器概念） | 有（offline_page、download_channel） | 低 |
| 29 | 订阅首页/详情/订阅墙 | 有 | 有 | 有 | 有 | 有（subscriptions 16 文件 + wall 路由） | 低 |
| 30 | 规则集编辑器 | 有 | 有 | 未确认 | 有 | 薄（规则集在订阅 state/pages 提及，编辑器页未确认） | 中 |
| 31 | 智能计划 SmartPlan | 未确认 | 有 | 未确认 | 有 | 薄（仅 subscriptions/README 提及） | 中 |
| 32 | 分享页/分享链接 | 有 | 有 | 有 | 有 | 有（share_page、/share/:slug） | 低 |
| 33 | 分享直链播放 s/[slug]/play | 未确认 | 未确认 | 未确认 | 有 | 未确认 | 高 |
| 34 | 通知中心 | 有 | 有 | 有 | 有 | 有（notices_page） | 低 |
| 35 | 推送（App Push / IM Push / 云推送） | 有 | 有 | 有 | 有 | 薄（core/notify 仅 1 文件；推送设置无） | 高 |
| 36 | 账号/设备管理 | 有 | 有 | 有 | 有 | 有（account_page、devices_page） | 低 |
| 37 | 应用更新 | 有 | 有 | 未确认 | 有 | 有（update_page） | 低 |
| 38 | 更多/我的页 | 有 | 有 | 有 | 有 | 有（more_page：会话/下载/服务器三段） | 低 |
| 39 | 插件应用页 apps/[plugin]（iframe 承载插件网页） | 无（未见对应页面，grep 仅命中 API 生成文件） | 无（同左） | 无（同左） | 有 | 无 | 高 |
| 40 | 主题 theme-sdk / 主题坑位（my/new 页由主题提供） | 无（未见主题包机制） | 无（同左） | 无（同左） | 有 | 无 | 高（需产品决策，见 §3） |
| 41 | 服务器安装向导 setup / 激活 activate / 健康检查 health | 有（激活 ActivateScreen；向导未确认） | 未确认 | 未确认 | 有 | 无 | 高 |
| 42 | 扩展管理 extension（安装/设置） | 未确认 | 未确认 | 未确认 | 有 | 无 | 高 |
| 43 | 远程转码/转码缓存 | 未确认 | 未确认 | 未确认 | 有 | 薄（仅播放设置副标题提及“转码/预览图/缓存”） | 高 |
| 44 | 定时任务 scheduled-tasks | 未确认 | 未确认 | 未确认 | 有 | 无 | 高 |
| 45 | 系统日志 logs | 未确认 | 有 | 有 | 有 | 无 | 高 |
| 46 | ChatGPT 计划连接 | 未确认 | 未确认 | 未确认 | 有 | 无 | 高 |
| 47 | 云导入 cloud-import | 未确认 | 未确认 | 未确认 | 有 | 无 | 高 |
| 48 | 站内搜索预设 / web 搜索设置 | 有 | 有 | 未确认 | 有 | 无 | 高 |
| 49 | 服务器维护（版本/重启/存储清理） | 有 | 有 | 有 | 有 | 有（maintenance_page） | 低 |
| 50 | 外观 appearance（主题色/深色） | 未确认 | 未确认 | 未确认 | 有 | 无 | 中 |

### 统计（主功能表，共 50 行）

| Flutter 现状 | 行数 |
|---|---|
| 有 | 21 |
| 薄 | 14 |
| 无 | 13 |
| 未确认 | 2 |

## 2. 设置分区 parity（web 的 24 个分区 + 外部访问）

分区来源：`web/lib/mock-data.ts` `settingsSectionGroups`（web `/settings/[section]`）；安卓对照 `feature/settings` 23 个文件；iOS 对照 `Features/Settings`；鸿蒙对照 `ets/settings` 21 个文件。

| 设置分区 | 安卓 | iOS | 鸿蒙 | web | Flutter 现状 | 优先级 |
|---|---|---|---|---|---|---|
| 总览 overview | 有 | 有 | 有 | 有 | 无 | 中 |
| 个人信息 profile | 有 | 有 | 有 | 有 | 有（profile_page） | 低 |
| 我的设备 devices | 有 | 有 | 有 | 有 | 有（devices_page） | 低 |
| 通知与提醒 notifications | 有 | 有 | 有 | 有 | 有（路由 /notices） | 低 |
| 外观 appearance | 未确认 | 未确认 | 未确认 | 有 | 无 | 中 |
| 成员 members | 有 | 有 | 有 | 有 | 无 | 高 |
| 订阅 subscription | 有 | 有 | 未确认 | 有 | 薄（订阅功能有，设置分区入口无） | 高 |
| 站点 sites | 有 | 未确认 | 未确认 | 有 | 无 | 高 |
| 下载器 downloaders | 有 | 未确认 | 未确认 | 有 | 无 | 高 |
| 导入监听 import-watch | 有 | 未确认 | 未确认 | 有 | 无 | 高 |
| 刮削 scrape | 有 | 有 | 有 | 有 | 无 | 高 |
| 播放 playback | 有 | 有 | 有 | 有 | 有（playback_page） | 低 |
| 网盘 drives | 未确认 | 未确认 | 未确认 | 有 | 无 | 高 |
| 应用推送 app-push | 有 | 有 | 有 | 有 | 无 | 高 |
| IM 推送 im-push | 未确认 | 未确认 | 未确认 | 有 | 无 | 高 |
| Webhook | 有 | 有 | 有 | 有 | 无 | 高 |
| LLM | 有 | 有 | 有 | 有 | 无 | 高 |
| MCP | 有 | 有 | 有 | 有 | 无 | 高 |
| AI 默认 ai | 有 | 有 | 未确认 | 有 | 无 | 高 |
| 云 cloud | 有 | 有（CloudPush） | 未确认 | 有 | 无 | 高 |
| 应用 app（含维护） | 有 | 有 | 有 | 有 | 薄（maintenance_page 覆盖版本/重启/清理） | 中 |
| 插件 plugins | 未确认 | 未确认 | 未确认 | 有 | 无 | 高 |
| 网络 network | 未确认 | 有 | 有 | 有 | 无 | 高 |
| 系统日志 logs | 未确认 | 有 | 有 | 有 | 无 | 高 |
| 外部访问 external-access | 有 | 未确认 | 有 | 有（组件存在，分区归属未确认） | 无 | 高 |

### 统计（设置表，共 25 行）

| Flutter 现状 | 行数 |
|---|---|
| 有 | 4（profile、devices、notifications、playback） |
| 薄 | 2（subscription、app/维护） |
| 无 | 19 |

### 关键证据：Flutter 设置现状

`lib/features/settings/pages/settings_page.dart` 的设置索引只有 7 个入口：个人信息、我的设备、通知与提醒、播放设置、**网页托管**、服务器维护、检查更新。其余管理功能走 `lib/features/settings/pages/web_managed_page.dart`，原文：

> “这一组设置由服务器网页端托管，客户端内不提供编辑。”——点击后用 `url_launcher` 在浏览器中打开服务器管理页。

这就是“替代 web”要消灭的核心缺口：**目前 Flutter 把 19 个设置分区外包给了浏览器**。安卓同样有 `*_WEB` 分区走 WebManagedSectionScreen，但安卓原生覆盖了其中大部分（见上表），Flutter 没有。

## 3. 目前只有 web 端有、app 里没有的功能（高优先级清单）

同时满足：web 有；安卓/iOS/鸿蒙均无或未确认；Flutter 无/薄/未确认。按“用户不用打开浏览器” 的阻塞程度排序：

1. **插件应用页 `apps/[plugin]`**——web 用 iframe 承载插件网页；三端原生均未见对应页面；Flutter 无。替代 web 必须回答：插件页在 app 内是 WebView 承载还是原生重写。
2. **服务器安装向导 `/setup`、激活 `/activate`、健康检查 `/health`**——Flutter 无（仅有登录/扫码配对）；安卓只有激活页。首次部署、换服、配对流程缺了它就得开浏览器。
3. **扩展管理**（`extension-settings`、`extension-install`）——Flutter 无；原生端未确认。
4. **远程转码 / 转码缓存 / 预览图开关**——Flutter 仅在播放设置副标题提及；无独立配置页。
5. **定时任务**（`scheduled-tasks-section`）——Flutter 无；原生端未确认。
6. **ChatGPT 计划连接**（`chatgpt-plan-connect`）——Flutter 无；原生端未确认。
7. **云导入**（`cloud-import-report`）——Flutter 无；原生端未确认。
8. **分享直链播放 `s/[slug]/play`**——Flutter 有 `/share/:slug` 路由，直达播放未确认。
9. **外部播放器**——Flutter 无；原生端未确认。
10. **主题 theme-sdk / 主题坑位**——web 的 `my`/`new` 页内容由主题提供；三端原生与 Flutter 均无主题包机制。**需产品决策**：主题是 web 表现层，不一定 1:1 移植到 app；若不移植，应明确 app 用固定主题 + 覆盖主题坑位提供的功能入口，而不是留空白。
11. **设置分区 19 项缺失**（见 §2）：站点、下载器、导入监听、刮削、网盘、成员、订阅设置、LLM、MCP、AI 默认、Webhook、云、插件、网络、日志、应用推送、IM 推送、外观、总览——这些在 web 都有，Flutter 全部走“网页托管”外链浏览器，是替代 web 的最大缺口。

## 4. 播放器后端对照（P1 范围，本清单只记录现状）

| 平台 | 原生后端 | 证据 |
|---|---|---|
| iOS / macOS | AVPlayer | `apple/Shared/Player/AVPlayerEngine.swift` |
| 安卓 | Media3 / ExoPlayer（待 P1 核实具体引擎类） | `android-core/playback` 内含 ExoPlayer/Media3 引用 |
| 鸿蒙 | 待调研 | `harmonyos/player_engine` + `harmonyos/playback` 模块存在，实现未核实 |
| web | HTML5 `<video>` | `web/components/player/video-player.tsx` 使用 `<video>` 元素 |
| Flutter 现状 | `video_player` 插件（iOS=AVPlayer、安卓=ExoPlayer、web=HTML5 video）；统一 Dart 接口尚未建立 | `pubspec.yaml`；注意其注释“AV Player 底层引擎（Android=ExoPlayer）”表述不准确，AVPlayer 只在 Apple 平台可用 |

## 5. 构建产物入仓

- `git ls-files` 检查（副本，HEAD 99f8ec2，332 个已跟踪文件）：仅 1 个构建产物已入仓——`android/build/reports/problems/problems-report.html`。
- 原因：原 `.gitignore` 只有根级 `/build/`，覆盖不到 `android/build/`。
- 处理：已在 `.gitignore` 补 `android/build/` 与 `**/build/`（见 P0.md）。**该文件仍处于已跟踪状态**，仅加规则不会让它脱离版本控制，需后续单独执行 `git rm --cached android/build/reports/problems/problems-report.html` 并提交；本次按任务要求未删任何文件、未动用户源码。
- 其余已跟踪文件无构建产物（`.metadata`、`android/.gitignore` 属正常入仓文件）。

## 6. 未确认项（本次未查到，不编造）

- 豆瓣详情、发现榜单、种子搜索在 iOS/鸿蒙的有无；媒体库管理、图片灯箱在安卓/鸿蒙的有无；外部播放器、远程转码、定时任务在三端原生的有无。
- Agent 技能/附件/媒体卡片在 Flutter 的有无；分享直链播放 `s/[slug]/play` 在 Flutter 的落地情况。
- 安卓播放器具体引擎类（Media3/ExoPlayer 的接线方式）；鸿蒙播放器实现细节。
- 主题是否纳入 app（需产品决策，见 §3 第 10 条）。
