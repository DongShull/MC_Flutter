# 03 · 统一 AV Player 设计（Flutter）

> 状态：设计稿。精读 MovieClaw 播放设计文档（player-engine / playback-startup / playback-speed / playback-history-sync / playback-qoe / skip-intro / video-chapters / subtitle-cues / player-display-modes / player-feel / transcode-latency / remote-transcode）后为 Flutter 重写项目制定。
> 原则：**全 App 只留一个播放器**（MovieClaw 移除 MPV 的教训：本机不留第二个播放器）；分层借鉴 iOS 的 PlaybackController / PlayerEngine 思想，不搬自研引擎本身。

## 1. 目标与非目标

**目标**

- 全 App 唯一播放入口 `PlayerService`，功能模块（detail / reels / offline / 继续观看）只经它调用，禁止各自持有引擎实例。
- 引擎封装：`video_player`（Android 底层 ExoPlayer）为主，`media_kit` 兜底；统一接口 + 明确的降级策略。
- 播放会话协议：协商 → 进度上报 → 心跳 → 退出关会话，与服务端（MovieClaw API）同一套契约。
- 字幕/音轨、倍速、跳过片头片尾、章节、进度同步、QOE 上报的实现要点。

**非目标**

- 不自研解复用/解码引擎；不做 iOS AVPlayer 原生通道（Flutter 目标平台为 Android 优先，桌面端走 media_kit）。
- 不实现服务端转码/远程 Worker 的客户端替代——客户端只消费服务端给的流与接口。

## 2. PlayerService：全 App 唯一播放入口

现有抽象 `lib/core/player/player_service.dart`：

```dart
abstract class PlayerService {
  Future<void> open(PlayerRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> close();
  ValueListenable<Duration> get position;
  ValueListenable<bool> get playing;
}
```

### 2.1 归属与规则

- 实例由 `lib/core/player/` 提供（riverpod provider，全局单例）；UI 层只拿 `PlayerService` 与其 `ValueListenable`，**不得 import 任何引擎包**（`video_player` / `media_kit` 只允许出现在 `lib/core/player/` 内，CI 用 grep 守卫）。
- 模块（detail / reels / offline）向服务传 `PlayerRequest`（url、headers、startPosition、媒体元数据），拿回会话句柄；多个页面切换播放时，一律先 `close()` 旧会话再 `open()` 新会话——同一时刻全 App 只有一个活动会话。
- 服务内部职责（对应 iOS PlaybackController）：开会话协议、选引擎、降级阶梯、心跳与进度上报、看门狗（卡顿/断线判定）。

### 2.2 接口演进（保持现有签名，增补可选能力）

`PlayerRequest` 增加：

```dart
class PlayerRequest {
  final String url;
  final Map<String, String> headers;
  final Duration? startPosition;
  // —— 会话协议与功能 ——
  final String? mediaItemId;        // 进度同步 / QOE 归属
  final String? libraryFileId;      // 章节 / 字幕 / 片段查询键
  final PlaybackSession? session;   // PlayerService.openSession() 的产物
  final List<TrackInfo>? audioTracks;
  final List<SubtitleInfo>? subtitles;
  final List<PlaybackSegment>? skipSegments; // 片头/片尾/广告区间
  final List<Chapter>? chapters;
  final double initialSpeed;        // 换集/换引擎重开要带给新引擎
}
```

事件流（引擎状态、首帧、卡顿、降级、结束原因）通过 `ValueListenable<PlayerEvent>` 或回调暴露，UI 不轮询引擎。

## 3. 引擎封装与降级策略

### 3.1 引擎抽象

```dart
abstract class PlayerEngine {
  Future<EngineOpenResult> open(EngineOpenRequest req); // url 可被服务端会话改写（转码流）
  Future<void> play();  Future<void> pause();  Future<void> dispose();
  Future<void> seekTo(Duration p, {SeekAccuracy accuracy}); 
  Future<void> setSpeed(double s);
  List<TrackInfo> get audioTracks;  Future<void> selectAudio(String trackId);
  List<SubtitleTrack> get subtitleTracks;  Future<void> selectSubtitle(String? id); // null=关
  Stream<EngineEvent> get events; // firstFrame / buffering / error / completed / droppedFrames…
  String get engineId; // 'video_player' | 'media_kit'
}
```

