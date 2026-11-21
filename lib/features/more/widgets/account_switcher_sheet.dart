import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../state/controllers.dart';

/// 本机快照里的一个可切换账号（mc_servers 快照的扁平视图）。
class _AccountOption {
  const _AccountOption({
    required this.origin,
    required this.username,
    this.nickname,
  });

  final String origin;
  final String username;
  final String? nickname;

  String get displayOrigin => origin
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'/$'), '');
}

/// 账号切换底部弹层（1:1 对齐鸿蒙截图）：
/// 标题+关闭 → 副标题 → 账号卡（头像/名称/@账号·地址/✓当前/✕移除）→
/// 添加账号 / 退出全部账号（红）→ 底注。
Future<void> showAccountSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _AccountSwitcherSheet(),
  );
}

class _AccountSwitcherSheet extends ConsumerStatefulWidget {
  const _AccountSwitcherSheet();

  @override
  ConsumerState<_AccountSwitcherSheet> createState() =>
      _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends ConsumerState<_AccountSwitcherSheet> {
  List<_AccountOption> _options = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  /// 读 mc_servers 多服务器快照（不含令牌，键与 account 域一致）。
  Future<void> _loadOptions() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    final raw = await storage.read(key: 'mc_servers');
    final options = <_AccountOption>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        for (final server in (jsonDecode(raw) as List<dynamic>)
            .whereType<Map<dynamic, dynamic>>()) {
          final origin = (server['origin'] ?? '').toString();
          for (final account
              in ((server['accounts'] ?? const []) as List<dynamic>)
                  .whereType<Map<dynamic, dynamic>>()) {
            final username = (account['username'] ?? '').toString();
            if (origin.isEmpty || username.isEmpty) continue;
            options.add(_AccountOption(
              origin: origin,
              username: username,
              nickname: account['nickname']?.toString(),
            ));
          }
        }
      } catch (_) {
        // 快照损坏当作空（不崩溃）。
      }
    }
    if (mounted) setState(() => _options = options);
  }

  String get _currentUsername =>
      (ref.read(moreProvider).valueOrNull?.session?['username'] ?? '')
          .toString();

  Future<void> _switch(_AccountOption option) async {
    if (_busy) return;
    setState(() => _busy = true);
    final store = ref.read(sessionStoreProvider);
    // 先把当前会话令牌快照回账号键（避免丢失），再取目标账号令牌。
    final curOrigin = store.baseUrl;
    final curUser = _currentUsername;
    if (curOrigin != null && curUser.isNotEmpty) {
      await store.snapshotAccountToken(origin: curOrigin, username: curUser);
    }
    final ok = await store.switchAccount(
      origin: option.origin,
      username: option.username,
    );
    if (!mounted) return;
    if (ok) {
      await ref.read(moreProvider.notifier).load();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${McStrings.accountSwitchedToastPrefix}${option.nickname ?? option.username}'),
          behavior: SnackBarBehavior.floating,
          width: 360,
        ),
      );
      return;
    }
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(McStrings.accountSwitchFailedToast),
        behavior: SnackBarBehavior.floating,
        width: 360,
      ),
    );
  }

  /// ✕ 移除账号：删令牌快照 + 从 mc_servers 摘除（当前登录账号不允许在这移除）。
  Future<void> _remove(_AccountOption option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除账号'),
        content: Text(
            '移除 ${option.nickname ?? option.username} 在本机的登录快照？再登录需要重新输密码。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE5615B),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final store = ref.read(sessionStoreProvider);
    await store.deleteAccountToken(
      origin: option.origin, username: option.username);
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    final raw = await storage.read(key: 'mc_servers');
    if (raw != null && raw.isNotEmpty) {
      try {
        final servers = (jsonDecode(raw) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
        for (final server in servers) {
          if (server['origin']?.toString() != option.origin) continue;
          final accounts = ((server['accounts'] ?? const []) as List<dynamic>)
              .where((a) =>
                  a is Map && a['username']?.toString() != option.username)
              .toList();
          if (accounts.isEmpty) {
            servers.remove(server);
          } else {
            server['accounts'] = accounts;
          }
          break;
        }
        await storage.write(key: 'mc_servers', value: jsonEncode(servers));
      } catch (_) {
        // 快照清理失败不阻断。
      }
    }
    await _loadOptions();
  }

  /// 退出全部账号：清所有快照并回登录页。
  Future<void> _logoutAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出全部账号'),
        content: const Text('本机所有账号的登录状态都会被清除，再回来需要重新输入密码。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE5615B),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('退出全部'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    await storage.delete(key: 'mc_servers');
    await ref.read(sessionStoreProvider).logout();
    if (!mounted) return;
    Navigator.of(context).pop();
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentUsername = _currentUsername;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题 + 关闭。
            Row(
              children: [
                Expanded(
                  child: Text(
                    McStrings.accountSwitcherTitle,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (_busy)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
            Text(
              '本机已登录的账号，点击即可切换，不用再输密码。',
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            // 账号卡列表。
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final option in _options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AccountCard(
                        option: option,
                        isCurrent: option.username == currentUsername,
                        onTap: () => _switch(option),
                        onRemove:
                            option.username == currentUsername
                                ? null
                                : () => _remove(option),
                      ),
                    ),
                  if (_options.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        McStrings.empty,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  // 添加账号 / 退出全部账号。
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.add,
                              size: 22, color: scheme.onSurface),
                          title: const Text('添加账号'),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go('/onboarding');
                          },
                        ),
                        Divider(height: 1, color: scheme.outlineVariant),
                        ListTile(
                          leading: const Icon(
                              Icons.logout,
                              size: 22,
                              color: Color(0xFFE5615B),
                          ),
                          title: const Text(
                            '退出全部账号',
                            style: TextStyle(color: Color(0xFFE5615B)),
                          ),
                          onTap: _logoutAll,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '添加账号时改一下服务器地址，就能登录到另一台 MovieClaw。',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 账号卡：头像圆 + 名称 + @账号 · 地址 + ✓当前 / ✕ 移除。
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.option,
    required this.isCurrent,
    required this.onTap,
    this.onRemove,
  });

  final _AccountOption option;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = option.nickname ?? option.username;
    final initial =
        name.isEmpty ? '?' : String.fromCharCode(name.runes.first);
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.tertiary],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '@${option.username} · ${option.displayOrigin}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 16, color: scheme.primary),
                    const SizedBox(width: 2),
                    Text('当前',
                        style: TextStyle(
                            fontSize: 13, color: scheme.primary)),
                  ],
                )
              else if (onRemove != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close,
                      size: 18, color: scheme.onSurfaceVariant),
                  onPressed: onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
