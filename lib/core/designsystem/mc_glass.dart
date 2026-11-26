import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// 液态玻璃（Liquid Glass）色调。
///
/// 对齐主项目 Web `04-iOS-液态玻璃底栏.md` 与 iOS 26 Regular / Clear Glass：
/// - `regular`：浮在内容上的导航栏、顶栏圆钮、悬浮面板（暗底自适应 + 菲涅尔亮边）
/// - `secondary`：次级玻璃胶囊按钮（白 14% → 4%）
/// - `primary`：亮银白主强调实底（`#EEF2F8 → #DDE5F2`），配深黑字
/// - `strong`：分段控件激活态高透白
/// - `danger` / `info` / `warn`：状态染色玻璃（如「已收藏」淡红玻璃、链路告警琥珀玻璃）
enum McGlassTone {
  regular,
  secondary,
  primary,
  strong,
  danger,
  info,
  warn,
}

class McGlass {
  const McGlass._();

  static Color _top(McGlassTone tone) => switch (tone) {
        McGlassTone.regular => const Color(0x78181B24),
        McGlassTone.primary => McTokens.accentStrong,
        McGlassTone.strong => const Color(0x42FFFFFF),
        McGlassTone.danger => const Color(0x3DFF6B6B),
        McGlassTone.info => const Color(0x387FB0FF),
        McGlassTone.warn => const Color(0x38F5C451),
        McGlassTone.secondary => const Color(0x24FFFFFF),
      };

  static Color _bottom(McGlassTone tone) => switch (tone) {
        McGlassTone.regular => const Color(0x61101218),
        McGlassTone.primary => const Color(0xFFDCE4F2),
        McGlassTone.strong => const Color(0x1FFFFFFF),
        McGlassTone.danger => const Color(0x1FFF6B6B),
        McGlassTone.info => const Color(0x1A7FB0FF),
        McGlassTone.warn => const Color(0x1AF5C451),
        McGlassTone.secondary => const Color(0x0DFFFFFF),
      };

  static Color edge(McGlassTone tone) => switch (tone) {
        McGlassTone.regular => const Color(0x29FFFFFF),
        McGlassTone.primary => const Color(0xE6FFFFFF),
        McGlassTone.strong => const Color(0x52FFFFFF),
        McGlassTone.danger => const Color(0x66FF6B6B),
        McGlassTone.info => const Color(0x5C7FB0FF),
        McGlassTone.warn => const Color(0x66F5C451),
        McGlassTone.secondary => const Color(0x24FFFFFF),
      };

  static Color defaultForeground(McGlassTone tone) => switch (tone) {
        McGlassTone.primary => McTokens.onAccent,
        McGlassTone.danger => const Color(0xFFFFB4B4),
        McGlassTone.info => const Color(0xFFC4DCFF),
        McGlassTone.warn => McTokens.warning,
        _ => McTokens.text,
      };

  /// 135° 透镜微高光渐变 + 1px 菲涅尔玻璃描边。
  static BoxDecoration decoration(
    McGlassTone tone, {
    double radius = 12,
    bool withShadow = false,
  }) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_top(tone), _bottom(tone)],
        ),
        border: Border.all(width: 1, color: edge(tone)),
        boxShadow: withShadow
            ? const [
                BoxShadow(
                  color: Color(0xAD000000),
                  blurRadius: 28,
                  spreadRadius: -10,
                  offset: Offset(0, 12),
                ),
              ]
            : null,
      );
}

/// 去除生硬 Material 水波纹的跟手按压反馈（按下 90ms 微缩 + 触点增亮，松手阻尼回弹）。
class McPressable extends StatefulWidget {
  const McPressable({
    super.key,
    required this.onTap,
    this.onLongPress,
    this.scaleDown = 0.96,
    this.haptic = false,
    this.behavior = HitTestBehavior.opaque,
    required this.child,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final bool haptic;
  final HitTestBehavior behavior;
  final Widget child;

  @override
  State<McPressable> createState() => _McPressableState();
}

class _McPressableState extends State<McPressable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        if (widget.haptic) HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              _setPressed(false);
              widget.onLongPress?.call();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1.0,
        duration: Duration(milliseconds: _pressed ? 90 : 220),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 通用液态玻璃容器（实时背景高斯模糊 + 顶部高光内沿 + 菲涅尔细边）。
///
/// 遵循 Apple HIG 分层铁律：只用于浮在滚动内容之上的导航层、顶栏圆钮、播放器控件与浮窗，
/// 内部子项使用纯透明度填充，严禁玻璃内部再套 `BackdropFilter`。
class McLiquidGlass extends StatelessWidget {
  const McLiquidGlass({
    super.key,
    this.tone = McGlassTone.regular,
    this.radius = McTokens.pillRadius,
    this.blurSigma = 22,
    this.padding,
    this.withShadow = true,
    required this.child,
  });

  final McGlassTone tone;
  final double radius;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final bool withShadow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget inner = DecoratedBox(
      decoration: McGlass.decoration(tone, radius: radius),
      child: Stack(
        children: [
          // 顶部透镜高光丝线
          Positioned(
            top: 0,
            left: radius * 0.35,
            right: radius * 0.35,
            height: 1,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00FFFFFF),
                      Color(0x42FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (padding != null)
            Padding(padding: padding!, child: child)
          else
            child,
        ],
      ),
    );

    if (blurSigma > 0 && tone != McGlassTone.primary) {
      inner = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: inner,
      );
    }

    final Widget clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: inner,
    );

    if (!withShadow) return clipped;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 30,
            spreadRadius: -10,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: clipped,
    );
  }
}

/// 液态玻璃按钮（保持原 `McGlassButton` 签名 100% 兼容，升级跟手缩放与银玻璃配色）。
class McGlassButton extends StatelessWidget {
  const McGlassButton({
    super.key,
    required this.onTap,
    this.tone = McGlassTone.secondary,
    this.radius = McTokens.pillRadius,
    this.padding = const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
    this.foregroundColor,
    this.blurSigma = 18,
    required this.child,
  });

  final VoidCallback? onTap;
  final McGlassTone tone;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? foregroundColor;
  final double blurSigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? McGlass.defaultForeground(tone);
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: McPressable(
        onTap: onTap,
        child: McLiquidGlass(
          tone: tone,
          radius: radius,
          blurSigma: tone == McGlassTone.primary ? 0 : blurSigma,
          withShadow: false,
          padding: padding,
          child: DefaultTextStyle(
            style: McText.sub.copyWith(
              fontSize: 15,
              fontWeight:
                  tone == McGlassTone.primary ? FontWeight.w600 : FontWeight.w500,
              color: fg,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: fg, size: 18),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶栏 / 详情页 / 播放器共用的圆形液态玻璃图标按钮（默认 36×36dp，触控热区扩至 44×44dp）。
class McGlassIconButton extends StatelessWidget {
  const McGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 36,
    this.iconSize = 18,
    this.tone = McGlassTone.regular,
    this.iconColor,
    this.badgeColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final McGlassTone tone;
  final Color? iconColor;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final fg = iconColor ?? McGlass.defaultForeground(tone);
    Widget button = McPressable(
      onTap: onTap,
      haptic: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
        child: Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: McLiquidGlass(
                    tone: tone,
                    radius: size / 2,
                    blurSigma: 20,
                    withShadow: false,
                    child: Center(
                      child: Icon(icon, size: iconSize, color: fg),
                    ),
                  ),
                ),
                if (badgeColor != null)
                  Positioned(
                    right: 1,
                    top: 1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: McTokens.bg, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
