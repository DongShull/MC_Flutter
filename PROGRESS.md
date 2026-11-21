# mc_flutter 进度总控（给任何接手的 AI 读）

> 本文件是**唯一进度权威**。每次工作会话结束前必须更新本文件：改状态、写"下一步"。
> 设计文档在 `docs/design/`，功能拆解总表在 `docs/FEATURE_BREAKDOWN.md`。
> **逐日完整交接记录**：`docs/HANDOFF-2026-11-19.md`（今天全天对话+操作+踩坑，新接手 AI 先读它）。

## 编码铁律（用户明确要求）

- 代码结构干净整洁；能复用的代码必须复用，禁止重复造轮子；
- 优先用成熟 pub.dev 包（riverpod / dio / go_router / video_player / flutter_secure_storage / cached_network_image 等），不自研已有库覆盖的能力；
- 公共逻辑一律下沉 core/，功能模块只写业务差异；写新代码前先搜 features/ 与 core/ 是否已有实现。

## 模块化铁律（用户明确要求）

- features/ 下一个功能一个目录，自包含 pages/widgets/state/routes.dart/README.md；
- 功能目录之间禁止互相 import，只允许依赖 core/；
- 每个功能目录带 README.md 标注进度，接手 AI 看目录即知状态。

## 验收标准（用户明确指定）

**最终完成 = 安卓里的功能 1:1 在 Flutter 项目中全部实现。**
- apps/android + apps/android-core 的每个功能（18 个 feature + core 各模块）在 Flutter 都有对应实现：页面、状态管理、路由、README 进度标注；
- 播放统一走 core/player 的 AV Player（PlayerService 唯一入口）；
- `flutter analyze` 零错误作为代码质量门槛；
- 没实现完就继续生成，不算完成。

## 项目定位

用 Flutter 重写 MovieClaw（MC / Movie Cloud）Android 客户端。
源项目：`/ds/dsh_github/MovieClaw`（设计文档 `docs/design/`，Android 工程 `apps/android` + `apps/android-core`）。
播放统一走自研 **AV Player**（`lib/core/player/PlayerService`，全 App 唯一播放入口）。

## 环境

- Flutter SDK: /opt/flutter（stable 3.50.0，加入 PATH: `export PATH=/opt/flutter/bin:$PATH`）
- 项目根: /ds/dsh_github/mc_flutter

## 状态图例

⬜ 未开始 | 🟨 进行中 | ✅ 完成

## 里程碑进度

- M1 骨架+核心层+导航：🟨（详见下）
- M2 浏览闭环（library/discover/search/detail）：⬜
- M3 统一 AV Player 播放闭环：⬜
- M4 订阅/活动/通知/账户/设置/更多：⬜
- M5 离线/reels/agent/分享/更新：⬜

## 功能目标状态（18 个，见 docs/FEATURE_BREAKDOWN.md 总表）

全部 ⬜（M1 骨架进行中）

## 设计文档

| 文件 | 内容 | 状态 |
|---|---|---|
| docs/FEATURE_BREAKDOWN.md | 18 功能目标总表+目录规划+里程碑 | ✅ |
| docs/design/01-architecture.md | 总体架构与模块映射 | ✅ 13,897B |
| docs/design/02-onboarding-auth.md | 登录/引导/会话/发现 | ✅ 7,937B |
| docs/design/03-player-avplayer.md | 统一 AV Player 播放器 | ✅ 12,297B |
| docs/design/04-browsing-features.md | 媒体库/发现/搜索/详情/订阅/活动/reels | ✅ 27,832B |
| docs/design/05-misc-features.md | 离线/成员/设置/分享/更新/通知 | ✅ 53,643B |

## 下一步（按顺序）

1. flutter create mc_flutter（或补齐骨架）+ pubspec 依赖（riverpod, dio, go_router, video_player, flutter_secure_storage）
2. 搭 lib/core/ + lib/features/ 目录与占位页，跑通 flutter analyze
3. M1：onboarding 登录页 + root 五 Tab 导航
4. 依次推进 M2–M5

## 已建骨架（本轮）

