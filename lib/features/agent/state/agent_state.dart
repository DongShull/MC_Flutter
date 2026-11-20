
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/agent_sse_client.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import 'models.dart';

/// agent 域 API 单例：复用 core 全局唯一 McClient（对应 Kotlin McApi.kt agent 段）。
final agentClientProvider = mcClientProvider;

/// agent API 封装。
class AgentApi {
  AgentApi(this._client);

  final McClient _client;

  /// GET /agent/sessions：会话列表。
  Future<List<SessionSummary>> sessions() async {
    final body = await _client.unwrap<List<dynamic>>(
        Channel.general, 'GET', '/api/v1/agent/sessions');
    return body
        .whereType<Map<String, dynamic>>()
        .map(SessionSummary.fromJson)
        .toList();
  }

  /// GET /agent/sessions/{id}：转录。
  Future<SessionTranscript> transcript(String sessionId) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
        Channel.general, 'GET', '/api/v1/agent/sessions/$sessionId');
    return SessionTranscript.fromJson(body);
  }

  /// POST /agent/sessions：开始会话（body {content, sessionId?, model?, thinkingLevel?}）。
  Future<Map<String, dynamic>> start({
    required String content,
    String? sessionId,
    String? model,
    String? thinkingLevel,
  }) async {
    return _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/agent/sessions',
      body: {
        'content': content,
        if (sessionId != null) 'sessionId': sessionId,
        'model': model ?? '',
        if (thinkingLevel != null) 'thinkingLevel': thinkingLevel,
      },
    );
  }

  /// POST /agent/sessions/{id}/stop。
  Future<void> stop(String sessionId) => _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/agent/sessions/$sessionId/stop',
      );

  /// POST /agent/sessions/{id}/retry（body {messageId?, content?}）。
  Future<Map<String, dynamic>> retry({
    required String sessionId,
    String? messageId,
    String? content,
  }) =>
      _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/agent/sessions/$sessionId/retry',
        body: {
          if (messageId != null) 'messageId': messageId,
          if (content != null) 'content': content,
        },
      );

  /// POST /agent/sessions/{id}/compact-context。
  Future<void> compactContext(String sessionId) =>
      _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/agent/sessions/$sessionId/compact-context',
      );

  /// PATCH /agent/sessions/{id}：重命名。
  Future<void> rename(String sessionId, String title) =>
      _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PATCH',
        '/api/v1/agent/sessions/$sessionId',
        body: {'title': title},
      );

  /// DELETE /agent/sessions/{id}。
  Future<void> delete(String sessionId) =>
      _client.delete(Channel.general, '/api/v1/agent/sessions/$sessionId');

  /// GET /agent/llm/models：可选模型。
  Future<List<LlmModelOption>> models() async {
    final body = await _client.unwrap<List<dynamic>>(
        Channel.general, 'GET', '/api/v1/agent/llm/models');
    return body
        .whereType<Map<String, dynamic>>()
        .map(LlmModelOption.fromJson)
        .toList();
  }
}

final agentApiProvider =
    Provider<AgentApi>((ref) => AgentApi(ref.watch(agentClientProvider)));

/// SSE 流式客户端（复用全局 SessionStore 的 baseUrl/token）。
final agentSseClientProvider = Provider<AgentSseClient>(
    (ref) => AgentSseClient(ref.watch(sessionStoreProvider)));

/// —— 会话列表控制器（对齐 AgentSessionsViewModel：load/delete）——
class SessionsController extends Notifier<List<SessionSummary>> {
  @override
  List<SessionSummary> build() {
    load();
    return const <SessionSummary>[];
  }

  Future<void> load() async {
    try {
      state = await ref.read(agentApiProvider).sessions();
    } catch (_) {
      // 离线/未登录时列表保持为空。
    }
  }

  Future<void> remove(String sessionId) async {
    await ref.read(agentApiProvider).delete(sessionId);
    state = state.where((s) => s.id != sessionId).toList();
  }
}

final sessionsProvider =
    NotifierProvider<SessionsController, List<SessionSummary>>(SessionsController.new);

/// 对话气泡（对齐 Kotlin Bubble：连续 thinking/tool 折叠为 ProcessBlock）。
class Bubble {
  const Bubble({
    required this.id,
    required this.role,
    required this.text,
    this.thinking,
    this.toolCalls = const [],
    this.toolOutput,
    this.toolError = false,
    this.processSummary,
    this.streaming = false,
  });

