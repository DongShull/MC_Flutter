
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// 对话页控制器（对齐 AgentViewModel）。
/// TODO(stream)：源端为 SSE 事件流（text_delta/tool_call/agent_done…），
/// 当前先一次性请求 + 轮询 transcript 到 running=false，接 SSE 后替换。
class ChatController extends Notifier<ChatState> {
  static const _modelKey = 'agent_composer_model';
  static const _thinkingKey = 'agent_composer_thinking';
  bool _disposed = false;

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
      await _pollUntilIdle(sessionId!);
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
      await _pollUntilIdle(sessionId);
    } catch (e) {
      _dropStreaming();
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(sending: false);
    }
  }

  /// POST /agent/sessions/{id}/stop：终止。
  Future<void> stop() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    try {
      await _api.stop(sessionId);
    } finally {
      _dropStreaming();
      await _loadTranscript(sessionId);
    }
  }

  /// 轮询转录直到会话空闲（SSE 落地前的 1:1 行为替代）。
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
    state = state.copyWith(
      bubbles: state.bubbles.where((b) => b.id != 'streaming').toList(),
    );
  }
}

final chatProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);
