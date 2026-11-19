# MovieClaw Flutter 总体架构设计

> 状态：设计稿。对应原 Android 原生版（Kotlin + Compose，见 `MovieClaw/docs/design/android-app.md` 与 `MovieClaw/apps/android/README.md`）。
> 目标：用 Flutter 重写手机端全部功能，验收口径不变——同一台服务器上，手机端网页、iOS App 与本 App 的功能与观感一致。
> 状态管理用 **Riverpod**，路由用 **go_router**，接口层对齐服务端 `/api/v1` 信封协议。

## 1. 技术选型

| 事项 | 结论 | 理由 |
|---|---|---|
| 框架 | Flutter（stable，Dart 3），最低 Android 8.0 / iOS 15 | 单代码库双端；自绘引擎不受 SurfaceView「拿不到帧」限制，播放页玻璃可用 BackdropFilter 真模糊（性能不达标再退回「黑底等价」） |
| 状态管理 | **Riverpod**（riverpod + flutter_riverpod + riverpod_annotation） | 编译期安全、无 BuildContext 依赖、天然支持 session 级全局 Provider 与页面级自动释放 |
| 路由 | **go_router** | 声明式路由 + 深链（`movieclaw://share/<slug>`）+ redirect 钩子接 session 状态机 |
| 网络 | **dio**（通用通道）+ **web_socket_channel / flutter_client_ssh 不用**——SSE 用 **dio 流式响应**或 `http` 包逐行读 | 对齐 Android 三通道设计；SSE 需要 Last-Event-ID 续传与指数退避，见 §4.3 |
| 播放 | **media_kit**（libmpv，FFmpeg 全解）为主内核，**video_player（ExoPlayer/AVPlayer）**为直连快路径 | 对齐 Android「默认省电内核 + 万能内核兜底」的双内核策略；media_kit 本机放不了的轨交服务端转码流 |
| 凭证存储 | **flutter_secure_storage**（iOS Keychain ThisDeviceOnly / Android EncryptedSharedPreferences） | 对齐 Android Keystore 与 iOS 钥匙串方案 |
| 序列化 | 手写模型 + `json_serializable`（可选）；字段**可空 + 有默认值**，JSON 解码 `SnakeCase` + `ignoreUnknownKeys` 语义 | 老服务端缺字段不能让解码失败（例：字幕轨 `title` 缺失回落语言码） |
| 图片 | **Coil 式缓存用 cached_network_image**，请求带鉴权头（自定义 HttpClient） | 对齐「带鉴权头的图片加载器」；缓存键按登录地址 |
| 依赖铁律 | 优先 pub.dev 成熟包，不自造；公共逻辑一律下沉 `core/` | 见 §5 |

## 2. 目录总览

```
lib/
  main.dart                 入口：初始化 secure storage、加载 session 快照、 runApp(ProviderScope)
  app.dart                  MaterialApp.router（go_router）+ 全局主题 + FeedbackBus 挂载
  core/
    models/                 服务端契约数据模型（全局 snake_case 映射，可空宽容解码）
    api/                    三通道 ApiClient + 信封解包 + ApiException + 中文错误映射 + UA
    session/                连接/登录状态机、TokenVault（secure storage）、多服务器多账号快照、
                            冷启动快开、地址簿与竞速（ServerRoute）
    discovery/              局域网发现（UDP 7359 + /24 扫描）
    player/                 播放引擎控制层：协商、心跳、上报、兜底阶梯、轨管理、字幕外观
    offline/                离线下载队列、续传、存储管理
    notify/                 通知中心（轮询）、本地通知、推送注册
    designsystem/           主题令牌（McType/McMetrics/McColor）、玻璃材质组件、格式化器 McFormat、
                            FeedbackBus + 顶部玻璃 Toast
  features/                 <18 个功能模块>，见 §3
```

## 3. 模块映射表（原 Android → Flutter）

### 3.1 core 层映射

| 原 Android | Flutter 落点 | 说明 |
|---|---|---|
| `core/network`（三通道 OkHttp） | `core/api/` | **三通道**：`GeneralChannel`（页面请求）/ `LiveChannel`（SSE 长连接）/ `PlaybackChannel`（播放专用连接池，不排页面请求后面）。dio 按 origin 缓存实例（对应 `ApiFactory`） |
| `core/api`（McApi Retrofit 端点） | `core/api/endpoints/` | 每个端点一个函数；**不要在页面里拼 URL** |
| `core/model` | `core/models/` | `SkipSegments`、`Playback`、`SubtitleGen` 等含平台专属模型 |
| `core/session`（TokenVault、SessionRepository） | `core/session/` | flutter_secure_storage 替代 Keystore；多服务器多账号快照同构 |
| `core/discovery` | `core/discovery/` | `RawDatagramSocket` 实现 UDP 7359，见 02 文档 |
| `core/playback`（PlaybackSessionHolder） | `core/player/` | 成员（MemberBackend）/ 访客分享（ShareBackend，`/share/{slug}/playback/…`）两套身份 |
| `core/designsystem` | `core/designsystem/` | McTopBar、FlatCard、GlassCapsule、底栏液态玻璃、PosterCard/LandscapeCard/GlassCard/Loadable 骨架屏 |
| `core/notify` | `core/notify/` | 30s 轮询通知中心 + flutter_local_notifications |
| （原 `routing/`） | `core/session/router.dart` + 各模块 `routes.dart` | 状态机 BOOTING → NEEDS_LOGIN / READY 驱动 go_router redirect |

