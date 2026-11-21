// more 域模型（对齐 Kotlin Notice / SessionSummary）。

/// 服务器公告 / 告警（GET /notices → Notice）。
class McNotice {
  const McNotice({
    this.id = 0,
    this.severity = 'info',
    this.source = '',
    this.title = '',
    this.message = '',
    this.groupKey,
    this.groupedUnder,
    this.createdAt,
  });

  factory McNotice.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    final Map<String, dynamic> p =
        payload is Map<String, dynamic> ? payload : const <String, dynamic>{};
    String? opt(Object? v) => v?.toString();
    return McNotice(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      severity: (json['severity'] ?? 'info').toString(),
      source: (json['source'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      groupKey: opt(p['group_key'] ?? p['groupKey']),
      groupedUnder: opt(p['grouped_under'] ?? p['groupedUnder']),
      createdAt: opt(json['createdAt'] ?? json['created_at']),
    );
  }

  final int id;
  final String severity;
  final String source;
  final String title;
  final String message;
  final String? groupKey;
  final String? groupedUnder;
  final String? createdAt;
}

/// 对话会话摘要（GET /agent/sessions → SessionSummary）。
class SessionSummary {
  const SessionSummary({
    this.id = '',
    this.title = '',
    this.lastPrompt = '',
    this.entryCount = 0,
    this.running = false,
    this.updatedAt,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        lastPrompt:
            (json['lastPrompt'] ?? json['last_prompt'] ?? '').toString(),
        entryCount: json['entryCount'] is num
            ? (json['entryCount'] as num).toInt()
            : json['entry_count'] is num
                ? (json['entry_count'] as num).toInt()
                : 0,
        running: json['running'] == true,
        updatedAt:
            json['updatedAt']?.toString() ?? json['updated_at']?.toString(),
      );

  final String id;
  final String title;
  final String lastPrompt;
  final int entryCount;
  final bool running;
  final String? updatedAt;

  String get displayTitle {
    final t = title;
    if (t.isNotEmpty) return t;
    final p = lastPrompt;
    return p.isNotEmpty ? p : '(无标题)';
  }
}
