import 'dart:convert';

// AI 助手域模型（1:1 对齐 Web / Kotlin feature/agent 的协议结构，并支持富媒体卡片与技能列表）。

/// 会话摘要（GET /api/v1/agent/sessions 的条目）。
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
        lastPrompt:
            json['last_prompt']?.toString() ?? json['lastPrompt']?.toString(),
        entryCount: (json['entry_count'] ?? json['entryCount'] ?? 0) is int
            ? (json['entry_count'] ?? json['entryCount'] ?? 0) as int
            : int.tryParse(
                  (json['entry_count'] ?? json['entryCount'] ?? 0).toString(),
                ) ??
                0,
        running: json['running'] == true,
        createdAt:
            json['createdAt']?.toString() ?? json['created_at']?.toString(),
        updatedAt:
            json['updatedAt']?.toString() ?? json['updated_at']?.toString(),
      );

  final String id;
  final String? title;
  final String? lastPrompt;
  final int entryCount;
  final bool running;
  final String? createdAt;
  final String? updatedAt;

  String get displayTitle =>
      (title != null && title!.trim().isNotEmpty)
          ? title!.trim()
          : (lastPrompt != null && lastPrompt!.trim().isNotEmpty)
              ? lastPrompt!.trim()
              : '新对话';
}

/// 一条 transcript 消息里的工具调用（兼容直接 `{id,name,arguments}` 与 OpenAI `{id,function:{name,arguments}}`）。
class ToolCall {
  const ToolCall({required this.id, required this.name, this.arguments});

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final fn = json['function'] is Map
        ? Map<String, dynamic>.from(json['function'] as Map)
        : null;
    final rawArgs = fn?['arguments'] ?? json['arguments'] ?? json['input'];
    final argsStr = rawArgs == null
        ? null
        : (rawArgs is String ? rawArgs : jsonEncode(rawArgs));
    return ToolCall(
      id: (json['id'] ?? '').toString(),
      name: (fn?['name'] ?? json['name'] ?? '').toString(),
      arguments: argsStr,
    );
  }

  final String id;
  final String name;
  final String? arguments;
}

/// AI 工具 `show_media_cards_v1` 产出的富媒体影视卡片。
class AgentMediaCard {
  const AgentMediaCard({
    required this.title,
    this.year,
    this.mediaType,
    this.titleRef,
    this.mediaItemId,
    this.libraryId,
    this.posterUrl,
    this.rating,
    this.overview,
    this.inLibrary = false,
  });

  factory AgentMediaCard.fromJson(Map<String, dynamic> json) {
    final mediaItemId = _int(json['media_item_id'] ?? json['mediaItemId']);
    final libraryId = _int(json['library_id'] ?? json['libraryId']);
    final ratingRaw = json['rating'] ?? json['vote_average'] ?? json['score'];
    final rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw?.toString() ?? '');
    return AgentMediaCard(
      title: (json['title'] ?? json['name'] ?? '未知影视').toString(),
      year: _int(json['year'] ?? json['release_year']),
      mediaType:
          (json['media_type'] ?? json['mediaType'] ?? json['type'])?.toString(),
      titleRef: (json['title_ref'] ?? json['titleRef'] ?? json['ref'])
          ?.toString(),
      mediaItemId: mediaItemId,
      libraryId: libraryId,
      posterUrl: (json['poster_url'] ??
              json['posterUrl'] ??
              json['poster_path'] ??
              json['cover_url'])
          ?.toString(),
      rating: rating,
      overview:
          (json['overview'] ?? json['summary'] ?? json['reason'])?.toString(),
      inLibrary: json['in_library'] == true ||
          json['inLibrary'] == true ||
          (mediaItemId != null && libraryId != null),
    );
  }

  static int? _int(Object? v) =>
      v == null ? null : (v is int ? v : int.tryParse(v.toString()));

  final String title;
  final int? year;
  final String? mediaType;
  final String? titleRef;
  final int? mediaItemId;
  final int? libraryId;
  final String? posterUrl;
  final double? rating;
  final String? overview;
  final bool inLibrary;

  /// 从一组 ToolCall 中提取所有 `show_media_cards_v1` / 影视推荐卡片。
  static List<AgentMediaCard> extractFromToolCalls(List<ToolCall> calls) {
    final results = <AgentMediaCard>[];
    for (final call in calls) {
      final lower = call.name.toLowerCase();
      if (!lower.contains('media_card') &&
          !lower.contains('show_cards') &&
          call.name != 'show_media_cards_v1') {
        continue;
      }
      final raw = call.arguments;
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List<dynamic>) {
          for (final item in decoded.whereType<Map<String, dynamic>>()) {
            results.add(AgentMediaCard.fromJson(item));
          }
        } else if (decoded is Map<String, dynamic>) {
          final list = decoded['cards'] ??
              decoded['items'] ??
              decoded['results'] ??
              decoded['media'];
          if (list is List<dynamic>) {
            for (final item in list.whereType<Map<String, dynamic>>()) {
              results.add(AgentMediaCard.fromJson(item));
            }
          } else if (decoded['title'] != null || decoded['name'] != null) {
            results.add(AgentMediaCard.fromJson(decoded));
          }
        }
      } catch (_) {
        // 忽略尚未闭合的半截 JSON 参数帧。
      }
    }
    return results;
  }
}