### 3.2 features 层映射（18 个功能模块）

每个模块目录**自包含**：

```
lib/features/<模块>/
  pages/        页面（ConsumerWidget）
  widgets/      本模块专属组件
  state/        Riverpod Provider / Notifier（本模块私有）
  routes.dart   本模块的 GoRoute 列表，由根路由聚合
  README.md     一句话说明本模块职责、依赖的 core 能力、对接的服务端端点
```

| # | 模块 | 原 Android 对应 | 内容 |
|---|---|---|---|
| 1 | `onboarding` | feature/onboarding | 登录页（星空背景 + 自动发现）、创建管理员、配对码批准入口 |
| 2 | `root` | feature/root + routing/AppNav | 五 Tab 主壳、底栏液态玻璃、通知路由总线 |
| 3 | `discover` | feature/discover | 服务端编排板块（`/ui/discovery/{movie|tv}`）、hero 大卡、横滑行、合集浏览页 |
| 4 | `detail` | feature/detail | 标题详情页：沉浸背景、演职员行、相关推荐、已入库识别（library_links → 播放/查看剧集/订阅） |
| 5 | `library` | feature/library | 海报墙分页（60 条/页 offset）、筛选面板（180ms 去抖重算计数）、A–Z 索引条、排序菜单 |
| 6 | `player` | feature/player | 播放页：手势层、控制层 4s 隐藏、画质菜单与记忆（片名×网络 300 条 LRU）、降质建议卡、轨菜单、trickplay 雪碧图 |
| 7 | `reels` | feature/reels | 刷片：当前条 + 预起下一条 + 字节预取 |
| 8 | `search` | feature/search | 三模式：资源（`/search/torrents/stream` 站点流式）、标题（title-preview 进订阅）、库内；搜索历史 |
| 9 | `subscriptions` | feature/subscriptions | 自动化就绪度徽标、today-arrivals、追更列表、订阅流程（预览→选季→创建）、订阅详情 |
| 10 | `activity` | feature/activity | 活动中心：`/jobs` 快照 + SSE `/jobs/stream`（120ms 防抖）、下载 10s 轮询、播放监控 8s 轮询 |
| 11 | `notices` | feature/notices | 通知中心（30s 轮询 + 乐观忽略 + 全部忽略） |
| 12 | `agent` | feature/agent | AI Agent 会话列表/对话页：SSE 11 种事件渲染（thinking_delta 折叠、tool_call 卡片等）、Markdown 轻量解析器、图片附件 multipart 上传 |
| 13 | `share` | feature/share | 访客分享：深链（`movieclaw://share/<slug>` 与 `https://<server>/s/<slug>`）、密码门、访客播放（PlaybackEndpoint 抽象） |
| 14 | `account` | feature/account | 多账号切换（按服务器分组）、个人信息（头像上传/改密）、家庭成员管理（启用停用/权限开关/重置密码） |
| 15 | `devices` | （设置内设备管理） | 登录设备管理：在线状态、改名、注销、管理员「显示所有成员设备」；配对码批准页 |
| 16 | `offline` | （离线下载） | 离线下载任务列表、续传（Range 按当前地址重拼）、存储用量 |
| 17 | `settings` | feature/settings | 设置区：播放设置（三开关乐观更新）、更新与维护（检查更新/一键更新/按目录清理缓存）、网络（代理三态/连通性测试）、日志（ERROR/WARN 着色） |
| 18 | `more` | feature/more | 「我的」页：入口聚合、网页托管分区（总览/订阅/站点/下载器/导入观看） |

> 与原版的差异：原 Android 把设备管理、离线放在设置/别的分区里；Flutter 版按「一个页面域一个模块」拆出 `devices` 与 `offline`，`settings` 只留纯设置项。若实施时想严格对齐原版，把这两个模块并入 `settings` 即为 16 模块，铁律不变。

## 4. 网络与协议约定

### 4.1 信封与容错

- 一切请求过 `core/api`；`/api/v1` 统一信封解包；`ApiException` + `friendlyMessage` 中文错误映射。
- 请求标识 UA：`MovieClaw-Flutter/<版本>`（活动页据此显示客户端）。
- 新增字段一律可空 + 有默认值；未知字段忽略。

### 4.2 三通道

| 通道 | 用途 | 实现 |
|---|---|---|
| GeneralChannel | 页面 CRUD、图片元数据 | dio 实例，按 origin 缓存 |
| LiveChannel | SSE：`/jobs/stream`、`/sessions/{id}/events`、通知 | dio `ResponseType.stream` 逐行解析 + Last-Event-ID 续传 + 指数退避重连 + 终止事件收尾 |
| PlaybackChannel | 协商、progress、心跳、stop、字幕 | 独立 dio 实例（独立连接池），不排队 |

