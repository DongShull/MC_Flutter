import 'dart:convert';

// AI 助手域模型（1:1 对齐 iOS `AgentAPI.swift` / `AgentSkills.swift` / `AgentMediaCards.swift` / `AgentTimeline.swift`）。

/// 会话摘要（GET /api/v1/sessions 的条目）。
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

/// 一次工具调用及其回执（支持流式 tool_call_start / tool_call_delta / tool_call / tool_result）。
class ToolCall {
  const ToolCall({
    required this.id,
    required this.name,
    this.arguments,
    this.output,
    this.isError = false,
    this.argsDone = true,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final fn = json['function'] is Map
        ? Map<String, dynamic>.from(json['function'] as Map)
        : null;
    final rawArgs = fn?['arguments'] ??
        json['arguments'] ??
        json['raw_arguments'] ??
        json['input'];
    final argsStr = rawArgs == null
        ? null
        : (rawArgs is String ? rawArgs : jsonEncode(rawArgs));
    return ToolCall(
      id: (json['id'] ?? '').toString(),
      name: (fn?['name'] ?? json['name'] ?? '').toString(),
      arguments: argsStr,
      output: json['output']?.toString(),
      isError: json['is_error'] == true || json['isError'] == true,
      argsDone: true,
    );
  }

  final String id;
  final String name;
  final String? arguments;
  final String? output;
  final bool isError;
  final bool argsDone;

  bool get streaming => !argsDone;
  bool get failed =>
      isError || (output?.startsWith('工具执行失败：') ?? false);

  ToolCall copyWith({
    String? id,
    String? name,
    String? arguments,
    String? output,
    bool? isError,
    bool? argsDone,
  }) =>
      ToolCall(
        id: id ?? this.id,
        name: name ?? this.name,
        arguments: arguments ?? this.arguments,
        output: output ?? this.output,
        isError: isError ?? this.isError,
        argsDone: argsDone ?? this.argsDone,
      );

  Map<String, dynamic>? get parsedArgs {
    final raw = arguments?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  /// 单行摘要（对齐 iOS `AgentToolCall.summary`）。
  String get summary {
    final map = parsedArgs;
    if (map != null) {
      if (name == 'bash' && map['command'] is String) {
        return (map['command'] as String)
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .join(' ');
      }
      return map.entries.map((e) {
        final v = e.value;
        return v is String ? '${e.key}: $v' : '${e.key}: ${jsonEncode(v)}';
      }).join(', ');
    }
    final raw = (arguments ?? '').trim();
    return raw == '{}' ? '' : raw;
  }

  /// 展开后的参数明细（bash 取 command，其余美化 JSON）。
  ({String code, String lang})? get inputDetail {
    final map = parsedArgs;
    if (map != null) {
      if (name == 'bash' && map['command'] is String) {
        return (code: map['command'] as String, lang: 'bash');
      }
      if (map.isEmpty) return null;
      const encoder = JsonEncoder.withIndent('  ');
      return (code: encoder.convert(map), lang: 'json');
    }
    final raw = (arguments ?? '').trim();
    if (raw.isEmpty || raw == '{}') return null;
    return (code: raw, lang: 'json');
  }
}

/// 真实 `show_media_cards_v1` 协议的卡片规格（按 ID 现拉实时元数据）。
enum AgentMediaCardKind { library, title, libraryItem, subscription }

class AgentMediaCardSpec {
  const AgentMediaCardSpec({
    required this.kind,
    required this.idKey,
    this.libraryId,
    this.titleRef,
    this.mediaItemId,
    this.seasonNumber,
    this.episodeNumber,
    this.subscriptionId,
  });

  final AgentMediaCardKind kind;
  final String idKey;
  final int? libraryId;
  final String? titleRef;
  final int? mediaItemId;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? subscriptionId;
}

class AgentMediaCardGroup {
  const AgentMediaCardGroup({
    required this.component,
    this.title,
    required this.specs,
  });

  final String component;
  final String? title;
  final List<AgentMediaCardSpec> specs;

  static final RegExp _titleRefRe =
      RegExp(r'^(tmdb:(movie|tv):\d+|douban:[^:/\s]+)$');

  static bool isMediaCardsTool(String name) => name == 'show_media_cards_v1';

  static int? _positiveInt(Object? v) {
    final n = v is int ? v : (v is num ? v.toInt() : int.tryParse('$v'));
    return (n != null && n > 0) ? n : null;
  }

  static AgentMediaCardGroup? parseToolCall(ToolCall call) {
    if (!isMediaCardsTool(call.name) || call.streaming || call.failed) {
      return null;
    }
    final args = call.parsedArgs;
    if (args == null) return null;
    final component = (args['component'] ?? '').toString();
    if (!const {'library', 'title', 'library_item', 'subscription'}
        .contains(component)) {
      return null;
    }
    final rawItems = args['items'];
    if (rawItems is! List) return null;

    final specs = <AgentMediaCardSpec>[];
    final seen = <String>{};
    for (var i = 0; i < rawItems.length; i++) {
      final item = rawItems[i];
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      AgentMediaCardSpec? spec;
      switch (component) {
        case 'library':
          final id = _positiveInt(m['library_id']);
          if (id != null) {
            spec = AgentMediaCardSpec(
              kind: AgentMediaCardKind.library,
              idKey: 'library:$id',
              libraryId: id,
            );
          }
          break;
        case 'subscription':
          final id = _positiveInt(m['subscription_id']);
          if (id != null) {
            spec = AgentMediaCardSpec(
              kind: AgentMediaCardKind.subscription,
              idKey: 'subscription:$id',
              subscriptionId: id,
            );
          }
          break;
        case 'title':
          var ref = (m['title_ref'] ?? '').toString().trim();
          if (ref.isEmpty) {
            final tmdb = _positiveInt(m['tmdb_id']);
            final type = (m['media_type'] ?? '').toString();
            if (tmdb != null && (type == 'movie' || type == 'tv')) {
              ref = 'tmdb:$type:$tmdb';
            }
          }
          if (_titleRefRe.hasMatch(ref)) {
            spec = AgentMediaCardSpec(
              kind: AgentMediaCardKind.title,
              idKey: ref,
              titleRef: ref,
            );
          }
          break;
        case 'library_item':
          final id = _positiveInt(m['media_item_id']);
          if (id != null) {
            final sRaw = m['season_number'];
            final s = sRaw is int
                ? (sRaw >= 0 ? sRaw : null)
                : (sRaw is num && sRaw.toInt() >= 0 ? sRaw.toInt() : null);
            final e = _positiveInt(m['episode_number']);
            final hasPair = s != null && e != null;
            spec = AgentMediaCardSpec(
              kind: AgentMediaCardKind.libraryItem,
              idKey: 'item:$id${hasPair ? ':s${s}e$e' : ''}:$i',
              mediaItemId: id,
              seasonNumber: hasPair ? s : null,
              episodeNumber: hasPair ? e : null,
            );
          }
          break;
      }
      if (spec != null && seen.add(spec.idKey)) {
        specs.add(spec);
      }
    }
    if (specs.isEmpty) return null;
    final rawTitle = (args['title'] ?? '').toString().trim();
    return AgentMediaCardGroup(
      component: component,
      title: rawTitle.isEmpty ? null : rawTitle,
      specs: specs,
    );
  }

  static List<AgentMediaCardGroup> extractFromToolCalls(List<ToolCall> calls) {
    final out = <AgentMediaCardGroup>[];
    for (final c in calls) {
      final g = parseToolCall(c);
      if (g != null) out.add(g);
    }
    return out;
  }
}

/// 兼容预填充地图格式的 `show_media_cards_v1` 富媒体影视卡片（保持旧单测与历史数据兼容）。
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

  /// 提取预填充格式的影视卡片（若为真实 `{component, items}` 实时协议则交由 `AgentMediaCardGroup` 现拉）。
  static List<AgentMediaCard> extractFromToolCalls(List<ToolCall> calls) {
    final results = <AgentMediaCard>[];
    for (final call in calls) {
      final lower = call.name.toLowerCase();
      if (!lower.contains('media_card') &&
          !lower.contains('show_cards') &&
          call.name != 'show_media_cards_v1') {
        continue;
      }
      // 真实 ID 协议交由 AgentMediaCardGroup 处理，不落成「未知影视」占位卡。
      if (AgentMediaCardGroup.parseToolCall(call) != null) continue;

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
              if (item['title'] != null || item['name'] != null) {
                results.add(AgentMediaCard.fromJson(item));
              }
            }
          } else if (decoded['title'] != null || decoded['name'] != null) {
            results.add(AgentMediaCard.fromJson(decoded));
          }
        }
      } catch (_) {}
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
      description:
          json['description']?.toString() ?? json['summary']?.toString(),
      prompt: json['prompt']?.toString() ?? json['command']?.toString(),
    );
  }

  final String name;
  final String title;
  final String? description;
  final String? prompt;
}

