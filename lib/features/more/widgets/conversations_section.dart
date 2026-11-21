import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../state/controllers.dart';
import '../state/models.dart';

/// 会话段（管理员）：AI 会话列表按 今天/昨天/更早 分组，
/// 行点击进 /agent/session/{id}，长按 / 菜单：续接 / 重命名 / 删除。
class ConversationsSection extends ConsumerWidget {
  const ConversationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(moreProvider);
    final sessions = state.valueOrNull?.sessions ?? const <SessionSummary>[];
    if (sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Column(
          children: [
            Text(
              McStrings.conversationsEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              McStrings.conversationsEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final groups = _groupByDay(sessions, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              group.$1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final s in group.$2)
            _SessionRow(
              session: s,
              onOpen: () => context.push('/agent/session/${s.id}'),
              onFork: () => _fork(context, ref, s),
              onRename: () => _rename(context, ref, s),
              onDelete: () => _delete(context, ref, s),
            ),
        ],
      ],
    );
  }

  /// 按自然日分组：今天 / 昨天 / 更早（组内保持原排序）。
  static List<(String, List<SessionSummary>)> _groupByDay(
    List<SessionSummary> sessions,
    DateTime now,
  ) {
    final today = <SessionSummary>[];
    final yesterday = <SessionSummary>[];
    final earlier = <SessionSummary>[];
    final todayStart = DateTime(now.year, now.month, now.day);
    for (final s in sessions) {
      final updated = DateTime.tryParse(s.updatedAt ?? '');
      final diff = updated == null
          ? 999
          : todayStart
              .difference(DateTime(updated.year, updated.month, updated.day))
              .inDays;
      if (diff <= 0) {
        today.add(s);
      } else if (diff == 1) {
        yesterday.add(s);
      } else {
        earlier.add(s);
      }
    }
    return [
      if (today.isNotEmpty) (McStrings.groupToday, today),
      if (yesterday.isNotEmpty) (McStrings.groupYesterday, yesterday),
      if (earlier.isNotEmpty) (McStrings.groupEarlier, earlier),
    ];
  }

  /// 时间小字：今天/昨天 HH:mm；当年 M月d日；跨年 y/M/d。
  static String timeLabel(SessionSummary s, DateTime now) {
    final t = DateTime.tryParse(s.updatedAt ?? '');
    if (t == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    final hm = '${two(t.hour)}:${two(t.minute)}';
    final todayStart = DateTime(now.year, now.month, now.day);
    final diff = todayStart.difference(DateTime(t.year, t.month, t.day)).inDays;
    if (diff <= 0) return hm;
    if (diff == 1) return '${McStrings.groupYesterday} $hm';
    if (t.year == now.year) return '${t.month}月${t.day}日';
    return '${t.year}/${t.month}/${t.day}';
  }

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        width: 360,
      ),
    );
  }

  static Future<void> _fork(
    BuildContext context,
    WidgetRef ref,
    SessionSummary s,
  ) async {
    final newId = await ref.read(moreProvider.notifier).forkSession(s.id);
    if (!context.mounted) return;
    if (newId != null) {
      context.push('/agent/session/$newId');
      return;
    }
    _toast(context, McStrings.forkFailedToast);
  }

  static Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    SessionSummary s,
  ) async {
    final controller = TextEditingController(text: s.title);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(McStrings.renameSessionTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text(McStrings.cancel),
          ),
          FilledButton(
            onPressed: () => ctx.pop(controller.text),
            child: const Text(McStrings.save),
          ),
        ],
      ),
    );
    if (next == null) return;
    // 对齐鸿蒙：截 80 字、去空白；无变化不发请求。
    var title = next.trim();
    if (title.length > 80) title = title.substring(0, 80);
    if (title.isEmpty || title == s.title) return;
    final err =
        await ref.read(moreProvider.notifier).renameSession(s.id, title);
    if (!context.mounted) return;
    _toast(context, err ?? McStrings.renamedToast);
  }

  static Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SessionSummary s,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(McStrings.deleteSessionTitle),
        content: Text(McStrings.deleteSessionConfirmBody
            .replaceFirst('%s', s.displayTitle)),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text(McStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => ctx.pop(true),
            child: const Text(McStrings.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await ref.read(moreProvider.notifier).deleteSession(s.id);
    if (!context.mounted) return;
    _toast(context, err ?? McStrings.deletedToast);
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.onOpen,
    required this.onFork,
    required this.onRename,
    required this.onDelete,
  });

  final SessionSummary session;
  final VoidCallback onOpen;
  final VoidCallback onFork;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onOpen,
      onLongPress: () => _showActions(context),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                session.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            session.running
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      McStrings.runningBadge,
                      style: TextStyle(fontSize: 12, color: scheme.primary),
                    ),
                  )
                : Text(
                    ConversationsSection.timeLabel(session, DateTime.now()),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz,
                  size: 18, color: scheme.onSurfaceVariant),
              onSelected: (v) => switch (v) {
                'fork' => onFork(),
                'rename' => onRename(),
                'delete' => onDelete(),
                _ => null,
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                    value: 'fork', child: Text(McStrings.forkSessionAction)),
                const PopupMenuItem(
                    value: 'rename',
                    child: Text(McStrings.renameSessionAction)),
                const PopupMenuItem(
                    value: 'delete', child: Text(McStrings.delete)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 长按菜单（对齐鸿蒙左滑/长按）：续接 / 重命名 / 删除。
  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(McIcons.history1),
              title: const Text(McStrings.forkSessionAction),
              onTap: () {
                Navigator.of(ctx).pop();
                onFork();
              },
            ),
            ListTile(
              leading: const Icon(McIcons.edit2),
              title: const Text(McStrings.renameSessionAction),
              onTap: () {
                Navigator.of(ctx).pop();
                onRename();
              },
            ),
            ListTile(
              leading:
                  Icon(McIcons.trash2, color: Theme.of(ctx).colorScheme.error),
              title: Text(McStrings.delete,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () {
                Navigator.of(ctx).pop();
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