  final String id;
  final String role; // user / assistant / tool / process / system
  final String text;
  final String? thinking;
  final List<ToolCall> toolCalls;
  final String? toolOutput;
  final bool toolError;
  final String? processSummary;
  final bool streaming;
}

/// 对话页 UI 状态。
class ChatState {
  const ChatState({
    this.sessionId,
    this.bubbles = const <Bubble>[],
    this.models = const <LlmModelOption>[],
    this.modelRef,
    this.thinkingLevels = const <String>[],
    this.thinkingLevel,
    this.loading = false,
    this.sending = false,
    this.error,
  });

  final String? sessionId;
  final List<Bubble> bubbles;
  final List<LlmModelOption> models;
  final String? modelRef; // null = 默认模型
  final List<String> thinkingLevels;
  final String? thinkingLevel;
  final bool loading;
  final bool sending;
  final String? error;

  ChatState copyWith({
    String? sessionId,
    List<Bubble>? bubbles,
    List<LlmModelOption>? models,
    String? modelRef,
    List<String>? thinkingLevels,
    String? thinkingLevel,
    bool? loading,
    bool? sending,
    String? error,
    bool clearError = false,
  }) =>
      ChatState(
        sessionId: sessionId ?? this.sessionId,
        bubbles: bubbles ?? this.bubbles,
        models: models ?? this.models,
        modelRef: modelRef ?? this.modelRef,
        thinkingLevels: thinkingLevels ?? this.thinkingLevels,
        thinkingLevel: thinkingLevel ?? this.thinkingLevel,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 服务器推来的一条 agent 执行事件（线格式 snake_case，对齐 web lib/api/agent.ts 的 AgentEvent）：
/// agent_start / thinking_delta / text_delta / tool_call_start / tool_call_delta /
/// tool_call / tool_result / context_compacted / agent_done / agent_error / agent_cancelled。
class _AgentEvent {
  _AgentEvent._(this._json);

  /// 解析一帧 SSE data；坏帧返回 null（跳过，不打断流）。
  static _AgentEvent? parse(String raw) {
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? _AgentEvent._(json) : null;
    } catch (_) {
      return null;
    }
  }

  final Map<String, dynamic> _json;

  String get type => (_json['type'] ?? '').toString();
  String get delta => (_json['delta'] ?? '').toString();
  ToolCall? get toolCall {
    final tc = _json['tool_call'] ?? _json['toolCall'];
    return tc is Map<String, dynamic> ? ToolCall.fromJson(tc) : null;
  }

  String? get error => _json['error']?.toString();
  String? get compactionSummary =>
      (_json['compaction']?['summary'])?.toString();
  int? get compactionBefore =>
      (_json['compaction']?['tokens_before']) is int
          ? (_json['compaction']?['tokens_before']) as int
          : null;
  int? get compactionAfter => (_json['compaction']?['tokens_after']) is int
      ? (_json['compaction']?['tokens_after']) as int
      : null;
}

/// 对话页控制器（对齐 AgentViewModel）。
/// 流式：发送/重试后订阅 GET …/sessions/{id}/events（SSE），
/// text_delta/thinking_delta 等增量实时渲染；服务器不支持 SSE 时回退轮询。
class ChatController extends Notifier<ChatState> {
  static const _modelKey = 'agent_composer_model';
  static const _thinkingKey = 'agent_composer_thinking';
  bool _disposed = false;

  /// SSE 探测失败后置 false：本会话内不再尝试流式，直接轮询回退。
  bool _sseSupported = true;
  StreamSubscription<SseEvent>? _streamSub;
  String? _lastEventId;

  /// SSE 端点候选前缀（按序探测，命中后缓存到 [_eventsBase]）：
  /// Flutter agent 域既有前缀 / Kotlin+Web 参考实现的前缀。
  static const _eventPathCandidates = <String>[
    '/api/v1/agent/sessions',
    '/api/v1/sessions',
  ];
  static String? _eventsBase;

  @override
  ChatState build() {
    ref.onDispose(() {
      _disposed = true;
    });
    loadModels();
    _restorePrefs();
    return const ChatState();
  }

