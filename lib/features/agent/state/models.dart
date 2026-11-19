
// AI 助手域模型（1:1 对齐 Kotlin feature/agent 的协议结构）。

/// 会话摘要（GET /agent/sessions 的条目）。
class SessionSummary {
  const SessionSummary({
    required this.id,
    this.title,
    this.lastPrompt,
    this.entryCount = 0,
    this.running = false,
    this.createdAt,
    this.updatedAt,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
        id: (json['id'] ?? '').toString(),
        title: json['title']?.toString(),
        lastPrompt: json['last_prompt']?.toString() ??
            json['lastPrompt']?.toString(),
        entryCount: (json['entry_count'] ?? json['entryCount'] ?? 0) is int
            ? (json['entry_count'] ?? json['entryCount'] ?? 0) as int
            : int.tryParse((json['entry_count'] ?? json['entryCount'] ?? 0).toString()) ?? 0,
        running: json['running'] == true,
        createdAt: json['createdAt']?.toString(),
        updatedAt: json['updatedAt']?.toString(),
      );

  final String id;
  final String? title;
  final String? lastPrompt;
  final int entryCount;
  final bool running;
  final String? createdAt;
  final String? updatedAt;

  String get displayTitle => title ?? lastPrompt ?? '新对话';
}

/// 一条 transcript 消息里的工具调用。
class ToolCall {
  const ToolCall({required this.id, required this.name, this.arguments});

  factory ToolCall.fromJson(Map<String, dynamic> json) => ToolCall(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        arguments: json['arguments']?.toString(),
      );

  final String id;
  final String name;
  final String? arguments;
}

/// transcript 消息主体。
class SessionMessage {
  const SessionMessage({
    required this.role,
    required this.content,
    this.toolCalls = const [],
  });

  factory SessionMessage.fromJson(Map<String, dynamic> json) => SessionMessage(
        role: (json['role'] ?? 'assistant').toString(),
        content: (json['content'] ?? '').toString(),
        toolCalls: ((json['toolCalls'] ?? json['tool_calls'] ?? const []) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(ToolCall.fromJson)
            .toList(),
      );

  final String role;
  final String content;
  final List<ToolCall> toolCalls;
}

/// transcript 条目：message / compaction / handoff 三态（判别字段对齐 Kotlin）。
class TranscriptEntry {
  const TranscriptEntry({
    this.messageId,
    this.compactionId,
    this.handoffId,
    this.message,
    this.summary,
    this.tokensBefore,
    this.tokensAfter,
  });

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) =>
      TranscriptEntry(
        messageId: json['messageId']?.toString() ?? json['message_id']?.toString(),
        compactionId: json['compactionId']?.toString() ?? json['compaction_id']?.toString(),
        handoffId: json['handoffId']?.toString() ?? json['handoff_id']?.toString(),
        message: json['message'] is Map<String, dynamic>
            ? SessionMessage.fromJson(json['message'] as Map<String, dynamic>)
            : null,
        summary: json['summary']?.toString(),
        tokensBefore: _int(json['tokensBefore'] ?? json['tokens_before']),
        tokensAfter: _int(json['tokensAfter'] ?? json['tokens_after']),
      );

  static int? _int(Object? v) =>
      v == null ? null : int.tryParse(v.toString());

  final String? messageId;
  final String? compactionId;
  final String? handoffId;
  final SessionMessage? message;
  final String? summary;
  final int? tokensBefore;
  final int? tokensAfter;
}

/// GET /agent/sessions/{id} 的完整转录。
class SessionTranscript {
  const SessionTranscript({required this.entries});

  factory SessionTranscript.fromJson(Map<String, dynamic> json) =>
      SessionTranscript(
        entries: ((json['entries'] ?? const []) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(TranscriptEntry.fromJson)
            .toList(),
      );

  final List<TranscriptEntry> entries;
}

/// 可选模型（GET /agent/llm/models）。
class LlmModelOption {
  const LlmModelOption({
    required this.ref,
    required this.label,
    this.isDefault = false,
    this.thinkingLevels = const [],
  });

  factory LlmModelOption.fromJson(Map<String, dynamic> json) =>
      LlmModelOption(
        ref: (json['ref'] ?? '').toString(),
        label: (json['label'] ?? json['ref'] ?? '').toString(),
        isDefault: json['isDefault'] == true || json['is_default'] == true,
        thinkingLevels: ((json['thinkingLevels'] ?? json['thinking_levels'] ?? const [])
                as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
      );

  final String ref;
  final String label;
  final bool isDefault;
  final List<String> thinkingLevels;
}