- **主引擎 `VideoPlayerEngine`**：`video_player`（Android = ExoPlayer/Media3）。负担直出/换封装流（MP4/MKV 直出、服务端 remux HLS）。
- **兜底引擎 `MediaKitEngine`**：`media_kit`（libmpv）。仅当主引擎报解码/容器类失败时使用；不与主引擎并存实例化。

### 3.2 降级阶梯（借鉴 player-engine 的 FailurePolicy 表驱动）

失败先**分类**（纯函数 `classifyFailure(error) → FailurePolicy`），再决定动作：

| 失败类别 | 动作 |
|---|---|
| 网络断流/缓冲枯竭 | **不换播放器**：原位重开（退避 2·4·8·15·15·15 秒，约 1 分钟）；缺粮 15 秒（服务端流 45 秒）才判断线 |
| HTTP 404 | 「文件不存在」中文报错，不降级不重开 |
| 解码/容器不支持（ExoPlayer 报 unsupported codec/container） | 先向服务端探片源能力 → 换 media_kit（软解）→ 仍失败则请求服务端转码流 → 中文报错 |
| 服务端转码流失败 | 原位重开一次 → 报错 |
| 存储写满（离线播放缓存） | 收窄缓冲窗口原位重开 |

降级时**保留现场**：当前播放位置、所选倍速、音轨/字幕选择、画质档全部带给新引擎（`initialSpeed` 等）。

### 3.3 画质降档与提示（QualitySuggestion）

- 画质/音轨/字幕选择**按片记**（本地 LRU 300 条）；网络环境分家里/外网/分不清（私网同网段=家，公网=分不清只按片记）。
- 换低画质提示触发：一次等满 8 秒，或 5 分钟内卡满 2 次，且实测吞吐中位 < 码率 90%。每会话最多提示一次；按实测速度留两成余量推荐档（1080p≈6 / 720p≈3 / 480p≈1.5 Mbps）。
- 慢线路：暂停时把前向缓冲窗口放大到 3 分钟攒缓冲。
- 流量每字节只下一次：片源字节缓存键 = 文件 id + 大小，1 GiB LRU（Android 端用 ExoPlayer 自带缓存实现）。

## 4. 播放会话协议（服务端契约）

与服务端（MovieClaw API）约定，客户端只做四件事：

```
POST   /playback/sessions        → 协商：服务端决策直出/换封装/转码，返回 url、start_ms、segments、token
POST   /playback/sessions/{id}/start + progress（每 10 秒）→ 起播与进度上报
POST   /playback/sessions/{id}/heartbeat（每 15 秒）→ 心跳
POST   /playback/sessions/{id}/stop → 退出关会话
```

- **协商**：请求带 media_item_id、期望画质、设备能力快照（解码器/屏幕/网络）、attempt_id；响应带播放 url（可能是直出、remux 或转码 HLS）、`start_ms`（吸附后的起播点）、`segments`（可跳区间）、`Server-Timing`。
- **progress 每 10 秒**上报播放头；**心跳每 15 秒**。心跳 404 = 服务端会话已过期/回收 → **原位重开**：按当前播放头重新 `POST /playback/sessions` 换新会话，UI 不出错误，播放不中断。
- **退出 stop**：`PlayerService.close()` 时必须发 stop（flush 一次最终 progress），关服务端会话；App 被杀场景靠心跳停跳由服务端回收（同网页端 10s 标记/30s 判定思路）。
- **consent（软件转码）**：会话落到的转码属于「可避免损失」类（本机可解却要求服务端压制）时，服务端先回 `policy_required`；客户端弹窗征得同意后 `PUT /playback/policy`（记录用户选择，按账号），然后**原请求重发**（同参数重开会话）。
- **画质降档**：协商阶段客户端声明实测吞吐与网络环境；会话中途降档 = 按新档位重开会话（换 url），由 PlayerService 统一执行、带着位置与倍速无缝切换。

## 5. 功能实现要点

### 5.1 字幕与音轨

- **外挂/服务端字幕**：服务端抽好 VTT（MKV 内嵌字幕按 Cues 索引精确抽取、失败退整片通读，见 subtitle-cues.md），客户端只加载渲染。SRT/VTT 优先；ASS 用 media_kit 渲染兜底，video_player 路线只保证 VTT。
- **挂载时机**：字幕轨在**第一次 playing 之后**再挂（借鉴 playback-startup：不拖慢首帧）。
- **音轨**：video_player/ExoPlayer 走 AudioTrack 选择（Media3 API）；media_kit 走 mpv track 切换。选择按片记。
- 显示模式（完整显示/铺满裁切/拉伸铺满）只改布局变换，不重开会话；本次播放器内保留，不存全局偏好；字幕锚定可见区域。

