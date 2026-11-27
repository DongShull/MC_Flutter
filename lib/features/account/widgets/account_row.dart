import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/l10n/mc_l10n.dart';
import '../../../core/session/permissions.dart';
import '../state/account_state.dart';

/// 账号行（对齐 Kotlin AccountRow）：银玻璃圆头像 + 昵称 + @username · 角色 + 当前标记；
/// 过期提示「点一下重新输入密码」；非当前账号给移除按钮（带二次确认、异常捕获与防重复点击）。
class AccountRow extends StatefulWidget {
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
  final FutureOr<void> Function() onRemove;

  @override
  State<AccountRow> createState() => _AccountRowState();
}

class _AccountRowState extends State<AccountRow> {
  bool _removing = false;

  Future<void> _confirmAndRemove() async {
    if (_removing || widget.busy) return;
    final displayName = widget.account.nickname ?? widget.account.username;
    final l10n = McL10n.of(context);
    final confirmed = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('移除本机账号「$displayName」？', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              '将清除本机保存的登录凭证并注销该设备的登录令牌，下次切换需要重新输入密码。',
              style: McText.sub.muted,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: l10n.cancel,
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
    if (confirmed != true || !mounted) return;
    setState(() => _removing = true);
    try {
      await widget.onRemove();
      if (mounted) McToast.success('已从本机移除 $displayName');
    } catch (e) {
      if (mounted) McToast.error('移除账号失败：$e');
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.account.nickname ?? widget.account.username;
    final disabled = widget.busy || _removing;
    return McPressable(
      onTap: (!widget.isCurrent && !disabled) ? widget.onSwitch : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.isCurrent ? McTokens.accentSoft : McTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(McTokens.cardRadius),
          border: Border.all(
            color: widget.isCurrent ? McTokens.lineStrong : McTokens.line,
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
                  color: widget.isCurrent
                      ? McTokens.accentStrong
                      : McTokens.line,
                  width: 1,
                ),
              ),
              child: Text(
                McPermissions.avatarInitials(displayName),
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
                      if (widget.isCurrent) ...[
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
                    "@${widget.account.username} · ${widget.account.role == 'admin' ? '超级管理员' : '成员'}",
                    style: McText.caption.muted,
                  ),
                  if (widget.account.expired) ...[
                    const SizedBox(height: 2),
                    Text(
                      '登录已失效，点一下重新输入密码',
                      style: McText.caption.copyWith(color: McTokens.warning),
                    ),
                  ],
                ],
              ),
            ),
            if (!widget.isCurrent)
              McGlassIconButton(
                icon: McIcons.close,
                size: 32,
                iconSize: 15,
                tooltip: '从本机移除',
                onTap: disabled ? null : _confirmAndRemove,
              ),
          ],
        ),
      ),
    );
  }
}
