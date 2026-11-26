import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/account_state.dart';
import '../widgets/account_row.dart';

/// 账号切换页（1:1 对齐 Kotlin AccountSwitcherScreen）：
/// 本机已登录账号分组展示，点一下即可切换不用再输密码；
/// 添加账号 -> /onboarding；退出全部账号走两段确认（第二段问是否连本机下载一起删）。
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accountProvider.notifier).restore();
    });
  }

  Future<bool?> _askSheet({
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
  }) {
    return showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: McText.titleSm),
            const SizedBox(height: 8),
            Text(message, style: McText.sub.muted),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: cancelLabel,
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: confirmLabel,
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
  }

  Future<void> _confirmLogoutAll(AccountUiState ui) async {
    final first = await _askSheet(
      title: '退出全部账号？',
      message: '本机保存的登录信息会被清除，之后需要重新输入密码。',
      cancelLabel: '取消',
      confirmLabel: '退出',
    );
    if (first != true || !mounted) return;
    final wipe = await _askSheet(
      title: '同时删除本机下载？',
      message: '只删本机上的副本，观看进度会保留。',
      cancelLabel: '保留下载',
      confirmLabel: '一起删除',
    );
    if (!mounted) return;
    await ref
        .read(accountProvider.notifier)
        .logoutAll(wipeOffline: wipe == true);
    if (!mounted) return;
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(accountProvider);
    final form = McFormWatch.of(context);
    final windowClass = mcWindowClassOf(form);
    final currentAccount = _currentAccount(ui);
    final displayName = ui.me?.nickname ??
        currentAccount?.nickname ??
        ui.me?.username ??
        ui.currentUsername ??
        '未登录';

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: '账号',
            titleVisible: true,
            trailing: [
              McFocusRing(
                borderRadius: 24,
                child: McGlassIconButton(
                  icon: McIcons.device,
                  tooltip: '设备管理',
                  onTap: () => context.push('$routeAccountLocal/devices'),
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: windowClass == McWindowClass.compact
                      ? double.infinity
                      : 720,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    McTokens.pagePadding,
                    12,
                    McTokens.pagePadding,
                    36,
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: McTokens.surfaceRaised,
                        borderRadius:
                            BorderRadius.circular(McTokens.cardRadius),
                        border: Border.all(color: McTokens.line, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2B3140), Color(0xFF171A24)],
                              ),
                              border: Border.all(
                                color: McTokens.lineStrong,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              displayName.isEmpty
                                  ? '?'
                                  : displayName.characters.first.toUpperCase(),
                              style: McText.title.copyWith(
                                color: McTokens.accentStrong,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName, style: McText.titleSm),
                                const SizedBox(height: 2),
                                Text(
                                  "@${ui.me?.username ?? ui.currentUsername ?? '-'} · ${ui.me?.username == null ? '未连接' : (ui.currentOrigin == null ? '成员' : '已登录')}",
                                  style: McText.caption.muted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final server in ui.servers) ...[
                      if (ui.servers.length > 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Text(
                            server.displayOrigin,
                            style: McText.caption.copyWith(
                              color: McTokens.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      for (final account in server.accounts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AccountRow(
                            server: server,
                            account: account,
                            isCurrent: server.origin == ui.currentOrigin &&
                                account.username == ui.currentUsername,
                            busy: ui.busy,
                            onSwitch: () =>
                                ref.read(accountProvider.notifier).switchTo(
                                      server.origin,
                                      account.username,
                                    ),
                            onRemove: () =>
                                ref.read(accountProvider.notifier).remove(
                                      server.origin,
                                      account.username,
                                    ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    Center(
                      child: McFocusRing(
                        borderRadius: McTokens.pillRadius,
                        child: McActionPill(
                          label: '添加账号',
                          icon: McIcons.userAdd,
                          primary: false,
                          expanded: true,
                          onTap: () => context.go('/onboarding'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: McFocusRing(
                        borderRadius: McTokens.pillRadius,
                        child: McActionPill(
                          label: '退出全部账号',
                          icon: McIcons.logout,
                          primary: false,
                          tone: McGlassTone.danger,
                          expanded: true,
                          onTap: () => _confirmLogoutAll(ui),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '本机已登录的账号，点击即可切换，不用再输密码。撤销凭证请到设置 → 设备管理。',
                      style: McText.caption.faint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SavedAccount? _currentAccount(AccountUiState ui) {
    for (final server in ui.servers) {
      if (server.origin != ui.currentOrigin) continue;
      for (final account in server.accounts) {
        if (account.username == ui.currentUsername) return account;
      }
    }
    return null;
  }
}

/// 本模块路由常量（与 routes.dart 保持一致；避免跨文件循环引用）。
const routeAccountLocal = '/account';
