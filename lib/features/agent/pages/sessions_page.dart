
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/agent_state.dart';

/// AI 助手入口页（对齐 Kotlin 会话列表）：新对话 + 会话列表（条数/时间），左滑删除。
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

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('$routeAgentLocal/new'),
        icon: const Icon(Icons.add),
        label: const Text('新对话'),
      ),
      body: sessions.isEmpty
          ? Center(
              child: Text(
                '还没有对话，点右下角开始。',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Dismissible(
                  key: ValueKey(session.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: scheme.error,
                    child: const Icon(Icons.delete_outline,
                        color: Colors.white),
                  ),
                  onDismissed: (_) =>
                      ref.read(sessionsProvider.notifier).remove(session.id),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(
                      session.running
                          ? Icons.autorenew
                          : Icons.chat_bubble_outline,
                      color: session.running
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    title: Text(
                      session.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${session.entryCount} 条消息'
                          "${session.updatedAt == null ? '' : ' · ${session.updatedAt!}'}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    onTap: () =>
                        context.push('$routeAgentLocal/session/${session.id}'),
                  ),
                );
              },
            ),
    );
  }
}

/// 本模块路由常量（与 routes.dart 保持一致）。
const routeAgentLocal = '/agent';
