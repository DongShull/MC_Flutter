import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';

/// 服务器段（对齐鸿蒙）：
/// 「当前服务器」卡 +（管理员且有数据时）待处理/可用更新两瓷砖 +
/// SettingsCatalog 分组入口列表（只列有真实路由的项；成员身份只显示设备）。
class ServerSection extends StatelessWidget {
  const ServerSection({
    super.key,
    required this.host,
    required this.isAdmin,
    required this.noticeCount,
    required this.updateLabel,
  });

  final String host;
  final bool isAdmin;
  final int noticeCount;
  final String? updateLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showTiles = isAdmin && (noticeCount > 0 || updateLabel != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  McStrings.currentServerLabel,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  host.isEmpty ? McStrings.serverNotConnected : host,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push('/settings'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            McStrings.serverSettings,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        Icon(McIcons.chevronRight,
                            size: 13, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showTiles)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (noticeCount > 0)
                  Expanded(
                    child: _Tile(
                      title: McStrings.pendingTileTitle,
                      value: '$noticeCount${McStrings.itemsSuffix}',
                      detail: McStrings.pendingTileDetail,
                      tint: scheme.error,
                      onTap: () => context.push('/notices'),
                    ),
                  ),
                if (noticeCount > 0 && updateLabel != null)
                  const SizedBox(width: 12),
                if (updateLabel != null)
                  Expanded(
                    child: _Tile(
                      title: McStrings.updateTileTitle,
                      value: updateLabel!,
                      detail: McStrings.updateTileDetail,
                      tint: scheme.primary,
                      onTap: () => context.push('/update'),
                    ),
                  ),
              ],
            ),
          ),
        _catalog(context),
      ],
    );
  }

  /// SettingsCatalog 分组入口（对齐 SettingsIndexPage；只列有真实路由的项）。
  Widget _catalog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget group(String label) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        group(McStrings.settingsGroupAccount),
        _CatalogRow(
          icon: McIcons.device,
          title: McStrings.settingsDevicesTitle,
          subtitle: McStrings.settingsDevicesSubtitle,
          onTap: () => context.push('/settings/devices'),
        ),
        group(McStrings.settingsGroupMedia),
        _CatalogRow(
          icon: McIcons.playCircle,
          title: McStrings.settingsPlaybackTitle,
          subtitle: McStrings.settingsPlaybackSubtitle,
          onTap: () => context.push('/settings/playback'),
        ),
        group(McStrings.settingsGroupSystem),
        _CatalogRow(
          icon: Icons.system_update_outlined,
          title: McStrings.settingsMaintenanceTitle,
          subtitle: McStrings.settingsMaintenanceSubtitle,
          onTap: () => context.push('/update'),
        ),
        _CatalogRow(
          icon: McIcons.globe,
          title: McStrings.settingsWebTitle,
          subtitle: McStrings.settingsWebSubtitle,
          onTap: () => context.push('/settings/web'),
        ),
      ],
    );
  }
}

/// 待处理 / 可用更新瓷砖（对齐鸿蒙：radius16、minHeight88、tint 色值）。
class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.value,
    required this.detail,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String value;
  final String detail;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: tint,
              ),
            ),
            Text(detail,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// 设置目录行（对齐鸿蒙设置行样式：icon 18 accent2 / title 15 /
/// subtitle 12 muted / chevron，padding L16 R16 V11）。
class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Icon(icon, size: 18, color: scheme.secondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(McIcons.chevronRight,
                size: 13, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
