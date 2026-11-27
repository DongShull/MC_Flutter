/// 通知中心域模型（1:1 对齐 iOS `NoticeCenterView.swift` 与 Web `notice-center.tsx`）。
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

  /// 事项的站内跳转目标（对齐 iOS `NoticeCenterView.href` 与 Web `noticeHref`）。
  String resolveWebHref() {
    switch (source) {
      case 'subscription':
        final rawId = payload['subscription_id'] ?? payload['subscriptionId'];
        final idVal =
            rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
        if (idVal != null && idVal > 0) return '/subscriptions/$idVal';
        return '/subscriptions';
      case 'ingest':
        return '/settings/import-watch';
      case 'channel':
        return '/settings/im-push';
      case 'downloader':
        return '/settings/downloaders';
      case 'site':
        return '/settings/sites';
      case 'cloud':
        return '/settings/cloud';
      case 'plugin':
        final actionHref =
            (payload['action_href'] ?? payload['actionHref'])?.toString().trim();
        if (actionHref != null &&
            actionHref.startsWith('/') &&
            !actionHref.startsWith('//')) {
          return actionHref;
        }
        return '/settings/plugins?tab=builtin';
      default:
        return '/settings';
    }
  }

  factory Notice.fromJson(Map<String, dynamic> j) {
    String? str(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return null;
    }

    final rawId = j['id'];
    final id =
        (rawId is num) ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0;
    return Notice(
      id: id,
      severity: str(['severity']) ?? 'info',
      source: str(['source']) ?? '',
      title: str(['title']) ?? '',
      message: str(['message']) ?? '',
      payload: (j['payload'] is Map)
          ? (j['payload'] as Map).cast<String, dynamic>()
          : const {},
      createdAt: str(['createdAt', 'created_at']),
      updatedAt: str(['updatedAt', 'updated_at']),
    );
  }
}

/// 只列该露出来的待处理事项（网页 notice-center / iOS `NoticeCenterView.visible` 同口径）：
/// 目录级根因告警（`payload.group_key`）存在时，被它收编的单种子告警
/// （`payload.grouped_under` 指向那个非空 key）折叠不显示。
List<Notice> visibleNotices(List<Notice> notices) {
  String? str(Notice n, List<String> keys) {
    for (final key in keys) {
      final v = n.payload[key];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  final groupKeys = notices
      .map((n) => str(n, const ['group_key', 'groupKey']))
      .whereType<String>()
      .toSet();
  return notices.where((notice) {
    final parent = str(notice, const ['grouped_under', 'groupedUnder']);
    return parent == null || !groupKeys.contains(parent);
  }).toList();
}
