import 'package:flutter/material.dart';

/// silver glass 主题令牌（对齐原 core/designsystem 的设计语言）。
abstract final class McColors {
  static const accent = Color(0xFF26A5E4);
  static const bgDark = Color(0xFF0B0F14);
  static const surfaceDark = Color(0xFF141A21);
}

/// 鸿蒙 AppTheme.ets 的颜色/尺寸令牌（1:1 抄值）：对齐鸿蒙版页面时统一从这里取。
abstract final class McTokens {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0B0D12);
  static const surfaceRaised = Color(0xFF14161D);
  static const text = Color(0xFFF3F5F9);
  static const textMuted = Color(0x9EF3F5F9); // rgba(243,245,249,.62)
  static const textFaint = Color(0x5CF3F5F9); // rgba(243,245,249,.36)
  static const line = Color(0x14FFFFFF); // rgba(255,255,255,.08)
  static const lineStrong = Color(0x26FFFFFF);
  static const accent = Color(0xFFCDD6E6);
  static const accentStrong = Color(0xFFEEF2F8);
  static const accent2 = Color(0xFF9FB0C9);
  static const ok = Color(0xFF4ADE80);
  static const info = Color(0xFF7FB0FF);
  static const danger = Color(0xFFFF6B6B);
  static const warning = Color(0xFFFBBF24);

  static const pagePadding = 16.0;
  static const posterRadius = 12.0;
  static const cardRadius = 16.0;
  static const posterAspect = 2 / 3;
}

abstract final class McTheme {
  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: McColors.accent,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // 飞牛原型主字体：思源黑体 CN Medium（assets/fonts 全量内嵌）。
      fontFamily: 'SourceHanSansCN',
      scaffoldBackgroundColor:
          brightness == Brightness.dark ? McColors.bgDark : null,
      cardTheme: CardThemeData(
        color: brightness == Brightness.dark ? McColors.surfaceDark : null,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
