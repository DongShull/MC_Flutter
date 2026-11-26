import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mc_glass.dart';
import 'mc_icons.dart';
import 'theme.dart';

/// A9 极光品牌标志（圆角播放三角，尺寸 ≤32px 自动切换细笔画母版 `mark-ui.png`）。
class McBrandMark extends StatelessWidget {
  const McBrandMark({super.key, this.size = 28, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final asset =
        size <= 32 ? 'assets/brand/mark-ui.png' : 'assets/brand/mark.png';
    final mark = Image.asset(
      asset,
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => ShaderMask(
        shaderCallback: (rect) => McTokens.auroraGradient.createShader(rect),
        child: Icon(McIcons.playFill, size: size, color: Colors.white),
      ),
    );
    if (!showWordmark) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.28),
        Text(
          'MovieClaw',
          style: TextStyle(
            fontFamily: McText.fontFamily,
            fontSize: size * 0.64,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.35,
            color: McTokens.text,
          ),
        ),
      ],
    );
  }
}

/// 顶栏吸顶护字黑雾（支持黑曜石磨砂，消除滚过顶栏时的白字穿透叠影）。
class McPageFog extends StatelessWidget {
  const McPageFog({
    super.key,
    this.height = 96,
    this.opacity = 1.0,
    this.blurSigma = 0,
  });

  final double height;
  final double opacity;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    Widget box = Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xEE000000),
            Color(0xC2000000),
            Color(0x00000000),
          ],
          stops: [0.0, 0.62, 1.0],
        ),
      ),
    );
    if (blurSigma > 0) {
      box = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: box,
        ),
      );
    }
    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: box,
      ),
    );
  }
}

/// 一级标签根页统一沉浸式顶栏（对齐 iOS `MainTabView` + `AppTopBar`）：
/// - 左侧：`30sp Bold` 页面大标题（或可点击切换菜单的自定义 `titleWidget`）
/// - 右侧：页面专属玻璃圆钮 + 最右侧搜索玻璃圆钮
/// - 背景：无实色硬边，铺黑曜石磨砂渐变黑雾，海报与文字滚过时柔和隐没
class McSliverTopBar extends StatelessWidget {
  const McSliverTopBar({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.actions = const [],
    this.onSearch,
    this.pinned = true,
    this.floating = false,
  });

  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onSearch;
  final bool pinned;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    const barHeight = 56.0;
    return SliverAppBar(
      pinned: pinned,
      floating: floating,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: barHeight,
      titleSpacing: McTokens.pagePadding,
      flexibleSpace: McPageFog(
        height: topPad + barHeight + 18,
        blurSigma: 16,
      ),
      title: titleWidget ??
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (title != null) Text(title!, style: McText.display),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: McText.sub.copyWith(
                      color: McTokens.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
      actions: [
        ...actions,
        if (onSearch != null)
          McGlassIconButton(
            icon: McIcons.search,
            tooltip: '搜索',
            onTap: onSearch,
          ),
        const SizedBox(width: 10),
      ],
    );
  }
}

/// 详情页 / 二级沉浸页浮动顶栏：顶部全透明，返回圆钮与右侧操作圆钮浮在剧照上；
/// 页面上滑滚过标题区后，居中小标题与吸顶黑雾平滑渐入（对齐 iOS `LibraryItemDetailView`）。
class McFloatingDetailBar extends StatelessWidget {
  const McFloatingDetailBar({
    super.key,
    required this.onBack,
    this.title = '',
    this.titleVisible = false,
    this.trailing = const [],
  });

