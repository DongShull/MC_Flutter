import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/agent_state.dart';
import '../state/models.dart';
import 'chat_page.dart';

const routeAgentLocal = '/agent';

/// AI 助手工作台：
/// - 桌面 / iPad 宽屏（`width >= 860`）：双栏 Master-Detail 工作台（左侧 296dp 会话列表 + 右侧实时对话流）；
/// - 手机紧凑屏：纯黑银玻璃会话列表页 + 左滑删除 + 右键/长按重命名与分叉。
class SessionsPage extends ConsumerStatefulWidget {
  const SessionsPage({super.key});

  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ConsumerState<SessionsPage> {
  String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionsProvider.notifier).load();
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _startNewSession({required bool splitView}) {
    if (splitView) {
      setState(() => _selectedSessionId = null);
      ref.read(chatProvider.notifier).resetNewSession();
    } else {
      ref.read(chatProvider.notifier).resetNewSession();
      context.push('$routeAgentLocal/new');
    }
  }

  void _openSession(SessionSummary session, {required bool splitView}) {
    if (splitView) {
      setState(() => _selectedSessionId = session.id);
      ref.read(chatProvider.notifier).openSession(session.id);
    } else {
      context.push('$routeAgentLocal/session/${session.id}');
    }
  }

  Future<void> _promptRename(SessionSummary session) async {
    final ctrl = TextEditingController(text: session.displayTitle);
    final nextTitle = await showMcSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(ctx).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('重命名会话', style: McText.title),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: McText.body,
              decoration: const InputDecoration(hintText: '输入会话标题'),
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
            const SizedBox(height: 16),
            McActionPill(
              label: '保存',
              icon: McIcons.check,
              primary: true,
              onTap: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            ),
          ],
        ),
      ),
    );
    if (nextTitle != null && nextTitle.isNotEmpty) {
      await ref.read(sessionsProvider.notifier).rename(session.id, nextTitle);
      McToast.success('已更新会话标题');
    }
  }

  void _showSessionMenu(
    SessionSummary session, {
    Offset? globalPos,
    required bool splitView,
  }) {
    showMcContextActions(
      context: context,
      title: session.displayTitle,
      globalPosition: globalPos,
      actions: [
        McPosterMenuAction(
          icon: McIcons.edit2,
          label: '重命名会话',
          onTap: () => _promptRename(session),
        ),
        McPosterMenuAction(
          icon: McIcons.merge,
          label: '分叉为新会话',
          onTap: () async {
            final newId = await ref
                .read(agentApiProvider)
                .forkSession(session.id);
            await ref.read(sessionsProvider.notifier).load();
            if (!mounted || newId == null || newId.isEmpty) return;
            McToast.success('已分叉新会话');
            if (splitView) {
              setState(() => _selectedSessionId = newId);
              await ref.read(chatProvider.notifier).openSession(newId);
            } else {
              context.push('$routeAgentLocal/session/$newId');
            }
          },
        ),
        McPosterMenuAction(
          icon: McIcons.trash2,
          label: '删除会话',
          destructive: true,
          onTap: () async {
            await ref.read(sessionsProvider.notifier).remove(session.id);
            if (_selectedSessionId == session.id) {
              setState(() => _selectedSessionId = null);
              ref.read(chatProvider.notifier).resetNewSession();
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);
    final activeChatId = ref.watch(chatProvider.select((s) => s.sessionId));
    final width = MediaQuery.sizeOf(context).width;
    final splitView = width >= 860;
    final form = McFormWatch.of(context);
    final wide = mcWindowClassOf(form) != McWindowClass.compact;
    final topPad = MediaQuery.paddingOf(context).top;

    if (splitView) {
      final effectiveSelected = _selectedSessionId ?? activeChatId;
      return Scaffold(
        backgroundColor: McTokens.bg,
        body: Row(
          children: [
            Container(
              width: 300,
              decoration: const BoxDecoration(
                color: McTokens.surfaceInset,
                border: Border(right: BorderSide(color: McTokens.line)),
              ),
              child: SafeArea(
                right: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Row(
                        children: [
                          McGlassIconButton(
                            icon: McIcons.arrowLeftS,
                            tooltip: '返回',
                            onTap: _back,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('AI 助手', style: McText.title),
                          ),
                          McActionPill(
                            label: '新对话',
                            icon: McIcons.addS,
                            primary: true,
                            height: 34,
                            onTap: () => _startNewSession(splitView: true),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: McTokens.line, height: 1),
                    Expanded(
                      child: sessions.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  '暂无历史会话\n在右侧直接提问即可自动保存',
                                  textAlign: TextAlign.center,
                                  style: McText.caption.faint,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(10),
                              itemCount: sessions.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final s = sessions[index];
                                final selected = s.id == effectiveSelected;
                                return GestureDetector(
                                  onSecondaryTapUp: (d) => _showSessionMenu(
                                    s,
                                    globalPos: d.globalPosition,
                                    splitView: true,
                                  ),
                                  child: McPressable(
                                    onTap: () =>
                                        _openSession(s, splitView: true),
                                    onLongPress: () =>
                                        _showSessionMenu(s, splitView: true),
                                    scaleDown: 0.99,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? McTokens.surfaceRaised
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selected
                                              ? McTokens.lineStrong
                                              : Colors.transparent,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            s.running
                                                ? McIcons.aiStarFill
                                                : McIcons.chat,
                                            size: 16,
                                            color: s.running
                                                ? McTokens.info
                                                : (selected
                                                    ? McTokens.accentStrong
                                                    : McTokens.textMuted),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  s.displayTitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: McText.sub.copyWith(
                                                    color: selected
                                                        ? McTokens.accentStrong
                                                        : McTokens.text,
                                                    fontWeight: selected
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${s.entryCount} 条消息',
                                                  style: McText.micro.faint,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ChatPage(
                key: ValueKey(_selectedSessionId ?? 'embedded-new'),
                sessionId: _selectedSessionId,
                embedded: true,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (sessions.isEmpty)
            McEmptyView(
              icon: McIcons.aiStar,
              title: '还没有 AI 会话',
              text: '点击下方按钮开始一段新的影视助手对话',
              actionLabel: '新建对话',
              onRetry: () => _startNewSession(splitView: false),
            )
          else
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: wide ? 760 : double.infinity,
                ),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(0, topPad + 64, 0, 48),
                  children: [
                    McInsetGroup(
                      header: '全部会话',
                      children: [
                        for (final session in sessions)
                          Dismissible(
                            key: ValueKey(session.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: McTokens.danger,
                              child: const Icon(
                                McIcons.trash2,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            onDismissed: (_) => ref
                                .read(sessionsProvider.notifier)
                                .remove(session.id),
                            child: GestureDetector(
                              onSecondaryTapUp: (d) => _showSessionMenu(
                                session,
                                globalPos: d.globalPosition,
                                splitView: false,
                              ),
                              onLongPress: () => _showSessionMenu(
                                session,
                                splitView: false,
                              ),
                              child: McInsetRow(
                                icon: session.running
                                    ? McIcons.aiStarFill
                                    : McIcons.chat,
                                iconColor: session.running
                                    ? McTokens.info
                                    : McTokens.textMuted,
                                title: session.displayTitle,
                                subtitle:
                                    '${session.entryCount} 条消息'
                                    "${session.updatedAt == null ? '' : ' · ${session.updatedAt!}'}",
                                showChevron: true,
                                onTap: () =>
                                    _openSession(session, splitView: false),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: McFloatingDetailBar(
              onBack: _back,
              title: 'AI 助手',
              titleVisible: true,
              trailing: [
                McActionPill(
                  label: '新对话',
                  icon: McIcons.addS,
                  primary: true,
                  height: 36,
                  onTap: () => _startNewSession(splitView: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
