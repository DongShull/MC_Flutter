import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/controllers.dart';
import '../state/mc_api.dart';
import '../widgets/settings_ui.dart';

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
    final next = await textInputDialog(
      context,
      title: '修改昵称',
      initial: current,
      hint: '昵称',
    );
    if (next == null || next.isEmpty || next == current) return;
    final err = await ref.read(profileProvider.notifier).rename(next);
    if (!mounted) return;
    showSettingsToast(context, err ?? '已更新昵称');
  }

  Future<void> _changePassword() async {
    final oldPw = await textInputDialog(
      context,
      title: '当前密码',
      obscureText: true,
    );
    if (oldPw == null || oldPw.isEmpty || !mounted) return;
    final newPw = await textInputDialog(
      context,
      title: '新密码（至少 8 位）',
      obscureText: true,
    );
    if (newPw == null || newPw.length < 8 || !mounted) return;
    final err =
        await ref.read(profileProvider.notifier).changePassword(oldPw, newPw);
    if (!mounted) return;
    showSettingsToast(context, err ?? '密码已更新');
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: '退出登录',
      message: '确定要退出当前账号吗？',
      confirmLabel: '退出',
    );
    if (!ok) return;
    await ref.read(profileProvider.notifier).logout();
    if (!mounted) return;
    showSettingsToast(context, '已退出登录');
    context.go('/');
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (x == null) return;
    try {
      await ref.read(settingsApiProvider).uploadAvatar(x.path);
      await ref.read(profileProvider.notifier).load();
      if (!mounted) return;
      showSettingsToast(context, '头像已更新');
    } catch (_) {
      if (!mounted) return;
      showSettingsToast(context, '头像上传失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    final session = state.valueOrNull;
    final avatarUrl = session?.avatarUrl;
    final initial = session?.displayName.isNotEmpty == true
        ? session!.displayName.characters.first.toUpperCase()
        : '?';

    return SettingsScaffold(
      title: '个人信息',
      body: state.isLoading && session == null
          ? const McLoadingView()
          : ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 32),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _uploadAvatar,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: McTokens.surfaceRaised,
                        border: Border.all(
                          color: McTokens.lineStrong,
                          width: 1.2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Text(
                                initial,
                                style: McText.titleLg,
                              ),
                            )
                          : Text(initial, style: McText.titleLg),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    session?.displayName ?? '未登录',
                    style: McText.titleLg,
                  ),
                ),
                if (session != null) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      '@${session.username} · ${session.roleLabel}',
                      style: McText.caption.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                McInsetGroup(
                  header: '账号资料',
                  dividerIndent: 48,
                  children: [
                    McInsetRow(
                      icon: McIcons.edit2,
                      title: '修改昵称',
                      valueText: session?.nickname,
                      onTap: () => _rename(session?.nickname ?? ''),
                    ),
                    McInsetRow(
                      icon: McIcons.key,
                      title: '修改密码',
                      onTap: _changePassword,
                    ),
                    McInsetRow(
                      icon: McIcons.imageAdd,
                      title: '更换头像',
                      onTap: _uploadAvatar,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                McInsetGroup(
                  children: [
                    McInsetRow(
                      icon: McIcons.logout,
                      title: '退出登录',
                      destructive: true,
                      onTap: _logout,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
