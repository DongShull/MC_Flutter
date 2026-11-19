/// 通知中心域模型（对齐原 core/model/Search.kt 的 Notice 段）。

library;

class Notice {
  const Notice({
    required this.id,
    this.severity = 'info',
    this.source = '',
    this.title = '',
    this.message = '',
    this.payload = const {},
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  /// info / warning / error / critical
  final String severity;
  final String source;
  final String title;
  final String message;

  /// 事项附加上下文：group_key / grouped_under 决定折叠（见 visibleNotices）。
  final Map<String, dynamic> payload;
  final String? createdAt;
  final String? updatedAt;

  factory Notice.fromJson(Map<String, dynamic> j) {
    String? str(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return null;
    }

    final rawId = j['id'];
    final id = (rawId is num) ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0;
    return Notice(
      id: id,
      severity: str(['severity']) ?? 'info',
      source: str(['source']) ?? '',
      title: str(['title']) ?? '',
      message: str(['message']) ?? '',
      payload: (j['payload'] is Map) ? (j['payload'] as Map).cast<String, dynamic>() : const {},
      createdAt: str(['createdAt', 'created_at']),
      updatedAt: str(['updatedAt', 'updated_at']),
    );
  }
}

/// 只列该露出来的待处理事项（网页 notice-center / iOS NoticeCenterView.visible 同口径）：
/// 目录级根因告警（payload.group_key）存在时，被它收编的单种子告警
/// （payload.grouped_under 指向那个 key）折叠不显示。
List<Notice> visibleNotices(List<Notice> notices) {
  String? str(Notice n, String key) {
    final v = n.payload[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  final groupKeys = notices
      .map((n) => str(n, 'group_key'))
      .whereType<String>()
      .toSet();
  return notices.where((notice) {
    final parent = str(notice, 'grouped_under');
    return parent == null || !groupKeys.contains(parent);
  }).toList();
}
