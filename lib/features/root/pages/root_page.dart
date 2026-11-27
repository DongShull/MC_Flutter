import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_watch.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_store.dart';
import '../../../core/shell/command_palette.dart';
import '../../../core/shell/tab_collapse.dart';
import '../state/main_tab_bus.dart';
import '../state/shell_badges.dart';

/// 主壳 Chrome（1:1 对齐 iOS 26 `MainTabView` + Web `glass-tab-bar.tsx`）：
/// - 手机：按权限动态裁剪的纯图标悬浮液态玻璃胶囊（媒体库 / [订阅] / 发现 / [活动] / 头像）
///   + 阻尼弹簧滑动选中药丸 + 左右按住拖动擦选 + 头像长按切换/双击秒切上一个账号 + 首次手势气泡提示
/// - 平板 / 桌面 / TV：左侧半透银玻璃侧边栏（移除重复的「我的」行，账号统一落在底部 `_SidebarAccountFooter`，
///   并支持动态挂载「我的收藏 / 媒体库列表 / 首页合集」侧边栏扩展段）。
class RootShell extends ConsumerWidget {
  const RootShell({
    super.key,
    required this.tabs,
    required this.activeTab,
    required this.pages,
    required this.onSelectTab,
    this.bottomAccessory,
    this.onAvatarLongPress,
    this.onAvatarDoubleTap,
    this.sidebarExtra,
    this.accountGestureTip,
  });

  final List<MainTab> tabs;
  final MainTab activeTab;
  final List<Widget> pages;
  final ValueChanged<MainTab> onSelectTab;
  final Widget? bottomAccessory;
  final VoidCallback? onAvatarLongPress;
  final VoidCallback? onAvatarDoubleTap;
  final Widget? sidebarExtra;
  final Widget? accountGestureTip;

  static String labelOf(MainTab tab) => switch (tab) {
        MainTab.library => '媒体库',
        MainTab.subscriptions => '订阅',
        MainTab.discover => '发现',
        MainTab.activity => '活动',
        MainTab.more => '我的',
      };

  static IconData iconOf(MainTab tab, {required bool selected}) => switch (tab) {
        MainTab.library => McIcons.mediaLibraryFill,
        MainTab.subscriptions =>
          selected ? McIcons.bookmarkFill : McIcons.bookmark,
        MainTab.discover => selected ? McIcons.aiSearchFill : McIcons.aiSearch,
        MainTab.activity => McIcons.waveform,
        MainTab.more =>
          selected ? McIcons.accountCircleFill : McIcons.accountCircle,
      };

  static Color? dotColorOf(MainTab tab, ShellBadges badges) {
    if (tab == MainTab.activity) {
      if (badges.attentionTotal > 0) return McTokens.danger;
      if (badges.livePlayback > 0) return McTokens.ok;
      if (badges.activeTotal > 0) return McTokens.info;
    } else if (tab == MainTab.more && badges.pendingUpdate) {
      return McTokens.info;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(shellBadgesProvider);
    final form = ref.watch(mcFormProvider);
    final activeIndex = tabs.indexOf(activeTab).clamp(0, pages.length - 1);

    final body = AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: IndexedStack(index: activeIndex, children: pages),
    );

    if (form == McDeviceForm.phone) {
      final collapsed = ref.watch(tabCollapseProvider).collapsed;
      return Scaffold(
        backgroundColor: McTokens.bg,
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(child: body),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 108,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x52000000),
                        Color(0xAD000000),
                      ],
                      stops: [0.0, 0.52, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PhoneBottomDock(
                tabs: tabs,
                activeTab: activeTab,
                collapsed: collapsed,
                badges: badges,
                onSelectTab: onSelectTab,
                bottomAccessory: bottomAccessory,
                onAvatarLongPress: onAvatarLongPress,
                onAvatarDoubleTap: onAvatarDoubleTap,
                accountGestureTip: accountGestureTip,
              ),
            ),
          ],
        ),
      );
    }

    // 侧边栏：移除重复的「我的」导航项（底部 `_SidebarAccountFooter` 即为专属账号/我的入口）。
    final sidebarTabs = tabs.where((t) => t != MainTab.more).toList();
    final sidebarIndex =
        activeTab == MainTab.more ? -1 : sidebarTabs.indexOf(activeTab);

    return McFormWatch(
      form: form,
      child: McAdaptiveScaffold(
        destinations: [
          for (final t in sidebarTabs)
            McAdaptiveDestination(
              icon: iconOf(t, selected: false),
              selectedIcon: iconOf(t, selected: true),
              label: labelOf(t),
              dotColor: dotColorOf(t, badges),
            ),
        ],
        currentIndex: sidebarIndex,
        onSelect: (i) {
          if (i >= 0 && i < sidebarTabs.length) {
            onSelectTab(sidebarTabs[i]);
          }
        },
        onOpenCommandPalette: McCommandPaletteController.instance.open,
        body: body,
        railTrailing: sidebarExtra,
        footerAccount: _SidebarAccountFooter(
          selected: activeTab == MainTab.more,
          hasUpdateDot: badges.pendingUpdate,
          onTap: () => onSelectTab(MainTab.more),
          onLongPress: onAvatarLongPress,
        ),
      ),
    );
  }
}

