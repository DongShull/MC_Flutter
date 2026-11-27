import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/session/session_store.dart';
import '../../offline/embed.dart';
import '../state/controllers.dart';
import '../state/mc_api.dart';
import '../widgets/settings_ui.dart';

/// 个人信息页（1:1 对齐 iOS `ProfileSettingsView` + `ProfileEditSheets`）：
/// - 头像上传 + 昵称编辑自动同步 `appSession.saveProfile(...)`；
/// - 统一单表单改密码（当前密码 + 新密码 8~128 位 + 确认新密码 + `sign_out_paired` 开关与配对设备数）；
/// - 右上角 `⋯` 菜单提供「清空播放记录」(`DELETE /api/v1/playback/history?scope=all`)；
/// - 切换账号入口 + 退出前调用 `askOfflineCleanupOnLogout` 再执行 `logoutCurrentAccount`。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileProvider.notifier).load());
  }

  Future<void> _rename(String current) async {
    final next = await textInputDialog(
      context,
      title: '修改昵称（最多 32 字）',
      initial: current,
      hint: '输入新昵称',
    );
    if (next == null || next.isEmpty || next == current) return;
    if (next.runes.length > 32) {
      McToast.error('昵称不能超过 32 个字符');
      return;
    }
    final err = await ref.read(profileProvider.notifier).rename(next);
    if (!mounted) return;
    showSettingsToast(context, err ?? '昵称已更新');
  }

  /// 单一完整改密码弹层（含确认密码校验与 `sign_out_paired` 配对设备注销开关）。
  Future<void> _openChangePasswordSheet() async {
    int? pairedCount;
    try {
      final devices = await ref.read(settingsApiProvider).devices();
      pairedCount = devices
          .where((d) => d.family == 'paired' || d.groupId == 'paired')
          .length;
    } catch (_) {}
    if (!mounted) return;

    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var signOutPaired = false;
    var submitting = false;
    String? err;

    final done = await showMcSheet<bool>(
      context: context,
      maxWidth: 540,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final cur = oldCtrl.text;
          final nw = newCtrl.text;
          final cf = confirmCtrl.text;
          String? validation;
          if (cur.runes.length > 128) {
            validation = '当前密码长度不能超过 128 位';
          } else if (nw.isNotEmpty &&
              (nw.runes.length < 8 || nw.runes.length > 128)) {
            validation = '新密码长度需在 8 到 128 位之间';
          } else if (cf.isNotEmpty && cf != nw) {
            validation = '两次输入的新密码不一致';
          }
          final valid = !submitting &&
              cur.isNotEmpty &&
              nw.isNotEmpty &&
              cf.isNotEmpty &&
              validation == null;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('修改登录密码', style: McText.titleSm),
                const SizedBox(height: 6),
                Text(
                  '修改密码后其他浏览器和手机登录态会自动失效，本机保持登录。',
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: oldCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '当前密码 *'),
                  onChanged: (_) => setSheet(() => err = null),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '新密码 *（8~128 位）',
                  ),
                  onChanged: (_) => setSheet(() => err = null),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '确认新密码 *'),
                  onChanged: (_) => setSheet(() => err = null),
                ),
                if (pairedCount != 0) ...[
                  const SizedBox(height: 12),
                  McInsetGroup(
                    margin: EdgeInsets.zero,
                    footer:
                        '${pairedCount != null ? '当前账号下有 $pairedCount 台配对终端/令牌。' : ''}开启后会一并注销配对设备与手工 API 令牌。',
                    children: [
                      McInsetRow(
                        title: '同时注销已配对设备与令牌',
                        trailing: Switch(
                          value: signOutPaired,
                          onChanged: (v) => setSheet(() => signOutPaired = v),
                        ),
                        onTap: () =>
                            setSheet(() => signOutPaired = !signOutPaired),
                      ),
                    ],
                  ),
                ],
                if (err != null || validation != null) ...[
                  const SizedBox(height: 10),
                  SettingsNoticeBanner(
                    text: err ?? validation!,
                    tone: SettingsTone.danger,
                    margin: EdgeInsets.zero,
                  ),
                ],
                const SizedBox(height: 18),
                McActionPill(
                  label: submitting ? '正在保存…' : '保存新密码',
                  primary: true,
                  expanded: true,
                  onTap: !valid
                      ? null
                      : () async {
                          setSheet(() {
                            submitting = true;
                            err = null;
                          });
                          final msg = await ref
                              .read(profileProvider.notifier)
                              .changePassword(
                                cur,
                                nw,
                                signOutPaired: signOutPaired,
                              );
                          if (!ctx.mounted) return;
                          if (msg == null) {
                            Navigator.of(ctx).pop(true);
                          } else {
                            setSheet(() {
                              submitting = false;
                              err = msg;
                            });
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
    oldCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    if (done == true && mounted) {
      McToast.success(
        signOutPaired ? '密码已更新，已注销所有配对设备' : '密码已更新',
      );
    }
  }

  Future<void> _clearPlaybackHistory() async {
    final ok = await confirmDialog(
      context,
      title: '清空全部播放记录？',
      message: '将清空当前账号的「继续观看」与历史播放记录，不会影响其他家庭成员，且无法恢复。',
      confirmLabel: '清空记录',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final msg = await ref.read(settingsApiProvider).clearPlaybackHistory();
      if (mounted) McToast.success(msg ?? '播放记录已清空');
    } catch (e) {
      if (mounted) McToast.error(settingsErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout(String displayName) async {
    final ok = await confirmDialog(
      context,
      title: '退出登录',
      message: '确定要退出「$displayName」吗？',
      confirmLabel: '退出',
    );
    if (!ok || !mounted) return;

    // 退出前先询问是否一并清理本机离线下载副本
    await askOfflineCleanupOnLogout(context, ref);
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      final sibling =
          await ref.read(profileProvider.notifier).logoutCurrentAccount();
      if (!mounted) return;
      if (sibling != null) {
        McToast.info('已自动切换到账号 ${sibling.username}');
        context.go('/home');
      } else {
        McToast.info('已退出登录');
        context.go('/onboarding');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (x == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final err = await ref.read(profileProvider.notifier).uploadAvatar(x.path);
      if (!mounted) return;
      if (err != null) {
        McToast.error('头像上传失败：$err');
      } else {
        McToast.success('头像已更新');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    final session = state.valueOrNull;
    final avatarUrl = session?.avatarUrl ?? appSession.avatarUrl;
    final displayName =
        session?.displayName ?? (appSession.username.isNotEmpty ? appSession.username : '未登录');
    final initial = displayName.isNotEmpty
        ? displayName.characters.first.toUpperCase()
        : '?';

    return SettingsScaffold(
      title: '个人信息',
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(McIcons.dotVerticalS, size: 20),
          enabled: !_busy,
          onSelected: (v) {
            if (v == 'clear_history') _clearPlaybackHistory();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'clear_history',
              child: Text(
                '清空播放记录',
                style: TextStyle(color: McTokens.danger),
              ),
            ),
          ],
        ),
      ],
      body: state.isLoading && session == null
          ? const McLoadingView()
          : ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 32),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _busy ? null : _uploadAvatar,
                    child: Container(
                      width: 82,
                      height: 82,
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
                      child: avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: McImageUrls.resolve(
                                avatarUrl,
                                widthPx: 164,
                              ),
                              httpHeaders: mcImageHeaders(),
                              width: 82,
                              height: 82,
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
                const SizedBox(height: 10),
                Center(
                  child: Text(displayName, style: McText.titleLg),
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
                    if (session != null)
                      McInsetRow(
                        icon: McIcons.accountCircle,
                        title: '登录用户名',
                        valueText: session.username,
                      ),
                    McInsetRow(
                      icon: McIcons.edit2,
                      title: '修改昵称',
                      valueText: session?.nickname,
                      onTap: _busy ? null : () => _rename(session?.nickname ?? ''),
                    ),
                    McInsetRow(
                      icon: McIcons.imageAdd,
                      title: '更换头像',
                      onTap: _busy ? null : _uploadAvatar,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                McInsetGroup(
                  header: '安全与账号切换',
                  dividerIndent: 48,
                  children: [
                    McInsetRow(
                      icon: McIcons.key,
                      title: '修改密码',
                      onTap: _busy ? null : _openChangePasswordSheet,
                    ),
                    McInsetRow(
                      icon: McIcons.team,
                      title: '切换账号 / 服务器',
                      subtitle: '在本机已保存的多账号与多台服务器间快速切换',
                      onTap: _busy ? null : () => context.push('/account'),
                    ),
                    McInsetRow(
                      icon: McIcons.history1Remove,
                      title: '清空播放记录',
                      destructive: true,
                      onTap: _busy ? null : _clearPlaybackHistory,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                McInsetGroup(
                  children: [
                    McInsetRow(
                      icon: McIcons.logout,
                      title: '退出登录',
                      destructive: true,
                      onTap: _busy ? null : () => _logout(displayName),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
