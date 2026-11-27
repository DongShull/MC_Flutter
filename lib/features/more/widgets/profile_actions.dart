import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/device_requests_api.dart';
import '../../../core/auth/pairing_qr_parser.dart';
import '../../../core/auth/session_watch.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/session/session_store.dart';
import '../state/controllers.dart';
import 'account_switcher_sheet.dart';

/// 设备接入授权文案口径（1:1 对齐 iOS `DeviceText.grant` 与 Web `devices-display.ts`）。
class _DeviceGrantCopy {
  const _DeviceGrantCopy({required this.title, required this.body});

  final String title;
  final String body;

  static String clientTypeLabel(String? type) => switch (type) {
        'worker' => '远程转码器',
        'cli' => '命令行工具',
        'tvos' => 'Apple TV',
        'macos' => 'Mac',
        'androidtv' => 'Android TV',
        'manual' => '手动令牌',
        _ => type == null || type.isEmpty ? '未知终端' : type,
      };

  static _DeviceGrantCopy grant(String? type, {required bool isAdmin}) {
    if (type == 'worker') {
      return const _DeviceGrantCopy(
        title: '将获得：远程转码节点权限',
        body: '该转码器可拉取待转码片源并回传媒体流，仅限服务器管理员批准。',
      );
    }
    if (type == 'androidtv') {
      return _DeviceGrantCopy(
        title: isAdmin ? '将获得：Android TV 管理员登录权限' : '将获得：Android TV 成员登录权限',
        body: '批准后这台电视将登录为你的账号，可浏览片库并同步观看进度，随时可在「设备」中撤销。',
      );
    }
    if (type == 'tvos') {
      return _DeviceGrantCopy(
        title: isAdmin ? '将获得：Apple TV 管理员登录权限' : '将获得：Apple TV 成员登录权限',
        body: '批准后这台电视将登录为你的账号，可浏览片库并同步观看进度，随时可在「设备」中撤销。',
      );
    }
    if (type == 'macos') {
      return _DeviceGrantCopy(
        title: isAdmin ? '将获得：Mac 客户端管理员权限' : '将获得：Mac 客户端成员权限',
        body: '批准后这台 Mac 将登录为你的账号并共享片库与设置权限，随时可在「设备」中撤销。',
      );
    }
    if (isAdmin) {
      return const _DeviceGrantCopy(
        title: '将获得：你的超级管理员完全权限',
        body: '批准后该设备将以你的管理员身份访问全部片库与服务器管理接口，请确认配对码无误。',
      );
    }
    return const _DeviceGrantCopy(
      title: '将获得：你的当前账号权限',
      body: '批准后该设备将登录为你的账号并同步观看记录，随时可在「设备」中撤销。',
    );
  }
}

/// 个人卡内动作：批准设备登录 / 切换账号 / 退出登录（全银玻璃交互弹层）。
class ProfileActions {
  ProfileActions._();

  static Future<void> approveLogin(
    BuildContext context,
    WidgetRef ref, {
    bool scanFirst = false,
  }) async {
    final api = ref.read(deviceRequestsApiProvider);
    final perms = ref.read(mcPermissionsProvider);
    final username = perms.displayName.isNotEmpty
        ? perms.displayName
        : appSession.username;

    String? initialCode;
    String? initialHost;

    if (scanFirst) {
      final raw = await GoRouter.of(context).push<String>(
        '/onboarding/qr-scan/raw',
      );
      if (raw == null || raw.isEmpty || !context.mounted) return;
      final parsed = PairingQrParser.parse(raw);
      initialCode = parsed?.code ?? PairingQrParser.normalize(raw) ?? raw;
      initialHost = parsed?.host;
    }

    if (!context.mounted) return;
    await showMcSheet<void>(
      context: context,
      builder: (sheetCtx) => _DeviceApprovalSheet(
        api: api,
        username: username,
        isAdmin: perms.isAdmin,
        initialCode: initialCode,
        initialHost: initialHost,
      ),
    );
  }

  /// 兼容外部直接构建批准弹窗体（默认非管理员需显式传入权限）。
  static Widget showDialogBody(
    BuildContext dialogContext,
    DeviceRequestsApi api,
    String username, {
    bool? isAdmin,
    String? initialCode,
    String? initialHost,
  }) {
    return _DeviceApprovalSheet(
      api: api,
      username: username,
      isAdmin: isAdmin ?? appSession.permissions.isAdmin,
      initialCode: initialCode,
      initialHost: initialHost,
    );
  }

