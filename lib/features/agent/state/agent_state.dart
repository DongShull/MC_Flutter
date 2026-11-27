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

/// 本地刚上传图片的预览路径缓存（attachment_id -> 本地文件路径）。
final Map<String, String> agentLocalImagePreviews = <String, String>{};

/// agent API 封装（1:1 对齐 iOS `AgentAPI.swift` & `Endpoints.swift`）。
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

  /// GET /api/v1/sessions/{id}：转录；不展示处理过程时携带 `?view=chat` 节省带宽。
  Future<SessionTranscript> transcript(
    String sessionId, {
    bool showProcess = true,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/sessions/${Uri.encodeComponent(sessionId)}',
      query: showProcess ? null : const {'view': 'chat'},
    );
    return SessionTranscript.fromJson(body);
  }

  /// POST /api/v1/sessions：开始或继续会话。
  /// 严格遵守三态契约：
  /// - `model == null`：省略 `'model'` 字段（延续会话上一轮模型 / 新会话用全局默认）；
  /// - `model == 'default'`：显式清回默认模型；
  /// - 其余非空串：显式指定模型引用。
  /// `thinkingLevel` 同理。
  Future<Map<String, dynamic>> start({
    required String content,
    List<String>? attachments,
    String? sessionId,
    String? model,
    String? thinkingLevel,
  }) async {
    final payload = <String, dynamic>{
      'content': content,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments,
      if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
      if (model != null && model.isNotEmpty) 'model': model,
      if (thinkingLevel != null && thinkingLevel.isNotEmpty)
        'thinking_level': thinkingLevel,
    };
    return _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/sessions',
      body: payload,
    );
  }

  /// POST /api/v1/sessions/attachments：上传图片附件（multipart 字段名 `file`）。
  Future<AgentAttachmentUpload> uploadAttachment({
    required String filePath,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    final body = await _client.postMultipart<Map<String, dynamic>>(
      Channel.general,
      '/api/v1/sessions/attachments',
      fileField: 'file',
      filePath: filePath,
      fileName: fileName,
      contentType: contentType,
    );
    return AgentAttachmentUpload.fromJson(body);
  }

  /// POST /api/v1/sessions/{id}/stop。
  Future<void> stop(String sessionId) => _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/sessions/${Uri.encodeComponent(sessionId)}/stop',
      );

  /// POST /api/v1/sessions/{id}/retry（锚定 user `message_id` 截断并重新提问）。
  Future<Map<String, dynamic>> retry({
    required String sessionId,
    required String messageId,
    String? content,
    String? model,
    String? thinkingLevel,
  }) =>
      _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/sessions/${Uri.encodeComponent(sessionId)}/retry',
        body: {
          'message_id': messageId,
          if (content != null) 'content': content,
          if (model != null && model.isNotEmpty) 'model': model,
          if (thinkingLevel != null && thinkingLevel.isNotEmpty)
            'thinking_level': thinkingLevel,
        },
      );

  /// POST /api/v1/sessions/{id}/fork：从当前或指定消息分叉出新会话。
  Future<String?> forkSession(String sessionId, {String? entryId}) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/sessions/${Uri.encodeComponent(sessionId)}/fork',
      body: {
        if (entryId != null && entryId.isNotEmpty) 'entry_id': entryId,
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
        '/api/v1/sessions/${Uri.encodeComponent(sessionId)}/compact-context',
      );

  /// PATCH /api/v1/sessions/{id}：重命名。
  Future<void> rename(String sessionId, String title) =>
      _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PATCH',
        '/api/v1/sessions/${Uri.encodeComponent(sessionId)}',
        body: {'title': title},
      );

  /// DELETE /api/v1/sessions/{id}。
  Future<void> delete(String sessionId) => _client.delete(
        Channel.general,
        '/api/v1/sessions/${Uri.encodeComponent(sessionId)}',
      );

  /// GET /api/v1/llm/providers：返回已配置服务商名称列表；探测失败返回 `null`（fail-open）。
  Future<List<String>?> llmProviders() async {
    try {
      final raw = await _client.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/llm/providers',
      );
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['providers'] ?? raw['items'] ?? raw['data'])
              : null);
      if (list is! List) return const <String>[];
      final seen = <String>{};
      final out = <String>[];
      for (final item in list) {
        if (item is! Map) continue;
        final name = (item['name'] ??
                item['provider_name'] ??
                item['label'] ??
                item['provider'] ??
                '')
            .toString()
            .trim();
        if (name.isNotEmpty && seen.add(name)) {
          out.add(name);
        }
      }
      return out;
    } catch (_) {
      return null;
    }
  }

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
            .whereType<Map>()
            .map((e) => AgentSkill.fromJson(Map<String, dynamic>.from(e)))
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
    } catch (_) {}
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

/// 对话气泡（支持 user / assistant / process / system / handoff / tool）。
class Bubble {
  const Bubble({
    required this.id,
    required this.role,
    required this.text,
    this.thinking,
    this.toolCalls = const [],
    this.mediaCards = const [],
    this.mediaCardGroups = const [],
    this.images = const [],
    this.handoff,
    this.userMessageId,
    this.toolOutput,
    this.toolError = false,
    this.processSummary,
    this.streaming = false,
    this.stopped = false,
    this.interrupted = false,
  });

  final String id;
  final String role; // user / assistant / tool / process / system / handoff
  final String text;
  final String? thinking;
  final List<ToolCall> toolCalls;
  final List<AgentMediaCard> mediaCards;
  final List<AgentMediaCardGroup> mediaCardGroups;
  final List<AgentTurnImage> images;
  final AgentHandoffInfo? handoff;

