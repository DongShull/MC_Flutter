import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/state_views.dart';
import '../state/controllers.dart';
import '../widgets/settings_ui.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 个人信息页（对应安卓 ProfileSectionScreen：头像 / 昵称 / 改密码 / 退出登录）。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileProvider.notifier).load());
  }

  Future<void> _rename(String current) async {
    final next = await textInputDialog(context,
        title: '修改昵称', initial: current, hint: '昵称');
    if (next == null || next.isEmpty || next == current) return;
    final err =
        await ref.read(profileProvider.notifier).rename(next);
    if (!mounted) return;
    showSettingsToast(context, err ?? '已更新昵称');
  }

  Future<void> _changePassword() async {
    final oldPw = await textInputDialog(context, title: '当前密码');
    if (oldPw == null || oldPw.isEmpty || !mounted) return;
    final newPw = await textInputDialog(context, title: '新密码（至少 8 位）');
    if (newPw == null || newPw.length < 8 || !mounted) return;
    final err = await ref
        .read(profileProvider.notifier)
        .changePassword(oldPw, newPw);
    if (!mounted) return;
    showSettingsToast(context, err ?? '密码已更新');
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(context,
        title: '退出登录', message: '确定要退出当前账号吗？', confirmLabel: '退出');
    if (!ok) return;
    await ref.read(profileProvider.notifier).logout();
    if (!mounted) return;
    showSettingsToast(context, '已退出登录');
    // TODO(login): 登录路由落定后跳转登录页。
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    final session = state.valueOrNull;

    return SettingsScaffold(
      title: '个人信息',
      body: state.isLoading && session == null
          ? const McLoadingView()
          : ListView(
              children: [
                const SizedBox(height: 16),
                Center(
                  child: session?.avatarUrl != null &&
                          session!.avatarUrl!.isNotEmpty
                      ? CircleAvatar(
                          radius: 36,
                          backgroundImage: NetworkImage(session.avatarUrl!),
                        )
                      : CircleAvatar(
                          radius: 36,
                          child: Text(
                            session?.displayName.isNotEmpty == true
                                ? session!.displayName.characters.first
                                : '?',
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(session?.displayName ?? '未登录',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Center(
                  child: Text(
                    session == null
                        ? ''
                        : '${session.username} · ${session.roleLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SettingsGroupLabel('账号'),
                SettingsRow(
                  icon: Icons.badge_outlined,
                  title: '修改昵称',
                  onTap: () => _rename(session?.nickname ?? ''),
                ),
                SettingsRow(
                  icon: McIcons.key,
                  title: '修改密码',
                  onTap: _changePassword,
                ),
                // TODO(avatar): 头像上传需要 multipart（McClient 暂缺）。
                const SizedBox(height: 16),
                SettingsRow(
                  icon: McIcons.logout,
                  title: '退出登录',
                  destructive: true,
                  trailing: const SizedBox.shrink(),
                  onTap: _logout,
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
