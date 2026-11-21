import 'dart:ui';

import 'package:flutter/material.dart';

/// 统一「渐变玻璃」按钮/瓷砖外观（对齐鸿蒙 GlassControls.ets GlassButtonModifier）。
///
/// 四个常用色调（同一套玻璃质感，只是色相不同）：
/// - secondary：冷白渐变（白 16% → 5%）；
/// - primary：银灰渐变（强调/选中），配深色文字；
/// - strong：更亮一档的白玻璃（分段控件选中态）；
/// - danger / info：红/蓝染色玻璃，配白字。
enum McGlassTone { secondary, primary, strong, danger, info }

class McGlass {
  const McGlass._();

  static Color _top(McGlassTone tone) => switch (tone) {
        McGlassTone.primary => const Color(0xFFEEF2F8),
        McGlassTone.strong => const Color(0x57FFFFFF), // rgba(255,255,255,.34)
        McGlassTone.danger => const Color(0xE0FF6B6B),
        McGlassTone.info => const Color(0xD17FB0FF),
        McGlassTone.secondary => const Color(0x29FFFFFF),
      };

  static Color _bottom(McGlassTone tone) => switch (tone) {
        McGlassTone.primary => const Color(0xFFBCC8DA),
        McGlassTone.strong => const Color(0x24FFFFFF),
        McGlassTone.danger => const Color(0x85FF6B6B),
        McGlassTone.info => const Color(0x6B7FB0FF),
        McGlassTone.secondary => const Color(0x0DFFFFFF),
      };

  static Color edge(McGlassTone tone) => switch (tone) {
        McGlassTone.primary => const Color(0xA6FFFFFF),
        McGlassTone.strong => const Color(0x61FFFFFF),
        McGlassTone.danger => const Color(0xB8FF6B6B),
        McGlassTone.info => const Color(0xA87FB0FF),
        McGlassTone.secondary => const Color(0x29FFFFFF),
      };

  /// 135° 渐变 + 背景模糊 + 1px 玻璃描边（鸿蒙 linearGradient 135 + COMPONENT_REGULAR 模糊）。
  static Decoration decoration(
    McGlassTone tone, {
    double radius = 12,
  }) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_top(tone), _bottom(tone)],
        ),
        border: Border.all(width: 1, color: edge(tone)),
      );
}

/// 玻璃按钮：容器统一渐变玻璃，内容自由（图标/文字/任意 Row）。
class McGlassButton extends StatelessWidget {
  const McGlassButton({
    super.key,
    required this.onTap,
    this.tone = McGlassTone.secondary,
    this.radius = 12,
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
    this.foregroundColor,
    required this.child,
  });

  final VoidCallback? onTap;
  final McGlassTone tone;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? foregroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ??
        (tone == McGlassTone.primary
            ? const Color(0xFF0B0D12)
            : Theme.of(context).colorScheme.onSurface);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: McGlass.decoration(tone, radius: radius),
            child: InkWell(
              onTap: onTap,
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(color: fg, size: 18),
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