  final VoidCallback onBack;
  final String title;
  final bool titleVisible;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: topPad + 54,
      child: Stack(
        children: [
          Positioned.fill(
            child: McPageFog(
              height: topPad + 64,
              opacity: titleVisible ? 1.0 : 0.35,
              blurSigma: titleVisible ? 18 : 0,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, topPad + 6, 12, 6),
            child: Row(
              children: [
                McGlassIconButton(
                  icon: McIcons.arrowLeftS,
                  iconSize: 22,
                  tooltip: '返回',
                  onTap: onBack,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedOpacity(
                    opacity: titleVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: McText.titleSm,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (trailing.isEmpty)
                  const SizedBox(width: 42)
                else
                  Row(mainAxisSize: MainAxisSize.min, children: trailing),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 全站统一分区标题行（对齐 iOS `LibrarySectionHeader`：左 `20sp w600` 标题 + 右 `查看全部 ›` 或附加信息）。
class McSectionHeader extends StatelessWidget {
  const McSectionHeader({
    super.key,
    required this.title,
    this.leadingDotColor,
    this.countLabel,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.padding =
        const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
  });

  final String title;
  final Color? leadingDotColor;
  final String? countLabel;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leadingDotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: leadingDotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.title,
                ),
              ),
              if (countLabel != null && countLabel!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  countLabel!,
                  style: McText.ui.copyWith(color: McTokens.textFaint).tabular,
                ),
              ],
              if (onTap != null && trailing == null && trailingText == null) ...[
                const SizedBox(width: 4),
                const Icon(
                  McIcons.chevronRight,
                  size: 15,
                  color: McTokens.textFaint,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ] else if (trailingText != null && trailingText!.isNotEmpty) ...[
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                trailingText!,
                style: McText.caption.copyWith(color: McTokens.textFaint),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                const Icon(
                  McIcons.chevronRight,
                  size: 14,
                  color: McTokens.textFaint,
                ),
              ],
            ],
          ),
        ],
      ],
    );
    if (onTap != null) {
      row = McPressable(onTap: onTap, scaleDown: 0.985, child: row);
    }
    return Padding(padding: padding, child: row);
  }
}

/// Hero 与详情页统一主/次胶囊操作按钮（对齐 iOS `HeroActionButton.swift`）：
/// - 主按钮（`primary: true`）：亮银白实心胶囊 `#EEF2F8` + `#0B0C0F` 半粗黑字
/// - 次按钮（`primary: false`）：液态玻璃胶囊（支持 `tone: McGlassTone.danger` 收藏激活态）
/// - 最小宽度 `120dp`，通栏模式最大宽度封顶 `408dp`（大屏不拉成细长条）
class McActionPill extends StatelessWidget {
  const McActionPill({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.primary = true,
    this.tone = McGlassTone.secondary,
    this.expanded = false,
    this.busy = false,
    this.height = 40,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  final McGlassTone tone;
  final bool expanded;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final effectiveTone = primary ? McGlassTone.primary : tone;
    final fg = McGlass.defaultForeground(effectiveTone);
    final Widget content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McText.ui.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: fg,
            ).tabular,
          ),
        ),
      ],
    );

    final Widget pill = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: expanded ? 0 : 124,
        maxWidth: expanded ? 408 : double.infinity,
        minHeight: height,
      ),
      child: McGlassButton(
        onTap: busy ? null : onTap,
        tone: effectiveTone,
        radius: McTokens.pillRadius,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        foregroundColor: fg,
        child: content,
      ),
    );
    return pill;
  }
}

/// 胶囊筛选片 / 轨道选择片（对齐 iOS `LibraryChip`：选中亮银实底深色字，未选 `surfaceInset` + `1px line`）。
class McChip extends StatelessWidget {
  const McChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? McTokens.onAccent : McTokens.textMuted;
    return McPressable(
      onTap: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: selected ? McTokens.accentStrong : McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(McTokens.pillRadius),
          border: Border.all(
            color: selected ? Colors.transparent : McTokens.line,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: compact ? 13 : 15, color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: (compact ? McText.caption : McText.sub).copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS insetGrouped 风格圆角分组容器（统一替代散落的裸 `ListTile` 与生硬 `Card`）。
class McInsetGroup extends StatelessWidget {
  const McInsetGroup({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
    this.dividerIndent = 16,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null && header!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                header!,
                style: McText.caption.copyWith(
                  color: McTokens.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: McTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(McTokens.cardRadius),
              border: Border.all(color: McTokens.line, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: EdgeInsets.only(left: dividerIndent),
                      child: const Divider(height: 1, color: McTokens.line),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null && footer!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 7, 6, 0),
              child: Text(
                footer!,
                style: McText.caption.copyWith(color: McTokens.textFaint),
              ),
            ),
        ],
      ),
    );
  }
}

/// `McInsetGroup` 内的标准交互行。
class McInsetRow extends StatelessWidget {
  const McInsetRow({
    super.key,
    this.leading,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.valueText,
    this.trailing,
    this.showChevron = false,
    this.destructive = false,
    this.onTap,
  });

  final Widget? leading;
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final String? valueText;
  final Widget? trailing;
  final bool showChevron;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = destructive ? McTokens.danger : McTokens.text;
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ] else if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: iconColor ??
                  (destructive ? McTokens.danger : McTokens.textMuted),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: McText.ui.copyWith(color: titleColor)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: McText.caption),
                ],
              ],
            ),
          ),
          if (valueText != null && valueText!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                valueText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.sub.copyWith(color: McTokens.textMuted),
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          if (showChevron || (onTap != null && trailing == null && !destructive)) ...[
            const SizedBox(width: 6),
            const Icon(
              McIcons.chevronRight,
              size: 16,
              color: McTokens.textFaint,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        highlightColor: McTokens.glassFillActive,
        child: row,
      ),
    );
  }
}

