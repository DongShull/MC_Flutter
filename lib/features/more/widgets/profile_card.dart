import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/image/image_urls.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';

/// 个人信息卡（对齐鸿蒙 ProfileCard）：
/// 80 圆形渐变头像（昵称首字 fallback）+ 右下铅笔角标、昵称居中、
/// 身份小字（@用户名 与昵称不同才重复加 + 角色）、整宽「切换账号」按钮。
/// 点头像 / 卡片进个人信息页（/settings/profile）。
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.nickname,
    required this.username,
    required this.roleLabel,
    this.avatarUrl,
    required this.onApproveLogin,
    required this.onSwitchAccount,
    required this.onLogout,
  });

  final String nickname;
  final String username;
  final String roleLabel;
  final String? avatarUrl;
  final VoidCallback onApproveLogin;
  final VoidCallback onSwitchAccount;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final identity = username.isNotEmpty && username != nickname
        ? '@$username · $roleLabel'
        : roleLabel;
    final avatarChar =
        nickname.isEmpty ? '?' : String.fromCharCode(nickname.runes.first);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/settings/profile'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [scheme.primary, scheme.tertiary],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        avatarChar,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimary.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    if ((avatarUrl ?? '').isNotEmpty)
                      Positioned.fill(
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl:
                                McImageUrls.resolve(avatarUrl, widthPx: 160),
                            httpHeaders: mcImageHeaders(),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.surfaceContainerHighest,
                          border: Border.all(color: scheme.surface, width: 2),
                        ),
                        child: Icon(McIcons.edit2, size: 14, color: muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                nickname,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (identity.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  identity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
              Divider(height: 24, color: scheme.outlineVariant),
              // 卡内三动作（对齐鸿蒙 ProfilePage 底部操作行）。
              Row(
                children: [
                  Expanded(
                    child: _CardAction(
                      icon: McIcons.shieldCheck,
                      label: McStrings.approveLogin,
                      onPressed: onApproveLogin,
                    ),
                  ),
                  Expanded(
                    child: _CardAction(
                      icon: McIcons.userSwitch,
                      label: McStrings.switchAccount,
                      onPressed: onSwitchAccount,
                    ),
                  ),
                  Expanded(
                    child: _CardAction(
                      icon: McIcons.logout,
                      label: McStrings.logout,
                      onPressed: onLogout,
                      danger: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 卡内单个小动作按钮（竖排图标+文字，鸿蒙 ProfileCard 底部样式）。
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE5615B) : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
