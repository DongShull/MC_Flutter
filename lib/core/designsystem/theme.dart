import 'package:flutter/material.dart';

/// silver glass 主题令牌（对齐原 core/designsystem 的设计语言）。
abstract final class McColors {
  static const accent = Color(0xFF26A5E4);
  static const bgDark = Color(0xFF0B0F14);
  static const surfaceDark = Color(0xFF141A21);
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
