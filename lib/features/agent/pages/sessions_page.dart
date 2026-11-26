import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/agent_state.dart';

const routeAgentLocal = '/agent';

/// AI 助手历史会话列表页（纯黑底 + 顶部新建对话胶囊 + `McInsetGroup` 分组左滑删除）。
class SessionsPage extends ConsumerStatefulWidget {
  const SessionsPage({super.key});

  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ConsumerState<SessionsPage> {
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

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);
    final form = McFormWatch.of(context);
    final wide = mcWindowClassOf(form) != McWindowClass.compact;
    final topPad = MediaQuery.paddingOf(context).top;

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
              onRetry: () => context.push('$routeAgentLocal/new'),
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
                              onTap: () => context.push(
                                '$routeAgentLocal/session/${session.id}',
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
                  onTap: () => context.push('$routeAgentLocal/new'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
