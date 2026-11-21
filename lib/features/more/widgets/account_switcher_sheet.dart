import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_icons.dart';
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

/// 打开账号切换底部弹层（对齐鸿蒙 ProfileCard 的「切换账号」）。
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentUsername = _currentUsername;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    McStrings.accountSwitcherTitle,
                    style: TextStyle(
                      fontSize: 16,
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
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final option in _options)
                  ListTile(
                    leading: Icon(
                      McIcons.accountCircleFill,
                      color: option.username == currentUsername
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    title: Text(option.nickname ?? option.username),
                    subtitle: Text(
                      '${option.displayOrigin} · ${option.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: option.username == currentUsername
                        ? Icon(Icons.check, size: 18, color: scheme.primary)
                        : null,
                    onTap: () => _switch(option),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