  static Future<void> logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('退出当前账号', style: McText.title),
            const SizedBox(height: 8),
            Text(
              '退出后本机不再保留该账号的登录状态并注销设备令牌，若同服务器还有其他账号将自动切换。',
              style: McText.caption.muted,
            ),
            const SizedBox(height: 20),
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
                    label: '退出登录',
                    icon: McIcons.logout,
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
    if (confirmed != true || !context.mounted) return;

    await askClearOfflineDownloadsOnLogout(context);
    if (!context.mounted) return;

    final switched = await appSession.logoutCurrentAccount(
      autoSwitchSibling: true,
    );
    if (!context.mounted) return;
    if (switched != null) {
      await ref.read(moreProvider.notifier).load();
      McToast.success(
        '${McStrings.accountSwitchedToastPrefix}${appSession.username.isNotEmpty ? appSession.username : switched.username}',
      );
    } else {
      context.go('/onboarding');
    }
  }

  static void switchAccount(BuildContext context) =>
      showAccountSwitcherSheet(context);
}

class _DeviceApprovalSheet extends StatefulWidget {
  const _DeviceApprovalSheet({
    required this.api,
    required this.username,
    required this.isAdmin,
    this.initialCode,
    this.initialHost,
  });

  final DeviceRequestsApi api;
  final String username;
  final bool isAdmin;
  final String? initialCode;
  final String? initialHost;

  @override
  State<_DeviceApprovalSheet> createState() => _DeviceApprovalSheetState();
}