class _PhoneBottomDock extends StatelessWidget {
  const _PhoneBottomDock({
    required this.tabs,
    required this.activeTab,
    required this.collapsed,
    required this.badges,
    required this.onSelectTab,
    this.bottomAccessory,
    this.onAvatarLongPress,
    this.onAvatarDoubleTap,
    this.accountGestureTip,
  });

  final List<MainTab> tabs;
  final MainTab activeTab;
  final bool collapsed;
  final ShellBadges badges;
  final ValueChanged<MainTab> onSelectTab;
  final Widget? bottomAccessory;
  final VoidCallback? onAvatarLongPress;
  final VoidCallback? onAvatarDoubleTap;
  final Widget? accountGestureTip;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final bottomMargin =
        safeBottom > 12 ? (safeBottom - 10).clamp(12.0, 28.0) : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(21, 0, 21, bottomMargin),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!collapsed && accountGestureTip != null) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: accountGestureTip!,
                ),
                const SizedBox(height: 8),
              ],
              if (!collapsed && bottomAccessory != null) ...[
                bottomAccessory!,
                const SizedBox(height: 8),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                child: collapsed
                    ? Align(
                        key: const ValueKey('collapsed'),
                        alignment: Alignment.centerLeft,
                        child: McPressable(
                          onTap: TabCollapseBus.instance.expand,
                          haptic: true,
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: McLiquidGlass(
                              radius: 28,
                              blurSigma: 24,
                              child: Center(
                                child: activeTab == MainTab.more
                                    ? const _TabAvatarBadge(size: 26)
                                    : Icon(
                                        RootShell.iconOf(
                                          activeTab,
                                          selected: true,
                                        ),
                                        size: 23,
                                        color: McTokens.text,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : _LiquidCapsuleBar(
                        key: const ValueKey('expanded'),
                        tabs: tabs,
                        activeTab: activeTab,
                        badges: badges,
                        onSelectTab: onSelectTab,
                        onAvatarLongPress: onAvatarLongPress,
                        onAvatarDoubleTap: onAvatarDoubleTap,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidCapsuleBar extends StatelessWidget {
  const _LiquidCapsuleBar({
    super.key,
    required this.tabs,
    required this.activeTab,
    required this.badges,
    required this.onSelectTab,
    this.onAvatarLongPress,
    this.onAvatarDoubleTap,
  });

  final List<MainTab> tabs;
  final MainTab activeTab;
  final ShellBadges badges;
  final ValueChanged<MainTab> onSelectTab;
  final VoidCallback? onAvatarLongPress;
  final VoidCallback? onAvatarDoubleTap;

  void _scrubAt(BuildContext context, Offset localPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.width <= 0 || tabs.isEmpty) return;
    final slot = ((localPos.dx / box.size.width) * tabs.length)
        .floor()
        .clamp(0, tabs.length - 1);
    final target = tabs[slot];
    if (target != activeTab) {
      HapticFeedback.selectionClick();
      onSelectTab(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = tabs.length;
    final activeIdx = tabs.indexOf(activeTab).clamp(0, count - 1);
    final alignX = count <= 1 ? 0.0 : -1.0 + (2.0 * activeIdx / (count - 1));

    return GestureDetector(
      onHorizontalDragUpdate: (d) => _scrubAt(context, d.localPosition),
      child: SizedBox(
        height: 60,
        child: McLiquidGlass(
          radius: 30,
          blurSigma: 24,
          padding: const EdgeInsets.all(5),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: Alignment(alignX, 0),
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutBack,
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0x2EFFFFFF),
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final tab in tabs)
                    Expanded(
                      child: _TabSlotItem(
                        tab: tab,
                        selected: tab == activeTab,
                        dotColor: RootShell.dotColorOf(tab, badges),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelectTab(tab);
                        },
                        onLongPress:
                            tab == MainTab.more ? onAvatarLongPress : null,
                        onDoubleTap:
                            tab == MainTab.more ? onAvatarDoubleTap : null,
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

class _TabSlotItem extends StatelessWidget {
  const _TabSlotItem({
    required this.tab,
    required this.selected,
    required this.dotColor,
    required this.onTap,
    this.onLongPress,
    this.onDoubleTap,
  });

  final MainTab tab;
  final bool selected;
  final Color? dotColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final isAvatar = tab == MainTab.more;
    // 统一所有页签图标落在 26×26 正方形内，与头像页签视觉尺寸一致（对齐 iOS TabIcon.side = 26）。
    final iconWidget = SizedBox(
      width: 26,
      height: 26,
      child: Center(
        child: isAvatar
            ? _TabAvatarBadge(size: 26, selected: selected)
            : Icon(
                RootShell.iconOf(tab, selected: selected),
                size: 23,
                color: selected ? McTokens.text : McTokens.textMuted,
              ),
      ),
    );

    return Tooltip(
      message: RootShell.labelOf(tab),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              },
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: iconWidget,
              ),
              if (dotColor != null)
                Positioned(
                  right: -4,
                  top: -3,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xCC0E1016),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabAvatarBadge extends ConsumerWidget {
  const _TabAvatarBadge({required this.size, this.selected = false});

  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(mcPermissionsProvider);
    final displayName =
        perms.displayName.isNotEmpty ? perms.displayName : appSession.username;
    final initials = McPermissions.avatarInitials(displayName);
    final avatar =
        perms.avatarUrl.isNotEmpty ? perms.avatarUrl : appSession.avatarUrl;
    final resolved = avatar.isNotEmpty
        ? McImageUrls.resolve(
            McImageUrls.tagAccount(avatar, appSession.accountUsername),
            widthPx: 96,
          )
        : '';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF4C9DFF), Color(0xFF9A6BFF)],
        ),
        border: Border.all(
          color: selected ? McTokens.accentStrong : McTokens.lineStrong,
          width: selected ? 1.6 : 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            initials,
            style: McText.micro.copyWith(
              fontSize: initials.length > 1 ? size * 0.36 : size * 0.44,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (resolved.isNotEmpty)
            Positioned.fill(
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: resolved,
                  httpHeaders: mcImageHeaders(),
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarAccountFooter extends ConsumerWidget {
  const _SidebarAccountFooter({
    required this.selected,
    required this.hasUpdateDot,
    required this.onTap,
    this.onLongPress,
  });

  final bool selected;
  final bool hasUpdateDot;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(mcPermissionsProvider);
    final collapsed = ref.watch(mcSidebarCollapsedProvider);
    final username = perms.displayName.isNotEmpty
        ? perms.displayName
        : (appSession.username.isEmpty ? '当前账号' : appSession.username);
    final wide = MediaQuery.widthOf(context) >= 900 && !collapsed;
    return McPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 12 : 0,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected ? McTokens.glassFillActive : McTokens.glassFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? McTokens.lineStrong : McTokens.line,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              wide ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _TabAvatarBadge(size: 30, selected: selected),
                if (hasUpdateDot)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: McTokens.info,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xCC0E1016),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (wide) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.sub.copyWith(
                        color: McTokens.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      hasUpdateDot ? '有可用更新 · 长按切账号' : '长按切换账号',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.micro.copyWith(
                        color: hasUpdateDot
                            ? McTokens.info
                            : McTokens.textFaint,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
