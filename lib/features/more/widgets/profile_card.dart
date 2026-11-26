import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';

/// 个人中心顶卡（对齐 iOS `ProfileHeaderCard`）：
/// 居中 `80dp` 圆形大头像（右下嵌 `28dp` 银玻璃编辑圆标）+ 居中昵称与身份摘要 +
/// 下方三颗等宽液态玻璃胶囊操作键（批准登录 / 切换账号 / 退出登录）。
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.nickname,
    required this.username,
    required this.roleLabel,
    this.avatarUrl,
    required this.onSwitchAccount,
    required this.onApproveLogin,
    required this.onLogout,
  });

  final String nickname;
  final String username;
  final String roleLabel;
  final String? avatarUrl;
  final VoidCallback onSwitchAccount;
  final VoidCallback onApproveLogin;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final identity = username.isNotEmpty && username != nickname
        ? '@$username${roleLabel.isNotEmpty ? ' · $roleLabel' : ''}'
        : roleLabel;
    final avatarChar = nickname.isEmpty
        ? 'M'
        : String.fromCharCode(nickname.runes.first).toUpperCase();
    final resolvedAvatar = McImageUrls.resolve(avatarUrl, widthPx: 200);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        8,
        McTokens.pagePadding,
        0,
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      child: Column(
        children: [
          McPressable(
            onTap: () => context.push('/settings/profile'),
            child: Column(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                            colors: [Color(0xFF3E6DA8), Color(0xFF6B53A8)],
                          ),
                          border: Border.all(
                            color: McTokens.lineStrong,
                            width: 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          avatarChar,
                          style: McText.display.copyWith(color: Colors.white),
                        ),
                      ),
                      if (resolvedAvatar.isNotEmpty)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: resolvedAvatar,
                                httpHeaders: mcImageHeaders(),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: McTokens.surfaceSolid,
                            border: Border.all(
                              color: McTokens.lineStrong,
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            McIcons.edit2,
                            size: 13,
                            color: McTokens.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: McText.titleLg,
                ),
                if (identity.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    identity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: McText.caption.muted,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  icon: McIcons.scan,
                  label: McStrings.approveLogin,
                  onTap: onApproveLogin,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardAction(
                  icon: McIcons.userSwitch,
                  label: McStrings.switchAccount,
                  onTap: onSwitchAccount,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardAction(
                  icon: McIcons.logout,
                  label: McStrings.logout,
                  danger: true,
                  onTap: onLogout,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? McTokens.danger : McTokens.text;
    return McPressable(
      onTap: onTap,
      haptic: true,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: danger ? const Color(0x14FF6B6B) : McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(McTokens.pillRadius),
          border: Border.all(
            color: danger ? const Color(0x38FF6B6B) : McTokens.line,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
