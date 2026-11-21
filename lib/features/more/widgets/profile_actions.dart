import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/device_requests_api.dart';
import '../../../core/api/session_providers.dart';
import 'account_switcher_sheet.dart';

/// 个人卡内动作（对齐鸿蒙 ProfilePage 底部操作）：
/// 批准登录（配对码审批）/ 切换账号（弹层）/ 退出登录（确认后清本机账号）。
class ProfileActions {
  ProfileActions._();

  static void approveLogin(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final api = ref.read(deviceRequestsApiProvider);
    DeviceRequestView? request;
    String? error;
    var busy = false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final theme = Theme.of(dialogContext);

          Future<void> load() async {
            setState(() {
              busy = true;
              error = null;
            });
            try {
              final r = await api.request(controller.text.trim());
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

          return AlertDialog(
            title: const Text('批准设备登录'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('输入设备上显示的配对码，核对信息后批准或拒绝。',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: '配对码',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => load(),
                  ),
                  const SizedBox(height: 12),
                  if (busy) const Center(child: CircularProgressIndicator()),
                  if (error != null)
                    Text(error!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: const Color(0xFFE5615B))),
                  if (request != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '设备：${request!.clientName ?? '未知'}\n'
                      '类型：${request!.clientType ?? '-'}${request!.requiresAdmin ? '（需管理员）' : ''}\n'
                      'IP：${request!.sourceIp ?? '-'}\n'
                      '剩余：${request!.expiresIn}s',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    busy ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              if (request == null)
                FilledButton(
                  onPressed:
                      busy || controller.text.trim().isEmpty ? null : load,
                  child: const Text('查询'),
                )
              else ...[
                OutlinedButton(
                  onPressed: busy ? null : () => act(false),
                  child: const Text('拒绝'),
                ),
                FilledButton(
                  onPressed: busy ? null : () => act(true),
                  child: const Text('批准'),
                ),
              ],
            ],
          );
        },
      ),
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
