import 'package:flutter/material.dart';

import '../state/account_state.dart';

/// 账号行（对齐 Kotlin AccountRow）：渐变圆头像 + 昵称 + @username · 角色 + 当前标记；
/// 过期提示「点一下重新输入密码」；非当前账号给移除按钮。
class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
    required this.server,
    required this.account,
    required this.isCurrent,
    required this.busy,
    required this.onSwitch,
    required this.onRemove,
  });

  final SavedServer server;
  final SavedAccount account;
  final bool isCurrent;
  final bool busy;
  final VoidCallback onSwitch;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayName = account.nickname ?? account.username;
    return InkWell(
      onTap: (!isCurrent && !busy)
          ? () {
              // 过期账号走重新输密码（/onboarding 预填）；这里保持切换语义。
              onSwitch();
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCurrent
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
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
                displayName.isEmpty
                    ? '?'
                    : displayName.characters.first.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check, size: 14, color: scheme.primary),
                        Text(
                          '当前',
                          style:
                              TextStyle(fontSize: 12, color: scheme.primary),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    "@${account.username} · ${account.role == 'admin' ? '超级管理员' : '成员'}",
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  if (account.expired)
                    Text(
                      '登录已失效，点一下重新输入密码',
                      style: TextStyle(fontSize: 11, color: scheme.tertiary),
                    ),
                ],
              ),
            ),
            if (!isCurrent)
              IconButton(
                tooltip: '从本机移除',
                onPressed: onRemove,
                icon:
                    Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}
