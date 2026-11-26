import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/theme.dart';
import '../state/controllers.dart';

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

/// 账号切换底部液态毛玻璃弹层。
Future<void> showAccountSwitcherSheet(BuildContext context) {
  return showMcSheet<void>(
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
          for (final account in ((server['accounts'] ?? const [])
                  as List<dynamic>)
              .whereType<Map<dynamic, dynamic>>()) {
            final username = (account['username'] ?? '').toString();
            if (origin.isEmpty || username.isEmpty) continue;
            options.add(
              _AccountOption(
                origin: origin,
                username: username,
                nickname: account['nickname']?.toString(),
              ),
            );
          }
        }
      } catch (_) {}
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
      McToast.success(
        '${McStrings.accountSwitchedToastPrefix}${option.nickname ?? option.username}',
      );
      return;
    }
    setState(() => _busy = false);
    McToast.error(McStrings.accountSwitchFailedToast);
  }

  Future<void> _remove(_AccountOption option) async {
    final confirmed = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('移除本机账号', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              '移除「${option.nickname ?? option.username}」在本机的登录快照？再次登录需重新输入密码。',
              style: McText.caption.muted,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '取消',
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '移除',
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
    if (confirmed != true) return;
    final store = ref.read(sessionStoreProvider);
    await store.deleteAccountToken(
      origin: option.origin,
      username: option.username,
    );
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
              .where(
                (a) => a is Map && a['username']?.toString() != option.username,
              )
              .toList();
          if (accounts.isEmpty) {
            servers.remove(server);
          } else {
            server['accounts'] = accounts;
          }
          break;
        }
        await storage.write(key: 'mc_servers', value: jsonEncode(servers));
      } catch (_) {}
    }
    await _loadOptions();
  }

  Future<void> _logoutAll() async {
    final confirmed = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('退出全部账号', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              '本机所有账号的登录状态都会被清除，重新进入需再次连接服务器。',
              style: McText.caption.muted,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '取消',
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '退出全部',
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
    final currentUsername = _currentUsername;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(McStrings.accountSwitcherTitle, style: McText.title),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: McTokens.accentStrong,
                    ),
                  ),
                ),
              McGlassIconButton(
                icon: McIcons.close2,
                size: 32,
                iconSize: 16,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('本机已保存的账号，轻点即可免密秒切。', style: McText.caption.muted),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final option in _options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AccountCard(
                        option: option,
                        isCurrent: option.username == currentUsername,
                        onTap: () => _switch(option),
                        onRemove: option.username == currentUsername
                            ? null
                            : () => _remove(option),
                      ),
                    ),
                  const SizedBox(height: 4),
                  McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      McInsetRow(
                        icon: McIcons.addCircle,
                        title: '添加其他账号 / 服务器',
                        showChevron: true,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go('/onboarding');
                        },
                      ),
                      McInsetRow(
                        icon: McIcons.logout,
                        title: '退出全部账号',
                        destructive: true,
                        onTap: _logoutAll,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final name = option.nickname ?? option.username;
    final initial = name.isEmpty
        ? 'M'
        : String.fromCharCode(name.runes.first).toUpperCase();

    return McPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent ? McTokens.glassFillActive : McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? McTokens.lineStrong : McTokens.line,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [Color(0xFF3E6DA8), Color(0xFF6B53A8)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: McText.titleSm.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.ui.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${option.username} · ${option.displayOrigin}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    McIcons.checkCircleFill,
                    size: 16,
                    color: McTokens.ok,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '当前',
                    style: McText.caption.copyWith(
                      color: McTokens.ok,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else if (onRemove != null)
              McGlassIconButton(
                icon: McIcons.close2,
                size: 30,
                iconSize: 15,
                onTap: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