  /// 本轮对应的 user message_id（供 assistant 气泡重试精准锚定提问）。
  final String? userMessageId;
  final String? toolOutput;
  final bool toolError;
  final String? processSummary;
  final bool streaming;
  final bool stopped;
  final bool interrupted;

  Bubble copyWith({
    String? id,
    String? role,
    String? text,
    String? thinking,
    List<ToolCall>? toolCalls,
    List<AgentMediaCard>? mediaCards,
    List<AgentMediaCardGroup>? mediaCardGroups,
    List<AgentTurnImage>? images,
    AgentHandoffInfo? handoff,
    String? userMessageId,
    String? toolOutput,
    bool? toolError,
    String? processSummary,
    bool? streaming,
    bool? stopped,
    bool? interrupted,
  }) =>
      Bubble(
        id: id ?? this.id,
        role: role ?? this.role,
        text: text ?? this.text,
        thinking: thinking ?? this.thinking,
        toolCalls: toolCalls ?? this.toolCalls,
        mediaCards: mediaCards ?? this.mediaCards,
        mediaCardGroups: mediaCardGroups ?? this.mediaCardGroups,
        images: images ?? this.images,
        handoff: handoff ?? this.handoff,
        userMessageId: userMessageId ?? this.userMessageId,
        toolOutput: toolOutput ?? this.toolOutput,
        toolError: toolError ?? this.toolError,
        processSummary: processSummary ?? this.processSummary,
        streaming: streaming ?? this.streaming,
        stopped: stopped ?? this.stopped,
        interrupted: interrupted ?? this.interrupted,
      );
}

enum ChatRunOutcome { idle, working, complete, failed }

/// 对话页 UI 状态。
class ChatState {
  const ChatState({
    this.sessionId,
    this.sessionTitle,
    this.bubbles = const <Bubble>[],
    this.models = const <LlmModelOption>[],
    this.skills = const <AgentSkill>[],
    this.modelRef,
    this.modelWireOverride,
    this.thinkingLevels = const <String>[],
    this.thinkingLevel,
    this.thinkingWireOverride,
    this.llmConfigured,
    this.providerNames = const <String>[],
    this.showProcess = true,
    this.outcome = ChatRunOutcome.idle,
    this.loading = false,
    this.sending = false,
    this.error,
  });

  final String? sessionId;
  final String? sessionTitle;
  final List<Bubble> bubbles;
  final List<LlmModelOption> models;
  final List<AgentSkill> skills;

  /// 当前界面展示生效的模型 ref（`null` 表示全局默认）。
  final String? modelRef;

  /// 三态线上覆盖值：`null`=未手动改动（发送时省略）；`'default'`=显式切回默认；其余=显式 ref。
  final String? modelWireOverride;

  final List<String> thinkingLevels;
  final String? thinkingLevel;

  /// 三态线上覆盖值：`null`=未改动（发送时省略）；`'default'`=显式恢复默认；其余=显式档位。
  final String? thinkingWireOverride;

  /// `false`=明确未接入任何 LLM 服务商；`true`=已配置；`null`=探测中/探测失败（fail-open）。
  final bool? llmConfigured;
  final List<String> providerNames;
  final bool showProcess;
  final ChatRunOutcome outcome;
  final bool loading;
  final bool sending;
  final String? error;

  static const Object _unset = Object();

  ChatState copyWith({
    Object? sessionId = _unset,
    Object? sessionTitle = _unset,
    List<Bubble>? bubbles,
    List<LlmModelOption>? models,
    List<AgentSkill>? skills,
    Object? modelRef = _unset,
    Object? modelWireOverride = _unset,
    List<String>? thinkingLevels,
    Object? thinkingLevel = _unset,
    Object? thinkingWireOverride = _unset,
    Object? llmConfigured = _unset,
    List<String>? providerNames,
    bool? showProcess,
    ChatRunOutcome? outcome,
    bool? loading,
    bool? sending,
    String? error,
    bool clearError = false,
  }) =>
      ChatState(
        sessionId: identical(sessionId, _unset)
            ? this.sessionId
            : sessionId as String?,
        sessionTitle: identical(sessionTitle, _unset)
            ? this.sessionTitle
            : sessionTitle as String?,
        bubbles: bubbles ?? this.bubbles,
        models: models ?? this.models,
        skills: skills ?? this.skills,
        modelRef: identical(modelRef, _unset)
            ? this.modelRef
            : modelRef as String?,
        modelWireOverride: identical(modelWireOverride, _unset)
            ? this.modelWireOverride
            : modelWireOverride as String?,
        thinkingLevels: thinkingLevels ?? this.thinkingLevels,
        thinkingLevel: identical(thinkingLevel, _unset)
            ? this.thinkingLevel
            : thinkingLevel as String?,
        thinkingWireOverride: identical(thinkingWireOverride, _unset)
            ? this.thinkingWireOverride
            : thinkingWireOverride as String?,
        llmConfigured: identical(llmConfigured, _unset)
            ? this.llmConfigured
            : llmConfigured as bool?,
        providerNames: providerNames ?? this.providerNames,
        showProcess: showProcess ?? this.showProcess,
        outcome: outcome ?? this.outcome,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 服务器推来的一条 agent 执行事件（对齐 iOS `AgentStreamEvent`）。
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
  String? get toolCallId =>
      _json['tool_call_id']?.toString() ?? _json['toolCallId']?.toString();

  ToolCall? get toolCall {
    final tc = _json['tool_call'] ?? _json['toolCall'];
    if (tc is Map) {
      return ToolCall.fromJson(Map<String, dynamic>.from(tc));
    }
    return null;
  }

  ({String toolCallId, String output, bool isError})? get toolResult {
    final tr = _json['tool_result'] ?? _json['toolResult'];
    if (tr is! Map) return null;
    final m = Map<String, dynamic>.from(tr);
    final id = (m['tool_call_id'] ?? m['toolCallId'] ?? '').toString();
    if (id.isEmpty) return null;
    return (
      toolCallId: id,
      output: (m['output'] ?? '').toString(),
      isError: m['is_error'] == true || m['isError'] == true,
    );
  }

  String? get error => _json['error']?.toString();
  String? get compactionSummary =>
      (_json['compaction'] is Map ? _json['compaction']['summary'] : null)
          ?.toString();
  int? get compactionBefore => (_json['compaction'] is Map
          ? _json['compaction']['tokens_before']
          : null) is num
      ? (_json['compaction']['tokens_before'] as num).toInt()
      : null;
  int? get compactionAfter => (_json['compaction'] is Map
          ? _json['compaction']['tokens_after']
          : null) is num
      ? (_json['compaction']['tokens_after'] as num).toInt()
      : null;
}

/// 对话页控制器：SSE 实时流（含 tool_call_delta / tool_result）、图片上传、三态模型/思考同步、
/// LLM 门禁探测、会话转录回放与重试。
class ChatController extends Notifier<ChatState> {
  static const _modelKey = 'agent_composer_model';
  static const _thinkingKey = 'agent_composer_thinking';
  static const _showProcessKey = 'agent_show_process';