/// 统一模态底部毛玻璃弹层（替代散落的默认 `showModalBottomSheet`）。
Future<T?> showMcSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  double maxWidth = 560,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xA6000000),
    constraints: BoxConstraints(maxWidth: maxWidth),
    builder: (ctx) => McSheetFrame(child: builder(ctx)),
  );
}

class McSheetFrame extends StatelessWidget {
  const McSheetFrame({
    super.key,
    this.title,
    this.trailing,
    required this.child,
  });

  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(McTokens.sheetRadius),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xEB151821),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(McTokens.sheetRadius),
              ),
              border: Border(
                top: BorderSide(color: McTokens.lineStrong, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0x47FFFFFF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (title != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(title!, style: McText.titleSm)),
                          if (trailing != null) trailing!,
                        ],
                      ),
                    ),
                  ] else
                    const SizedBox(height: 8),
                  Flexible(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 全局底部液态玻璃胶囊 Toast（对齐 iOS `Feedback.swift`） ──

enum McToastTone { info, success, error }

class _ToastEntry {
  const _ToastEntry({
    required this.id,
    required this.message,
    required this.tone,
  });

  final int id;
  final String message;
  final McToastTone tone;
}

/// 全局轻提示单例：浮在底部导航栏/软键盘上方，同一时刻只保留最新一条，点按或下滑即收。
class McToast {
  McToast._();

  static final _notifier = ValueNotifier<_ToastEntry?>(null);
  static int _seq = 0;
  static Timer? _timer;

  static void show(
    String message, {
    McToastTone tone = McToastTone.info,
    Duration? duration,
  }) {
    _timer?.cancel();
    final id = ++_seq;
    if (tone == McToastTone.error) {
      HapticFeedback.heavyImpact();
    } else if (tone == McToastTone.success) {
      HapticFeedback.lightImpact();
    }
    _notifier.value = _ToastEntry(id: id, message: message, tone: tone);
    final d = duration ??
        (tone == McToastTone.error
            ? const Duration(seconds: 5)
            : const Duration(milliseconds: 3200));
    _timer = Timer(d, () {
      if (_notifier.value?.id == id) {
        _notifier.value = null;
      }
    });
  }

  static void success(String message) =>
      show(message, tone: McToastTone.success);
  static void error(String message) => show(message, tone: McToastTone.error);
  static void info(String message) => show(message, tone: McToastTone.info);

  static void dismiss() {
    _timer?.cancel();
    _notifier.value = null;
  }
}

/// 挂在 `MaterialApp.builder` 顶层，承接所有 `McToast` 提示。
class McToastHost extends StatelessWidget {
  const McToastHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final bottomOffset = kb > 0 ? kb + 16 : safeBottom + 88;

    return Stack(
      children: [
        child,
        Positioned(
          left: 20,
          right: 20,
          bottom: bottomOffset,
          child: ValueListenableBuilder<_ToastEntry?>(
            valueListenable: McToast._notifier,
            builder: (context, entry, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (w, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(anim),
                    child: w,
                  ),
                ),
                child: entry == null
                    ? const SizedBox.shrink()
                    : Center(
                        key: ValueKey(entry.id),
                        child: GestureDetector(
                          onTap: McToast.dismiss,
                          onVerticalDragUpdate: (d) {
                            if (d.primaryDelta != null && d.primaryDelta! > 4) {
                              McToast.dismiss();
                            }
                          },
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: McLiquidGlass(
                              tone: switch (entry.tone) {
                                McToastTone.error => McGlassTone.danger,
                                McToastTone.success => McGlassTone.regular,
                                McToastTone.info => McGlassTone.regular,
                              },
                              radius: McTokens.pillRadius,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    switch (entry.tone) {
                                      McToastTone.success =>
                                        McIcons.checkCircleFill,
                                      McToastTone.error => McIcons.alert1,
                                      McToastTone.info => McIcons.information,
                                    },
                                    size: 17,
                                    color: switch (entry.tone) {
                                      McToastTone.success => McTokens.ok,
                                      McToastTone.error => McTokens.danger,
                                      McToastTone.info => McTokens.info,
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      entry.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: McText.sub.copyWith(
                                        color: McTokens.text,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}
