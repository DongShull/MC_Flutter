import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/device_requests_api.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/controllers.dart';
import 'account_switcher_sheet.dart';

/// 个人卡内动作：批准设备登录 / 切换账号 / 退出登录（全银玻璃交互弹层）。
class ProfileActions {
  ProfileActions._();

  static String _normalizeCode(String raw) {
    var s = raw.trim();
    final key = RegExp(r'code=([A-Za-z0-9-]+)');
    final m = key.firstMatch(s);
    if (m != null) s = m.group(1)!;
    s = s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    return s.length > 8 ? s.substring(0, 8) : s;
  }

  static void approveLogin(BuildContext context, WidgetRef ref) {
    final api = ref.read(deviceRequestsApiProvider);
    final username =
        (ref.read(moreProvider).valueOrNull?.session?['username'] ?? '')
            .toString();
    showMcSheet<void>(
      context: context,
      builder: (sheetCtx) => showDialogBody(sheetCtx, api, username),
    );
  }

  static Widget showDialogBody(
    BuildContext dialogContext,
    DeviceRequestsApi api,
    String username,
  ) {
    final controller = TextEditingController();
    DeviceRequestView? request;
    String? error;
    var busy = false;
    return StatefulBuilder(
      builder: (dialogContext, setState) {
        final code = _normalizeCode(controller.text);

        Future<void> load() async {
          setState(() {
            busy = true;
            error = null;
          });
          try {
            final r = await api.request(code);
            setState(() {
              request = r;
              busy = false;
            });
          } catch (e) {
            setState(() {
              error = e.toString();
              busy = false;
            });
          }
        }

        Future<void> act(bool approve) async {
          setState(() => busy = true);
          try {
            if (approve) {
              await api.approve(request!.userCode);
            } else {
              await api.deny(request!.userCode);
            }
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
              McToast.success(approve ? '已批准该设备登录' : '已拒绝登录请求');
            }
          } catch (e) {
            setState(() {
              error = e.toString();
              busy = false;
            });
          }
        }

        Future<void> scan() async {
          final raw = await GoRouter.of(
            dialogContext,
          ).push<String>('/onboarding/qr-scan/raw');
          if (raw == null || raw.isEmpty) return;
          controller.text = _normalizeCode(raw);
          if (dialogContext.mounted) load();
        }

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
                      icon: McIcons.close2,
                      size: 32,
                      iconSize: 16,
                      onTap: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '输入 Apple TV、桌面端或命令行上显示的 8 位配对码，或直接扫描屏幕二维码。',
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 18),
                if (request == null) ...[
                  _PairingCodeField(
                    controller: controller,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  if (error != null) ...[
                    Text(
                      error!,
                      style: McText.caption.copyWith(color: McTokens.danger),
                    ),
                    const SizedBox(height: 10),
                  ],
                  McActionPill(
                    label: '继续',
                    primary: true,
                    expanded: true,
                    height: 44,
                    busy: busy,
                    onTap: busy || code.length != 8 ? null : load,
                  ),
                  const SizedBox(height: 10),
                  McActionPill(
                    label: '扫描二维码',
                    icon: McIcons.scan,
                    primary: false,
                    expanded: true,
                    height: 42,
                    onTap: busy ? null : scan,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    username.isEmpty
                        ? '将以当前登录账号身份授权'
                        : '将以「$username」的身份授权登录',
                    textAlign: TextAlign.center,
                    style: McText.micro.copyWith(
                      fontWeight: FontWeight.w400,
                      color: McTokens.textFaint,
                    ),
                  ),
                ] else ...[
                  McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      McInsetRow(
                        icon: McIcons.device,
                        title: request!.clientName ?? '未知设备',
                        subtitle:
                            '类型：${request!.clientType ?? '-'}${request!.requiresAdmin ? ' · 需管理员权限' : ''}',
                      ),
                      McInsetRow(
                        icon: McIcons.globe,
                        title: '来源 IP：${request!.sourceIp ?? '-'}',
                        valueText: '剩余 ${request!.expiresIn}s',
                      ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: McText.caption.copyWith(color: McTokens.danger),
                    ),
                  ],
                  const SizedBox(height: 18),
                  McActionPill(
                    label: '批准登录',
                    icon: McIcons.check,
                    primary: true,
                    expanded: true,
                    height: 44,
                    busy: busy,
                    onTap: busy ? null : () => act(true),
                  ),
                  const SizedBox(height: 10),
                  McActionPill(
                    label: '拒绝请求',
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    height: 42,
                    onTap: busy ? null : () => act(false),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> logout(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionStoreProvider);
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
              '退出后本机不再保留该账号的登录状态，下次连接需重新输入密码。',
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
    if (confirmed != true) return;

    final origin = session.baseUrl;
    final username = session.username;
    if (origin != null && username.isNotEmpty) {
      await session.deleteAccountToken(origin: origin, username: username);
      await _removeAccountSnapshot(origin, username);
    }
    await session.logout();
    if (context.mounted) context.go('/onboarding');
  }

  static Future<void> _removeAccountSnapshot(
    String origin,
    String username,
  ) async {
    try {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      final raw = await storage.read(key: 'mc_servers');
      if (raw == null || raw.isNotEmpty) return;
      final servers = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((s) => Map<String, dynamic>.from(s))
          .toList();
      for (final server in servers) {
        if (server['origin']?.toString() != origin) continue;
        final accounts = ((server['accounts'] ?? const []) as List<dynamic>)
            .where((a) => a is Map && a['username']?.toString() != username)
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

  static void switchAccount(BuildContext context) =>
      showAccountSwitcherSheet(context);
}

class _PairingCodeField extends StatelessWidget {
  const _PairingCodeField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final code = controller.text
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    return Stack(
      alignment: Alignment.center,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          showCursor: false,
          maxLength: 8,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            counterText: '',
            isDense: true,
          ),
          style: const TextStyle(color: Colors.transparent),
          onChanged: (_) => onChanged(),
        ),
        IgnorePointer(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 8; i++) ...[
                  if (i == 4)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('-', style: McText.title.faint),
                    ),
                  Container(
                    width: 38,
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: McTokens.surfaceInset,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: code.length == i
                            ? McTokens.accentStrong
                            : McTokens.lineStrong,
                        width: code.length == i ? 1.8 : 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      i < code.length ? code[i] : '',
                      style: McText.title.tabular,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
