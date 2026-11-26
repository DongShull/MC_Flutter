import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/network/server_routes.dart';

/// 服务器段：当前服务器连接卡（含局域网/公网选路状态）+ 待处理/更新提醒瓷砖 + `McInsetGroup` 分组目录。
class ServerSection extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final routeLabel = ref.watch(serverRoutesProvider).routeLabel;
    final showTiles = isAdmin && (noticeCount > 0 || updateLabel != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(
            McTokens.pagePadding,
            6,
            McTokens.pagePadding,
            0,
          ),
          decoration: BoxDecoration(
            color: McTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(McTokens.cardRadius),
            border: Border.all(color: McTokens.line, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          McStrings.currentServerLabel,
                          style: McText.caption.muted,
                        ),
                        const Spacer(),
                        if (routeLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x1F4ADE80),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x4D4ADE80),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '● $routeLabel',
                              style: McText.micro.copyWith(color: McTokens.ok),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      host.isEmpty ? McStrings.serverNotConnected : host,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: McText.title,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: McTokens.line),
              McInsetRow(
                icon: McIcons.setting1,
                title: McStrings.serverSettings,
                showChevron: true,
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ),
        if (showTiles)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              12,
              McTokens.pagePadding,
              0,
            ),
            child: Row(
              children: [
                if (noticeCount > 0)
                  Expanded(
                    child: _StatusTile(
                      title: McStrings.pendingTileTitle,
                      value: '$noticeCount${McStrings.itemsSuffix}',
                      detail: McStrings.pendingTileDetail,
                      tint: McTokens.danger,
                      onTap: () => context.push('/notices'),
                    ),
                  ),
                if (noticeCount > 0 && updateLabel != null)
                  const SizedBox(width: 12),
                if (updateLabel != null)
                  Expanded(
                    child: _StatusTile(
                      title: McStrings.updateTileTitle,
                      value: updateLabel!,
                      detail: McStrings.updateTileDetail,
                      tint: McTokens.info,
                      onTap: () => context.push('/update'),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        McInsetGroup(
          header: McStrings.settingsGroupAccount,
          children: [
            McInsetRow(
              icon: McIcons.device,
              title: McStrings.settingsDevicesTitle,
              subtitle: McStrings.settingsDevicesSubtitle,
              showChevron: true,
              onTap: () => context.push('/settings/devices'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        McInsetGroup(
          header: McStrings.settingsGroupMedia,
          children: [
            McInsetRow(
              icon: McIcons.playCircle,
              title: McStrings.settingsPlaybackTitle,
              subtitle: McStrings.settingsPlaybackSubtitle,
              showChevron: true,
              onTap: () => context.push('/settings/playback'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        McInsetGroup(
          header: McStrings.settingsGroupSystem,
          children: [
            McInsetRow(
              icon: McIcons.dataupgrade,
              title: McStrings.settingsMaintenanceTitle,
              subtitle: McStrings.settingsMaintenanceSubtitle,
              showChevron: true,
              onTap: () => context.push('/update'),
            ),
            McInsetRow(
              icon: McIcons.globe,
              title: McStrings.settingsWebTitle,
              subtitle: McStrings.settingsWebSubtitle,
              showChevron: true,
              onTap: () => context.push('/settings/web'),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
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
    return McPressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: McTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(McTokens.cardRadius),
          border: Border.all(color: McTokens.line, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: McText.caption.muted),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: McText.titleSm.copyWith(color: tint).tabular,
            ),
            const SizedBox(height: 2),
            Text(detail, style: McText.micro.copyWith(color: McTokens.textFaint)),
          ],
        ),
      ),
    );
  }
}
