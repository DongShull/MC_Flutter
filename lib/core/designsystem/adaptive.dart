import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/mc_l10n.dart';
import 'mc_chrome.dart';
import 'mc_glass.dart';
import 'mc_icons.dart';
import 'theme.dart';

/// 多设备形态枚举：
/// - `phone`：手机竖屏或窄窗口（`< 600dp`）
/// - `tablet`：iPad / 安卓平板 / macOS / Windows / Linux 桌面宽屏（`>= 600dp`）
/// - `tv`：Android TV 10 英尺遥控器界面（或显式 Override），绝不把桌面显示器误判为 TV！
enum McDeviceForm { phone, tablet, tv }

enum McWindowClass { compact, medium, expanded }

final mcFormOverrideProvider = StateProvider<McDeviceForm?>((ref) => null);

/// 侧边栏手动折叠状态（宽屏下支持 `236dp ↔ 76dp` 一键折叠，对齐桌面端习惯）。
final mcSidebarCollapsedProvider = StateProvider<bool>((ref) => false);

bool mcIsDesktopPlatform() {
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

McDeviceForm mcDetectDeviceForm(Size size, {McDeviceForm? override}) {
  if (override != null) return override;
  // 桌面系统（macOS / Windows / Linux）按窗口宽度在 phone（极窄小窗）与 tablet（侧栏宽屏）间自由切换，永不误判为 TV。
  if (mcIsDesktopPlatform()) {
    return size.width >= 600 ? McDeviceForm.tablet : McDeviceForm.phone;
  }
  if (size.width >= 600 && size.shortestSide >= 540) {
    return McDeviceForm.tablet;
  }
  return McDeviceForm.phone;
}

/// 监听窗口尺寸实时变化的自适应通知器（支持 iPad Stage Manager 分屏与桌面拖拽缩放）。
class _ViewportSizeNotifier extends ChangeNotifier with WidgetsBindingObserver {
  _ViewportSizeNotifier() {
    WidgetsBinding.instance.addObserver(this);
  }

  Size get currentSize {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return const Size(390, 844);
    final view = views.first;
    final dpr = view.devicePixelRatio <= 0 ? 1.0 : view.devicePixelRatio;
    return view.physicalSize / dpr;
  }

  @override
  void didChangeMetrics() {
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final _viewportSizeProvider =
    ChangeNotifierProvider<_ViewportSizeNotifier>((ref) {
  return _ViewportSizeNotifier();
});

final mcFormProvider = Provider<McDeviceForm>((ref) {
  final override = ref.watch(mcFormOverrideProvider);
  final viewport = ref.watch(_viewportSizeProvider);
  return mcDetectDeviceForm(viewport.currentSize, override: override);
});

McWindowClass mcWindowClassOf(McDeviceForm form, {double? width}) {
  if (width != null) {
    if (width < 600) return McWindowClass.compact;
    if (width < 960) return McWindowClass.medium;
    return McWindowClass.expanded;
  }
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
  int max = 10,
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
      mcDetectDeviceForm(MediaQuery.sizeOf(context));

  @override
  bool updateShouldNotify(McFormWatch oldWidget) => oldWidget.form != form;
}

/// 平板 / iPadOS / macOS / Windows / Linux / TV 共用半透银玻璃侧边栏脚手架：
/// - 支持顶部 `⌘K` 全局命令搜索胶囊
/// - 支持宽屏 `236dp ↔ 76dp` 一键折叠切换
class McAdaptiveScaffold extends ConsumerWidget {
  const McAdaptiveScaffold({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.body,
    this.onOpenCommandPalette,
    this.railLeading,
    this.railTrailing,
    this.footerAccount,
  });

  final List<McAdaptiveDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final VoidCallback? onOpenCommandPalette;
  final Widget? railLeading;
  final Widget? railTrailing;
  final Widget? footerAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = McFormWatch.of(context);
    if (form == McDeviceForm.phone) return body;

    final collapsed = ref.watch(mcSidebarCollapsedProvider);
    final l10n = McL10n.of(context);
    final canExtend =
        form == McDeviceForm.tv || MediaQuery.widthOf(context) >= 900;
    final extended = canExtend && !collapsed;
    final sidebarWidth = extended ? 236.0 : 76.0;
    final shortcutLabel = defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.iOS
        ? '⌘K'
        : 'Ctrl+K';

    Widget collapseToggleButton() {
      final tip = extended
          ? l10n.sidebarCollapseTooltip
          : l10n.sidebarExpandTooltip;
      return Semantics(
        button: true,
        label: tip,
        child: Tooltip(
          message: tip,
          child: McPressable(
            onTap: () => ref
                .read(mcSidebarCollapsedProvider.notifier)
                .state = !collapsed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(
                  extended ? McIcons.panelLeft : McIcons.panelRight,
                  size: 17,
                  color: McTokens.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Row(
        children: [
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: sidebarWidth,
                decoration: const BoxDecoration(
                  color: McTokens.surfaceSidebar,
                  border: Border(
                    right: BorderSide(color: McTokens.line, width: 1),
                  ),
                ),
                child: SafeArea(
                  right: false,
                  child: ClipRect(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final showExpanded =
                            extended && constraints.maxWidth >= 160;
                        return FocusTraversalGroup(
                          child: Column(
                            crossAxisAlignment: showExpanded
                                ? CrossAxisAlignment.stretch
                                : CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  showExpanded ? 18 : 0,
                                  showExpanded ? 12 : 14,
                                  showExpanded ? 6 : 0,
                                  10,
                                ),
                                child: showExpanded
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Flexible(
                                            child: McBrandMark(
                                              size: 26,
                                              showWordmark: true,
                                            ),
                                          ),
                                          if (canExtend &&
                                              form != McDeviceForm.tv)
                                            collapseToggleButton(),
                                        ],
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const McBrandMark(
                                            size: 26,
                                            showWordmark: false,
                                          ),
                                          if (canExtend &&
                                              form != McDeviceForm.tv)
                                            collapseToggleButton(),
                                        ],
                                      ),
                              ),
                              if (onOpenCommandPalette != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    10,
                                  ),
                                  child: McFocusRing(
                                    borderRadius: 12,
                                    child: Tooltip(
                                      message: l10n.sidebarSearchPlaceholder,
                                      child: McPressable(
                                        onTap: onOpenCommandPalette,
                                        child: Container(
                                          height: 38,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: showExpanded ? 12 : 0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: McTokens.surfaceInset,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: McTokens.line,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: showExpanded
                                                ? MainAxisAlignment.start
                                                : MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                McIcons.search,
                                                size: 16,
                                                color: McTokens.textMuted,
                                              ),
                                              if (showExpanded) ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    l10n.sidebarSearchPlaceholder,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style:
                                                        McText.caption.muted,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        McTokens.glassFillHover,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      6,
                                                    ),
                                                    border: Border.all(
                                                      color: McTokens.line,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    shortcutLabel,
                                                    style: McText.micro.faint,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
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
                                      child: Tooltip(
                                        message: showExpanded ? '' : d.label,
                                        child: McPressable(
                                          onTap: () => onSelect(i),
                                          scaleDown: 0.98,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            height: 44,
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  showExpanded ? 14 : 0,
                                            ),
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? McTokens.glassFillActive
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                McTokens.pillRadius,
                                              ),
                                              border: selected
                                                  ? Border.all(
                                                      color:
                                                          McTokens.lineStrong,
                                                      width: 1,
                                                    )
                                                  : null,
                                            ),
                                            child: Row(
                                              mainAxisAlignment: showExpanded
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
                                                          decoration:
                                                              BoxDecoration(
                                                            color: d.dotColor,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (showExpanded) ...[
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      d.label,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          McText.sub.copyWith(
                                                        fontSize: 15,
                                                        color: selected
                                                            ? McTokens.text
                                                            : McTokens
                                                                .textMuted,
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
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (showExpanded && railTrailing != null)
                                railTrailing!,
                              if (footerAccount != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    12,
                                    14,
                                  ),
                                  child: footerAccount!,
                                ),
                            ],
                          ),
                        );
                      },
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

/// TV 与硬件键盘（macOS / Windows / Linux / iPad Magic Keyboard）通用银玻璃柔光焦点环：
/// 触屏点击不触发，按下键盘 Tab / 方向键或处于 TV 模式时自动亮起冷银高光环。
class McFocusRing extends StatefulWidget {
  const McFocusRing({super.key, required this.child, this.borderRadius = 12});

  final Widget child;
  final double borderRadius;

  @override
  State<McFocusRing> createState() => _McFocusRingState();
}

class _McFocusRingState extends State<McFocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final form = McFormWatch.of(context);
    final isTraditionalFocus =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (form != McDeviceForm.tv &&
        !mcIsDesktopPlatform() &&
        !isTraditionalFocus) {
      return widget.child;
    }
    return Focus(
      canRequestFocus: form == McDeviceForm.tv,
      onFocusChange: (v) {
        if (_focused != v && mounted) setState(() => _focused = v);
      },
      child: AnimatedScale(
        scale: _focused && form == McDeviceForm.tv ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: _focused
                ? Border.all(color: McTokens.accentStrong, width: 1.8)
                : null,
            boxShadow: _focused
                ? const [
                    BoxShadow(color: McTokens.focusRing, blurRadius: 12),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
