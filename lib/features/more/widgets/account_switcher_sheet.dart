import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/l10n/mc_l10n.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/platform/download_channel.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_store.dart';
import '../state/controllers.dart';

const _offlineTasksPrefsKey = 'offline_tasks_v2';

enum _AccountFreshness { loading, fresh, expired, unreachable }

class _AccountOption {
  const _AccountOption({
    required this.origin,
    required this.username,
    this.nickname,
    this.role = 'member',
    this.avatarUrl,
    this.expired = false,
  });

  final String origin;
  final String username;
  final String? nickname;
  final String role;
  final String? avatarUrl;
  final bool expired;

  String get key =>
      '${SessionStore.normalizeOrigin(origin)}#${SessionStore.normalizeUsername(username)}';

  String get displayName =>
      (nickname != null && nickname!.trim().isNotEmpty) ? nickname! : username;

  String get displayOrigin => ServerRoutes.hostLabelOf(origin);

  _AccountOption copyWith({
    String? nickname,
    String? role,
    String? avatarUrl,
    bool? expired,
  }) =>
      _AccountOption(
        origin: origin,
        username: username,
        nickname: nickname ?? this.nickname,
        role: role ?? this.role,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        expired: expired ?? this.expired,
      );
}

/// 账号切换底部液态毛玻璃弹层（1:1 对齐 iOS `AccountSwitcherSheet.swift`）。
Future<void> showAccountSwitcherSheet(BuildContext context) {
  return showMcSheet<void>(
    context: context,
    builder: (_) => const _AccountSwitcherSheet(),
  );
}

/// 退出前询问是否同时删除本机离线下载（仅本机存在离线任务时弹出）。
Future<bool> askClearOfflineDownloadsOnLogout(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_offlineTasksPrefsKey);
    if (raw == null || raw.isEmpty) return false;
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.isEmpty) return false;

    if (!context.mounted) return false;
    final clear = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('同时删除本机离线下载？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              '检测到本机保存了 ${decoded.length} 项离线缓存。只删除本机副本，服务端观看进度不会受影响。',
              style: McText.caption.muted,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '保留下载',
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '一起删除',
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
    if (clear == true) {
      for (final item in decoded.whereType<Map>()) {
        final savePath = item['savePath']?.toString();
        if (savePath != null && savePath.isNotEmpty) {
          try {
            await McDownloadChannel.delete(savePath);
          } catch (_) {}
        }
      }
      await prefs.remove(_offlineTasksPrefsKey);
      return true;
    }
  } catch (_) {}
  return false;
}

class _AccountSwitcherSheet extends ConsumerStatefulWidget {
  const _AccountSwitcherSheet();

