# 09 · 飞牛 App 优点深度分析 → mc_flutter 可采用技术清单

> 来源：/ds/dsh_github/fnos_reference/（静态逆向：blutter 反汇编 + 对象池 + 资源 + 启动分析）。
> 本文回答一个问题：**飞牛 App 到底好在哪，哪些 mc_flutter 可以抄、怎么抄、抄到什么程度。**

## 一、高维评价：飞牛 App 的六个架构级优点

### 1. 启动链路是"被设计过的"，不是默认的
飞牛 main() 不是直接 runApp：首帧前有 ≥3 层异步初始化链 + `EndWarmUpFrame` 引擎预热帧 +
`RequestDartPerformanceMode` 性能模式。白屏时间被主动压缩。
**本质**：把"启动"当成一条管线来排程——什么必须在首帧前、什么可以在首帧后、什么可以懒到用时再说。

### 2. 服务懒注册 + 模块按需加载
`lazyPut / useLazyPreparation`（非首屏服务不实例化）+ `deferred`（Dart 延迟加载，非核心模块按需编译进内存）。
**本质**：包体 131MB 但冷启动只付"首屏成本"。

### 3. 媒体体验的"预"字诀
`preloadArtwork` 封面预加载管线（进库前预拉图）+ 播放页 keep-alive
（`HostKeepAliveApi.startKeepAlive` / `playbackRecoveryKeepAlive` / `PlaybackInterruptionRecovery*` 枚举族）。
**本质**：媒体类 App 的体感 = 等待时间，飞牛把等待前置到用户看见之前。

### 4. 重 IO 下沉原生（Go 引擎）
12MB `libgojni.so`（gomobile）：传输层/大文件 IO 走 Go，Dart 只做 UI 编排。
**本质**：UI 线程永不被 IO 打断。

### 5. 播放会话是"多端协议"，不是播放器属性
trim_playback_session_plugin：注册参与者→激活抢占→心跳→命令下发→快照广播（详见 docs/design/08）。
**本质**：为多端同看/投屏/远控预留了一等协议位。

### 6. 自有设计系统 trim_ui
1068 图标自绘字体 + 思源黑体 + 全量自研组件 + 5979 条中文文案统一管理。
**本质**：不依赖 Material 皮肤，品牌一致性与改版成本都可控。

## 二、逐项回填清单（可抄 → 已抄/待抄）

| # | 飞牛技术 | mc_flutter 对应 | 状态 |
|---|---|---|---|
| 1 | EndWarmUpFrame 预热帧 | main.dart 分阶段启动 + 首帧栅格化后延迟任务（core/bootstrap） | ✅ 本轮 |
| 2 | lazyPut 懒服务 | Riverpod 天然惰性（Provider 首次 read 才实例化） | ✅ 已满足 |
| 3 | deferred 模块加载 | 18 feature 已按路由分包；deferred import 收益有限暂缓 | 🟨 评估中 |
| 4 | preloadArtwork 封面预取 | core/image CoverPreloader（并发上限+去重队列） | ✅ 本轮落 core |
| 5 | 播放保活/中断恢复 | 播放页 AppLifecycleListener：后台自动暂停、回前台恢复；wakelock_plus 常亮 | ✅ 本轮 |
| 6 | Go 引擎传输层 | Dart 侧用 compute()/isolates 分担大 JSON/列表解析（无新依赖） | 🟨 待接 |
| 7 | 播放会话协议 | core/player/session PlaybackCoordinator（上一轮 87b92fb） | ✅ 已落 |
| 8 | trim_ui 设计系统 | McIcons 1068 图标（813a848）+ core/designsystem | ✅ 已落 |
| 9 | 性能模式 RequestDartPerformanceMode | 引擎 API 较新，低优先级 | ⬜ 观察 |
| 10 | mmkv 本地存储 | shared_preferences/secure_storage 已够用 | ⬜ 不抄 |

## 三、本轮落地代码（对应上表 #1 #4 #5）

- `lib/core/bootstrap/app_bootstrap.dart` + main.dart：
  runZonedGuarded 全局错误兜底 → 首帧栅格化前只做最小集 →
  waitUntilFirstFrameRasterized 后再跑非首屏任务（会话恢复、预热钩子）。
- `lib/core/image/cover_preloader.dart`：CoverPreloader.preload(urls)——
  precacheImage 队列，并发 4、URL 去重，library/discover/reels 进网格前调它。
- 播放页：AppLifecycleListener（后台→暂停播放，回前台→恢复[若非用户手动暂停]）；
  wakelock_plus 保持屏幕常亮（播放中启用、退出释放）。

## 四、待真机动态验证（静态榨干的部分）

各阶段毫秒数、每页 TTFT、帧率、GC 行为——需 Frida + profile 实测（用户确认暂不需要）。

## 五、第二轮落地（续）

- **"进即用"启动重定向**：main() 首帧前 `appSession.restore()`（secure storage 读令牌）；
  router redirect：会话就绪时访问 /onboarding 直接重定向 /home（对齐飞牛启动直达媒体库的体验）。
  全 App 唯一 SessionStore 单例 `appSession`（core/session/session_store.dart），
  sessionStoreProvider 返回同一实例——重定向与业务层永远看到同一份会话。
- **传输层自愈**：lib/core/api/retry_interceptor.dart（对齐 trim_http_client 重试思想）——
  仅幂等 GET；连接错误/超时重试，指数退避（300/600ms）+ 抖动防惊群，上限 2 次；McClient 三通道全挂。
- **崩溃兜底**：BootstrapErrorLog 环形缓冲（50 条）记录 uncaught zone error，未来接上报直接读。
- **预取扩展**：discover 筛选结果网格接入 CoverPreloader（结果集变化即预取全部海报）。

### 回填清单状态更新
| # | 技术 | 状态 |
|---|---|---|
| 6 | Go 引擎传输层 → 重试/自愈拦截器 | ✅（isolate 解析仍待接） |
| — | 启动直达（session restore + redirect） | ✅ 新增 |
| — | 错误环形缓冲 | ✅ 新增 |
