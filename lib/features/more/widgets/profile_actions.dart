import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/device_requests_api.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../state/controllers.dart';
import 'account_switcher_sheet.dart';

/// 个人卡内动作（对齐鸿蒙 ProfilePage 底部操作）：
/// 批准登录（配对码审批）/ 切换账号（弹层）/ 退出登录（确认后清本机账号）。
class ProfileActions {
  ProfileActions._();

  /// 配对码归一：从扫码结果/手输串里提出 8 位码。
  static String _normalizeCode(String raw) {
    var s = raw.trim();
    final key = RegExp(r'code=([A-Za-z0-9-]+)');
    final m = key.firstMatch(s);
    if (m != null) s = m.group(1)!;
    s = s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    return s.length > 8 ? s.substring(0, 8) : s;
  }

  /// 批准登录弹窗（1:1 对齐鸿蒙 DeviceApprovalDialog）：
  /// 标题+说明 → 8 格配对码（XXXX-XXXX）→ 继续 → 扫描二维码 → 底注身份；
  /// 查到设备后展示设备信息 + 拒绝/批准。
  static void approveLogin(BuildContext context, WidgetRef ref) {
    final api = ref.read(deviceRequestsApiProvider);
    final username =
        (ref.read(moreProvider).valueOrNull?.session?['username'] ?? '')
            .toString();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => showDialogBody(dialogContext, api, username),
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
        final theme = Theme.of(dialogContext);
        final scheme = theme.colorScheme;
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
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          } catch (e) {
            setState(() {
              error = e.toString();
              busy = false;
            });
          }
        }

        Future<void> scan() async {
          final raw = await GoRouter.of(dialogContext)
              .push<String>('/onboarding/qr-scan/raw');
          if (raw == null || raw.isEmpty) return;
          controller.text = _normalizeCode(raw);
          if (dialogContext.mounted) load();
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('批准设备登录'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '输入 Apple TV、Mac、命令行或转码器上显示的配对码，或者扫它旁边的二维码。',
                ),
                const SizedBox(height: 16),
                if (request == null) ...[
                  _PairingCodeField(
                    controller: controller,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  if (busy)
                    const Center(child: CircularProgressIndicator()),
                  if (error != null) ...[
                    Text(
                      error!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFFE5615B)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          busy || code.length != 8 ? null : load,
                      child: const Text('继续'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : scan,
                      icon: const Icon(McIcons.scan, size: 18),
                      label: const Text('扫描二维码'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    username.isEmpty
                        ? '以当前账号的身份批准 · 换账号请先在「我的」页切换'
                        : '以「$username」的身份批准 · 换账号请先在「我的」页切换',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '设备：${request!.clientName ?? '未知'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          '类型：${request!.clientType ?? '-'}${request!.requiresAdmin ? '（需管理员）' : ''}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          'IP：${request!.sourceIp ?? '-'} · 剩余 ${request!.expiresIn}s',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFFE5615B)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : () => act(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                      ),
                      child: const Text('批准'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: busy ? null : () => act(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE5615B),
                      ),
                      child: const Text('拒绝'),
                    ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后本机不再保留这个账号的登录状态，再回来需要重新输入密码。'),
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
            child: const Text('退出'),
          ),
        ],
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

  /// 本机快照移除当前账号（mc_servers 只留仍然有效的账号）。
  static Future<void> _removeAccountSnapshot(
      String origin, String username) async {
    try {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      final raw = await storage.read(key: 'mc_servers');
      if (raw == null || raw.isEmpty) return;
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
    } catch (_) {
      // 快照清理失败不阻断登出。
    }
  }

  static void switchAccount(BuildContext context) =>
      showAccountSwitcherSheet(context);
}

/// 8 格配对码输入（XXXX-XXXX，1:1 对齐鸿蒙）：隐藏 TextField 承接输入，
/// 上面画 8 个圆角格子，第 5 格前画「-」，当前光标位高亮描边。
class _PairingCodeField extends StatelessWidget {
  const _PairingCodeField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final code = controller.text
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    return Stack(
      alignment: Alignment.center,
      children: [
        // 隐形输入框（透明，铺满整行承接点击/键盘）。
        TextField(
          controller: controller,
          autofocus: true,
          showCursor: false,
          maxLength: 8,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
            isDense: true,
          ),
          style: const TextStyle(color: Colors.transparent),
          onChanged: (_) => onChanged(),
        ),
        // 8 格可视化。
        IgnorePointer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 8; i++) ...[
                if (i == 4)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('-',
                        style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ),
                Container(
                  width: 40,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: code.length == i
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: code.length == i ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    i < code.length ? code[i] : '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
