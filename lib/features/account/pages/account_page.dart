import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';

import '../state/account_state.dart';
import '../widgets/account_row.dart';
import '../../../core/designsystem/mc_icons.dart';

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

  Future<void> _confirmLogoutAll(AccountUiState ui) async {
    final scheme = Theme.of(context).colorScheme;
    // 第一段：确认退出全部账号。
    final first = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出全部账号？'),
        content: const Text('本机保存的登录信息会被清除，之后需要重新输入密码。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('退出', style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    // 第二段：问是否连本机下载的副本一起删（对齐 askOfflineCleanup）。
    final wipe = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('同时删除本机下载？'),
        content: const Text('只删本机上的副本，观看进度会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('保留下载'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('一起删除', style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await ref.read(accountProvider.notifier).logoutAll(wipeOffline: wipe == true);
    if (!mounted) return;
    // 登出完成 -> 跳 /onboarding 重新登录。
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(accountProvider);
    final scheme = Theme.of(context).colorScheme;
    final form = McFormWatch.of(context);
    final windowClass = mcWindowClassOf(form);
    final currentAccount = _currentAccount(ui);
    final displayName = ui.me?.nickname ??
        currentAccount?.nickname ??
        ui.me?.username ??
        ui.currentUsername ??
        '未登录';

    return Scaffold(
      appBar: AppBar(
        title: const Text('账号'),
        actions: [
          // TV：设备管理入口 D-pad 聚焦环。
          McFocusRing(
            borderRadius: 24,
            child: IconButton(
              tooltip: '设备管理',
              icon: const Icon(McIcons.device),
              // 设备管理唯一实现在 settings（/settings/devices），
              // account 不再保留重复页（P4 合并）。
              onPressed: () => context.push('/settings/devices'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: windowClass == McWindowClass.compact
                ? double.infinity
                : 720,
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
          // 当前用户信息卡。
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF26A5E4), Color(0xFF7C6FF0)],
                    ),
                  ),
                  child: Text(
                    displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(
                        "@${ui.me?.username ?? ui.currentUsername ?? '-'} · ${ui.me?.username == null ? '未连接' : (ui.currentOrigin == null ? '成员' : '已登录')}",
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 本机账号分组（对齐 AccountSwitcherScreen 的 servers.forEach）。
          for (final server in ui.servers) ...[
            if (ui.servers.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  server.displayOrigin,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final account in server.accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
          // 添加账号。
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: McFocusRing(
              borderRadius: 20,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/onboarding'),
                icon: const Icon(McIcons.userAdd),
                label: const Text('添加账号'),
              ),
            ),
          ),
          // 退出全部账号（Danger）。
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: McFocusRing(
              borderRadius: 20,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
                ),
                onPressed: () => _confirmLogoutAll(ui),
                icon: const Icon(McIcons.logout),
                label: const Text('退出全部账号'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '本机已登录的账号，点击即可切换，不用再输密码。撤销凭证请到设置 → 设备管理。',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
            ],
          ),
        ),
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
