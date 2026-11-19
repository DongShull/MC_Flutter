import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';

/// 多设备适配层：手机 / 平板 / TV pad。
///
/// 判定优先级：显式 McFormOverrideProvider > TV 启发（大屏无手势导航）
/// > 平板（shortestSide>=600）> 手机。业务代码不要自行写断点判断，
/// 统一读取 mcFormProvider / mcWindowClassProvider / McAdaptive 便捷组件。

enum McDeviceForm { phone, tablet, tv }

enum McWindowClass { compact, medium, expanded }

/// 显式覆盖形态（设置页/测试用）；null 表示自动判定。
final mcFormOverrideProvider =
    StateProvider<McDeviceForm?>((ref) => null);

McDeviceForm _autoDetect(Size size) {
  final shortest = size.shortestSide;
  final longest = size.longestSide;
  final diagonalInches =
      math.sqrt(size.width * size.width + size.height * size.height) /
          (WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio *
              160);
  // TV/盒子：大屏 + 无手势导航条 + 典型 16:9 电视分辨率。
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
      return McWindowClass.expanded;
    case McDeviceForm.tablet:
      return McWindowClass.expanded;
    case McDeviceForm.phone:
      return McWindowClass.compact;
  }
}

/// 媒体墙网格列数：每格约 [cellExtent] px， clamp 到 [min,max]。
int mcGridCrossAxisCount(McDeviceForm form, BoxConstraints constraints,
    {double cellExtent = 160, int min = 2, int max = 8}) {
  switch (form) {
    case McDeviceForm.phone:
      return math.max(min, 3);
    case McDeviceForm.tablet:
      return (constraints.maxWidth / cellExtent).floor().clamp(min, max).toInt();
    case McDeviceForm.tv:
      return (constraints.maxWidth / (cellExtent * 1.25))
          .floor()
          .clamp(math.max(5, min), max + 2)
          .toInt();
  }
}

/// InheritedWidget：把形态值下发给子树，纯组件可不依赖 Riverpod 读取形态。
class McFormWatch extends InheritedWidget {
  const McFormWatch({super.key, required this.form, required super.child});

  final McDeviceForm form;

  static McDeviceForm of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<McFormWatch>()?.form ??
      _autoDetect(MediaQuery.sizeOf(context));

  @override
  bool updateShouldNotify(McFormWatch oldWidget) => oldWidget.form != form;
}

/// 自适应页脚手架：手机=底部导航；平板/TV=左侧 Rail。
/// [destinations] 与 [currentIndex] 语义与 BottomNavigationBar 相同。
class McAdaptiveScaffold extends StatelessWidget {
  const McAdaptiveScaffold({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.body,
    this.railLeading,
    this.railTrailing,
  });

  final List<McAdaptiveDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final Widget? railLeading;
  final Widget? railTrailing;

  @override
  Widget build(BuildContext context) {
    final form = McFormWatch.of(context);
    if (form == McDeviceForm.phone) {
      return body; // 手机继续用 root_page 现有悬浮胶囊底栏。
    }
    final extended = form == McDeviceForm.tv ||
        MediaQuery.widthOf(context) >= 1024;
    return Scaffold(
      body: Row(
        children: [
          FocusTraversalGroup(
            child: NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onSelect,
              extended: extended,
              minExtendedWidth: 256,
              leading: railLeading,
              trailing: railTrailing,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
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
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// TV 焦点环：所有可聚焦控件的 focus 外观统一入口。
/// 非_tv 形态下原样返回子组件，零开销。
class McFocusRing extends StatelessWidget {
  const McFocusRing({super.key, required this.child, this.borderRadius = 12});

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final form = McFormWatch.of(context);
    if (form != McDeviceForm.tv) return child;
    return Focus(
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: focused ? McColors.accent : const Color(0x00000000),
              width: 2,
            ),
            boxShadow: focused
                ? [BoxShadow(color: McColors.accent.withOpacity(0.35), blurRadius: 12)]
                : const [],
          ),
          child: child,
        );
      }),
    );
  }
}
