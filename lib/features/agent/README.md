
# feature/agent

- 原 Kotlin 模块：apps/android .../feature/agent（AgentScreens.kt / AgentViewModel.kt / AgentSessionsViewModel.kt）
- 设计文档：docs/design/05-misc-features.md（§AI 助手）
- 状态：✅ 已实现（1:1；流式为 TODO(stream)，先一次性请求 + 轮询）
  - pages/sessions_page.dart：会话列表（标题 = title/lastPrompt/新对话、条数 + 更新时间、
    running 图标、左滑删除 POST DELETE /agent/sessions/{id}）+ 新对话入口。
  - pages/chat_page.dart：消息流 + 底部输入框；模型 chip（GET /agent/llm/models，
    选回默认 = ref null，偏好持久化 shared_preferences）；user 气泡长按 复制/改写，
    改写填回原文、提交走 POST /agent/sessions/{id}/retry {messageId, content}；
    发送中新会话 POST /agent/sessions {content, sessionId?, model, thinkingLevel?}，
    结束后重拉 transcript；AppBar 停止按钮 POST /agent/sessions/{id}/stop。
  - widgets/bubble.dart：BubbleView（user 半透明白玻璃圆角 18；assistant 可选中文本；
    system 居中小字；streaming「思考中…」）+ ProcessBlockView（连续 thinking/tool 折叠，
    完成「已思考，调用 N 次工具」，点开看原文与工具列表）。
  - state/agent_state.dart：AgentApi（sessions/transcript/start/stop/retry/compact-context/
    rename/delete/models，全部走 McClient Channel.general，前缀 /api/v1）+
    SessionsController（load/delete）+ ChatController（openSession/send/resendEdited/stop/
    模型与 thinking 偏好持久化）。
  - state/models.dart：SessionSummary/SessionMessage/ToolCall/TranscriptEntry/
    SessionTranscript/LlmModelOption（判别字段与 Kotlin 协议一致）。
  - routes.dart：routeAgent='/agent' 主路由（会话列表）+ 子路由 /agent/new、/agent/session/:sessionId。
  - TODO(stream)：源端为 SSE 事件流（agent_start/thinking_delta/text_delta/tool_call_start/
    tool_call/tool_result/context_compacted/agent_done/agent_error/agent_cancelled），
    当前实现为一次性请求 + 每 2s 轮询会话状态到 running=false 再拉转录；接 SSE 后替换 _pollUntilIdle。
- 实现要求：页面放 pages/，私有组件放 widgets/，状态放 state/（Riverpod），路由只从 routes.dart 导出；
  禁止 import 其他 feature 目录；播放相关一律走 core/player PlayerService。

> 重构注记：已下沉 core 复用（session/McClient provider、格式化、状态视图、防抖/序号守卫）。
- M6 多设备：会话列表与输入区 expanded 限宽 720 居中，FAB/发送/模型 chip/停止按钮包 McFocusRing。

## P4（2026-11-22）
- 技能页：pages/skills_page.dart（GET /api/v1/skills，路由 /agent/skills，会话列表页 AppBar 技能入口）。
- 媒体卡片：state/media_cards.dart（show_media_cards_v1 参数解析，移植自 web lib/agent-media-cards.ts）
  + widgets/media_cards.dart（按编号现取数据：标题/媒体项/订阅/媒体库，点卡片跳详情）；渲染点在
  ProcessBlockView（工具调用折叠块下方，流式与历史回放同一路径）。
- 附件：AgentApi.start 支持 attachments；ChatState 增加 attachments/uploadingAttachment；
  chat_page 输入框左侧附件按钮（image_picker 选图 → POST /sessions/attachments），
  待发送附件以 Chip 展示、可移除；发送时随消息提交，发完清空。
  未确认：纯附件（无文字）发送时服务端是否接受空 content（见 P4.md）。
