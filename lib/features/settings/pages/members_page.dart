// 成员页（对应 web settings members 分区 / 安卓 MembersSettingsScreen）：
// 成员列表、新建、改昵称与能力开关（订阅/搜索/直接下载）、
// 启用停用、重置密码、强制退出、删除。仅管理员。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../../../core/designsystem/mc_icons.dart';
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key});

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  late Future<List<core.MemberView>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<core.MemberView>> _load() =>
      ref.read(settingsApiProvider).members();

  void _reload() => setState(() => _future = _load());

  Future<void> _run(Future<void> Function() fn, String okMsg) async {
    try {
      await fn();
      if (!mounted) return;
      showSettingsToast(context, okMsg);
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '操作失败：$e');
    }
  }

  Future<void> _create() async {
    final values = await showAdminFormDialog(
      context,
      title: '新建成员',
      fields: const [
        AdminFieldSpec(key: 'username', label: '用户名', required: true),
        AdminFieldSpec(key: 'password', label: '密码', kind: AdminFieldKind.password, required: true),
        AdminFieldSpec(key: 'nickname', label: '昵称'),
      ],
    );
    if (values == null) return;
    await _run(
      () => ref.read(settingsApiProvider).createMember(
            core.MemberCreateRequest(
              username: values['username'] as String? ?? '',
              password: values['password'] as String? ?? '',
              nickname: values['nickname'] as String? ?? '',
            ),
          ),
      '已创建成员',
    );
  }

  Future<void> _edit(core.MemberView m) async {
    final values = await showAdminFormDialog(
      context,
      title: '编辑成员',
      initial: {
        'nickname': m.nickname,
        'allowSubscribe': m.allowSubscribe,
        'allowSearch': m.allowSearch,
        'allowDirectDownload': m.allowDirectDownload,
        'allLibraries': m.allLibraries,
      },
      fields: const [
        AdminFieldSpec(key: 'nickname', label: '昵称'),
        AdminFieldSpec(key: 'allowSubscribe', label: '允许订阅', kind: AdminFieldKind.boolean),
        AdminFieldSpec(key: 'allowSearch', label: '允许搜索', kind: AdminFieldKind.boolean),
        AdminFieldSpec(key: 'allowDirectDownload', label: '允许直接下载', kind: AdminFieldKind.boolean),
        AdminFieldSpec(key: 'allLibraries', label: '全部媒体库', kind: AdminFieldKind.boolean),
      ],
    );
    if (values == null) return;
    await _run(
      () => ref.read(settingsApiProvider).updateMember(
            m.id,
            core.MemberUpdateRequest(
              nickname: values['nickname'] as String?,
              allowSubscribe: values['allowSubscribe'] as bool?,
              allowSearch: values['allowSearch'] as bool?,
              allowDirectDownload: values['allowDirectDownload'] as bool?,
              allLibraries: values['allLibraries'] as bool?,
            ),
          ),
      '已保存',
    );
  }

  Future<void> _resetPassword(core.MemberView m) async {
    final ok = await confirmDialog(
      context,
      title: '重置密码',
      message: '重置「${m.username}」的密码？新密码将只显示一次。',
      confirmLabel: '重置',
    );
    if (!ok) return;
    try {
      final result =
          await ref.read(settingsApiProvider).resetMemberPassword(m.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('新密码'),
          content: SelectableText(result.password),
          actions: [
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('知道了')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '重置失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '成员',
        body: AdminAsyncBody<List<core.MemberView>>(
          future: _future,
          onRetry: _reload,
          builder: (context, members) => ListView(
            children: [
              for (final m in members)
                SettingsRow(
                  icon: McIcons.accountCircle,
                  title: m.nickname.isEmpty ? m.username : m.nickname,
                  subtitle:
                      '${m.username} · ${m.status} · 设备 ${m.deviceCount}',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (m.status != 'active')
                        const Text('已停用'),
                      IconButton(
                        tooltip: '启用/停用',
                        icon: Icon(m.status == 'active'
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline),
                        onPressed: () => _run(
                          () => ref
                              .read(settingsApiProvider)
                              .setMemberStatus(
                                m.id,
                                core.MemberStatusRequest(
                                    enabled: m.status != 'active'),
                              ),
                          m.status == 'active' ? '已停用' : '已启用',
                        ),
                      ),
                    ],
                  ),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(McIcons.edit),
                            title: const Text('编辑昵称与权限'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _edit(m);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.key),
                            title: const Text('重置密码'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _resetPassword(m);
                            },
                          ),
                          ListTile(
                            leading: const Icon(McIcons.logout),
                            title: const Text('强制退出登录'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _run(
                                () => ref
                                    .read(settingsApiProvider)
                                    .signOutMember(m.id),
                                '已强制退出',
                              );
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete,
                                color: Theme.of(context).colorScheme.error),
                            title: Text('删除成员',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final ok = await confirmDialog(
                                context,
                                title: '删除成员',
                                message: '确定删除「${m.username}」吗？',
                                confirmLabel: '删除',
                              );
                              if (ok) {
                                await _run(
                                  () => ref
                                      .read(settingsApiProvider)
                                      .deleteMember(m.id),
                                  '已删除',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('新建成员'),
                  onPressed: _create,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
