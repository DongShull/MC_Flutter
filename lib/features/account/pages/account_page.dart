import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_watch.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_store.dart';
import '../state/account_state.dart';
import '../widgets/account_row.dart';

/// 账号切换页：
/// 本机已登录账号按服务器分组展示，点一下即可免密秒切；
/// 添加账号 -> `/onboarding?mode=add`；退出全部账号走两段确认并通过 `PendingRevocations` 注销令牌。
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
      message: '本机保存的登录信息会被清除并注销设备令牌，之后需要重新输入密码。',
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

  bool _isSameAccount(
    String serverOrigin,
    String username,
    AccountUiState ui,
  ) {
    final curOrigin = SessionStore.normalizeOrigin(ui.currentOrigin ?? '');
    final curUser = SessionStore.normalizeUsername(ui.currentUsername ?? '');
    return curOrigin.isNotEmpty &&
        curUser.isNotEmpty &&
        SessionStore.normalizeOrigin(serverOrigin) == curOrigin &&
        SessionStore.normalizeUsername(username) == curUser;
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(accountProvider);
    final perms = ref.watch(mcPermissionsProvider);
    final form = McFormWatch.of(context);
    final windowClass = mcWindowClassOf(form);
    final currentAccount = _currentAccount(ui);
    final displayName = ui.me?.nickname ??
        currentAccount?.nickname ??
        ui.me?.username ??
        ui.currentUsername ??
        '未登录';
    final roleBadge = perms.isAdmin ? '超级管理员' : '成员';

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
                              McPermissions.avatarInitials(displayName),
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
                                  "@${ui.me?.username ?? ui.currentUsername ?? '-'} · $roleBadge",
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
                            isCurrent: _isSameAccount(
                              server.origin,
                              account.username,
                              ui,
                            ),
                            busy: ui.busy,
                            onSwitch: () {
                              if (account.expired) {
                                context.push(
                                  Uri(
                                    path: '/onboarding',
                                    queryParameters: {
                                      'mode': 'relogin',
                                      'server': server.origin,
                                      'username': account.username,
                                    },
                                  ).toString(),
                                );
                                return;
                              }
                              ref.read(accountProvider.notifier).switchTo(
                                    server.origin,
                                    account.username,
                                  );
                            },
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
                          onTap: () {
                            final origin = ui.currentOrigin;
                            context.push(
                              Uri(
                                path: '/onboarding',
                                queryParameters: {
                                  'mode': 'add',
                                  if (origin != null && origin.isNotEmpty)
                                    'server': origin,
                                },
                              ).toString(),
                            );
                          },
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
                      perms.isAdmin
                          ? '本机已登录的账号，点击即可免密秒切。完整成员与设备策略请前往设置中心。'
                          : '本机已登录的账号，点击即可切换，不用再输密码。管理登录设备请点击右上角设备图标。',
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
      for (final account in server.accounts) {
        if (_isSameAccount(server.origin, account.username, ui)) {
          return account;
        }
      }
    }
    return null;
  }
}

/// 本模块路由常量（与 routes.dart 保持一致；避免跨文件循环引用）。
const routeAccountLocal = '/account';