  bool _disposed = false;
  bool _sseSupported = true;
  StreamSubscription<SseEvent>? _streamSub;
  String? _lastEventId;
  String? _savedModelPref;
  String? _savedThinkingPref;

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
    unawaited(_initCatalog());
    return const ChatState();
  }

  AgentApi get _api => ref.read(agentApiProvider);

  Future<void> _initCatalog() async {
    await _restorePrefs();
    await Future.wait([
      checkLlmProviders(),
      loadModels(),
      loadSkills(),
    ]);
  }

  Future<void> _restorePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModel = prefs.getString(_modelKey);
      final savedThinking = prefs.getString(_thinkingKey);
      final showProc = prefs.getBool(_showProcessKey) ?? true;
      if (_disposed) return;
      _savedModelPref =
          (savedModel != null && savedModel.isNotEmpty) ? savedModel : null;
      _savedThinkingPref = (savedThinking != null && savedThinking.isNotEmpty)
          ? savedThinking
          : null;
      state = state.copyWith(
        showProcess: showProc,
        modelRef: state.sessionId == null ? _savedModelPref : state.modelRef,
        thinkingLevel:
            state.sessionId == null ? _savedThinkingPref : state.thinkingLevel,
      );
    } catch (_) {}
  }

  Future<void> checkLlmProviders() async {
    final providers = await _api.llmProviders();
    if (_disposed) return;
    if (providers == null) {
      // fail-open：探测失败不锁死输入
      return;
    }
    state = state.copyWith(
      llmConfigured: providers.isNotEmpty,
      providerNames: providers,
    );
  }

  Future<void> loadModels() async {
    try {
      final models = await _api.models();
      if (_disposed) return;
      final reconciled = _reconcileChoice(
        models: models,
        modelRef: state.modelRef ?? _savedModelPref,
        thinkingLevel: state.thinkingLevel ?? _savedThinkingPref,
      );
      final providerSet = <String>{...state.providerNames};
      for (final m in models) {
        if (m.providerName.isNotEmpty) providerSet.add(m.providerName);
      }
      state = state.copyWith(
        models: models,
        providerNames: providerSet.toList(),
        modelRef: reconciled.modelRef,
        thinkingLevels: reconciled.thinkingLevels,
        thinkingLevel: reconciled.thinkingLevel,
      );
    } catch (_) {}
  }

  ({String? modelRef, List<String> thinkingLevels, String? thinkingLevel})
      _reconcileChoice({
    required List<LlmModelOption> models,
    required String? modelRef,
    required String? thinkingLevel,
  }) {
    if (models.isEmpty) {
      return (
        modelRef: modelRef,
        thinkingLevels: const <String>[],
        thinkingLevel: thinkingLevel,
      );
    }
    LlmModelOption? matched;
    String? effectiveRef = modelRef;
    if (modelRef != null && modelRef.isNotEmpty) {
      for (final m in models) {
        if (m.ref == modelRef) {
          matched = m;
          break;
        }
      }
      // 缓存模型已失效 → 丢弃缓存模型与思考档位
      if (matched == null) {
        effectiveRef = null;
        thinkingLevel = null;
      }
    }
    matched ??= models.where((m) => m.isDefault).firstOrNull ?? models.first;
    final stops = AgentThinking.stops(matched.thinkingLevels);
    final validThinking = (thinkingLevel != null && stops.contains(thinkingLevel))
        ? thinkingLevel
        : null;
    return (
      modelRef: effectiveRef,
      thinkingLevels: stops,
      thinkingLevel: validThinking,
    );
  }

  Future<void> loadSkills() async {
    try {
      final skills = await _api.skills();
      if (_disposed || skills.isEmpty) return;
      state = state.copyWith(skills: skills);
    } catch (_) {}
  }

  /// 切换模型：选默认项记 `modelWireOverride = 'default'`（在旧会话里显式清回默认），
  /// 同时把思考档位清回默认。
  Future<void> setModel(String? refId) async {
    final option = _resolveOption(refId);
    final isDefaultSelection = refId == null || (option?.isDefault == true);
    final nextModelRef = isDefaultSelection ? null : refId;
    final stops = AgentThinking.stops(option?.thinkingLevels ?? const []);
    state = state.copyWith(
      modelRef: nextModelRef,
      modelWireOverride: isDefaultSelection ? 'default' : nextModelRef,
      thinkingLevels: stops,
      thinkingLevel: null,
      thinkingWireOverride: 'default',
    );
    _savedModelPref = nextModelRef;
    _savedThinkingPref = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelKey, nextModelRef ?? '');
      await prefs.setString(_thinkingKey, '');
    } catch (_) {}
  }

  LlmModelOption? _resolveOption(String? refId) {
    if (state.models.isEmpty) return null;
    if (refId != null && refId.isNotEmpty) {
      for (final m in state.models) {
        if (m.ref == refId) return m;
      }
    }
    return state.models.where((m) => m.isDefault).firstOrNull ??
        state.models.first;
  }

  Future<void> setThinkingLevel(String? level) async {
    final normalized = (level != null && level.isNotEmpty) ? level : null;
    state = state.copyWith(
      thinkingLevel: normalized,
      thinkingWireOverride: normalized ?? 'default',
    );
    _savedThinkingPref = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_thinkingKey, normalized ?? '');
    } catch (_) {}
  }

  Future<void> setShowProcess(bool show) async {
    if (state.showProcess == show) return;
    state = state.copyWith(showProcess: show);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_showProcessKey, show);
    } catch (_) {}
    final sid = state.sessionId;
    if (sid != null && !state.sending) {
      await _loadTranscript(sid);
    }
  }

  /// 上传单张图片附件（POST /api/v1/sessions/attachments）。
  Future<AgentTurnImage> uploadImage({
    required String filePath,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    final uploaded = await _api.uploadAttachment(
      filePath: filePath,
      fileName: fileName,
      contentType: contentType,
    );
    agentLocalImagePreviews[uploaded.attachmentId] = filePath;
    return AgentTurnImage(
      attachmentId: uploaded.attachmentId,
      name: uploaded.name,
      localPath: filePath,
    );
  }

  /// 重置为空白新对话（沿用本机记忆的模型/思考档位，不携带旧会话覆盖）。
  void resetNewSession() {
    _streamSub?.cancel();
    _streamSub = null;
    final rec = _reconcileChoice(
      models: state.models,
      modelRef: _savedModelPref,
      thinkingLevel: _savedThinkingPref,
    );
    state = state.copyWith(
      sessionId: null,
      sessionTitle: null,
      bubbles: const <Bubble>[],
      modelRef: rec.modelRef,
      modelWireOverride: rec.modelRef,
      thinkingLevels: rec.thinkingLevels,
      thinkingLevel: rec.thinkingLevel,
      thinkingWireOverride: rec.thinkingLevel,
      outcome: ChatRunOutcome.idle,
      loading: false,
      sending: false,
      clearError: true,
    );
  }

  /// 打开已有会话：拉转录并同步该会话最后生效的模型/思考档位。
  Future<void> openSession(String sessionId) async {
    await _streamSub?.cancel();
    _streamSub = null;
    state = state.copyWith(
      sessionId: sessionId,
      loading: true,
      bubbles: const <Bubble>[],
      modelWireOverride: null,
      thinkingWireOverride: null,
      outcome: ChatRunOutcome.idle,
      clearError: true,
    );
    await _loadTranscript(sessionId);
  }

  Future<void> _loadTranscript(String sessionId) async {
    try {
      final transcript = await _api.transcript(
        sessionId,
        showProcess: state.showProcess,
      );
      if (_disposed) return;

      // 从转录最近一条 user 行同步会话当前生效的模型与思考档位
      String? sessionModel;
      String? sessionThinking;
      for (final entry in transcript.entries.reversed) {
        if (entry.message?.role == 'user') {
          if (sessionModel == null &&
              entry.model != null &&
              entry.model!.isNotEmpty) {
            sessionModel = entry.model;
          }
          if (sessionThinking == null &&
              entry.thinkingLevel != null &&
              entry.thinkingLevel!.isNotEmpty) {
            sessionThinking = entry.thinkingLevel;
          }
          if (sessionModel != null && sessionThinking != null) break;
        }
      }
      final rec = _reconcileChoice(
        models: state.models,
        modelRef: sessionModel,
        thinkingLevel: sessionThinking,
      );
      final bubbles = _bubblesFromTranscript(transcript);
      final stillRunning = transcript.session?.running == true;

      state = state.copyWith(
        sessionTitle: transcript.session?.displayTitle ?? state.sessionTitle,
        bubbles: bubbles,
        modelRef: rec.modelRef,
        thinkingLevels: rec.thinkingLevels,
        thinkingLevel: rec.thinkingLevel,
        loading: false,
        sending: stillRunning,
        outcome: stillRunning ? ChatRunOutcome.working : ChatRunOutcome.idle,
        clearError: true,
      );
      if (stillRunning) {
        unawaited(_runToCompletion(sessionId).whenComplete(() {
          if (!_disposed) {
            state = state.copyWith(sending: false);
          }
        }));
      }
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        loading: false,
        outcome: ChatRunOutcome.failed,
        error: e.toString(),
      );
    }
  }

  /// transcript -> 气泡流：解析 handoff、compaction、user（剥离 `<skill>` XML + 图片）、
  /// process（折叠思考 + 工具调用 + 合并 tool_call_id 输出 + 抽出 show_media_cards_v1）、
  /// assistant（含 stopped/interrupted 标记与对应 userMessageId）。
  List<Bubble> _bubblesFromTranscript(SessionTranscript transcript) {
    final bubbles = <Bubble>[];
    var thinkingParts = <String>[];
    var toolCalls = <ToolCall>[];
    String? currentUserMsgId;
    var lastTurnClosed = true;
    var lastTurnStopped = false;

    void flushProcess() {
      if (thinkingParts.isEmpty && toolCalls.isEmpty) return;
      final legacyCards = AgentMediaCard.extractFromToolCalls(toolCalls);
      final liveGroups = AgentMediaCardGroup.extractFromToolCalls(toolCalls);
      final visibleTools = toolCalls
          .where((t) => !AgentMediaCardGroup.isMediaCardsTool(t.name))
          .toList();
      final commands = visibleTools.where((t) => t.name == 'bash').length;
      final others = visibleTools.length - commands;
      final summaryParts = <String>[
        if (thinkingParts.isNotEmpty) '已思考',
        if (commands > 0) '执行 $commands 次命令',
        if (others > 0) '调用 $others 次工具',
      ];
      bubbles.add(
        Bubble(
          id: 'process-${bubbles.length}',
          role: 'process',
          text: '',
          thinking: thinkingParts.join('\n\n'),
          toolCalls: List<ToolCall>.from(toolCalls),
          mediaCards: legacyCards,
          mediaCardGroups: liveGroups,
          userMessageId: currentUserMsgId,
          processSummary: summaryParts.isEmpty ? '处理过程' : summaryParts.join('，'),
        ),
      );
      thinkingParts = <String>[];
      toolCalls = <ToolCall>[];
    }

    void closePreviousTurnIfNeeded() {
      if (currentUserMsgId == null) return;
      if (!lastTurnClosed && !lastTurnStopped) {
        // 本轮未以无工具调用正文收尾，标记中断
        if (bubbles.isNotEmpty && bubbles.last.role == 'assistant') {
          bubbles[bubbles.length - 1] =
              bubbles.last.copyWith(interrupted: true);
        } else {
          bubbles.add(
            Bubble(
              id: 'interrupted-${bubbles.length}',
              role: 'assistant',
              text: '',
              userMessageId: currentUserMsgId,
              interrupted: true,
            ),
          );
        }
      }
    }

    for (final entry in transcript.entries) {
      if (entry.type == 'handoff' &&
          entry.sourceSessionId != null &&
          entry.sourceSessionId!.isNotEmpty) {
        flushProcess();
        bubbles.add(
          Bubble(
            id: 'handoff-${entry.handoffId ?? entry.sourceSessionId}',
            role: 'handoff',
            text: '',
            handoff: AgentHandoffInfo(
              sourceSessionId: entry.sourceSessionId!,
              sourceTitle: entry.sourceTitle,
            ),
          ),
        );
        continue;
      }

      if (entry.type == 'compaction' || entry.compactionId != null) {
        flushProcess();
        final before = entry.tokensBefore?.toString() ?? '?';
        final after = entry.tokensAfter?.toString() ?? '?';
        bubbles.add(
          Bubble(
            id: 'compact-${entry.compactionId ?? bubbles.length}',
            role: 'system',
            text: '上下文已压缩：${entry.summary ?? ''}（$before → $after tokens）',
          ),
        );
        continue;
      }

      final message = entry.message;
      if (message == null) continue;

      switch (message.role) {
        case 'user':
          flushProcess();
          closePreviousTurnIfNeeded();
          currentUserMsgId = entry.messageId ?? 'user-${bubbles.length}';
          lastTurnClosed = false;
          lastTurnStopped = false;
          bubbles.add(
            Bubble(
              id: currentUserMsgId,
              role: 'user',
              text: AgentSkillText.toTokenForm(message.content),
              images: message.images,
              userMessageId: currentUserMsgId,
            ),
          );
          break;
        case 'tool':
          final callId = message.toolCallId;
          if (callId != null && callId.isNotEmpty) {
            var matched = false;
            for (var i = toolCalls.length - 1; i >= 0; i--) {
              if (toolCalls[i].id == callId) {
                toolCalls[i] = toolCalls[i].copyWith(
                  output: message.content,
                  isError: message.content.startsWith('工具执行失败：'),
                );
                matched = true;
                break;
              }
            }
            if (!matched) {
              // 往前查找已 flush 进 process 气泡的工具调用
              for (var bIdx = bubbles.length - 1; bIdx >= 0; bIdx--) {
                if (bubbles[bIdx].role != 'process') continue;
                final list = List<ToolCall>.from(bubbles[bIdx].toolCalls);
                for (var i = list.length - 1; i >= 0; i--) {
                  if (list[i].id == callId) {
                    list[i] = list[i].copyWith(
                      output: message.content,
                      isError: message.content.startsWith('工具执行失败：'),
                    );
                    bubbles[bIdx] = bubbles[bIdx].copyWith(
                      toolCalls: list,
                      mediaCardGroups:
                          AgentMediaCardGroup.extractFromToolCalls(list),
                    );
                    matched = true;
                    break;
                  }
                }
                if (matched) break;
              }
            }
          } else if (message.toolCalls.isNotEmpty) {
            toolCalls = [...toolCalls, ...message.toolCalls];
          }
          break;
        case 'thinking':
          if (message.content.isNotEmpty) {
            thinkingParts = [...thinkingParts, message.content];
          }
          break;
        default:
          if (message.thinking != null && message.thinking!.isNotEmpty) {
            thinkingParts = [...thinkingParts, message.thinking!];
          }
          if (message.toolCalls.isNotEmpty) {
            toolCalls = [...toolCalls, ...message.toolCalls];
          }
          final aborted = entry.finishReason == 'aborted';
          if (aborted) lastTurnStopped = true;
          lastTurnClosed = message.toolCalls.isEmpty && !aborted;

          flushProcess();
          if (message.content.trim().isNotEmpty || aborted) {
            bubbles.add(
              Bubble(
                id: entry.messageId ?? 'assistant-${bubbles.length}',
                role: 'assistant',
                text: message.content,
                userMessageId: currentUserMsgId,
                stopped: aborted,
              ),
            );
          }
          break;
      }
    }
    flushProcess();
    closePreviousTurnIfNeeded();
    return bubbles;
  }

  /// 发送消息（支持文本 + 图片附件）；返回会话 ID（新建会话时供页面替换路由 `/agent/new` -> `/agent/session/:id`）。
  Future<String?> send(
    String text, {
    List<AgentTurnImage> images = const [],
  }) async {
    final content = text.trim();
    if ((content.isEmpty && images.isEmpty) || state.sending) return null;

    final localUserId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final isNewSession = state.sessionId == null;
    final wireModel = isNewSession ? state.modelRef : state.modelWireOverride;
    final wireThinking =
        isNewSession ? state.thinkingLevel : state.thinkingWireOverride;

    state = state.copyWith(
      sending: true,
      outcome: ChatRunOutcome.working,
      clearError: true,
      bubbles: [
        ...state.bubbles,
        Bubble(
          id: localUserId,
          role: 'user',
          text: content,
          images: images,
          userMessageId: localUserId,
        ),
        Bubble(
          id: 'streaming',
          role: 'assistant',
          text: '',
          userMessageId: localUserId,
          streaming: true,
        ),
      ],
    );
    String? activeSessionId = state.sessionId;
    try {
      final accepted = await _api.start(
        content: content,
        attachments: images.isEmpty
            ? null
            : images.map((e) => e.attachmentId).toList(),
        sessionId: state.sessionId,
        model: wireModel,
        thinkingLevel: wireThinking,
      );
      activeSessionId = state.sessionId ??
          accepted['sessionId']?.toString() ??
          accepted['session_id']?.toString() ??
          accepted['id']?.toString();
      final acceptedMsgId =
          accepted['message_id']?.toString() ?? accepted['messageId']?.toString();

      // 把乐观用户消息 id 替换成服务端返回的真实 message_id
      final patchedBubbles = (acceptedMsgId != null && acceptedMsgId.isNotEmpty)
          ? state.bubbles
              .map(
                (b) => b.id == localUserId
                    ? b.copyWith(id: acceptedMsgId, userMessageId: acceptedMsgId)
                    : (b.userMessageId == localUserId
                        ? b.copyWith(userMessageId: acceptedMsgId)
                        : b),
              )
              .toList()
          : state.bubbles;

      state = state.copyWith(
        sessionId: activeSessionId,
        bubbles: patchedBubbles,
        modelWireOverride: null,
        thinkingWireOverride: null,
      );
      unawaited(ref.read(sessionsProvider.notifier).load());
      if (activeSessionId != null && activeSessionId.isNotEmpty) {
        await _runToCompletion(activeSessionId);
      }
      return activeSessionId;
    } catch (e) {
      _dropStreaming();
      state = state.copyWith(
        outcome: ChatRunOutcome.failed,
        error: e.toString(),
      );
      return activeSessionId;
    } finally {
      if (!_disposed) {
        state = state.copyWith(sending: false);
        unawaited(ref.read(sessionsProvider.notifier).load());
      }
    }
  }

  /// 改写某条用户消息并重发（截断该消息之后的全部轮次）。
  Future<void> resendEdited(String messageId, String newContent) async {
    if (state.sending) return;
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    final cutIdx = state.bubbles.indexWhere((b) => b.id == messageId);
    final preserved = cutIdx >= 0
        ? state.bubbles.sublist(0, cutIdx)
        : state.bubbles;
    final originalImages =
        cutIdx >= 0 ? state.bubbles[cutIdx].images : const <AgentTurnImage>[];

    state = state.copyWith(
      sending: true,
      outcome: ChatRunOutcome.working,
      clearError: true,
      bubbles: [
        ...preserved,
        Bubble(
          id: messageId,
          role: 'user',
          text: newContent,
          images: originalImages,
          userMessageId: messageId,
        ),
        Bubble(
          id: 'streaming',
          role: 'assistant',
          text: '',
          userMessageId: messageId,
          streaming: true,
        ),
      ],
    );
    try {
      await _api.retry(
        sessionId: sessionId,
        messageId: messageId,
        content: newContent,
        model: state.modelWireOverride,
        thinkingLevel: state.thinkingWireOverride,
      );
      state = state.copyWith(
        modelWireOverride: null,
        thinkingWireOverride: null,
      );
      await _runToCompletion(sessionId);
    } catch (e) {
      _dropStreaming();
      state = state.copyWith(
        outcome: ChatRunOutcome.failed,
        error: e.toString(),
      );
      await _loadTranscript(sessionId);
    } finally {
      if (!_disposed) state = state.copyWith(sending: false);
    }
  }

  /// 原文重试某一轮（必须传入 user `message_id`）。
  Future<void> retryAssistant({String? messageId}) async {
    if (state.sending) return;
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    // 解析对应的 user message_id
    String? userMsgId;
    if (messageId != null && messageId.isNotEmpty) {
      final hit = state.bubbles.where((b) => b.id == messageId).firstOrNull;
      if (hit != null) {
        userMsgId = hit.role == 'user' ? hit.id : hit.userMessageId;
      }
    }
    userMsgId ??= state.bubbles
        .where((b) => b.role == 'user' && !b.id.startsWith('local-'))
        .lastOrNull
        ?.id;
    if (userMsgId == null || userMsgId.isEmpty) {
      state = state.copyWith(error: '找不到可重试的提问记录');
      return;
    }

    final cutIdx = state.bubbles.indexWhere((b) => b.id == userMsgId);
    final preserved = cutIdx >= 0
        ? state.bubbles.sublist(0, cutIdx + 1)
        : state.bubbles;

    state = state.copyWith(
      sending: true,
      outcome: ChatRunOutcome.working,
      clearError: true,
      bubbles: [
        ...preserved,
        Bubble(
          id: 'streaming',
          role: 'assistant',
          text: '',
          userMessageId: userMsgId,
          streaming: true,
        ),
      ],
    );
    try {
      await _api.retry(
        sessionId: sessionId,
        messageId: userMsgId,
        model: state.modelWireOverride,
        thinkingLevel: state.thinkingWireOverride,
      );
      state = state.copyWith(
        modelWireOverride: null,
        thinkingWireOverride: null,
      );
      await _runToCompletion(sessionId);
    } catch (e) {
      _dropStreaming();
      state = state.copyWith(
        outcome: ChatRunOutcome.failed,
        error: e.toString(),
      );
      await _loadTranscript(sessionId);
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

  /// POST /api/v1/sessions/{id}/stop：终止生成。
  Future<void> stop() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    await _streamSub?.cancel();
    _streamSub = null;
    try {
      await _api.stop(sessionId);
    } finally {
      _finishStreamingBubbles(stopped: true);
      state = state.copyWith(sending: false, outcome: ChatRunOutcome.idle);
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
    final encoded = Uri.encodeComponent(sessionId);
    final candidates = _eventsBase != null
        ? <String>['$_eventsBase/$encoded/events']
        : [for (final b in _eventPathCandidates) '$b/$encoded/events'];
    for (final path in candidates) {
      final result = await _consumeStream(sse, path, sessionId);
      if (result == null) continue;
      _eventsBase = path.substring(0, path.lastIndexOf('/$encoded/events'));
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
        if (ev.toolCall != null) {
          _appendToProcess(
            toolCall: ev.toolCall!.copyWith(
              arguments: '',
              argsDone: false,
            ),
          );
        }
        break;
      case 'tool_call_delta':
        _appendToolCallDelta(ev.toolCallId, ev.delta);
        break;
      case 'tool_call':
        if (ev.toolCall != null) {
          _finalizeToolCall(ev.toolCall!.copyWith(argsDone: true));
        }
        break;
      case 'tool_result':
        final res = ev.toolResult;
        if (res != null) {
          _applyToolResult(res.toolCallId, res.output, res.isError);
        }
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
        state = state.copyWith(
          outcome: ChatRunOutcome.failed,
          error: ev.error ?? 'Agent 运行失败',
        );
        break;
      case 'agent_done':
        _finishStreamingBubbles();
        state = state.copyWith(outcome: ChatRunOutcome.complete);
        break;
      case 'agent_cancelled':
        _finishStreamingBubbles(stopped: true);
        state = state.copyWith(outcome: ChatRunOutcome.idle);
        break;
      default:
        break;
    }
  }

  void _appendToProcess({String? thinkingDelta, ToolCall? toolCall}) {
    _patchBubbles((bubbles) {
      final list = List<Bubble>.from(bubbles);
      // 去掉末尾空占位 streaming assistant 气泡，使 process 块位于回复正文前
      if (list.isNotEmpty &&
          list.last.role == 'assistant' &&
          list.last.streaming &&
          list.last.text.isEmpty) {
        list.removeLast();
      }
      final last = list.isEmpty ? null : list.last;
      if (last != null && last.role == 'process' && last.streaming) {
        final nextThinking = (last.thinking ?? '') + (thinkingDelta ?? '');
        final nextCalls =
            toolCall == null ? last.toolCalls : [...last.toolCalls, toolCall];
        list[list.length - 1] = last.copyWith(
          thinking: nextThinking,
          toolCalls: nextCalls,
          mediaCards: AgentMediaCard.extractFromToolCalls(nextCalls),
          mediaCardGroups: AgentMediaCardGroup.extractFromToolCalls(nextCalls),
          processSummary: _liveProcessSummary(nextThinking, nextCalls),
        );
      } else {
        final calls = toolCall == null ? const <ToolCall>[] : [toolCall];
        list.add(
          Bubble(
            id: 'process-live-${list.length}',
            role: 'process',
            text: '',
            thinking: thinkingDelta ?? '',
            toolCalls: calls,
            mediaCards: AgentMediaCard.extractFromToolCalls(calls),
            mediaCardGroups: AgentMediaCardGroup.extractFromToolCalls(calls),
            processSummary: _liveProcessSummary(thinkingDelta ?? '', calls),
            streaming: true,
          ),
        );
      }
      return list;
    });
  }

  void _appendToolCallDelta(String? toolCallId, String delta) {
    if (delta.isEmpty) return;
    _patchToolInLatestProcess(
      match: (t) =>
          (toolCallId != null && toolCallId.isNotEmpty)
              ? t.id == toolCallId
              : t.streaming,
      fallbackMatch: (t) => t.streaming,
      patch: (t) => t.copyWith(arguments: (t.arguments ?? '') + delta),
    );
  }

  void _finalizeToolCall(ToolCall finalized) {
    var patched = false;
    _patchToolInLatestProcess(
      match: (t) => t.id == finalized.id,
      patch: (t) {
        patched = true;
        return t.copyWith(
          name: finalized.name,
          arguments: finalized.arguments,
          argsDone: true,
        );
      },
    );
    if (!patched) {
      _appendToProcess(toolCall: finalized);
    }
  }

  void _applyToolResult(String toolCallId, String output, bool isError) {
    _patchToolInLatestProcess(
      match: (t) => t.id == toolCallId,
      patch: (t) => t.copyWith(
        output: output,
        isError: isError,
        argsDone: true,
      ),
    );
  }

  void _patchToolInLatestProcess({
    required bool Function(ToolCall) match,
    bool Function(ToolCall)? fallbackMatch,
    required ToolCall Function(ToolCall) patch,
  }) {
    _patchBubbles((bubbles) {
      final list = List<Bubble>.from(bubbles);
      for (var bIdx = list.length - 1; bIdx >= 0; bIdx--) {
        final b = list[bIdx];
        if (b.role != 'process') continue;
        final calls = List<ToolCall>.from(b.toolCalls);
        var hit = -1;
        for (var i = calls.length - 1; i >= 0; i--) {
          if (match(calls[i])) {
            hit = i;
            break;
          }
        }
        if (hit < 0 && fallbackMatch != null) {
          for (var i = calls.length - 1; i >= 0; i--) {
            if (fallbackMatch(calls[i])) {
              hit = i;
              break;
            }
          }
        }
        if (hit >= 0) {
          calls[hit] = patch(calls[hit]);
          list[bIdx] = b.copyWith(
            toolCalls: calls,
            mediaCards: AgentMediaCard.extractFromToolCalls(calls),
            mediaCardGroups: AgentMediaCardGroup.extractFromToolCalls(calls),
            processSummary: _liveProcessSummary(b.thinking ?? '', calls),
          );
          return list;
        }
      }
      return list;
    });
  }

  String _liveProcessSummary(String thinking, List<ToolCall> calls) {
    final visible = calls
        .where((t) => !AgentMediaCardGroup.isMediaCardsTool(t.name))
        .toList();
    if (visible.isNotEmpty) {
      final tail = visible.last;
      if (tail.streaming) return '正在准备工具 ${tail.name}…';
      if (tail.output == null) return '正在执行 ${tail.name}…';
    }
    return [
      if (thinking.isNotEmpty) '思考中',
      if (visible.isNotEmpty) '已调用 ${visible.length} 次工具',
    ].join(' · ');
  }

  void _appendToAssistant(String delta) {
    if (delta.isEmpty) return;
    _patchBubbles((bubbles) {
      final list = List<Bubble>.from(bubbles);
      if (list.isNotEmpty && list.last.role == 'process' && list.last.streaming) {
        list[list.length - 1] = list.last.copyWith(streaming: false);
      }
      if (list.isNotEmpty &&
          list.last.role == 'assistant' &&
          list.last.streaming) {
        list[list.length - 1] =
            list.last.copyWith(text: list.last.text + delta);
      } else {
        final lastUserId = list
            .where((b) => b.role == 'user')
            .lastOrNull
            ?.userMessageId;
        list.add(
          Bubble(
            id: 'streaming-${list.length}',
            role: 'assistant',
            text: delta,
            userMessageId: lastUserId,
            streaming: true,
          ),
        );
      }
      return list;
    });
  }

  void _finishStreamingBubbles({bool stopped = false}) {
    _patchBubbles((bubbles) {
      final out = <Bubble>[];
      for (var i = 0; i < bubbles.length; i++) {
        final b = bubbles[i];
        if (b.streaming && b.role == 'assistant' && b.text.isEmpty && !stopped) {
          continue;
        }
        out.add(
          b.copyWith(
            streaming: false,
            stopped: stopped && b.role == 'assistant' && i == bubbles.length - 1
                ? true
                : b.stopped,
          ),
        );
      }
      return out;
    });
  }

  void _dropStreaming() {
    _patchBubbles((bubbles) => bubbles.where((b) => !b.streaming).toList());
  }

  void _patchBubbles(List<Bubble> Function(List<Bubble>) transform) {
    if (_disposed) return;
    state = state.copyWith(bubbles: transform(state.bubbles));
  }

  /// SSE 不可用时兜底：每 1.2s 轮询会话列表与转录直到运行结束。
  Future<void> _pollUntilIdle(String sessionId) async {
    for (var i = 0; i < 120; i++) {
      if (_disposed) return;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (_disposed) return;
      try {
        final list = await _api.sessions();
        final current = list.where((s) => s.id == sessionId).firstOrNull;
        await _loadTranscript(sessionId);
        if (current == null || !current.running) {
          if (!_disposed) {
            state = state.copyWith(outcome: ChatRunOutcome.complete);
          }
          return;
        }
      } catch (_) {}
    }
  }
}

final chatProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
