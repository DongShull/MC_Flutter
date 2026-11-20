import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/state_views.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../widgets/more_cards.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 「我的」页（对应安卓 feature/more）：用户卡片 / 提醒组 / 对话会话列表 / 设置入口。
class MorePage extends ConsumerStatefulWidget {
  const MorePage({super.key});

  @override
  ConsumerState<MorePage> createState() => _MorePageState();
}

class _MorePageState extends ConsumerState<MorePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(moreProvider.notifier).load());
  }

  Future<void> _rename(SessionSummary s) async {
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: s.title);
        return AlertDialog(
          title: const Text('重命名会话'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(onPressed: () => ctx.pop(), child: const Text('取消')),
            FilledButton(
              onPressed: () => ctx.pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (next == null || next.isEmpty) return;
    final err = await ref.read(moreProvider.notifier).renameSession(s.id, next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? '已重命名'), behavior: SnackBarBehavior.floating, width: 360),
    );
  }

  Future<void> _delete(SessionSummary s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('删除「${s.displayTitle}」？该操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => ctx.pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await ref.read(moreProvider.notifier).deleteSession(s.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? '已删除'), behavior: SnackBarBehavior.floating, width: 360),
    );
  }

  Future<void> _fork(SessionSummary s) async {
    final err = await ref.read(moreProvider.notifier).forkSession(s.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? '已创建分叉会话'),
        behavior: SnackBarBehavior.floating,
        width: 360,
      ),
    );
    // TODO(agent): agent 路由支持会话参数后，直接跳入新会话。
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(moreProvider);
    final form = ref.watch(mcFormProvider);
    final data = state.valueOrNull;
    final session = data?.session;
    final nickname = (session?['nickname'] ?? session?['username'] ?? '未登录').toString();
    final role = (session?['role'] ?? '').toString();
    final roleLabel = switch (role) {
      'admin' => '超级管理员',
      'member' => '成员',
      '' => '',
      _ => '访客',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: state.isLoading && data == null
          ? const McLoadingView()
          : state.hasError
              ? McErrorView(
                  text: '加载失败',
                  onRetry: () => ref.read(moreProvider.notifier).load(),
                )
              : Center(
                  // 平板/TV（expanded）：列表放宽列宽，内容限宽居中；手机保持现状。
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: form == McDeviceForm.phone
                          ? double.infinity
                          : 720,
                    ),
                    child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                      ref.read(moreProvider.notifier).loadMoreSessions();
                    }
                    return false;
                  },
                  child: ListView(
                    children: [
                      MoreUserCard(
                        displayName: nickname,
                        detail: roleLabel.isEmpty ? '' : roleLabel,
                        onTap: () => context.push('/settings/profile'),
                      ),
                      const MoreSectionLabel('提醒'),
                      MoreEntryRow(
                        icon: McIcons.bellOn,
                        title: '通知与提醒',
                        badge: data?.reminderCount ?? 0,
                        onTap: () => context.push('/notices'),
                      ),
                      MoreEntryRow(
                        icon: Icons.system_update_outlined,
                        title: '检查更新',
                        badge: data?.pendingUpdateLabel != null ? 1 : 0,
                        onTap: () => context.push('/update'),
                      ),
                      const MoreSectionLabel('对话会话'),
                      for (final s in data?.sessions ?? const <SessionSummary>[])
                        ListTile(
                          leading: Icon(
                            s.running ? McIcons.refreshS : McIcons.chat,
                            color: s.running
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(s.displayTitle,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${s.entryCount} 条记录 · ${s.updatedAt ?? ''}',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) => switch (v) {
                              'open' => context.push('/agent'),
                              'rename' => _rename(s),
                              'fork' => _fork(s),
                              'delete' => _delete(s),
                              _ => null,
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(value: 'open', child: Text('打开')),
                              PopupMenuItem(value: 'rename', child: Text('重命名')),
                              PopupMenuItem(value: 'fork', child: Text('创建分叉')),
                              PopupMenuItem(value: 'delete', child: Text('删除')),
                            ],
                          ),
                          onTap: () => context.push('/agent'),
                        ),
                      if (data?.sessions.isEmpty ?? false)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('还没有对话会话')),
                        ),
                      if (data?.loadingMore ?? false)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )),
                        ),
                      const MoreSectionLabel('更多'),
                      MoreEntryRow(
                        icon: McIcons.setting1,
                        title: '设置',
                        onTap: () => context.push('/settings'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                  ),
                ),
    );
  }
}
