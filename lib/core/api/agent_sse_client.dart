import 'sse_client.dart';

export 'sse_client.dart' show SseEvent, SseUnsupportedException;

/// Agent 聊天流式客户端：通用 [SseClient] 的 agent 域特化。
///
/// 仅剩 agent 域的终态事件集（对齐 Kotlin EventStream.kt DEFAULT_TERMINAL）；
/// 连接/重连/退避/解析逻辑全部在 [SseClient]（P1 核心层统一 SSE 客户端）。
/// 既有调用方（agent_state / activity）与单测沿用此类名与 [terminalEvents]。
class AgentSseClient extends SseClient {
  AgentSseClient(super.session, {super.baseUrl, super.token});

  /// 终态事件名（对齐 EventStream.kt DEFAULT_TERMINAL）。
  static const terminalEvents = <String>{
    'done',
    'agent_done',
    'agent_error',
    'agent_cancelled',
  };

  /// 帧解析转发（静态成员不继承，旧调用方 `AgentSseClient.parseFrame`
  /// 与单测沿用此类名；实现在 [SseClient]）。
  static SseEvent? parseFrame(String block) => SseClient.parseFrame(block);

  @override
  Stream<SseEvent> events(
    String path, {
    String? lastEventId,
    Set<String> terminalEvents = terminalEvents,
    Map<String, String>? query,
  }) =>
      super.events(
        path,
        lastEventId: lastEventId,
        terminalEvents: terminalEvents,
        query: query,
      );
}
