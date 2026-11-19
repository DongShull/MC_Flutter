# 08 播放会话设计（参照 trim_playback_session_plugin 逆向）

> 依据：飞牛 App v1.37.3 blutter 逆向（fnos_reference/）。目标：为 mc_flutter 的 core/player TODO(playback-session) 给出实现蓝图。

## 飞牛的架构：Pigeon 多端协同播放会话

原生宿主(Host) ⇄ Flutter(Dart) 通过 Pigeon 代码生成通道通信，全部方法名已从对象池还原：

**HostPlaybackSessionApi（Dart → 原生）**
- initialize — 会话服务初始化
- registerParticipant / unregisterParticipant — 注册/注销播放参与者（每个播放页面或投屏端=1 参与者）
- reportParticipantState — 上报参与者播放状态
- reportRemoteUserPaused — 远端用户暂停（投屏对端操作）
- reportUserStopped — 用户停止
- requestActivation — 申请激活（抢占播放权）
- synchronize — 全员同步（时间轴对齐）
- acknowledgeCommand — 确认协调器下发命令

**FlutterPlaybackSessionApi（原生 → Dart 回调）**
- onCoordinatorCommand — 协调器命令下发（play/pause/seek…）
- onSessionSnapshotChanged — 会话快照变化（当前参与者/状态集合）
- onSessionDiagnostic — 诊断事件

**消息键**：sessionId / session / keepAliveId(心跳) / participant_* / coordinatorFailure / delivery
**失败口径**：participant_command_timeout、participant_execution_failed、participant_pin_legacy_failed、participant_register_failed、participant_reregister_failed、participant_resume_failed

**相关服务端线索**
- 请求头 `X-TRIM-IJK-Transcode-HLS`（ijk 走 HLS 转码流）
- 端点：`/sac/hardwareacceleration/v1/hardware-acceleration/transcode`、流播放 `/p/api/v1/stream/p/t/`、`/api/redirect`
- 枚举家族：PlaybackSessionActivationStatus / OperatingMode / CommandReason / DiagnosticSeverity+Category、PlaybackDeliveryType、PlaybackKeepAliveAction、TranscodeSessionState、PlaybackInterruptionRecoveryReason/Outcome

## mc_flutter 实现方案（mc_session）

1. **core/player/session/playback_session.dart**：纯 Dart 协调器（不依赖原生也能跑）
   - `PlaybackSessionState { sessionId, participants[], activeId, snapshot }`
   - `PlaybackCoordinator`：registerParticipant/requestActivation/synchronize/reportUserStopped
   - 状态广播用 Stream，多窗口/多端后续接
2. **激活与抢占**：同一时间仅 1 个 activeParticipant；新参与者 requestActivation 时旧参与者收到 onCoordinatorCommand(pause)
3. **心跳**：每 5s keepAliveId；3 次超时判参与者失联 → 移除+快照更新（对应 participant_command_timeout）
4. **与服务端**：后端未提供会话端点前纯本地；有服务端时把 coordinator 事件透传（对照 MovieClaw playback 通道）
5. **Pigeon 平台通道**：暂不引入（Android/iOS 原生侧尚无需求），接口形状与飞牛对齐以便将来替换

## 验收
- analyze/test 全绿；player feature 接入 coordinator：进入播放页注册、退出注销、暂停/seek 上报 participantState
