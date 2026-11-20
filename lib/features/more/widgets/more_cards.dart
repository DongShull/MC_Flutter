import 'package:flutter/material.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 「我的」页内部小部件。

/// 用户卡片：头像圈 + 昵称 + 角色，点按进个人信息。
class MoreUserCard extends StatelessWidget {
  const MoreUserCard({
    super.key,
    required this.displayName,
    required this.detail,
    this.onTap,
  });

  final String displayName;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            child: Text(
              displayName.isNotEmpty ? displayName.characters.first : '?',
              style: const TextStyle(fontSize: 20),
            ),
          ),
          title: Text(displayName, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(detail),
          trailing: const Icon(McIcons.chevronRight),
        ),
      );
}

/// 区块标题（「提醒」「对话会话」…）。
class MoreSectionLabel extends StatelessWidget {
  const MoreSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}

/// 带角标的入口行。
class MoreEntryRow extends StatelessWidget {
  const MoreEntryRow({
    super.key,
    required this.icon,
    required this.title,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final int? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      trailing: badge != null && badge! > 0
          ? Badge(
              label: Text('$badge'),
              backgroundColor: scheme.error,
            )
          : const Icon(McIcons.chevronRight),
    );
  }
}
