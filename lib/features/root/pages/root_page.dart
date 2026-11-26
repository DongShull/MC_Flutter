import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/session/session_store.dart';
import '../../../core/shell/tab_collapse.dart';
import '../state/shell_badges.dart';

/// 主壳 Chrome（1:1 对齐 iOS 26 `MainTabView` + Web `glass-tab-bar.tsx`）：
/// - 手机：5 格纯图标悬浮液态玻璃胶囊（媒体库 / 订阅 / 发现 / 活动 / 头像）
///   + 阻尼弹簧滑动选中药丸 + 左右按住拖动擦选 + 下滑左收圆钮 + 底栏上方「接着看」浮条槽位
/// - 平板 / 桌面 / TV：左侧半透银玻璃侧边栏（`McAdaptiveScaffold`）
class RootShell extends ConsumerWidget {
  const RootShell({
    super.key,
    required this.index,
    required this.pages,
    required this.onSelect,
    this.bottomAccessory,
    this.onAvatarLongPress,
  });

  final int index;
  final List<Widget> pages;
  final ValueChanged<int> onSelect;
  final Widget? bottomAccessory;
  final VoidCallback? onAvatarLongPress;

  static const _labels = ['媒体库', '订阅', '发现', '活动', '我的'];
  static const _icons = [
    McIcons.mediaLibraryFill,
    McIcons.bookmark,
    McIcons.aiSearch,
    McIcons.waveform,
    McIcons.accountCircle,
  ];
  static const _filledIcons = [
    McIcons.mediaLibraryFill,
    McIcons.bookmarkFill,
    McIcons.aiSearchFill,
    McIcons.waveform,
    McIcons.accountCircleFill,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(shellBadgesProvider);
    final form = ref.watch(mcFormProvider);

    final body = AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: IndexedStack(index: index, children: pages),
    );

    if (form == McDeviceForm.phone) {
      final collapsed = ref.watch(tabCollapseProvider).collapsed;
      return Scaffold(
        backgroundColor: McTokens.bg,
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(child: body),
            // 底部柔和滚动压暗雾带（对齐 Web `.glass-tabbar-edge`），避免亮白海报把底栏冲花
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
                index: index,
                collapsed: collapsed,
                badges: badges,
                onSelect: onSelect,
                bottomAccessory: bottomAccessory,
                onAvatarLongPress: onAvatarLongPress,
              ),
            ),
          ],
        ),
      );
    }

    return McFormWatch(
      form: form,
      child: McAdaptiveScaffold(
        destinations: [
          for (var i = 0; i < _labels.length; i++)
            McAdaptiveDestination(
              icon: _icons[i],
              selectedIcon: _filledIcons[i],
              label: _labels[i],
              dotColor: _dotColor(i, badges),
            ),
        ],
        currentIndex: index,
        onSelect: onSelect,
        body: body,
        footerAccount: _SidebarAccountFooter(
          selected: index == 4,
          onTap: () => onSelect(4),
          onLongPress: onAvatarLongPress,
        ),
      ),
    );
  }

  static Color? _dotColor(int i, ShellBadges badges) {
    if (i == 3) {
      if (badges.attentionTotal > 0) return McTokens.danger;
      if (badges.livePlayback > 0) return McTokens.ok;
      if (badges.activeTotal > 0) return McTokens.info;
    } else if (i == 4 && badges.pendingUpdate) {
      return McTokens.info;
    }
    return null;
  }
}

class _PhoneBottomDock extends StatelessWidget {
  const _PhoneBottomDock({
    required this.index,
    required this.collapsed,
    required this.badges,
    required this.onSelect,
    this.bottomAccessory,
    this.onAvatarLongPress,
  });

  final int index;
  final bool collapsed;
  final ShellBadges badges;
  final ValueChanged<int> onSelect;
  final Widget? bottomAccessory;
  final VoidCallback? onAvatarLongPress;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // 对齐 Web `--tabbar-bottom: max(16px, calc(var(--safe-bottom) - 12px))`
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
                                child: index == 4
                                    ? const _TabAvatarBadge(size: 26)
                                    : Icon(
                                        RootShell._filledIcons[index],
                                        size: 22,
                                        color: McTokens.text,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : _LiquidCapsuleBar(
                        key: const ValueKey('expanded'),
                        index: index,
                        badges: badges,
                        onSelect: onSelect,
                        onAvatarLongPress: onAvatarLongPress,
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
    required this.index,
    required this.badges,
    required this.onSelect,
    this.onAvatarLongPress,
  });

  final int index;
  final ShellBadges badges;
  final ValueChanged<int> onSelect;
  final VoidCallback? onAvatarLongPress;

  void _scrubAt(BuildContext context, Offset localPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.width <= 0) return;
    final slot = ((localPos.dx / box.size.width) * RootShell._labels.length)
        .floor()
        .clamp(0, RootShell._labels.length - 1);
    if (slot != index) {
      HapticFeedback.selectionClick();
      onSelect(slot);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = RootShell._labels.length;
    // Alignment.x 从 -1.0 到 +1.0 线性映射 5 个槽位
    final alignX = count <= 1 ? 0.0 : -1.0 + (2.0 * index / (count - 1));

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
              // 弹簧滑动选中药丸（避免玻璃叠玻璃：内部只用半透冷白填充 + 极细亮沿）
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
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: _TabSlotItem(
                        slot: i,
                        selected: i == index,
                        dotColor: RootShell._dotColor(i, badges),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelect(i);
                        },
                        onLongPress: i == count - 1 ? onAvatarLongPress : null,
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
    required this.slot,
    required this.selected,
    required this.dotColor,
    required this.onTap,
    this.onLongPress,
  });

  final int slot;
  final bool selected;
  final Color? dotColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isAvatar = slot == RootShell._labels.length - 1;
    final iconWidget = isAvatar
        ? _TabAvatarBadge(size: 26, selected: selected)
        : Icon(
            selected ? RootShell._filledIcons[slot] : RootShell._icons[slot],
            size: 22,
            color: selected ? McTokens.text : McTokens.textMuted,
          );

    return Tooltip(
      message: RootShell._labels[slot],
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
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
                  right: -5,
                  top: -4,
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

class _TabAvatarBadge extends StatelessWidget {
  const _TabAvatarBadge({required this.size, this.selected = false});

  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final nickname = appSession.username;
    final initial = nickname.isEmpty
        ? 'M'
        : String.fromCharCode(nickname.runes.first).toUpperCase();
    final avatar = appSession.avatarUrl;

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
            initial,
            style: McText.micro.copyWith(
              fontSize: size * 0.46,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (avatar.isNotEmpty)
            Positioned.fill(
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: McImageUrls.resolve(avatar, widthPx: 96),
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

class _SidebarAccountFooter extends StatelessWidget {
  const _SidebarAccountFooter({
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final username = appSession.username.isEmpty ? '当前账号' : appSession.username;
    final wide = MediaQuery.widthOf(context) >= 900;
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
          border: Border.all(color: McTokens.line, width: 1),
        ),
        child: Row(
          mainAxisAlignment:
              wide ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            _TabAvatarBadge(size: 30, selected: selected),
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
                      '长按切换账号',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.micro.copyWith(
                        color: McTokens.textFaint,
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