/// 服务端注册的 Agent Skill（GET /api/v1/skills）。
class AgentSkill {
  const AgentSkill({
    required this.name,
    required this.title,
    this.description,
    this.prompt,
  });

  factory AgentSkill.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['id'] ?? json['slug'] ?? '').toString();
    final title =
        (json['title'] ?? json['display_name'] ?? json['label'] ?? name)
            .toString();
    return AgentSkill(
      name: name,
      title: title.isEmpty ? '技能' : title,
      description: json['description']?.toString() ?? json['summary']?.toString(),
      prompt: json['prompt']?.toString() ?? json['command']?.toString(),
    );
  }

  final String name;
  final String title;
  final String? description;
  final String? prompt;
}

/// transcript 消息主体（兼容 `content` 为纯字符串或 `[{type:'thinking'|'text', text:...}]` 多段数组）。
class SessionMessage {
  const SessionMessage({
    required this.role,
    required this.content,
    this.thinking,
    this.toolCalls = const [],
  });

  factory SessionMessage.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    var text = '';
    String? thinking;
    final extraToolCalls = <ToolCall>[];
    if (rawContent is List) {
      final textParts = <String>[];
      final thinkParts = <String>[];
      for (final part in rawContent) {
        if (part is String) {
          if (part.isNotEmpty) textParts.add(part);
        } else if (part is Map) {
          final m = Map<String, dynamic>.from(part);
          final pType = (m['type'] ?? '').toString();
          if (pType == 'thinking' || pType == 'reasoning') {
            final t = (m['thinking'] ?? m['text'] ?? '').toString();
            if (t.trim().isNotEmpty) thinkParts.add(t.trim());
          } else if (pType == 'tool_use' || pType == 'tool_call') {
            extraToolCalls.add(ToolCall.fromJson(m));
          } else {
            final t = (m['text'] ?? m['content'] ?? '').toString();
            if (t.isNotEmpty) textParts.add(t);
          }
        }
      }
      text = textParts.join('\n\n');
      if (thinkParts.isNotEmpty) thinking = thinkParts.join('\n\n');
    } else if (rawContent != null) {
      text = rawContent.toString();
    }
    final rawCalls = json['toolCalls'] ?? json['tool_calls'];
    final parsedCalls = <ToolCall>[
      if (rawCalls is List)
        for (final item in rawCalls)
          if (item is Map) ToolCall.fromJson(Map<String, dynamic>.from(item)),
      ...extraToolCalls,
    ];
    return SessionMessage(
      role: (json['role'] ?? 'assistant').toString(),
      content: text,
      thinking: thinking,
      toolCalls: parsedCalls,
    );
  }

  final String role;
  final String content;
  final String? thinking;
  final List<ToolCall> toolCalls;
}

/// transcript 条目：message / compaction / handoff 三态。
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
        messageId:
            json['messageId']?.toString() ?? json['message_id']?.toString(),
        compactionId: json['compactionId']?.toString() ??
            json['compaction_id']?.toString(),
        handoffId:
            json['handoffId']?.toString() ?? json['handoff_id']?.toString(),
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

/// GET /api/v1/agent/sessions/{id} 的完整转录。
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

/// 可选模型（GET /api/v1/agent/llm/models）。
class LlmModelOption {
  const LlmModelOption({
    required this.ref,
    required this.label,
    this.isDefault = false,
    this.thinkingLevels = const [],
  });

  factory LlmModelOption.fromJson(Map<String, dynamic> json) => LlmModelOption(
        ref: (json['ref'] ?? '').toString(),
        label: (json['label'] ?? json['ref'] ?? '').toString(),
        isDefault: json['isDefault'] == true || json['is_default'] == true,
        thinkingLevels: ((json['thinkingLevels'] ??
                    json['thinking_levels'] ??
                    const [])
                as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
      );

  final String ref;
  final String label;
  final bool isDefault;
  final List<String> thinkingLevels;
}