### 4.3 地址选择（ServerRoute，对齐 server-addresses.md）

- 登录地址是服务器在本机的身份，令牌/缓存都按它存，**不迁移**；另记路由表 `ServerRoutes`。
- 候选 = 地址簿（`GET /api/v1/server/addresses`）+ 登录地址；蜂窝网络内网候选不参加。
- 竞速：内网并发 `/health?nonce=`（1.5s 超时），外网晚 250ms（Happy Eyeballs），先通先用，内网后到升级过去。
- 网络指纹 = 网卡类型 + IPv4 网段 + VPN 网段，记最近 8 个；没验过身份的地址不带令牌。
- 三关身份校验：`X-Movieclaw-Spec-Hash` → `instance_id` → `proof`（Ed25519，用 `cryptography` 包验签）。
- 所有 API 请求带 `X-MovieClaw-Route: lan|vpn|wan`；VPN 识别用 `NetworkInterface` 列表（TUN 198.18.0.0/15 排除），不读 Wi-Fi 名。
- Flutter 侧监听：`connectivity_plus` 网络变化事件。

## 5. 模块化铁律

1. **features 目录自包含**：每个 `features/<模块>` 必须含 `pages/`、`widgets/`、`state/`、`routes.dart`、`README.md`。模块的页面、私有组件、私有 Provider 全部在目录内。
2. **功能间禁止互相 import**：`features/a` 不得 import `features/b` 的任何文件。跨功能的跳转只走 go_router 具名路由；跨功能的数据只走 core 层 Provider。
3. **只依赖 core/**：features 只允许 import `core/` 与自身目录。放不进任何单模块的共享组件，说明它属于 `core/designsystem`（或对应 core 域）；「放不下就说明它其实是两个东西」。
4. **路由聚合**：根路由文件只做 `GoRoute` 列表拼接与 redirect，不写页面逻辑；每个模块的路径前缀为 `/<模块>`。
5. **CI 守护**：加一条 lint/脚本检查——扫描 `lib/features/*` 的 import，出现跨模块 import 即失败。

## 6. 复用铁律

1. **优先 pub.dev 成熟包**，不自造轮子。对照表：

| 需求 | 用的包 | 不自造 |
|---|---|---|
| 状态管理 | flutter_riverpod / riverpod_annotation | — |
| 路由与深链 | go_router | — |
| HTTP | dio | — |
| 安全存储 | flutter_secure_storage | 不自写 Keystore/Keychain 绑定 |
| 播放 | media_kit + video_player | 不手写 JNI/原生桥 |
| 图片加载与缓存 | cached_network_image | — |
| 本地通知 | flutter_local_notifications | — |
| 网络状态 | connectivity_plus | — |
| Ed25519 验签 | cryptography | — |
| UDP | dart:io RawDatagramSocket | （标准库即可） |
| PIN/UDP 竞速计时 | dart:io + Stopwatch | — |

2. **公共逻辑下沉 core/**：两个以上模块要用的一段逻辑（格式化器、Toast、信封解包、轨标签解析…）第二次出现时必须搬进 `core/`，不允许复制。
3. **平台通道例外**：确需原生能力（画中画、系统媒体会话）时，优先找有维护的插件（如 `floating`、media_kit 的 MPRIS/NowPlaying 集成）；真要自写 channel，代码放 `core/player/native/` 并在 README 里写明平台范围。
4. **文案一律取上游**（网页 / iOS 现成文案逐字用），不自造；代码注释里标出处。

## 7. 状态管理与路由

### 7.1 Riverpod 分层

- `core/session` 暴露全局 Provider：`sessionStateProvider`（BOOTING/NEEDS_LOGIN/READY）、`currentAccountProvider`、`serverRouteProvider`。
- 每模块 `state/` 内放页面级 Provider；页面退出自动释放（`autoDispose`）。
- SSE 流用 `StreamProvider`；jobs 流在 `activity` 模块内做 120ms 防抖聚合。

### 7.2 go_router

- redirect 钩子读 `sessionStateProvider`：BOOTING 显示启动屏；NEEDS_LOGIN 全部路由重定向 `/onboarding`；READY 放行。
- 深链（分享 `mc_route` 等价物）优先于会话状态处理：先暂存目标路由，登录/就绪后再跳。
- 通知落点：`core/notify` 发路由事件（对应原「通知路由总线」），root 模块监听并跳转。

## 8. 验收方法

1. **对照**：对着同一台服务器，把手机端网页 / iOS 的动线走一遍；视觉以截图对照（发现页 hero、详情页轨道行、播放页控制层、活动页、我的页）。
2. **协议契约测试**：`flutter test` + 用 mock 服务端（`mocktail` + 本地 fixture JSON）验证筛选参数名、信封解包、轨标题回落、身份隔离。
3. **端到端**：真机连 Docker 容器（默认 `http://<NAS_IP>:3000`）；覆盖登录→浏览→播放→离线→多账号切换全链路。
4. **CI**：`flutter analyze` + `flutter test` + 双端 `flutter build`；加跨模块 import 守护脚本。