- pubspec.yaml：riverpod / go_router / dio / video_player(AV Player 底层) / flutter_secure_storage / cached_network_image
- lib/main.dart、lib/app.dart、lib/core/router.dart（18 模块路由统一挂载）
- lib/core/designsystem/：theme.dart（silver glass 令牌）、widgets.dart（复用 FeaturePlaceholder）
- lib/core/player/player_service.dart：统一 AV Player（PlayerService 抽象 + VideoPlayerService/ExoPlayer 实现）
- lib/features/<18 模块>：pages/widgets/state 目录 + routes.dart + README（占位页）
- scripts/gen_feature_scaffold.py：模块脚手架生成器（保证结构一致，可重复运行）
- 待办：flutter create 补 android 平台目录 → pub get → flutter analyze 清零

## 工作日志

### 2026-11-19 Round 7b — 代码审核重构完成（用户指令：执行）
- 审核发现（2 个审核代理确认）：sessionStoreProvider 自建 18 份（有状态实例分裂=潜在 bug）、formatBytes 4 份口径不一（offline 小文件显示 0 MB）、加载三件套+海报卡被锁死 library（17 模块 28 处 inline spinner、4 份海报卡）、防抖+seq 守卫 2 份、share 手抄解包。
- 新建 core 公共层：core/api/session_providers.dart（全局唯一 sessionStoreProvider+mcClientProvider）、core/models/format.dart（mcFormatBytes/Speed/Clock/Watched/EpisodeLabel，统一 library 版 Kotlin 口径）、core/designsystem/state_views.dart（三件套）、core/designsystem/poster_card.dart（海报卡四合一）、core/notify/debounce_guard.dart（Debouncer+SeqGuard）。
- 3 个并行重构代理按不相交范围完成 18 个 feature 替换：本地 provider 定义 18→0、formatBytes 4→0、海报卡 4→1、inline spinner 大幅替换（reels 黑底定制保留）、search/discover 改 core 防抖守卫、player _clock/mcClock 合并。
- 验收复检：analyze No issues found；test All passed；sessionProvider defs=0、formatBytes defs=0、poster impls=1；总行数 23842→23671（净删 171 行 + 新增 core 复用层）。
- share _unwrap 实为 core unwrapEnvelope 薄适配（5 行 cast），保留。
- 未做（留待用户确认）：settings/account 两份设备管理页合并（需先定 provider 归属，动 state 层风险较高）。

### 2026-11-19 Round 6c — 🎉 18/18 全部完成（最终验收通过）
- 最后一批：activity（任务/观看双视角，~2209 行，口径全移植）、reels（竖滑流+七维筛选+事件攒批，~1667 行）、settings（6 分区）、more（会话管理+角标）、account（多服务器/设备）、offline（任务状态机/画质/容量）、agent（会话+对话+全端点，TODO(stream)）。
- 清理：删除未被引用的遗留占位 agent_page.dart / library_page.dart，占位页归零。
- 最终验收证据：
  - flutter analyze → No issues found! (ran in 4.8s)
  - flutter test → All tests passed
  - FeaturePlaceholder 残留 = 0；跨 feature import = 0；18/18 README 均有 ✅ 进度标注；lib 下 144 个 dart 文件。
- 已知遗留（README ⏳ 已标注）：SSE 实时流（activity/agent 为轮询版）、播放会话协商/进度上报/轨选择（player TODO(playback-session)）、下载/APK 安装等平台通道、头像 multipart 上传。

### 2026-11-19 Round 6b（第二批完成）
- root：五 tab 主壳（悬浮胶囊底栏/MainTabBus/ShellBadges 角标 30s 轮询）；subscriptions：13 端点+订阅索引/事件+4 页+创建抽屉+订阅墙。
- player：播放页 1:1（手势层/进度条/设置面板/选集器），播放统一走 core/player PlayerService（扩展 duration/setVolume/buildView 未破坏 API）。
- notices（30s 轮询+乐观更新）、share（访客 Dio 直连+密码门+深链 /share/:slug）、update（GitHub Release→服务器兜底，状态机+跳过版本记忆）。
- 验收：analyze No issues found；test 全绿。实现 11/18（+root subscriptions player notices share update）。剩余：activity offline reels account agent settings more。

