import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import 'quick_input.dart';

/// 会话段（管理员）：AI 历史对话按 今天 / 昨天 / 更早 分组，`McInsetGroup` 圆角容器 + 左滑管理 + 底部 `QuickInputCard`。
class ConversationsSection extends ConsumerWidget {
  const ConversationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(moreProvider);
    final sessions = state.valueOrNull?.sessions ?? const <SessionSummary>[];
    if (sessions.isEmpty) {
      return const Column(
        children: [
          QuickInputCard(),
          SizedBox(height: 12),
          McEmptyView(
            icon: McIcons.aiStar,
            title: McStrings.conversationsEmptyTitle,
            text: McStrings.conversationsEmptyHint,
          ),
        ],
      );
    }

    final groups = _groupByDay(sessions, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const QuickInputCard(),
        const SizedBox(height: 12),
        McSectionHeader(
          title: 'AI 会话历史',
          trailingText: '打开完整双栏工作台',
          onTap: () => context.push('/agent'),
        ),
        for (final group in groups) ...[
          const SizedBox(height: 16),
          McInsetGroup(
            header: group.$1,
            children: [
              for (final s in group.$2)
                _SwipeableSessionRow(
                  key: ValueKey('session-row-${s.id}'),
                  session: s,
                  onOpen: () => context.push('/agent/session/${s.id}'),
                  onFork: () => _fork(context, ref, s),
                  onRename: () => _rename(context, ref, s),
                  onDelete: () => _delete(context, ref, s),
                ),
            ],
          ),
        ],
      ],
    );
  }

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

  static String timeLabel(SessionSummary s, DateTime now) {
    final t = DateTime.tryParse(s.updatedAt ?? '');
    if (t == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    final hm = '${two(t.hour)}:${two(t.minute)}';
    final todayStart = DateTime(now.year, now.month, now.day);
    final diff = todayStart
        .difference(DateTime(t.year, t.month, t.day))
        .inDays;
    if (diff <= 0) return hm;
    if (diff == 1) return '${McStrings.groupYesterday} $hm';
    if (t.year == now.year) return '${t.month}月${t.day}日';
    return '${t.year}/${t.month}/${t.day}';
  }

  static Future<void> _fork(
    BuildContext context,
    WidgetRef ref,
    SessionSummary s,
  ) async {
    final confirmed = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('续接「${s.displayTitle}」？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              '将复制当前对话上下文并创建一条独立新会话，原会话记录不受影响。',
              style: McText.caption.muted,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: McStrings.cancel,
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '新建续接会话',
                    primary: true,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final newId = await ref.read(moreProvider.notifier).forkSession(s.id);
    if (!context.mounted) return;
    if (newId != null) {
      context.push('/agent/session/$newId');
      return;
    }
    McToast.error(McStrings.forkFailedToast);
  }

  static Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    SessionSummary s,
  ) async {
    final initialTitle = s.title.isNotEmpty
        ? s.title
        : (s.lastPrompt.isNotEmpty ? s.lastPrompt : '');
    final controller = TextEditingController(text: initialTitle);
    final next = await showMcSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(McStrings.renameSessionTitle, style: McText.titleSm),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: McText.body,
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: McStrings.cancel,
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: McStrings.save,
                    primary: true,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(controller.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (next == null) return;
    var title = next.trim();
    if (title.length > 80) title = title.substring(0, 80);
    if (title.isEmpty || title == initialTitle) return;
    final err = await ref
        .read(moreProvider.notifier)
        .renameSession(s.id, title);
    if (!context.mounted) return;
    if (err != null) {
      McToast.error(err);
    } else {
      McToast.success(McStrings.renamedToast);
    }
  }

  static Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SessionSummary s,
  ) async {
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(McStrings.deleteSessionTitle, style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              McStrings.deleteSessionConfirmBody.replaceFirst(
                '%s',
                s.displayTitle,
              ),
              style: McText.caption.muted,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: McStrings.cancel,
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: McStrings.delete,
                    icon: McIcons.trash2,
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final err = await ref.read(moreProvider.notifier).deleteSession(s.id);
    if (!context.mounted) return;
    if (err != null) {
      McToast.error(err);
    } else {
      McToast.success(McStrings.deletedToast);
    }
  }
}

class _SwipeableSessionRow extends StatelessWidget {
  const _SwipeableSessionRow({
    super.key,
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
    return Dismissible(
      key: ValueKey('session-swipe-${session.id}-${session.updatedAt}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: McTokens.danger,
        child: const Icon(McIcons.trash2, color: Colors.white, size: 20),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: _SessionRow(
        session: session,
        onOpen: onOpen,
        onFork: onFork,
        onRename: onRename,
        onDelete: onDelete,
      ),
    );
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

  void _showActions(BuildContext context) {
    showMcSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          margin: EdgeInsets.zero,
          children: [
            McInsetRow(
              icon: McIcons.history1,
              title: McStrings.forkSessionAction,
              onTap: () {
                Navigator.of(ctx).pop();
                onFork();
              },
            ),
            McInsetRow(
              icon: McIcons.edit2,
              title: McStrings.renameSessionAction,
              onTap: () {
                Navigator.of(ctx).pop();
                onRename();
              },
            ),
            McInsetRow(
              icon: McIcons.trash2,
              title: McStrings.delete,
              destructive: true,
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        onLongPress: () => _showActions(context),
        highlightColor: McTokens.glassFillActive,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(
            children: [
              const Icon(
                McIcons.chat,
                size: 18,
                color: McTokens.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  session.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.ui,
                ),
              ),
              const SizedBox(width: 8),
              if (session.running)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1F7FB0FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x4D7FB0FF)),
                  ),
                  child: Text(
                    McStrings.runningBadge,
                    style: McText.micro.copyWith(color: McTokens.info),
                  ),
                )
              else
                Text(
                  ConversationsSection.timeLabel(session, DateTime.now()),
                  style: McText.caption.faint.tabular,
                ),
              const SizedBox(width: 4),
              McGlassIconButton(
                icon: McIcons.more,
                size: 30,
                iconSize: 15,
                onTap: () => _showActions(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