class _DeviceApprovalSheetState extends State<_DeviceApprovalSheet> {
  late final TextEditingController _controller;
  DeviceRequestView? _request;
  String? _scannedHost;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode ?? '');
    _scannedHost = widget.initialHost;
    if (widget.initialCode != null && widget.initialCode!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _serverMismatchHint() {
    final scanned = _scannedHost;
    final currentOrigin = appSession.baseUrl ?? '';
    if (scanned == null || scanned.isEmpty || currentOrigin.isEmpty) {
      return '';
    }
    final knownHosts = ServerRoutes.instance.hostLabels(currentOrigin);
    final matched = knownHosts.any(
      (h) => h.toLowerCase() == scanned.toLowerCase(),
    );
    if (matched) return '';
    final mine = ServerRoutes.hostLabelOf(currentOrigin);
    return '\n（二维码来自 $scanned，但当前连接的是 $mine，请先切换到对应服务器的账号）';
  }

  Future<void> _lookup() async {
    final normalized = PairingQrParser.normalize(_controller.text);
    if (normalized == null) {
      setState(() {
        _error = '请输入有效的配对码（如 MCLW-7F3K 或后 4 位 7F3K）';
      });
      return;
    }
    if (_busy) return;
    _controller.text = normalized;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final req = await widget.api.request(normalized);
      if (!mounted) return;
      setState(() {
        _request = req;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.httpStatus == 404
          ? '未找到配对请求 $normalized（可能已过期或已被处理）${_serverMismatchHint()}'
          : e.friendlyMessage;
      setState(() {
        _error = msg;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '查询配对请求失败：$e';
        _busy = false;
      });
    }
  }

  Future<void> _decide(bool approve) async {
    final req = _request;
    if (req == null || _busy) return;
    if (approve && req.requiresAdmin && !widget.isAdmin) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (approve) {
        await widget.api.approve(req.userCode);
      } else {
        await widget.api.deny(req.userCode);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      McToast.success(approve ? '已批准「${req.clientName ?? '该设备'}」登录' : '已拒绝登录请求');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.friendlyMessage;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  Future<void> _scan() async {
    final raw = await GoRouter.of(context).push<String>(
      '/onboarding/qr-scan/raw',
    );
    if (raw == null || raw.isEmpty || !mounted) return;
    final parsed = PairingQrParser.parse(raw);
    _scannedHost = parsed?.host;
    _controller.text = parsed?.code ?? PairingQrParser.normalize(raw) ?? raw;
    await _lookup();
  }

  @override
  Widget build(BuildContext context) {
    final req = _request;
    final normalizedPreview = PairingQrParser.normalize(_controller.text);
    final blockedByAdmin = req != null && req.requiresAdmin && !widget.isAdmin;
    final grant = req == null
        ? null
        : _DeviceGrantCopy.grant(req.clientType, isAdmin: widget.isAdmin);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('批准设备登录', style: McText.title),
                ),
                McGlassIconButton(
                  icon: McIcons.close,
                  size: 32,
                  iconSize: 16,
                  onTap: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '输入 Apple TV、桌面端或命令行上的配对码（支持直接输后 4 位），或扫描屏幕二维码。',
              style: McText.caption.muted,
            ),
            const SizedBox(height: 18),
            if (req == null) ...[
              TextField(
                controller: _controller,
                autofocus: widget.initialCode == null,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enabled: !_busy,
                style: McText.title.tabular.copyWith(letterSpacing: 1.5),
                textInputAction: TextInputAction.go,
                onChanged: (_) => setState(() {
                  _scannedHost = null;
                  _error = null;
                }),
                onSubmitted: (_) => _lookup(),
                decoration: InputDecoration(
                  hintText: 'MCLW-XXXX 或 4 位后段',
                  prefixIcon: const Icon(McIcons.device, size: 18),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(McIcons.close, size: 16),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _scannedHost = null;
                              _error = null;
                            });
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: McText.caption.copyWith(color: McTokens.danger),
                ),
                const SizedBox(height: 12),
              ],
              McActionPill(
                label: '继续',
                primary: true,
                expanded: true,
                height: 44,
                busy: _busy,
                onTap: _busy || normalizedPreview == null ? null : _lookup,
              ),
              const SizedBox(height: 10),
              McActionPill(
                label: '扫描二维码',
                icon: McIcons.scan,
                primary: false,
                expanded: true,
                height: 42,
                onTap: _busy ? null : _scan,
              ),
              const SizedBox(height: 14),
              Text(
                widget.username.isEmpty
                    ? '将以当前登录账号身份授权'
                    : '将以「${widget.username}」的身份授权登录',
                textAlign: TextAlign.center,
                style: McText.micro.copyWith(
                  fontWeight: FontWeight.w400,
                  color: McTokens.textFaint,
                ),
              ),
            ] else ...[
              Center(
                child: Column(
                  children: [
                    Text(
                      req.userCode,
                      style: McText.display.tabular.copyWith(
                        color: McTokens.accentStrong,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '请与设备屏幕上的配对码逐字核对',
                      style: McText.caption.muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              McInsetGroup(
                margin: EdgeInsets.zero,
                children: [
                  McInsetRow(
                    icon: McIcons.device,
                    title: req.clientName ?? '未知设备',
                    subtitle: req.platform?.isNotEmpty == true
                        ? req.platform!
                        : _DeviceGrantCopy.clientTypeLabel(req.clientType),
                  ),
                  if (req.sourceIp != null && req.sourceIp!.isNotEmpty)
                    McInsetRow(
                      icon: McIcons.globe,
                      title: '来源 IP：${req.sourceIp}',
                      valueText:
                          req.expiresIn > 0 ? '剩余 ${req.expiresIn}s' : null,
                    ),
                ],
              ),
              if (grant != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: McTokens.surfaceInset,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: McTokens.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(grant.title, style: McText.sub.semibold),
                      const SizedBox(height: 4),
                      Text(grant.body, style: McText.caption.muted),
                    ],
                  ),
                ),
              ],
              if (blockedByAdmin) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x1FF5C451),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x4DF5C451)),
                  ),
                  child: Text(
                    '此设备请求需要超级管理员权限才能批准，普通成员无法授权转码器或高权限终端。',
                    style: McText.caption.copyWith(color: McTokens.warning),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: McText.caption.copyWith(color: McTokens.danger),
                ),
              ],
              const SizedBox(height: 16),
              McActionPill(
                label: blockedByAdmin ? '仅超级管理员可批准' : '批准登录',
                icon: McIcons.check,
                primary: !blockedByAdmin,
                expanded: true,
                height: 44,
                busy: _busy,
                onTap: _busy || blockedByAdmin ? null : () => _decide(true),
              ),
              const SizedBox(height: 10),
              McActionPill(
                label: '拒绝请求',
                primary: false,
                tone: McGlassTone.danger,
                expanded: true,
                height: 42,
                onTap: _busy ? null : () => _decide(false),
              ),
              const SizedBox(height: 12),
              Text(
                widget.username.isEmpty
                    ? '将以当前登录账号身份授权'
                    : '将以「${widget.username}」的身份授权登录',
                textAlign: TextAlign.center,
                style: McText.micro.copyWith(
                  fontWeight: FontWeight.w400,
                  color: McTokens.textFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
