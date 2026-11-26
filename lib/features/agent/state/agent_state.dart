import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/agent_sse_client.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import 'models.dart';

/// agent 域 API 单例：复用 core 全局唯一 McClient。
final agentClientProvider = mcClientProvider;

/// agent API 封装（完整对齐 Web / 后端 `/api/v1/agent/*` 与 `/api/v1/skills`）。
class AgentApi {
  AgentApi(this._client);

  final McClient _client;

  /// GET /api/v1/sessions：会话列表。
  Future<List<SessionSummary>> sessions() async {
    final body = await _client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/sessions',
    );
    return body
        .whereType<Map>()
        .map((m) => SessionSummary.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /api/v1/sessions/{id}：转录。
  Future<SessionTranscript> transcript(String sessionId) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/sessions/$sessionId',
    );
    return SessionTranscript.fromJson(body);
  }

  /// POST /api/v1/sessions：开始或继续会话。
  Future<Map<String, dynamic>> start({
    required String content,
    String? sessionId,
    String? model,
    String? thinkingLevel,
  }) async {
    return _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/sessions',
      body: {
        'content': content,
        if (sessionId != null) 'session_id': sessionId,
        if (sessionId != null) 'sessionId': sessionId,
        'model': model ?? '',
        if (thinkingLevel != null && thinkingLevel.isNotEmpty)
          'thinking_level': thinkingLevel,
        if (thinkingLevel != null && thinkingLevel.isNotEmpty)
          'thinkingLevel': thinkingLevel,
      },
    );
  }

  /// POST /api/v1/sessions/{id}/stop。
  Future<void> stop(String sessionId) => _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/sessions/$sessionId/stop',
      );

  /// POST /api/v1/sessions/{id}/retry。
  Future<Map<String, dynamic>> retry({
    required String sessionId,
    String? messageId,
    String? content,
  }) =>
      _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/sessions/$sessionId/retry',
        body: {
          if (messageId != null) 'messageId': messageId,
          if (content != null) 'content': content,
        },
      );

  /// POST /api/v1/sessions/{id}/fork：从当前或指定消息分叉出新会话。
  Future<String?> forkSession(String sessionId, {String? entryId}) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/sessions/$sessionId/fork',
      body: {
        if (entryId != null && entryId.isNotEmpty) 'entry_id': entryId,
        if (entryId != null && entryId.isNotEmpty) 'messageId': entryId,
      },
    );
    final nested = body['session'];
    if (nested is Map && nested['id'] != null) {
      return nested['id'].toString();
    }
    return body['id']?.toString() ??
        body['sessionId']?.toString() ??
        body['session_id']?.toString();
  }

  /// POST /api/v1/sessions/{id}/compact-context。
  Future<void> compactContext(String sessionId) =>
      _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/sessions/$sessionId/compact-context',
      );

  /// PATCH /api/v1/sessions/{id}：重命名。
  Future<void> rename(String sessionId, String title) =>
      _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PATCH',
        '/api/v1/sessions/$sessionId',
        body: {'title': title},
      );

  /// DELETE /api/v1/sessions/{id}。
  Future<void> delete(String sessionId) =>
      _client.delete(Channel.general, '/api/v1/sessions/$sessionId');

  /// GET /api/v1/llm/models：可选模型。
  Future<List<LlmModelOption>> models() async {
    final body = await _client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/llm/models',
    );
    return body
        .whereType<Map>()
        .map((m) => LlmModelOption.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// GET /api/v1/skills（回退 `/api/v1/agent/skills`）：技能列表。
  Future<List<AgentSkill>> skills() async {
    for (final path in const ['/api/v1/skills', '/api/v1/agent/skills']) {
      try {
        final raw = await _client.unwrap<Object?>(Channel.general, 'GET', path);
        final list = raw is List<dynamic>
            ? raw
            : (raw is Map<String, dynamic>
                ? ((raw['items'] ?? raw['skills'] ?? const []) as List<dynamic>)
                : const <dynamic>[]);
        return list
            .whereType<Map<String, dynamic>>()
            .map(AgentSkill.fromJson)
            .where((s) => s.name.isNotEmpty || s.title.isNotEmpty)
            .toList();
      } catch (_) {
        continue;
      }
    }
    return const <AgentSkill>[];
  }
}