/// 技能显式调用的文本规则（1:1 对齐 iOS `AgentSkillText` & 后端 `skills.py`）。
abstract final class AgentSkillText {
  static String token(String name) => '/skill:$name ';

  static final RegExp _tokenRegex =
      RegExp(r'(?:^|(?<=\s))/skill:([A-Za-z0-9._-]+)');
  static final RegExp _blockRegex = RegExp(
    r'^<skill\s+name="([^"]*)"\s+location="[^"]*">\s*[\s\S]*?</skill>\s*',
  );
  static final RegExp _slashQueryRegex =
      RegExp(r'(^|\s)/([A-Za-z0-9._:-]{0,64})$');

  /// 服务端已展开的 `<skill name="..." location="...">...</skill>` → `/skill:name 用户原文`。
  static String toTokenForm(String text) {
    final names = <String>[];
    var rest = text;
    while (true) {
      final m = _blockRegex.firstMatch(rest);
      if (m == null) break;
      final name = m.group(1) ?? '';
      if (name.isNotEmpty) names.add(name);
      rest = rest.substring(m.end);
    }
    if (names.isEmpty) return text;
    return names.map(token).join() + rest;
  }

  /// 从 token 形态拆出技能名（首现序去重）与剩余用户正文。
  static ({List<String> names, String text}) parseTokens(
    String input, {
    Set<String>? allow,
  }) {
    final normalized = toTokenForm(input);
    final names = <String>[];
    final seen = <String>{};
    final lines = normalized.split('\n').map((line) {
      final matches = _tokenRegex.allMatches(line).toList();
      if (matches.isEmpty) return line;
      final buf = StringBuffer();
      var cursor = 0;
      var touched = false;
      for (final m in matches) {
        final name = m.group(1) ?? '';
        final key = name.toLowerCase();
        if (allow != null && !allow.contains(key)) continue;
        touched = true;
        if (seen.add(key)) names.add(name);
        buf.write(line.substring(cursor, m.start));
        cursor = m.end;
      }
      if (!touched) return line;
      buf.write(line.substring(cursor));
      return buf.toString().replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    }).toList();

    final kept = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].isNotEmpty || (i > 0 && i < lines.length - 1)) {
        kept.add(lines[i]);
      }
    }
    return (names: names, text: kept.join('\n').trim());
  }

  /// 输入框末尾的 `/query` 或 `/skill:query` 触发技能自动补全。
  static ({String query, int start, int end})? slashQuery(String text) {
    final m = _slashQueryRegex.firstMatch(text);
    if (m == null) return null;
    final start = text[m.start] == '/' ? m.start : m.start + 1;
    var q = text.substring(start + 1).toLowerCase();
    if (q.startsWith('skill:')) q = q.substring(6);
    if (q.contains(':')) return null;
    return (query: q, start: start, end: text.length);
  }
}

