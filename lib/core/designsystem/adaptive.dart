import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mc_chrome.dart';
import 'mc_glass.dart';
import 'theme.dart';

/// 多设备适配层：手机 / 平板 / TV。
///
/// 判定优先级：显式 McFormOverrideProvider > TV 启发（大屏无手势导航）
/// > 平板（shortestSide>=600）> 手机。
enum McDeviceForm { phone, tablet, tv }

enum McWindowClass { compact, medium, expanded }

final mcFormOverrideProvider = StateProvider<McDeviceForm?>((ref) => null);

McDeviceForm _autoDetect(Size size) {
  final shortest = size.shortestSide;
  final longest = size.longestSide;
  final dpr = WidgetsBinding
      .instance.platformDispatcher.views.first.devicePixelRatio;
  final diagonalInches = math.sqrt(
        size.width * size.width + size.height * size.height,
      ) /
      (dpr * 160);
  final platform = defaultTargetPlatform;
  final looksTv = platform == TargetPlatform.android &&
      shortest >= 960 &&
      (longest / shortest) < 2.0;
  if (looksTv || diagonalInches >= 20) return McDeviceForm.tv;
  if (shortest >= 600) return McDeviceForm.tablet;
  return McDeviceForm.phone;
}

final mcFormProvider = Provider<McDeviceForm>((ref) {
  final override = ref.watch(mcFormOverrideProvider);
  if (override != null) return override;
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final logicalSize = view.physicalSize / view.devicePixelRatio;
  return _autoDetect(logicalSize);
});

McWindowClass mcWindowClassOf(McDeviceForm form) {
  switch (form) {
    case McDeviceForm.tv:
    case McDeviceForm.tablet:
      return McWindowClass.expanded;
    case McDeviceForm.phone:
      return McWindowClass.compact;
  }
}

/// 媒体墙自适应网格列数（对齐 Web 移动/桌面栅格节奏）。
int mcGridCrossAxisCount(
  McDeviceForm form,
  BoxConstraints constraints, {
  double cellExtent = 156,
  int min = 3,
  int max = 8,
}) {
  final w = constraints.maxWidth;
  switch (form) {
    case McDeviceForm.phone:
      if (w < 340) return 2;
      if (w >= 520) return 4;
      return 3;
    case McDeviceForm.tablet:
      return (w / cellExtent).floor().clamp(min, max).toInt();
    case McDeviceForm.tv:
      return (w / (cellExtent * 1.2))
          .floor()
          .clamp(math.max(5, min), max + 2)
          .toInt();
  }
}

class McFormWatch extends InheritedWidget {
  const McFormWatch({super.key, required this.form, required super.child});

  final McDeviceForm form;

  static McDeviceForm of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<McFormWatch>()?.form ??
      _autoDetect(MediaQuery.sizeOf(context));

  @override
  bool updateShouldNotify(McFormWatch oldWidget) => oldWidget.form != form;
}

/// 自适应页脚手架：平板 / 桌面 / TV 采用 Web 银玻璃同款半透毛玻璃侧边栏（取代生硬的 Material NavigationRail）。
class McAdaptiveScaffold extends StatelessWidget {
  const McAdaptiveScaffold({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.body,
    this.railLeading,
    this.railTrailing,
    this.footerAccount,
  });

  final List<McAdaptiveDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final Widget? railLeading;
  final Widget? railTrailing;
  final Widget? footerAccount;

  @override
  Widget build(BuildContext context) {
    final form = McFormWatch.of(context);
    if (form == McDeviceForm.phone) return body;

    final extended =
        form == McDeviceForm.tv || MediaQuery.widthOf(context) >= 900;
    final sidebarWidth = extended ? 236.0 : 76.0;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Row(
        children: [
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                width: sidebarWidth,
                decoration: const BoxDecoration(
                  color: McTokens.surfaceSidebar,
                  border: Border(
                    right: BorderSide(color: McTokens.line, width: 1),
                  ),
                ),
                child: SafeArea(
                  right: false,
                  child: FocusTraversalGroup(
                    child: Column(
                      crossAxisAlignment: extended
                          ? CrossAxisAlignment.stretch
                          : CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            extended ? 20 : 0,
                            18,
                            extended ? 16 : 0,
                            18,
                          ),
                          child: Align(
                            alignment: extended
                                ? Alignment.centerLeft
                                : Alignment.center,
                            child: McBrandMark(
                              size: 26,
                              showWordmark: extended,
                            ),
                          ),
                        ),
                        if (railLeading != null) railLeading!,
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            itemCount: destinations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, i) {
                              final d = destinations[i];
                              final selected = i == currentIndex;
                              return McFocusRing(
                                borderRadius: McTokens.pillRadius,
                                child: McPressable(
                                  onTap: () => onSelect(i),
                                  scaleDown: 0.98,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    height: 44,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: extended ? 14 : 0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? McTokens.glassFillActive
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(
                                        McTokens.pillRadius,
                                      ),
                                      border: selected
                                          ? Border.all(
                                              color: McTokens.lineStrong,
                                              width: 1,
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: extended
                                          ? MainAxisAlignment.start
                                          : MainAxisAlignment.center,
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Icon(
                                              selected
                                                  ? d.selectedIcon
                                                  : d.icon,
                                              size: 20,
                                              color: selected
                                                  ? McTokens.text
                                                  : McTokens.textMuted,
                                            ),
                                            if (d.dotColor != null)
                                              Positioned(
                                                right: -3,
                                                top: -3,
                                                child: Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration: BoxDecoration(
                                                    color: d.dotColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (extended) ...[
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              d.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: McText.sub.copyWith(
                                                fontSize: 15,
                                                color: selected
                                                    ? McTokens.text
                                                    : McTokens.textMuted,
                                                fontWeight: selected
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (railTrailing != null) railTrailing!,
                        if (footerAccount != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                            child: footerAccount!,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class McAdaptiveDestination {
  const McAdaptiveDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.dotColor,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color? dotColor;
}

/// TV / 键盘焦点环：采用银玻璃冷银白柔光环（`McTokens.focusRing`），替换旧版刺眼亮蓝环。
class McFocusRing extends StatelessWidget {
  const McFocusRing({super.key, required this.child, this.borderRadius = 12});

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final form = McFormWatch.of(context);
    if (form != McDeviceForm.tv) return child;
    return Focus(
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return AnimatedScale(
            scale: focused ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 160),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: focused ? McTokens.accentStrong : Colors.transparent,
                  width: 2,
                ),
                boxShadow: focused
                    ? const [
                        BoxShadow(
                          color: McTokens.focusRing,
                          blurRadius: 14,
                        ),
                      ]
                    : const [],
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