  AgentApi get _api => ref.read(agentApiProvider);

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      modelRef: prefs.getString(_modelKey),
      thinkingLevel: prefs.getString(_thinkingKey),
    );
  }

  /// GET /agent/llm/models：模型 chip；无默认项时补「默认」选项（ref=null）。
  Future<void> loadModels() async {
    try {
      final models = await _api.models();
      final defaults = models.where((m) => m.isDefault).toList();
      state = state.copyWith(
        models: models,
        modelRef: state.modelRef ??
            (defaults.isEmpty ? null : defaults.first.ref),
        thinkingLevels: defaults.isEmpty ? const <String>[] : defaults.first.thinkingLevels,
      );
    } catch (_) {
      // 模型列表拉不到不影响本地输入。
    }
  }

  Future<void> setModel(String? refId) async {
    state = state.copyWith(modelRef: refId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, refId ?? '');
    // 换模型后 thinkingLevels 跟着换；选回默认 = ref null。
    final match = models(refId);
    state = state.copyWith(
      thinkingLevels: match?.thinkingLevels ?? const <String>[],
      thinkingLevel: null,
    );
  }

  LlmModelOption? models(String? refId) {
    for (final m in state.models) {
      if (m.ref == refId) return m;
    }
    return null;
  }

  Future<void> setThinkingLevel(String? level) async {
    state = state.copyWith(thinkingLevel: level);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_thinkingKey, level ?? '');
  }

  /// 打开已有会话：拉转录并折叠渲染。
  Future<void> openSession(String sessionId) async {
    state = state.copyWith(
      sessionId: sessionId,
      loading: true,
      bubbles: const <Bubble>[],
    );
    await _loadTranscript(sessionId);
  }

  Future<void> _loadTranscript(String sessionId) async {
    try {
      final transcript = await _api.transcript(sessionId);
      state = state.copyWith(
        bubbles: _bubblesFromTranscript(transcript),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// transcript -> 气泡流：连续 thinking/tool 折叠为 ProcessBlock（对齐 Kotlin 折叠口径）。
  List<Bubble> _bubblesFromTranscript(SessionTranscript transcript) {
    final bubbles = <Bubble>[];
    var thinkingParts = <String>[];
    var toolCalls = <ToolCall>[];
    void flushProcess() {
      if (thinkingParts.isEmpty && toolCalls.isEmpty) return;
      final commands = toolCalls.length;
      bubbles.add(Bubble(
        id: 'process-${bubbles.length}',
        role: 'process',
        text: '',
        thinking: thinkingParts.join('\n\n'),
        toolCalls: toolCalls,
        processSummary: [
          if (thinkingParts.isNotEmpty) '已思考',
          if (commands > 0) '调用 $commands 次工具',
        ].join('，'),
      ));
      thinkingParts = <String>[];
      toolCalls = <ToolCall>[];
    }

    for (final entry in transcript.entries) {
      final message = entry.message;
      if (entry.compactionId != null) {
        flushProcess();
        final before = entry.tokensBefore?.toString() ?? '?';
        final after = entry.tokensAfter?.toString() ?? '?';
        bubbles.add(Bubble(
          id: 'compact-${entry.compactionId ?? bubbles.length}',
          role: 'system',
          text: '上下文已压缩：${entry.summary ?? ''}（$before -> $after tokens）',
        ));
        continue;
      }
      if (message == null) continue;
      switch (message.role) {
        case 'user':
          flushProcess();
          bubbles.add(Bubble(
            id: entry.messageId ?? 'user-${bubbles.length}',
            role: 'user',
            text: message.content,
          ));
          break;
        case 'tool':
          toolCalls = [...toolCalls, ...message.toolCalls];
          if (message.content.isNotEmpty && message.toolCalls.isEmpty) {
            thinkingParts = [...thinkingParts, message.content];
          }
          break;
        case 'thinking':
          thinkingParts = [...thinkingParts, message.content];
          break;
        default:
          flushProcess();
          bubbles.add(Bubble(
            id: entry.messageId ?? 'assistant-${bubbles.length}',
            role: 'assistant',
            text: message.content,
          ));
      }
    }
    flushProcess();
    return bubbles;
  }

  /// 发送：新会话 POST /agent/sessions；已有会话同样 POST（带 sessionId）。
  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || state.sending) return;
    state = state.copyWith(
      sending: true,
      bubbles: [
        ...state.bubbles,
        Bubble(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            role: 'user',
            text: content),
        const Bubble(id: 'streaming', role: 'assistant', text: '', streaming: true),
      ],
    );
    try {
      final accepted = await _api.start(
        content: content,
        sessionId: state.sessionId,
        model: state.modelRef,
        thinkingLevel: state.thinkingLevel,
      );
      final sessionId = state.sessionId ??
          accepted['sessionId']?.toString() ??
          accepted['session_id']?.toString();
      state = state.copyWith(sessionId: sessionId);
      await _runToCompletion(sessionId!);
    } catch (e) {
      _dropStreaming();
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(sending: false);
    }
  }

  /// 改写重发（对齐 beginEdit -> retry）：填回原文后由 retry(messageId) 提交。
  Future<void> resendEdited(String messageId, String newContent) async {
    if (state.sending) return;
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    state = state.copyWith(
      sending: true,
      bubbles: [
        ...state.bubbles,
        const Bubble(id: 'streaming', role: 'assistant', text: '', streaming: true),
      ],
    );
    try {
      await _api.retry(sessionId: sessionId, messageId: messageId, content: newContent);
      await _runToCompletion(sessionId);
    } catch (e) {
      _dropStreaming();
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(sending: false);
    }
  }

  /// POST /agent/sessions/{id}/stop：终止（同时断开 SSE 流）。
  Future<void> stop() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    await _streamSub?.cancel();
    _streamSub = null;
    try {
      await _api.stop(sessionId);
    } finally {
      _finishStreamingBubbles();
      await _loadTranscript(sessionId);
    }
  }

  /// 发送/重试后推进到会话空闲：优先 SSE 流式增量渲染，不支持/中断则轮询回退。
  Future<void> _runToCompletion(String sessionId) async {
    _lastEventId = null;
    if (_sseSupported) {
      if (await _streamSession(sessionId)) return;
      // 流式不可用（端点 404 / 重连耗尽）→ 回退现有轮询兜底。
    }
    await _pollUntilIdle(sessionId);
  }

  /// 订阅一次 agent 事件流直到终态。返回 true = 收到终态；
  /// false = 流中断（走轮询兜底）；路径候选全部 404 时置 _sseSupported=false。
  Future<bool> _streamSession(String sessionId) async {
    final sse = ref.read(agentSseClientProvider);
    final candidates = _eventsBase != null
        ? <String>['$_eventsBase/$sessionId/events']
        : [for (final b in _eventPathCandidates) '$b/$sessionId/events'];
    for (final path in candidates) {
      final result = await _consumeStream(sse, path, sessionId);
      if (result == null) continue; // 该端点不存在，试下一个候选
      _eventsBase = path.substring(0, path.lastIndexOf('/'));
      return result;
    }
    _sseSupported = false;
    return false;
  }

  /// 消费一条流。null = 端点不支持；true = 终态收尾；false = 网络中断。
  Future<bool?> _consumeStream(
    AgentSseClient sse,
    String path,
    String sessionId,
  ) async {
    final done = Completer<bool?>();
    var gotEvent = false;
    StreamSubscription<SseEvent>? sub;
    sub = sse.events(path, lastEventId: _lastEventId).listen((event) {
      if (event.id != null) _lastEventId = event.id;
      gotEvent = true;
      final ev = _AgentEvent.parse(event.data);
      if (ev != null) _applyAgentEvent(ev);
      if (AgentSseClient.terminalEvents.contains(event.name) &&
          !done.isCompleted) {
        done.complete(true);
      }
    }, onError: (Object e) {
      if (done.isCompleted) return;
      // 该路径从未产出事件且服务器明确 404/非流式 → 端点不支持；
      // 已经收到过事件（重连耗尽等）→ 当作中断走轮询兜底。
      done.complete(e is SseUnsupportedException && !gotEvent ? null : false);
    }, onDone: () {
      if (!done.isCompleted) done.complete(false);
    });
    _streamSub = sub;
    final result = await done.future;
    await sub.cancel();
    _streamSub = null;
    if (result == true) await _loadTranscript(sessionId); // 终态后以转录复原折叠
    return result;
  }

  /// 把一条 agent 事件落到气泡流（打字机式增量，对齐 Kotlin 流式渲染口径）。
  void _applyAgentEvent(_AgentEvent ev) {
    switch (ev.type) {
      case 'thinking_delta':
        _appendToProcess(thinkingDelta: ev.delta);
        break;
      case 'text_delta':
        _appendToAssistant(ev.delta);
        break;
      case 'tool_call_start':
      case 'tool_call':
        if (ev.toolCall != null) _appendToProcess(toolCall: ev.toolCall);
        break;
      case 'context_compacted':
        _finishStreamingBubbles();
        _patchBubbles((bubbles) => [...bubbles, Bubble(
              id: 'compact-${DateTime.now().microsecondsSinceEpoch}',
              role: 'system',
              text: '上下文已压缩：${ev.compactionSummary ?? ''}'
                  '（${ev.compactionBefore ?? '?'} -> ${ev.compactionAfter ?? '?'} tokens）',
            )]);
        break;
      case 'agent_error':
        _finishStreamingBubbles();
        state = state.copyWith(error: ev.error ?? 'Agent 运行失败');
        break;
      case 'agent_done':
      case 'agent_cancelled':
        _finishStreamingBubbles();
        break;
      default:
        break; // agent_start / tool_call_delta / tool_result：渲染无需单独处理
    }
  }

  void _patchBubbles(List<Bubble> Function(List<Bubble>) fn) {
    state = state.copyWith(bubbles: fn(state.bubbles));
  }

  /// thinking 增量 / 工具调用落到末尾的 streaming process 气泡（无则新建）。
  void _appendToProcess({String? thinkingDelta, ToolCall? toolCall}) {
    _patchBubbles((bubbles) {
      if (bubbles.isNotEmpty && bubbles.last.role == 'process' && bubbles.last.streaming) {
        final last = bubbles.last;
        final merged = Bubble(
          id: last.id,
          role: 'process',
          text: '',
          thinking: [
            if (last.thinking != null) last.thinking!,
            if (thinkingDelta != null && thinkingDelta.isNotEmpty) thinkingDelta,
          ].join(),
          toolCalls: [
            ...last.toolCalls,
            if (toolCall != null) toolCall,
          ],
          processSummary: _processSummary([
            if (((last.thinking ?? '') + (thinkingDelta ?? '')).trim().isNotEmpty)
              '已思考',
            if (last.toolCalls.length + (toolCall != null ? 1 : 0) > 0)
              '调用 ${last.toolCalls.length + (toolCall != null ? 1 : 0)} 次工具',
          ]),
          streaming: true,
        );
        return [...bubbles.sublist(0, bubbles.length - 1), merged];
      }
      return [
        ...bubbles,
        Bubble(
          id: 'process-${DateTime.now().microsecondsSinceEpoch}',
          role: 'process',
          text: '',
          thinking: (thinkingDelta != null && thinkingDelta.isNotEmpty) ? thinkingDelta : null,
          toolCalls: toolCall != null ? [toolCall] : const <ToolCall>[],
          processSummary: _processSummary([
            if (thinkingDelta != null && thinkingDelta.trim().isNotEmpty) '已思考',
            if (toolCall != null) '调用 1 次工具',
          ]),
          streaming: true,
        ),
      ];
    });
  }

  /// text 增量落到末尾的 streaming assistant 气泡（无则新建，打字机式追加）。
  void _appendToAssistant(String delta) {
    if (delta.isEmpty) return;
    _patchBubbles((bubbles) {
      if (bubbles.isNotEmpty && bubbles.last.role == 'assistant' && bubbles.last.streaming) {
        final last = bubbles.last;
        return [
          ...bubbles.sublist(0, bubbles.length - 1),
          Bubble(
            id: last.id,
            role: 'assistant',
            text: last.text + delta,
            streaming: true,
          ),
        ];
      }
      return [
        ...bubbles,
        Bubble(id: 'streaming', role: 'assistant', text: delta, streaming: true),
      ];
    });
  }

  String _processSummary(List<String> parts) => parts.join('，');

  /// 终态/停止：所有 streaming 气泡落定。
  void _finishStreamingBubbles() {
    _patchBubbles((bubbles) => [
          for (final b in bubbles) if (b.streaming) _unstream(b) else b,
        ]);
  }

  Bubble _unstream(Bubble b) => Bubble(
        id: b.id,
        role: b.role,
        text: b.text,
        thinking: b.thinking,
        toolCalls: b.toolCalls,
        toolOutput: b.toolOutput,
        toolError: b.toolError,
        processSummary: b.processSummary,
        streaming: false,
      );

  /// 轮询转录直到会话空闲（SSE 不可用时的回退路径）。
  Future<void> _pollUntilIdle(String sessionId) async {
    for (var attempt = 0; attempt < 300 && !_disposed; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (_disposed) return;
      var stillRunning = false;
      try {
        final summaries = await _api.sessions();
        for (final s in summaries) {
          if (s.id == sessionId && s.running) stillRunning = true;
        }
      } catch (_) {
        break;
      }
      if (!stillRunning) break;
    }
    if (_disposed) return;
    await _loadTranscript(sessionId);
  }

  void _dropStreaming() {
    _streamSub?.cancel();
    _streamSub = null;
    state = state.copyWith(
      bubbles: state.bubbles.where((b) => b.id != 'streaming').toList(),
    );
  }
}

final chatProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);
