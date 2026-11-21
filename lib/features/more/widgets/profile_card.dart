import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/image/image_urls.dart';

import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';

/// 个人信息卡（1:1 对齐鸿蒙 ProfileCard）：
/// 左侧 80 圆形渐变头像（首字 fallback）+ 右下铅笔角标 + 昵称 + 身份小字；
/// 右侧 2×2 按钮格：批准登录 / 切换账号 / 退出账号（红）/ 空占位（虚线框）。
/// 点头像进个人信息页（/settings/profile），按钮不触发卡片跳转。
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 左：头像 + 昵称 + 身份（点头像进个人信息页）。
            Expanded(
              flex: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/settings/profile'),
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
                                color:
                                    scheme.onPrimary.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                          if ((avatarUrl ?? '').isNotEmpty)
                            Positioned.fill(
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: McImageUrls.resolve(avatarUrl,
                                      widthPx: 160),
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
                                border:
                                    Border.all(color: scheme.surface, width: 2),
                              ),
                              child: Icon(McIcons.edit2, size: 14, color: muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 110,
                      child: Text(
                        nickname,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (identity.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 110,
                        child: Text(
                          identity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 右：2×2 按钮格（批准登录/切换账号/退出账号/空占位）。
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CardAction(
                          icon: McIcons.scan,
                          label: McStrings.approveLogin,
                          onTap: onApproveLogin,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CardAction(
                          icon: McIcons.userSwitch,
                          label: McStrings.switchAccount,
                          onTap: onSwitchAccount,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _CardAction(
                          icon: McIcons.logout,
                          label: McStrings.logout,
                          danger: true,
                          onTap: onLogout,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 空占位（对齐鸿蒙：虚线空格子）。
                      const Expanded(
                        child: _EmptySlot(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡内玻璃小按钮（图标+文字横排，玻璃 secondary；danger=红色文字）。
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
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? const Color(0xFFE5615B) : scheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: McGlass.decoration(McGlassTone.secondary, radius: 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 空占位格子（虚线描边，预留扩展）。
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _DashedBorderPainter(
        radius: 14,
        color: scheme.outlineVariant,
      ),
      child: const SizedBox(height: 52),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 四条边分别画虚线（沿外框直线段近似）。
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    // 四条边分别画虚线（路径沿 rrect 外框近似直线段）。
    final edges = [
      [Offset(radius, 0), Offset(size.width - radius, 0)],
      [Offset(size.width, radius), Offset(size.width, size.height - radius)],
      [Offset(size.width - radius, size.height),
        Offset(radius, size.height)],
      [Offset(0, size.height - radius), Offset(0, radius)],
    ];
    for (final e in edges) {
      final a = e[0];
      final b = e[1];
      final len = (b - a).distance;
      final dir = (b - a) / len;
      var d = 0.0;
      while (d < len) {
        final end = (d + dash).clamp(0.0, len);
        canvas.drawLine(a + dir * d, a + dir * end, paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