final agentApiProvider =
    Provider<AgentApi>((ref) => AgentApi(ref.watch(agentClientProvider)));

/// SSE 流式客户端（复用全局 SessionStore 的 baseUrl/token）。
final agentSseClientProvider = Provider<AgentSseClient>(
  (ref) => AgentSseClient(ref.watch(sessionStoreProvider)),
);

/// —— 会话列表控制器 ——
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

  Future<void> rename(String sessionId, String title) async {
    await ref.read(agentApiProvider).rename(sessionId, title);
    await load();
  }
}

final sessionsProvider =
    NotifierProvider<SessionsController, List<SessionSummary>>(
  SessionsController.new,
);

/// 对话气泡（连续 thinking/tool 折叠为 ProcessBlock，并携带 `show_media_cards_v1` 富媒体卡片）。
class Bubble {
  const Bubble({
    required this.id,
    required this.role,
    required this.text,
    this.thinking,
    this.toolCalls = const [],
    this.mediaCards = const [],
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
  final List<AgentMediaCard> mediaCards;
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
    this.skills = const <AgentSkill>[],
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
  final List<AgentSkill> skills;
  final String? modelRef; // null = 默认模型
  final List<String> thinkingLevels;
  final String? thinkingLevel;
  final bool loading;
  final bool sending;
  final String? error;

  static const Object _unset = Object();

  ChatState copyWith({
    Object? sessionId = _unset,
    List<Bubble>? bubbles,
    List<LlmModelOption>? models,
    List<AgentSkill>? skills,
    Object? modelRef = _unset,
    List<String>? thinkingLevels,
    Object? thinkingLevel = _unset,
    bool? loading,
    bool? sending,
    String? error,
    bool clearError = false,
  }) =>
      ChatState(
        sessionId:
            identical(sessionId, _unset) ? this.sessionId : sessionId as String?,
        bubbles: bubbles ?? this.bubbles,
        models: models ?? this.models,
        skills: skills ?? this.skills,
        modelRef:
            identical(modelRef, _unset) ? this.modelRef : modelRef as String?,
        thinkingLevels: thinkingLevels ?? this.thinkingLevels,
        thinkingLevel: identical(thinkingLevel, _unset)
            ? this.thinkingLevel
            : thinkingLevel as String?,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 服务器推来的一条 agent 执行事件（线格式 snake_case）。
class _AgentEvent {
  _AgentEvent._(this._json);

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

/// 对话页控制器：支持 SSE 增量流式渲染、技能加载、思维深度切换、上下文压缩与会话分叉。
class ChatController extends Notifier<ChatState> {
  static const _modelKey = 'agent_composer_model';
  static const _thinkingKey = 'agent_composer_thinking';
  bool _disposed = false;

  bool _sseSupported = true;
  StreamSubscription<SseEvent>? _streamSub;
  String? _lastEventId;

  static const _eventPathCandidates = <String>[
    '/api/v1/sessions',
    '/api/v1/agent/sessions',
  ];
  static String? _eventsBase;

  @override
  ChatState build() {
    ref.onDispose(() {
      _disposed = true;
      _streamSub?.cancel();
    });
    loadModels();
    loadSkills();
    _restorePrefs();
    return const ChatState();
  }

  AgentApi get _api => ref.read(agentApiProvider);

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModel = prefs.getString(_modelKey);
    final savedThinking = prefs.getString(_thinkingKey);
    if (_disposed) return;
    state = state.copyWith(
      modelRef: (savedModel != null && savedModel.isNotEmpty) ? savedModel : null,
      thinkingLevel: (savedThinking != null && savedThinking.isNotEmpty)
          ? savedThinking
          : null,
    );
  }

  Future<void> loadModels() async {
    try {
      final models = await _api.models();
      if (_disposed) return;
      final defaults = models.where((m) => m.isDefault).toList();
      final activeRef =
          state.modelRef ?? (defaults.isEmpty ? null : defaults.first.ref);
      LlmModelOption? matched;
      for (final m in models) {
        if (m.ref == activeRef) matched = m;
      }
      state = state.copyWith(
        models: models,
        modelRef: activeRef,
        thinkingLevels: matched?.thinkingLevels ??
            (defaults.isEmpty ? const <String>[] : defaults.first.thinkingLevels),
      );
    } catch (_) {
      // 模型列表拉不到不影响本地输入。
    }
  }

  Future<void> loadSkills() async {
    try {
      final skills = await _api.skills();
      if (_disposed || skills.isEmpty) return;
      state = state.copyWith(skills: skills);
    } catch (_) {}
  }

  Future<void> setModel(String? refId) async {
    final match = models(refId);
    state = state.copyWith(
      modelRef: refId,
      thinkingLevels: match?.thinkingLevels ?? const <String>[],
      thinkingLevel: null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, refId ?? '');
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

  /// 重置为空白新对话（供桌面/平板双栏或新建对话按钮调用）。
  void resetNewSession() {
    _streamSub?.cancel();
    _streamSub = null;
    state = state.copyWith(
      sessionId: null,
      bubbles: const <Bubble>[],
      loading: false,
      sending: false,
      clearError: true,
    );
  }

  /// 打开已有会话：拉转录并折叠渲染。
  Future<void> openSession(String sessionId) async {
    await _streamSub?.cancel();
    _streamSub = null;
    state = state.copyWith(
      sessionId: sessionId,
      loading: true,
      bubbles: const <Bubble>[],
      clearError: true,
    );
    await _loadTranscript(sessionId);
  }

  Future<void> _loadTranscript(String sessionId) async {
    try {
      final transcript = await _api.transcript(sessionId);
      if (_disposed) return;
      state = state.copyWith(
        bubbles: _bubblesFromTranscript(transcript),
        loading: false,
        clearError: true,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// transcript -> 气泡流：连续 thinking/tool 折叠为 ProcessBlock，并提取富媒体卡片。
  List<Bubble> _bubblesFromTranscript(SessionTranscript transcript) {
    final bubbles = <Bubble>[];
    var thinkingParts = <String>[];
    var toolCalls = <ToolCall>[];
    void flushProcess() {
      if (thinkingParts.isEmpty && toolCalls.isEmpty) return;
      final commands = toolCalls.length;
      final cards = AgentMediaCard.extractFromToolCalls(toolCalls);
      bubbles.add(Bubble(
        id: 'process-${bubbles.length}',
        role: 'process',
        text: '',
        thinking: thinkingParts.join('\n\n'),
        toolCalls: toolCalls,
        mediaCards: cards,
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
          text: '上下文已压缩：${entry.summary ?? ''}（$before → $after tokens）',
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
          if (message.thinking != null && message.thinking!.isNotEmpty) {
            thinkingParts = [...thinkingParts, message.thinking!];
          }
          if (message.toolCalls.isNotEmpty) {
            toolCalls = [...toolCalls, ...message.toolCalls];
          }
          flushProcess();
          if (message.content.trim().isNotEmpty) {
            bubbles.add(Bubble(
              id: entry.messageId ?? 'assistant-${bubbles.length}',
              role: 'assistant',
              text: message.content,
            ));
          }
      }
    }
    flushProcess();
    return bubbles;
  }

  /// 发送消息。
  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || state.sending) return;
    state = state.copyWith(
      sending: true,
      clearError: true,
      bubbles: [
        ...state.bubbles,
        Bubble(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          role: 'user',
          text: content,
        ),
        const Bubble(
          id: 'streaming',
          role: 'assistant',
          text: '',
          streaming: true,
        ),
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
          accepted['session_id']?.toString() ??
          accepted['id']?.toString();
      state = state.copyWith(sessionId: sessionId);
      unawaited(ref.read(sessionsProvider.notifier).load());
      if (sessionId != null && sessionId.isNotEmpty) {
        await _runToCompletion(sessionId);
      }
    } catch (e) {
      _dropStreaming();
      state = state.copyWith(error: e.toString());
    } finally {
      if (!_disposed) {
        state = state.copyWith(sending: false);
        unawaited(ref.read(sessionsProvider.notifier).load());
      }
    }
  }

  /// 改写用户消息并重发。
  Future<void> resendEdited(String messageId, String newContent) async {
    if (state.sending) return;
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    state = state.copyWith(
      sending: true,
      clearError: true,
      bubbles: [
        ...state.bubbles,
        const Bubble(
          id: 'streaming',
          role: 'assistant',
          text: '',
          streaming: true,
        ),
      ],
    );
    try {
      await _api.retry(
        sessionId: sessionId,
        messageId: messageId,
        content: newContent,
      );
      await _runToCompletion(sessionId);
    } catch (e) {
      _dropStreaming();
      state = state.copyWith(error: e.toString());
    } finally {
      if (!_disposed) state = state.copyWith(sending: false);
    }
  }

  /// 重新生成 AI 回复。
  Future<void> retryAssistant({String? messageId}) async {
    if (state.sending) return;
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    state = state.copyWith(
      sending: true,
      clearError: true,
      bubbles: [
        ...state.bubbles,
        const Bubble(
          id: 'streaming',
          role: 'assistant',
          text: '',
          streaming: true,
        ),
      ],
    );
    try {
      await _api.retry(
        sessionId: sessionId,
        messageId:
            (messageId != null && !messageId.startsWith('assistant-'))
                ? messageId
                : null,
      );
      await _runToCompletion(sessionId);
    } catch (e) {
      _dropStreaming();
      state = state.copyWith(error: e.toString());
    } finally {
      if (!_disposed) state = state.copyWith(sending: false);
    }
  }

  /// 手动压缩当前会话上下文。
  Future<bool> compactCurrentSession() async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.sending) return false;
    try {
      await _api.compactContext(sessionId);
      await _loadTranscript(sessionId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 从当前会话（或某条消息）分叉出新会话并切换过去。
  Future<String?> forkCurrentSession({String? entryId}) async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.sending) return null;
    try {
      final newId = await _api.forkSession(sessionId, entryId: entryId);
      if (newId != null && newId.isNotEmpty) {
        await ref.read(sessionsProvider.notifier).load();
        await openSession(newId);
        return newId;
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
    return null;
  }

  /// POST /api/v1/agent/sessions/{id}/stop：终止生成。
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

  Future<void> _runToCompletion(String sessionId) async {
    _lastEventId = null;
    if (_sseSupported) {
      if (await _streamSession(sessionId)) return;
    }
    await _pollUntilIdle(sessionId);
  }

  Future<bool> _streamSession(String sessionId) async {
    final sse = ref.read(agentSseClientProvider);
    final candidates = _eventsBase != null
        ? <String>['$_eventsBase/$sessionId/events']
        : [for (final b in _eventPathCandidates) '$b/$sessionId/events'];
    for (final path in candidates) {
      final result = await _consumeStream(sse, path, sessionId);
      if (result == null) continue;
      _eventsBase = path.substring(0, path.lastIndexOf('/'));
      return result;
    }
    _sseSupported = false;
    return false;
  }

  Future<bool?> _consumeStream(
    AgentSseClient sse,
    String path,
    String sessionId,
  ) async {
    final done = Completer<bool?>();
    var gotEvent = false;
    StreamSubscription<SseEvent>? sub;
    sub = sse.events(path, lastEventId: _lastEventId).listen(
      (event) {
        if (event.id != null) _lastEventId = event.id;
        gotEvent = true;
        final ev = _AgentEvent.parse(event.data);
        if (ev != null) _applyAgentEvent(ev);
        if (AgentSseClient.terminalEvents.contains(event.name) &&
            !done.isCompleted) {
          done.complete(true);
        }
      },
      onError: (Object e) {
        if (done.isCompleted) return;
        done.complete(
          e is SseUnsupportedException && !gotEvent ? null : false,
        );
      },
      onDone: () {
        if (!done.isCompleted) done.complete(false);
      },
    );
    _streamSub = sub;
    final result = await done.future;
    await sub.cancel();
    _streamSub = null;
    if (result == true) await _loadTranscript(sessionId);
    return result;
  }

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
        _patchBubbles(
          (bubbles) => [
            ...bubbles,
            Bubble(
              id: 'compact-${DateTime.now().microsecondsSinceEpoch}',
              role: 'system',
              text: '上下文已压缩：${ev.compactionSummary ?? ''}'
                  '（${ev.compactionBefore ?? '?'} → ${ev.compactionAfter ?? '?'} tokens）',
            ),
          ],
        );
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
        break;
    }
  }

  void _patchBubbles(List<Bubble> Function(List<Bubble>) fn) {
    state = state.copyWith(bubbles: fn(state.bubbles));
  }

  void _appendToProcess({String? thinkingDelta, ToolCall? toolCall}) {
    _patchBubbles((bubbles) {
      // 去掉占位空 assistant streaming 气泡，让过程卡排在正文前
      final cleaned = bubbles
          .where(
            (b) => !(b.id == 'streaming' && b.role == 'assistant' && b.text.isEmpty),
          )
          .toList();
      if (cleaned.isNotEmpty &&
          cleaned.last.role == 'process' &&
          cleaned.last.streaming) {
        final last = cleaned.last;
        final nextCalls = [
          ...last.toolCalls,
          if (toolCall != null) toolCall,
        ];
        final merged = Bubble(
          id: last.id,
          role: 'process',
          text: '',
          thinking: [
            if (last.thinking != null) last.thinking!,
            if (thinkingDelta != null && thinkingDelta.isNotEmpty) thinkingDelta,
          ].join(),
          toolCalls: nextCalls,
          mediaCards: AgentMediaCard.extractFromToolCalls(nextCalls),
          processSummary: _processSummary([
            if (((last.thinking ?? '') + (thinkingDelta ?? '')).trim().isNotEmpty)
              '已思考',
            if (nextCalls.isNotEmpty) '调用 ${nextCalls.length} 次工具',
          ]),
          streaming: true,
        );
        return [...cleaned.sublist(0, cleaned.length - 1), merged];
      }
      final calls = toolCall != null ? <ToolCall>[toolCall] : const <ToolCall>[];
      return [
        ...cleaned,
        Bubble(
          id: 'process-${DateTime.now().microsecondsSinceEpoch}',
          role: 'process',
          text: '',
          thinking:
              (thinkingDelta != null && thinkingDelta.isNotEmpty) ? thinkingDelta : null,
          toolCalls: calls,
          mediaCards: AgentMediaCard.extractFromToolCalls(calls),
          processSummary: _processSummary([
            if (thinkingDelta != null && thinkingDelta.trim().isNotEmpty) '已思考',
            if (toolCall != null) '调用 1 次工具',
          ]),
          streaming: true,
        ),
      ];
    });
  }

  void _appendToAssistant(String delta) {
    if (delta.isEmpty) return;
    _patchBubbles((bubbles) {
      if (bubbles.isNotEmpty &&
          bubbles.last.role == 'assistant' &&
          bubbles.last.streaming) {
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

  void _finishStreamingBubbles() {
    _patchBubbles(
      (bubbles) => [
        for (final b in bubbles)
          if (b.streaming) _unstream(b) else b,
      ],
    );
  }

  Bubble _unstream(Bubble b) => Bubble(
        id: b.id,
        role: b.role,
        text: b.text,
        thinking: b.thinking,
        toolCalls: b.toolCalls,
        mediaCards: b.mediaCards,
        toolOutput: b.toolOutput,
        toolError: b.toolError,
        processSummary: b.processSummary,
        streaming: false,
      );

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

final chatProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
