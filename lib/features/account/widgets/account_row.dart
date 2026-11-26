import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../state/account_state.dart';

/// 账号行（对齐 Kotlin AccountRow）：银玻璃圆头像 + 昵称 + @username · 角色 + 当前标记；
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
    final displayName = account.nickname ?? account.username;
    return McPressable(
      onTap: (!isCurrent && !busy) ? onSwitch : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCurrent ? McTokens.accentSoft : McTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(McTokens.cardRadius),
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
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2B3140), Color(0xFF171A24)],
                ),
                border: Border.all(
                  color: isCurrent ? McTokens.accentStrong : McTokens.line,
                  width: 1,
                ),
              ),
              child: Text(
                displayName.isEmpty
                    ? '?'
                    : displayName.characters.first.toUpperCase(),
                style: McText.ui.copyWith(
                  color: McTokens.accentStrong,
                  fontWeight: FontWeight.w600,
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
                          style: McText.ui.semibold,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: McTokens.ok.withValues(alpha: 0.14),
                            borderRadius:
                                BorderRadius.circular(McTokens.pillRadius),
                            border: Border.all(
                              color: McTokens.ok.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                McIcons.check,
                                size: 11,
                                color: McTokens.ok,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '当前',
                                style: McText.micro.copyWith(
                                  color: McTokens.ok,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "@${account.username} · ${account.role == 'admin' ? '超级管理员' : '成员'}",
                    style: McText.caption.muted,
                  ),
                  if (account.expired) ...[
                    const SizedBox(height: 2),
                    Text(
                      '登录已失效，点一下重新输入密码',
                      style: McText.caption.copyWith(color: McTokens.warning),
                    ),
                  ],
                ],
              ),
            ),
            if (!isCurrent)
              McGlassIconButton(
                icon: McIcons.close2,
                size: 32,
                iconSize: 15,
                tooltip: '从本机移除',
                onTap: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