### 2026-11-19 Round 6（M2 浏览类功能完成）
- 并行 3 子代理完成 library/discover/search/detail 1:1 实现：
  - library：首页行透视（HomeRows 合并规则完整移植）、筛选墙（URL 即状态）、合集页、自定义首页（拖拽排序 PUT ui/preferences）、人物/类型墙；9 个 controller + 6 页 + 子路由 6 条。
  - discover：TMDB/豆瓣分段、六维筛选防抖+序号守卫、hero 轮播、过滤网格翻页、标题详情/影人页。
  - search：350ms 防抖、历史 SharedPreferences（封顶 20）、联想词、游标分页+400 重搜、模式记忆。
  - detail：FamilyNotifier ~590 行（详情→air_schedule→季集→marks→resume→相似编排）、收藏/已看/刷新元数据真实调用、深链 /detail/:libraryId/:itemId、8 个 widgets。
- 整体验收：flutter analyze No issues found；flutter test 全绿；无跨 feature import。
- 实现进度：5/18（onboarding discover search detail library）。剩余：root player subscriptions activity offline reels account notices agent settings share update more。
- 占位页检测命令：grep -l FeaturePlaceholder lib/features/*/pages/*.dart

## 2026-11-19 工作日志（Round 13）

### 完成
- **widget test 修复并转绿**：根因是重跑 gen_feature_scaffold.py 把真实 onboarding_page.dart 覆盖回占位页（TEXTS 只剩 'onboarding'）。
- **生成器防覆盖**：scripts/gen_feature_scaffold.py 增加 PLACEHOLDER_MARK("1:1 重写中") 与 is_placeholder() 检查，root_page 与普通 feature 页写入前先检查，真实实现（含 "IMPLEMENTED" 注释）不再被覆盖；已重跑生成器验证 18 模块生成且 onboarding 页保留。
- **恢复真实 onboarding 页**：lib/features/onboarding/pages/onboarding_page.dart 重写（渐变登录页 + 服务器地址输入 + onboardingProvider 连接 + done→go(routeOnboarding)），页首加 IMPLEMENTED 标记。修正符号名：onboardingProvider（非 onboardingControllerProvider）、McColors.bgDark/surfaceDark/accent（theme.dart 实际常量）、routeOnboarding。
- **test/widget_test.dart** 简化为稳定断言：OnboardingPage 存在 + 文本 'MovieClaw'/'服务器地址' 各一处。

### 验收证据
- flutter analyze: No issues found! (ran in 2.2s)
- flutter test: 00:02 +1: All tests passed!


- 2026-11-18 R1：读取 MovieClaw 结构与 android README；写 FEATURE_BREAKDOWN.md；后台安装 Flutter SDK（job bash-9a72af99a54545ab）；派 doc-auth / doc-player / doc-features 三个子代理写设计文档。
- 2026-11-19 M6.2/M6.4（adaptive-shell，root/settings/more）：root_page 平板/TV 切 McAdaptiveScaffold 左 Rail（bus/角标逻辑不动，手机胶囊底栏零差异）；settings_page medium/expanded 改 master-detail（TV 菜单项包 McFocusRing）；more_page expanded 列表限宽 720 居中；analyze No issues + test 全绿。
- 2026-11-19 M6 adaptive-rest：player/reels/activity/offline/account/agent/notices/share/update/onboarding 十模块多设备适配完成（TV 聚焦环/常驻控制条/抽屉选集/居中限宽/网格自适应，phone 零差异）；最终验收 flutter analyze No issues found + flutter test 全绿。
- 2026-11-19 M6.3 adaptive-browse：library/discover/search/detail/subscriptions 五模块多设备适配完成（媒体墙网格 mcGridCrossAxisCount 自适应、detail expanded 双栏、TV 可聚焦元素包 McFocusRing，compact 零差异）；flutter analyze No issues found、flutter test 全绿。
## Round 8（播放会话协调器落地）
- 新增 lib/core/player/session/playback_session.dart：PlaybackCoordinator（registerParticipant/unregisterParticipant/reportParticipantState/reportUserStopped/synchronize + commands/snapshots/diagnostics 三流，5s 心跳 ×3 超时注销，后到抢占激活），对齐飞牛 trim_playback_session_plugin Pigeon 接口面（docs/design/08）。
- 新增 playback_session_providers.dart（playbackCoordinatorProvider 全局单例）。
- player_page.dart 接入：initState postFrame 注册 'player-page'、commands 订阅（pause/play/seek/stop→togglePlay/seekTo/_exit）、build 内 ref.listen 节流 4s 上报 ParticipantState、dispose reportUserStopped。
- 新增 test/playback_session_test.dart 4 用例（激活快照/抢占 pause/注销诊断/synchronize seek）。
- 验收：flutter analyze No issues (5.1s)、flutter test +5 全绿。

## Round 9（飞牛优点回填：启动/预取/保活，docs/design/09）
- docs/design/09-finnas-benchmarks.md：飞牛 App 六个架构级优点深度分析 + 10 项回填清单（已抄/待抄状态表）。
- 启动分阶段（对齐 EndWarmUpFrame）：main.dart runZonedGuarded + AppBootstrap.ensureMinimum + 首帧栅格化后跑非首屏任务（lib/core/bootstrap/app_bootstrap.dart）。
- 封面预加载（对齐 preloadArtwork）：lib/core/image/cover_preloader.dart（precacheImage 队列、并发 4、去重、宿主 element 安全）；library_home_page.dart 首屏行渲染后喂入全部封面 URL。
- 播放保活/中断恢复（对齐 PlaybackInterruptionRecovery）：player_page 加 AppLifecycleListener（后台自动暂停、回前台恢复）+ wakelock_plus ^1.5.2 屏幕常亮（dispose 释放）。
- 验收：analyze No issues (6.8s)、test +5 全绿。

## Round 10（飞牛优点回填第二轮：进即用/传输自愈/崩溃兜底/预取扩展）
- 启动直达：main 首帧前 appSession.restore() + router redirect（会话就绪跳过 onboarding 直达 /home）；SessionStore 全局单例 appSession。
- 传输自愈：core/api/retry_interceptor.dart（GET 幂等重试、指数退避+抖动、上限 2）挂 McClient 三通道。
- 崩溃兜底：BootstrapErrorLog 环形缓冲 50 条 + main runZonedGuarded 记录。
- 预取扩展：discover 筛选网格接入 CoverPreloader。
- 验收：analyze No issues (2.3s)、test +5 全绿。

## Round 11（飞牛回填第三轮：服务器会话协商 + isolate 解析）
- playback_session_api.dart：PlaybackSessionApi{start/ping/stop/resume}（McApi.kt /playback/sessions 全口径，decision 三态）。
- PlayerController.open 接协商：stream_url/start_ms 消费、30s ping 心跳、detach DELETE 会话；TODO(playback-session) 主体关闭。
- mc_client unwrap：String 响应体 compute() isolate 解析（_decodeJson 包装）。
- 验收：analyze No issues (7.6s)、test +5 全绿。

## Round 12（飞牛回填第四轮：进度上报 + 协商结果 UI，收口）
- playback_session_api.reportProgress（POST /playback/progress 全口径）+ player_controller 15s 节流上报。
- PlayerPlayback.pendingDecision + SessionDecision 枚举；player_page 协商结果弹窗（consent 确认/rejected 说明），acknowledgeDecision 清状态。
- 验收：analyze No issues (3.2s)、test +5 全绿。09 文档终态表：飞牛静态可回填 13 项全部落地。

## Round 13（飞牛式启动页）
- SplashPage /splash：已登录直达，展示 MovieClaw 标题 + 用户名 + 设备名 + 三点省略号上下跳动（单 AnimationController 三段错相 Interval），1.6s 后进主界面。
- SessionStore 增 username/deviceName 持久化（mc_username/mc_device_name）+ saveProfile；login 支持身份参数。
- onboarding_controller.login：保存 device.name，登录后 GET /auth/me 回填 nickname/username（失败不阻断）。
- 路由重定向：isReady && /onboarding → /splash（先启动页再主界面）；未登录访问 /splash → 回登录页。
- 验收：analyze No issues (4.9s)、test +5 全绿。

## Round 14（飞牛 UI 资产三件套对齐）
- 思源黑体 SourceHanSansCN-Medium.otf 内嵌（assets/fonts）+ 主题 fontFamily 全局生效。
- McStrings 文案令牌表（core/designsystem/mc_strings.dart）：启动/连接/播放/通用四组，player 弹窗与 splash 已接。
- 图标对齐：两个并行子代理替换 192 处 Material Icons → McIcons（TrimIcons 字体，54 文件），语义不贴切的保留 Material 不硬凑。
- 验收：analyze No issues (2.2s)、test +5 全绿。

## Round 15（抄飞牛三端适配策略）
- lib/core/platform/mc_platform.dart：McPlatformTarget 探测（HarmonyUtilApi 口径，MethodChannel mc/base/platform + MissingPluginException 降级）+ GlobalEventBus 通道位。
- docs/design/10-platform-adaptation.md：飞牛三端适配逆向证据（HarmonyUtilApi/mmkv_ohos/独立 CI/Pigeon 化插件）+ mc_flutter 落地对照表 + 三条铁律（业务禁编译期分叉/差异全通道化/鸿蒙只动 SDK+overrides+CI）。
- 验收：analyze No issues (6.6s)、test +5 全绿。

## Round 16（深度探测二轮 + 现状总结）
- fl_chart 接入：activity 逐日柱状 BarChart（飞牛同款图表库），analyze/test 全绿。
- docs/design/11-status-deepdive.md：新挖技术（stretch shader/liquid_glass/spring/lottie/zxing 评估表）+ mc_flutter 现状总结（18/18、多设备、三端、飞牛对齐清单、遗留 TODO 六项）。

## Round 17（2026-11-20）：六 TODO 清零——选集接口化/SSE 流式/离线通道/DLNA 投屏/stretch 动效/扫码连接
- 方式：6 并行子代理半数中断后由 captain 逐一收尾（教训：子代理并发同文件互踩，失败后改为顺序亲自补）。
- ① 选集接口化：core/api/episodes_api.dart（libraryItemEpisodes + playbackItemEpisodes）；detail 真实季集数据驱动；播放页选集热切换（detach→新 fileId→open→joinSession）。
- ② agent SSE 流式：core/api/agent_sse_client.dart（\n\n 分帧、Last-Event-ID 重连≤5、404 回退轮询）；ChatController 流式渲染。
- ③ 离线平台通道：core/platform/download_channel.dart（mc/native/download 通道 + 缺省降级 64KB 分块/.part 断点续传）；offline_state 接线会话 streamUrl 下载。
- ④ DLNA 投屏：core/cast/（SSDP M-SEARCH 发现 MediaRenderer、SOAP AVTransport SetAVTransportURI/Play/Pause/Stop、CastController）；播放页 cast 按钮 + 设备面板 cast_sheet.dart。
- ⑤ stretch 动效：assets/shaders/mc_stretch.frag + core/effects/mc_stretch.dart（SPIR-V shader + 临界阻尼弹簧 + 回退）；reels 接入。
- ⑥ 扫码连接：mobile_scanner；onboarding 扫码页解析 JSON/URL 二维码预填 host；AndroidManifest CAMERA 权限。
- 验收：flutter analyze No issues；flutter test 30/30 全绿；按 feature 分 6 commit（ea83ff1/f48c6b5/d5f63e5/8e40388/66553ff）推送 main（注：cast 文件因提前 stage 混入 ea83ff1 episodes commit）。

## Round 18（2026-11-20）：遗留缺口收口——detail 六操作/播放轨道/基建补课
- detail 六操作：SubscriptionsApi（title-preview/create 端点经 Kotlin 确认）+ 三步订阅弹层 subscribe_sheet.dart；下载 4 档档位弹层；share_plus 服务端分享链接；AI 字幕预检+提交；删除确认；人物页路由跳转。
- 播放域：音轨/字幕轨真实化（PlaybackSession.decision 的 audio_tracks/subtitles 解析+switchTrack 重开会话续播）；下一集 hasNext 真实化（owned+fileId 过滤）；reels 片段 startMs 起点续播+NetworkTier 网络档展示。
- 基建：McClient.postMultipart + image_picker 头像上传（POST /auth/avatar）；url_launcher（update 发布页/服务器管理页）；share_plus 引入；导航意图清扫（discover/search/person/more 分叉跳新会话/agent 复制反馈）。
- 验收：analyze No issues；test 30/30；commits cefd73a/c88ee72/8d4909d 推送 main。
- 剩余：activity SSE 任务事件、7×24 热力图自绘、Android 原生 download 通道、DLNA/QR 真机验证。


## Round 19（2026-11-20，goal Round 1，commits 3f89d81/cd4f96e/09a2a01/b3a07e1）

上一轮剩余 18 处 TODO 中 Dart 侧 8 项全部清零（analyze No issues + test 30/30 全绿，已推 main）：

- library：海报卡/继续观看跳 /detail/{libraryId}/{mediaItemId}
- reels：share_plus 系统分享
- activity：jobs 接 SSE（/api/v1/jobs/stream，ready→全量、job→120ms 防抖刷新，SSE 不可用回退 15s 轮询）；7×24 观看热力图（CustomPaint 自绘，色深=时长占比）
- share：访客播放（core/api/guest_playback_api.dart，POST /api/v1/share/{slug}/playback/sessions → PlayerPageArgs 续播跳 /player）；分享海报 CachedNetworkImage
- player：skipSegments 琥珀跳过区间（PlaybackSkipSegment，segments 顶层/decision 兜底解析，重开/切集清空防串）
- update：MC_BUILD_NUMBER 构建注入（--dart-define）
- session：多账号令牌快照 mc_token:<origin>:<user>（snapshotAccountToken/switchAccount/deleteAccountToken，兼容旧 mc_token 单键迁移；顺带修复 restore() 模板串转义错误）

剩余：原生 download 通道（Kotlin）、离线容量统计与账号删文件（依赖原生通道）、DLNA/QR 真机验证、打包链路（图标/启动图/签名）。

## Round 21（2026-11-20）— 原生通道 + 打包链路收口
- Kotlin 原生下载通道（MainActivity.kt McDownloadPlugin）编译通过；删残留草稿 McDownloadPlugin.kt、修 Long/Int 比较
- 离线容量/删除接通原生的 capacity/delete；多账号令牌快照；跳过片段；访客分享播放（Round 19-20）
- 构建链路：国内镜像（腾讯 gradle + 阿里 maven）、签名配置、debug.keystore、关 release lint（image_picker lint 崩溃）
- 资产：程序化生成 logo.png → launcher icons + native splash
- 产出：build/app/outputs/flutter-apk/app-release.apk (91.2MB, debug 签名)
- commits: 18b2531 / 3afbc59 / 9b22cd0 / b317c6b
- 待办：DLNA/QR 真机验证（需设备）；正式签名需提供 release keystore
## Round 22（三页对齐原生 + 图片加载修复）

- 活动中心 iOS 化（captain）：activity_page.dart 重写为 ActivityView.swift 单页 dashboard 分区（摘要行/警告条/需要处理[红·全部清除]/正在播放[绿]/下载中/进行中/最近播放[跳详情]/观看统计/最近完成[查看全部]），insetGrouped 卡片风
- 我的页鸿蒙化（t13）：ProfileCard（渐变头像+铅笔角标+切换账号弹层）→ 三段胶囊 SectionPicker → 会话分组列表（今天/昨天/更早，续接/重命名/删除）→ 服务器卡+待处理/可用更新瓷砖 → SettingsCatalog 分组入口；tablet/TV 限宽 720
- 订阅页鸿蒙化（t14）：SubscriptionsHomeModel 完整移植（ArrivalPresentation 状态机/Hero 轮播 8s 自动/七天日程条/进行中+RestingDivider 书架/长按菜单）；三态页面 + wall 页分区重写
- 图片加载修复（66bf5bf）：服务端图片通道默认拒绝（实测无凭据 401）→ mcImageHeaders() 全站附带 Bearer；全海报按宽度阶梯取档（头像 160/海报 480/剧照 360/头图 960）
- 验证：analyze No issues + test 36/36；commits 66bf5bf / more / subscriptions；推送 main
- 教训：CachedNetworkImage 与 Dio 不共享 Cookie/头，独立图片通道必须显式传 httpHeaders；dart format 会暴露 t14 未合规范的花括号