### 5.2 倍速

- 档位统一 **0.5 / 0.75 / 1 / 1.25 / 1.5 / 2**（最高 2x，各端一致）；变速不变调由平台时域伸缩保证。
- 按片记非正常速度（存则删正常记录，300 条 LRU）；换集/换档/降级重开把所选倍速带给新引擎。
- 加速吃光缓冲（< 1 秒）自动回 1x 并提示；加速期间及回落后 8 秒内不判掉帧/卡顿（避免误报）。

### 5.3 跳过片头片尾（segments）

- 数据来自会话响应 `segments: [{type: intro|outro|ad|preview|other, start_ms, end_ms, to_end}]`，客户端**零计算**。
- 交互（与 Web/iOS 同一套规则）：
  - 自然播进区间、距段尾 > 3 秒时显示胶囊按钮（「跳过片头/片尾/广告/预告/此段」）；拖动或 ±10 秒跳进去只给按钮不自动跳。
  - 自动跳过：ad/preview 直接跳 +「已跳过 · 撤回」停 5 秒；intro 按剧学（手动跳过一次即记，撤回即忘），偏好随账号走。
  - `to_end` 的片尾段：进入后提前 8 秒弹「即将播放」倒计时卡片；最后一集不弹；暂停停倒计时。
- 进度条用琥珀色标出可跳段。

### 5.4 章节

- 章节列表由服务端随会话或条目接口下发（挂 library_file，含合成章节与真实 `frame_ms` 抓图，见 video-chapters.md）。
- 跳播 `seekTo(chapter.position)`，位置参数用秒；进度条按章节分段渲染；抓图懒加载。

### 5.5 进度同步（历史）

- 播放头经会话 progress 上报，服务端落观看进度；离线播放结束后补报最终位置。
- 插件历史同步（catalog/import/state）由服务端完成，客户端不直接对接插件 API；`media.identity` 用 tmdb/imdb_id 防 SQLite id 复用串写（见 playback-history-sync.md）。

### 5.6 QOE 上报

对齐 playback-qoe.md 口径，一次播放一条记录（`attempt_id`）：

- **起播**：从点下算起（不是从引擎初始化），StartupTrace 分段计时（点击→协商→引擎 open→首帧→开播），随结束上报；起播 > 2s、跳转 > 1.5s 算打扰（北极星）。
- **卡顿**：每 250ms 采样播放头，0.5 秒不走算一次；首帧/落地后 1.5 秒宽限。
- **跳转**：记来源（按钮/拖动/手势）、是否换会话、落地时间（seek 完成后下一帧）。
- **时间线** ≤ 200 条随结束上报；失败附引擎日志环形缓冲（300 行 ≤ 32KB）。
- 上报走本地队列落盘补发；上报失败不阻塞播放。服务端 `/playback/stats/qoe` 消费，规则表判定规格损失（设备上限不算损失）。
- 实验室播放打 `lab_scenario` 标签，统计默认排除。

## 6. 起播性能要点（借鉴 playback-startup）

1. 点下播放即开始协商（不等播放器页面搭完），协商在后台一口气跑完：决策→选引擎→开会话。
2. 播放专用连接池/预连：详情页出现时预热 HTTP 连接。
3. 起播点吸附：使用会话 `start_ms`（服务端已吸附到分片/关键帧起点），客户端不再自行精确 seek。
4. 字幕、章节抓图等非必需资源等第一次 playing 后再加载。
5. 目标：局域网直出首帧 p50 ≤ 1.0s / p90 ≤ 1.5s；转码流起播 > 2s 记打扰。

## 7. 模块边界与守护

| 层 | 允许依赖 | 禁止 |
|---|---|---|
| UI（detail/reels/offline/播放器页） | PlayerService、PlayerRequest、ValueListenable | 直接持有 VideoPlayerController / MediaKit / Player(mpk) |
| lib/core/player | video_player、media_kit、会话 API client | UI 路由 |
| 会话/上报（lib/core/playback_api/） | dio/http client | 引擎依赖 |

验证：CI grep 检查 `lib/\(?!core/player\).*\}(video_player|media_kit)` 引用为零；播放冒烟用例覆盖「打开→seek→倍速→字幕→降级→关闭」全链路。
