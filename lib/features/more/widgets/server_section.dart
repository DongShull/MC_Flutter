import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/network/server_routes.dart';

/// 服务器段（对齐 iOS `MorePage.server` & `ServerRouteLabel.swift`）：
/// - 当前服务器地址卡 + 实际选路徽标（家里网络 / 外网（经 VPN）/ 外网 + 主机）+ 「全部设置与控制中心」；
/// - 管理员专属「待处理提醒」与「可用更新（指向 `/settings/maintenance`）」双状态瓷砖；
/// - 精简高频入口（非管理员不展示 `/notices` 与管理员设置项）。
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

  static String? _routeDisplayText(ServerRoutes routes, String fallbackOrigin) {
    final routeKind = routes.routeKind;
    if (routeKind == null) return null;
    final activeOrigin = routes.currentOrigin(fallbackOrigin);
    final hostLabel = ServerRoutes.hostLabelOf(activeOrigin);
    final prefix = switch (routeKind) {
      RouteKind.lan => '家里网络',
      RouteKind.vpn => '经 VPN',
      RouteKind.wan => '外网',
    };
    return hostLabel.isNotEmpty ? '$prefix · $hostLabel' : prefix;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(serverRoutesProvider);
    final routeDisplay = _routeDisplayText(routes, host);
    final routeTint = switch (routes.routeKind) {
      RouteKind.lan => McTokens.ok,
      RouteKind.vpn => McTokens.info,
      RouteKind.wan => McTokens.accentStrong,
      null => McTokens.ok,
    };
    final showTiles = isAdmin && (noticeCount > 0 || updateLabel != null);
    final displayHost = ServerRoutes.hostLabelOf(host).isNotEmpty
        ? ServerRoutes.hostLabelOf(host)
        : host;
    final isIos = !kIsWeb && Platform.isIOS;

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
                    Text(
                      McStrings.currentServerLabel,
                      style: McText.caption.muted,
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      displayHost.isEmpty
                          ? McStrings.serverNotConnected
                          : displayHost,
                      style: McText.title,
                    ),
                    if (routeDisplay != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: routeTint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              routeDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.caption.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: McTokens.line),
              McInsetRow(
                icon: McIcons.setting1,
                title: isAdmin ? '服务器与全部设置' : '个人与播放设置',
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
                      // 服务器更新统一前往「更新与维护」，不跳客户端 APK 更新页。
                      onTap: () => context.push('/settings/maintenance'),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        McInsetGroup(
          header: McStrings.settingsGroupAccount,
          children: [
            McInsetRow(
              icon: McIcons.device,
              title: McStrings.settingsDevicesTitle,
              subtitle: '登录设备管理与配对码批准',
              showChevron: true,
              onTap: () => context.push('/settings/devices'),
            ),
            McInsetRow(
              icon: McIcons.playCircle,
              title: McStrings.settingsPlaybackTitle,
              subtitle: McStrings.settingsPlaybackSubtitle,
              showChevron: true,
              onTap: () => context.push('/settings/playback'),
            ),
            if (isAdmin)
              McInsetRow(
                icon: McIcons.bellOn,
                title: '待处理提醒与通知中心',
                valueText: noticeCount > 0 ? '$noticeCount 项' : null,
                showChevron: true,
                onTap: () => context.push('/notices'),
              ),
            if (isAdmin)
              McInsetRow(
                icon: McIcons.tools,
                title: McStrings.settingsMaintenanceTitle,
                subtitle: updateLabel ?? McStrings.settingsMaintenanceSubtitle,
                showChevron: true,
                onTap: () => context.push('/settings/maintenance'),
              ),
            if (!isIos)
              McInsetRow(
                icon: McIcons.dataupgrade,
                title: '关于与客户端更新',
                subtitle: '查看版本信息与检查客户端更新',
                showChevron: true,
                onTap: () => context.push('/update'),
              )
            else
              McInsetRow(
                icon: McIcons.alertCircle,
                title: '关于 MovieClaw',
                subtitle: '版本与发行说明',
                showChevron: true,
                onTap: () => context.push('/update'),
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
            Text(
              detail,
              style: McText.micro.copyWith(color: McTokens.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}