  @override
  ConsumerState<_AccountSwitcherSheet> createState() =>
      _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends ConsumerState<_AccountSwitcherSheet> {
  List<_AccountOption> _options = const [];
  final Map<String, _AccountFreshness> _freshness = {};
  final Map<String, bool> _serverUnreachable = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  bool _isCurrent(_AccountOption option) {
    final curOrigin = SessionStore.normalizeOrigin(appSession.baseUrl ?? '');
    final curUser = SessionStore.normalizeUsername(appSession.accountUsername);
    return curOrigin.isNotEmpty &&
        curUser.isNotEmpty &&
        SessionStore.normalizeOrigin(option.origin) == curOrigin &&
        SessionStore.normalizeUsername(option.username) == curUser;
  }

  Future<void> _loadOptions() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
    final raw = await storage.read(key: 'mc_servers');
    final options = <_AccountOption>[];
    final seen = <String>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        for (final server in (jsonDecode(raw) as List<dynamic>)
            .whereType<Map<dynamic, dynamic>>()) {
          final origin =
              SessionStore.normalizeOrigin((server['origin'] ?? '').toString());
          for (final account
              in ((server['accounts'] ?? const []) as List<dynamic>)
                  .whereType<Map<dynamic, dynamic>>()) {
            final username = (account['username'] ?? '').toString().trim();
            if (origin.isEmpty || username.isEmpty) continue;
            final hasToken =
                appSession.hasTokenFor(origin: origin, username: username);
            final opt = _AccountOption(
              origin: origin,
              username: username,
              nickname: account['nickname']?.toString(),
              role: (account['role'] ?? 'member').toString(),
              avatarUrl: account['avatar_url']?.toString(),
              expired: account['expired'] == true || !hasToken,
            );
            if (seen.add(opt.key)) {
              options.add(opt);
            }
          }
        }
      } catch (_) {}
    }

    // 确保当前活跃账号始终出现在列表中（即使 mc_servers 尚未刷新）。
    final activeOrigin = SessionStore.normalizeOrigin(appSession.baseUrl ?? '');
    final activeUser = appSession.accountUsername;
    if (appSession.isReady &&
        activeOrigin.isNotEmpty &&
        activeUser.isNotEmpty) {
      final activeOpt = _AccountOption(
        origin: activeOrigin,
        username: activeUser,
        nickname: appSession.username,
        role: appSession.permissions.role,
        avatarUrl: appSession.avatarUrl,
      );
      if (seen.add(activeOpt.key)) {
        options.insert(0, activeOpt);
      }
    }

    if (!mounted) return;
    setState(() {
      _options = options;
      for (final opt in options) {
        _freshness[opt.key] =
            opt.expired ? _AccountFreshness.expired : _AccountFreshness.loading;
      }
    });
    unawaited(_refreshAllAccounts(options));
  }

  /// 并行向各已保存账号请求 `/api/v1/auth/me`：区分在线有效 / 401 已过期 / 网络不可达。
  Future<void> _refreshAllAccounts(List<_AccountOption> options) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 6),
        headers: <String, String>{
          'User-Agent': McClient.defaultUserAgent,
          'Accept': 'application/json',
        },
        validateStatus: (_) => true,
      ),
    );

    await Future.wait(
      options.map((opt) async {
        final token = appSession.tokenFor(
          origin: opt.origin,
          username: opt.username,
        );
        if (token == null || token.isEmpty) {
          if (mounted) {
            setState(() {
              _freshness[opt.key] = _AccountFreshness.expired;
              _updateOption(opt.key, (o) => o.copyWith(expired: true));
            });
          }
          return;
        }
        final targetBase = ServerRoutes.instance.originFor(opt.origin);
        try {
          final res = await dio.get<dynamic>(
            '$targetBase/api/v1/auth/me',
            options: Options(
              headers: <String, String>{'Authorization': 'Bearer $token'},
            ),
          );
          if (!mounted) return;
          final status = res.statusCode ?? 0;
          if (status == 200 && res.data is Map) {
            final root = (res.data as Map).cast<String, dynamic>();
            final data = root['data'] is Map
                ? (root['data'] as Map).cast<String, dynamic>()
                : root;
            final nick = (data['nickname'] ?? '').toString().trim();
            final role = (data['role'] ?? opt.role).toString();
            final avatar =
                (data['avatar_url'] ?? data['avatarUrl'] ?? '').toString();
            setState(() {
              _freshness[opt.key] = _AccountFreshness.fresh;
              _serverUnreachable[opt.origin] = false;
              _updateOption(
                opt.key,
                (o) => o.copyWith(
                  nickname: nick.isNotEmpty ? nick : o.nickname,
                  role: role.isNotEmpty ? role : o.role,
                  avatarUrl: avatar.isNotEmpty ? avatar : o.avatarUrl,
                  expired: false,
                ),
              );
            });
          } else if (status == 401) {
            await appSession.deleteAccountToken(
              origin: opt.origin,
              username: opt.username,
            );
            if (!mounted) return;
            setState(() {
              _freshness[opt.key] = _AccountFreshness.expired;
              _serverUnreachable[opt.origin] = false;
              _updateOption(opt.key, (o) => o.copyWith(expired: true));
            });
          } else {
            setState(() {
              _freshness[opt.key] = _AccountFreshness.unreachable;
              _serverUnreachable[opt.origin] = true;
            });
          }
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _freshness[opt.key] = _AccountFreshness.unreachable;
            _serverUnreachable[opt.origin] = true;
          });
        }
      }),
    );
  }

  void _updateOption(
    String key,
    _AccountOption Function(_AccountOption) transform,
  ) {
    _options = [
      for (final o in _options) o.key == key ? transform(o) : o,
    ];
  }

  Future<void> _onTapOption(_AccountOption option) async {
    if (_busy || _isCurrent(option)) return;

    final expired = option.expired ||
        _freshness[option.key] == _AccountFreshness.expired ||
        !appSession.hasTokenFor(
          origin: option.origin,
          username: option.username,
        );
    if (expired) {
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      final query = Uri(
        path: '/onboarding',
        queryParameters: {
          'mode': 'relogin',
          'server': option.origin,
          'username': option.username,
        },
      ).toString();
      router.push(query);
      return;
    }

    setState(() => _busy = true);
    final store = ref.read(sessionStoreProvider);
    final curOrigin = store.baseUrl;
    final curUser = store.accountUsername;
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
        '${McStrings.accountSwitchedToastPrefix}${option.displayName}',
      );
      return;
    }
    setState(() => _busy = false);
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(
      Uri(
        path: '/onboarding',
        queryParameters: {
          'mode': 'relogin',
          'server': option.origin,
          'username': option.username,
        },
      ).toString(),
    );
  }

  Future<void> _remove(_AccountOption option) async {
    final isCurrent = _isCurrent(option);
    final confirmed = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isCurrent ? '退出当前账号' : '移除本机账号',
              style: McText.titleSm,
            ),
            const SizedBox(height: 8),
            Text(
              isCurrent
                  ? '退出「${option.displayName}」并注销本机设备令牌？若同服务器还有其他账号将自动切换。'
                  : '从本机移除「${option.displayName}」并注销其设备令牌？再次登录需重新输入密码。',
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
                    label: isCurrent ? '退出' : '移除',
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
    if (confirmed != true || !mounted) return;

    if (isCurrent) {
      await askClearOfflineDownloadsOnLogout(context);
      if (!mounted) return;
      setState(() => _busy = true);
      final switched = await appSession.logoutCurrentAccount(
        autoSwitchSibling: true,
      );
      if (!mounted) return;
      if (switched != null) {
        await ref.read(moreProvider.notifier).load();
        if (!mounted) return;
        Navigator.of(context).pop();
        McToast.success(
          '${McStrings.accountSwitchedToastPrefix}${appSession.username.isNotEmpty ? appSession.username : switched.username}',
        );
      } else {
        Navigator.of(context).pop();
        context.go('/onboarding');
      }
      return;
    }

    await appSession.removeAccount(
      origin: option.origin,
      username: option.username,
    );
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
              '本机所有服务器上的登录状态都会被清除并注销设备令牌，重新进入需再次连接服务器。',
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
    if (confirmed != true || !mounted) return;
    await askClearOfflineDownloadsOnLogout(context);
    if (!mounted) return;
    await appSession.logoutAll();
    if (!mounted) return;
    Navigator.of(context).pop();
    context.go('/onboarding');
  }

  Map<String, List<_AccountOption>> _groupedByServer() {
    final activeOrigin = SessionStore.normalizeOrigin(appSession.baseUrl ?? '');
    final grouped = <String, List<_AccountOption>>{};
    for (final opt in _options) {
      grouped.putIfAbsent(opt.origin, () => []).add(opt);
    }
    final orderedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == activeOrigin) return -1;
        if (b == activeOrigin) return 1;
        return a.compareTo(b);
      });
    return {for (final k in orderedKeys) k: grouped[k]!};
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedByServer();
    final multiServer = grouped.length > 1;
    final activeOrigin = SessionStore.normalizeOrigin(appSession.baseUrl ?? '');

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
                icon: McIcons.close,
                size: 32,
                iconSize: 16,
                tooltip: McL10n.of(context).close,
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
                  for (final entry in grouped.entries) ...[
                    if (multiServer || _serverUnreachable[entry.key] == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                        child: Row(
                          children: [
                            const Icon(
                              McIcons.server,
                              size: 13,
                              color: McTokens.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                ServerRoutes.hostLabelOf(entry.key),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: McText.caption.copyWith(
                                  color: McTokens.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_serverUnreachable[entry.key] == true) ...[
                              const SizedBox(width: 6),
                              Text(
                                '· 连不上',
                                style: McText.caption.copyWith(
                                  color: McTokens.warning,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    for (final option in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AccountCard(
                          option: option,
                          isCurrent: _isCurrent(option),
                          freshness: _freshness[option.key] ??
                              _AccountFreshness.fresh,
                          onTap: () => _onTapOption(option),
                          onRemove: () => _remove(option),
                        ),
                      ),
                  ],
                  const SizedBox(height: 4),
                  McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      McInsetRow(
                        icon: McIcons.addCircle,
                        title: '添加账号',
                        subtitle: '登录当前服务器的其他账号或新服务器',
                        showChevron: true,
                        onTap: () {
                          final router = GoRouter.of(context);
                          Navigator.of(context).pop();
                          final target = Uri(
                            path: '/onboarding',
                            queryParameters: {
                              'mode': 'add',
                              if (activeOrigin.isNotEmpty)
                                'server': activeOrigin,
                            },
                          ).toString();
                          router.push(target);
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
    required this.freshness,
    required this.onTap,
    required this.onRemove,
  });

  final _AccountOption option;
  final bool isCurrent;
  final _AccountFreshness freshness;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final name = option.displayName;
    final initials = McPermissions.avatarInitials(name);
    final roleText = option.role == 'admin' ? '超级管理员' : '成员';
    final isExpired =
        option.expired || freshness == _AccountFreshness.expired;
    final isUnreachable = freshness == _AccountFreshness.unreachable;
    final avatarUrl =
        option.avatarUrl != null && option.avatarUrl!.isNotEmpty
            ? McImageUrls.resolve(
                McImageUrls.tagAccount(option.avatarUrl, option.username),
                widthPx: 96,
                baseUrl: option.origin,
              )
            : '';

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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    initials,
                    style: McText.sub.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (avatarUrl.isNotEmpty)
                    Positioned.fill(
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatarUrl,
                          httpHeaders: mcImageHeadersFor(
                            origin: option.origin,
                            username: option.username,
                          ),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                ],
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
                    '@${option.username} · $roleText · ${option.displayOrigin}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.caption.muted,
                  ),
                  if (!isCurrent && isExpired) ...[
                    const SizedBox(height: 2),
                    Text(
                      '需要重新登录',
                      style: McText.caption.copyWith(color: McTokens.warning),
                    ),
                  ] else if (!isCurrent && isUnreachable) ...[
                    const SizedBox(height: 2),
                    Text(
                      '服务器暂时不可达',
                      style: McText.caption.copyWith(color: McTokens.textFaint),
                    ),
                  ],
                ],
              ),
            ),
            if (isCurrent) ...[
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
              ),
              const SizedBox(width: 6),
            ],
            McGlassIconButton(
              icon: McIcons.close,
              size: 30,
              iconSize: 15,
              tooltip: isCurrent ? '退出账号' : '移除账号',
              onTap: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