/// 思维链强度自适应控件逻辑（1:1 对齐 iOS `AgentThinking`）。
enum AgentThinkingShape { hidden, toggle, slider }

abstract final class AgentThinking {
  static const order = <String>[
    'off',
    'minimal',
    'low',
    'medium',
    'high',
    'xhigh',
    'max',
  ];

  static const labels = <String, String>{
    'off': '关闭',
    'minimal': '极简',
    'low': '低',
    'medium': '中',
    'high': '高',
    'xhigh': '极高',
    'max': '最大',
  };

  static List<String> stops(List<String> levels) =>
      order.where(levels.contains).toList();

  static AgentThinkingShape shape(List<String> stops) {
    if (stops.isEmpty) return AgentThinkingShape.hidden;
    if (stops.length == 1) return AgentThinkingShape.toggle;
    return AgentThinkingShape.slider;
  }

  static String label(String? value) {
    if (value == null || value.isEmpty) return '默认';
    return labels[value] ?? value;
  }
}

/// 用户消息携带的图片附件引用。
class AgentTurnImage {
  const AgentTurnImage({
    required this.attachmentId,
    this.name,
    this.localPath,
  });

  final String attachmentId;
  final String? name;
  final String? localPath;
}

/// 附件上传回执（POST /api/v1/sessions/attachments）。
class AgentAttachmentUpload {
  const AgentAttachmentUpload({
    required this.attachmentId,
    required this.name,
  });

  factory AgentAttachmentUpload.fromJson(Map<String, dynamic> json) =>
      AgentAttachmentUpload(
        attachmentId:
            (json['attachment_id'] ?? json['attachmentId'] ?? '').toString(),
        name: (json['name'] ?? '图片.jpg').toString(),
      );

  final String attachmentId;
  final String name;
}

/// 派生会话的来源卡片数据（`type: "handoff"`）。
class AgentHandoffInfo {
  const AgentHandoffInfo({
    required this.sourceSessionId,
    this.sourceTitle,
  });

  final String sourceSessionId;
  final String? sourceTitle;
}

/// transcript 消息主体（兼容字符串与多段数组，支持 text / thinking / image / tool_calls / tool_call_id）。
class SessionMessage {
  const SessionMessage({
    required this.role,
    required this.content,
    this.thinking,
    this.toolCalls = const [],
    this.toolCallId,
    this.images = const [],
  });

  factory SessionMessage.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    var text = '';
    String? thinking;
    final extraToolCalls = <ToolCall>[];
    final images = <AgentTurnImage>[];
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
          } else if (pType == 'image') {
            final attId =
                (m['attachment_id'] ?? m['attachmentId'] ?? '').toString();
            if (attId.isNotEmpty) {
              images.add(
                AgentTurnImage(
                  attachmentId: attId,
                  name: m['name']?.toString(),
                ),
              );
            }
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
      toolCallId:
          json['tool_call_id']?.toString() ?? json['toolCallId']?.toString(),
      images: images,
    );
  }

  final String role;
  final String content;
  final String? thinking;
  final List<ToolCall> toolCalls;
  final String? toolCallId;
  final List<AgentTurnImage> images;
}

/// transcript 条目：message / compaction / handoff 三态。
class TranscriptEntry {
  const TranscriptEntry({
    this.type = 'message',
    this.messageId,
    this.compactionId,
    this.handoffId,
    this.timestamp,
    this.model,
    this.finishReason,
    this.thinkingLevel,
    this.message,
    this.summary,
    this.tokensBefore,
    this.tokensAfter,
    this.sourceSessionId,
    this.sourceTitle,
  });

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString();
    return TranscriptEntry(
      type: type.isNotEmpty
          ? type
          : (json['source_session_id'] != null
              ? 'handoff'
              : (json['compactionId'] != null || json['compaction_id'] != null
                  ? 'compaction'
                  : 'message')),
      messageId:
          json['messageId']?.toString() ?? json['message_id']?.toString(),
      compactionId:
          json['compactionId']?.toString() ?? json['compaction_id']?.toString(),
      handoffId:
          json['handoffId']?.toString() ?? json['handoff_id']?.toString(),
      timestamp: json['timestamp']?.toString(),
      model: json['model']?.toString(),
      finishReason: json['finish_reason']?.toString() ??
          json['finishReason']?.toString(),
      thinkingLevel: json['thinking_level']?.toString() ??
          json['thinkingLevel']?.toString(),
      message: json['message'] is Map
          ? SessionMessage.fromJson(
              Map<String, dynamic>.from(json['message'] as Map),
            )
          : null,
      summary: json['summary']?.toString(),
      tokensBefore: _int(json['tokensBefore'] ?? json['tokens_before']),
      tokensAfter: _int(json['tokensAfter'] ?? json['tokens_after']),
      sourceSessionId: json['source_session_id']?.toString() ??
          json['sourceSessionId']?.toString(),
      sourceTitle:
          json['source_title']?.toString() ?? json['sourceTitle']?.toString(),
    );
  }

  static int? _int(Object? v) =>
      v == null ? null : int.tryParse(v.toString());

  final String type;
  final String? messageId;
  final String? compactionId;
  final String? handoffId;
  final String? timestamp;
  final String? model;
  final String? finishReason;
  final String? thinkingLevel;
  final SessionMessage? message;
  final String? summary;
  final int? tokensBefore;
  final int? tokensAfter;
  final String? sourceSessionId;
  final String? sourceTitle;
}

/// GET /api/v1/sessions/{id} 的完整转录。
class SessionTranscript {
  const SessionTranscript({required this.entries, this.session});

  factory SessionTranscript.fromJson(Map<String, dynamic> json) =>
      SessionTranscript(
        session: json['session'] is Map
            ? SessionSummary.fromJson(
                Map<String, dynamic>.from(json['session'] as Map),
              )
            : null,
        entries: ((json['entries'] ?? const []) as List<dynamic>)
            .whereType<Map>()
            .map((e) => TranscriptEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  final SessionSummary? session;
  final List<TranscriptEntry> entries;
}

/// 可选模型（GET /api/v1/llm/models）。
class LlmModelOption {
  const LlmModelOption({
    required this.ref,
    required this.label,
    this.providerName = '',
    this.isDefault = false,
    this.thinkingLevels = const [],
  });

  factory LlmModelOption.fromJson(Map<String, dynamic> json) => LlmModelOption(
        ref: (json['ref'] ?? '').toString(),
        label: (json['label'] ?? json['ref'] ?? '').toString(),
        providerName: (json['provider_name'] ??
                json['providerName'] ??
                json['provider'] ??
                '')
            .toString(),
        isDefault: json['isDefault'] == true || json['is_default'] == true,
        thinkingLevels: ((json['thinkingLevels'] ??
                    json['thinking_levels'] ??
                    const []) as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
      );

  final String ref;
  final String label;
  final String providerName;
  final bool isDefault;
  final List<String> thinkingLevels;
}
