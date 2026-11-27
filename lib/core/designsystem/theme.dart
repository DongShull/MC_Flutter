import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// MovieClaw 银玻璃（Silver Glass）唯一设计令牌。
///
/// 色值、字阶、圆角与留白 1:1 对齐主项目：
/// - Web 端：`apps/web/app/globals.css`（`:root` 银玻璃语义变量 + 移动端 HIG 字阶）
/// - iOS 端：`apps/apple/Shared/DesignSystem/Theme.swift`（纯黑底 + 液态玻璃 + 四档信号色）
abstract final class McTokens {
  // ── 画布与分层表面（Pure Black + Translucent Layers） ──
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0B0D12);
  static const posterPlaceholder = Color(0xFF1C1C1E);
  static const surfaceMain = Color(0x6B0E0E10); // rgba(14, 14, 16, 0.42)
  static const surfaceSidebar = Color(0x8C161618); // rgba(22, 22, 24, 0.55)
  static const surfaceRaised = Color(0xBD1E212B); // rgba(30, 33, 43, 0.74)
  static const surfaceSolid = Color(0xFF15171F); // 实色兜底（弹层深层底）
  static const surfaceInset = Color(0x0DFFFFFF); // rgba(255, 255, 255, 0.05)

  // ── 行内玻璃交互态 ──
  static const glassFill = Color(0x0AFFFFFF); // 4%
  static const glassFillHover = Color(0x13FFFFFF); // 7.5%
  static const glassFillActive = Color(0x1FFFFFFF); // 12%

  // ── 文本层级（冷白） ──
  static const text = Color(0xFFF3F5F9);
  static const textMuted = Color(0x9EF3F5F9); // 62%
  static const textFaint = Color(0x5CF3F5F9); // 36%
  static const onAccent = Color(0xFF0B0C0F);

  // ── 细描边与焦点环 ──
  static const line = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  static const lineStrong = Color(0x26FFFFFF); // rgba(255, 255, 255, 0.15)
  static const focusRing = Color(0x8CC8DAFF); // rgba(200, 218, 255, 0.55)

  // ── 去色冷银高光强调（不用刺眼电光蓝） ──
  static const accent = Color(0xFFCDD6E6);
  static const accentStrong = Color(0xFFEEF2F8);
  static const accent2 = Color(0xFF9FB0C9);
  static const accentSoft = Color(0x24CDD6E6); // 14%

  // ── 四档状态信号色（冷调对齐） ──
  static const ok = Color(0xFF4ADE80);
  static const info = Color(0xFF7FB0FF);
  static const warning = Color(0xFFF5C451);
  static const warn = warning;
  static const danger = Color(0xFFFF6B6B);
  static const dangerSolid = Color(0xFFC73838); // 实底白字专用（对比度 5.8:1）
  static const skippable = Color(0xFFF5B852); // 播放器可跳过片头段

  // ── A9 极光品牌渐变（仅限标志、欢迎页光晕与 AI 局部点缀） ──
  static const auroraColors = <Color>[
    Color(0xFF36E2BD),
    Color(0xFF4C9DFF),
    Color(0xFF9A6BFF),
    Color(0xFFFF7FCF),
  ];

  static const auroraGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: auroraColors,
  );

  // ── 布局与圆角规范（全站锁死 6 档圆角） ──
  static const pagePadding = 16.0;
  static const pagePaddingWide = 24.0;
  static const radiusXs = 4.0;
  static const radiusSm = 8.0;
  static const posterRadius = 12.0;
  static const cardRadius = 16.0;
  static const sheetRadius = 24.0;
  static const pillRadius = 999.0;
  static const posterAspect = 2 / 3;
  static const backdropAspect = 16 / 9;

  /// 手机悬浮底栏总让位高度（60dp 胶囊 + 24dp 距底 + 54dp 接着看条与间距 + 呼吸余量）。
  static const bottomBarClearance = 148.0;
}

/// 语义排版阶梯（对齐 Web `globals.css` 移动端 HIG 换档与 iOS Dynamic Type）。
abstract final class McText {
  static const fontFamily = 'Inter';
  static const fontFallback = <String>[
    'PingFang SC',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Source Han Sans SC',
    'Microsoft YaHei',
    'sans-serif',
  ];

  static const tabular = <FontFeature>[FontFeature.tabularFigures()];

  /// 30sp Bold —— 一级标签根页左上角大标题（媒体库 / 订阅 / 电影 / 活动 / 我的）。
  static const display = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.18,
    letterSpacing: -0.4,
    color: McTokens.text,
  );

  /// 22sp Bold —— 详情页片名、个人中心昵称、欢迎页标题。
  static const titleLg = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
    color: McTokens.text,
  );

  /// 20sp SemiBold —— 分区行标题（Section Header）、弹层主标题。
  static const title = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.28,
    letterSpacing: -0.2,
    color: McTokens.text,
  );

  /// 17sp SemiBold —— 卡片大标题、分组标题。
  static const titleSm = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.32,
    color: McTokens.text,
  );

  /// 17sp Regular —— 详情页简介、AI 会话阅读正文。
  static const bodyLg = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.52,
    color: McTokens.text,
  );

  /// 16sp Medium —— 列表行主标题、按钮、菜单项、导航项。
  static const ui = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: McTokens.text,
  );

  /// 16sp Regular —— 常规正文、输入框、聊天气泡。
  static const body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.48,
    color: McTokens.text,
  );

  /// 14sp SemiBold —— 海报卡下方单行片名。
  static const posterTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.28,
    color: McTokens.text,
  );

  /// 14sp Regular —— 辅助说明、表单副文案。
  static const sub = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: McTokens.textMuted,
  );

  /// 13sp Regular（默认开启等宽数字） —— 年份、评分、时长、相对时间。
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.32,
    color: McTokens.textMuted,
    fontFeatures: tabular,
  );

  /// 11sp SemiBold（最小字号下限） —— 海报胶囊角标、4K/HDR/直连徽标。
  static const micro = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
    color: McTokens.text,
    fontFeatures: tabular,
  );

  /// 欢迎页电影台词专用思源宋体。
  static TextStyle welcomeSerif({
    double size = 20,
    Color color = McTokens.text,
    double height = 1.55,
  }) =>
      TextStyle(
        fontFamily: 'WelcomeSerif',
        fontFamilyFallback: const ['Noto Serif CJK SC', 'Songti SC', 'serif'],
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: height,
        color: color,
      );
}

extension McTextStyleX on TextStyle {
  TextStyle get tabular => copyWith(fontFeatures: McText.tabular);
  TextStyle get muted => copyWith(color: McTokens.textMuted);
  TextStyle get faint => copyWith(color: McTokens.textFaint);
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);
}

/// 挂入 `ThemeData.extensions` 的银玻璃调色板（未来若扩展第二套主题可直接替换）。
@immutable
class McPalette extends ThemeExtension<McPalette> {
  const McPalette({
    this.bg = McTokens.bg,
    this.surface = McTokens.surface,
    this.surfaceRaised = McTokens.surfaceRaised,
    this.surfaceInset = McTokens.surfaceInset,
    this.posterPlaceholder = McTokens.posterPlaceholder,
    this.text = McTokens.text,
    this.textMuted = McTokens.textMuted,
    this.textFaint = McTokens.textFaint,
    this.line = McTokens.line,
    this.lineStrong = McTokens.lineStrong,
    this.accent = McTokens.accent,
    this.accentStrong = McTokens.accentStrong,
    this.onAccent = McTokens.onAccent,
    this.ok = McTokens.ok,
    this.info = McTokens.info,
    this.warn = McTokens.warning,
    this.danger = McTokens.danger,
    this.dangerSolid = McTokens.dangerSolid,
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceInset;
  final Color posterPlaceholder;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color line;
  final Color lineStrong;
  final Color accent;
  final Color accentStrong;
  final Color onAccent;
  final Color ok;
  final Color info;
  final Color warn;
  final Color danger;
  final Color dangerSolid;

  static const silverGlass = McPalette();

  @override
  McPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceInset,
    Color? posterPlaceholder,
    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? line,
    Color? lineStrong,
    Color? accent,
    Color? accentStrong,
    Color? onAccent,
    Color? ok,
    Color? info,
    Color? warn,
    Color? danger,
    Color? dangerSolid,
  }) {
    return McPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceInset: surfaceInset ?? this.surfaceInset,
      posterPlaceholder: posterPlaceholder ?? this.posterPlaceholder,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      onAccent: onAccent ?? this.onAccent,
      ok: ok ?? this.ok,
      info: info ?? this.info,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
      dangerSolid: dangerSolid ?? this.dangerSolid,
    );
  }

  @override
  McPalette lerp(covariant ThemeExtension<McPalette>? other, double t) {
    if (other is! McPalette) return this;
    return McPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceInset: Color.lerp(surfaceInset, other.surfaceInset, t)!,
      posterPlaceholder:
          Color.lerp(posterPlaceholder, other.posterPlaceholder, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      info: Color.lerp(info, other.info, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSolid: Color.lerp(dangerSolid, other.dangerSolid, t)!,
    );
  }
}

extension McThemeContextX on BuildContext {
  McPalette get mc =>
      Theme.of(this).extension<McPalette>() ?? McPalette.silverGlass;
}

/// iOS 风弹性滚动行为（移除 Android 默认蓝色拉伸水波光晕）。
class McScrollBehavior extends MaterialScrollBehavior {
  const McScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

abstract final class McTheme {
  /// 全站固定纯黑「银玻璃」暗色主题（light/dark 均返回同一套暗色规范，杜绝浅色闪烁）。
  static ThemeData light() => dark();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: McTokens.accentStrong,
      onPrimary: McTokens.onAccent,
      primaryContainer: McTokens.accentSoft,
      onPrimaryContainer: McTokens.text,
      secondary: McTokens.accent,
      onSecondary: McTokens.onAccent,
      secondaryContainer: Color(0x1FFFFFFF),
      onSecondaryContainer: McTokens.text,
      tertiary: McTokens.info,
      onTertiary: McTokens.onAccent,
      error: McTokens.danger,
      onError: Colors.white,
      errorContainer: McTokens.dangerSolid,
      onErrorContainer: Colors.white,
      surface: McTokens.bg,
      onSurface: McTokens.text,
      onSurfaceVariant: McTokens.textMuted,
      surfaceContainerLowest: McTokens.bg,
      surfaceContainerLow: McTokens.surface,
      surfaceContainer: McTokens.surfaceSolid,
      surfaceContainerHigh: Color(0xFF1C1F29),
      surfaceContainerHighest: McTokens.posterPlaceholder,
      outline: McTokens.lineStrong,
      outlineVariant: McTokens.line,
      scrim: Color(0xB8000000),
    );

    const textTheme = TextTheme(
      displayLarge: McText.display,
      displayMedium: McText.display,
      displaySmall: McText.titleLg,
      headlineLarge: McText.display,
      headlineMedium: McText.titleLg,
      headlineSmall: McText.title,
      titleLarge: McText.title,
      titleMedium: McText.titleSm,
      titleSmall: McText.posterTitle,
      bodyLarge: McText.bodyLg,
      bodyMedium: McText.body,
      bodySmall: McText.sub,
      labelLarge: McText.ui,
      labelMedium: McText.caption,
      labelSmall: McText.micro,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: McText.fontFamily,
      fontFamilyFallback: McText.fontFallback,
      textTheme: textTheme,
      scaffoldBackgroundColor: McTokens.bg,
      canvasColor: McTokens.surfaceSolid,
      dividerColor: McTokens.line,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: McTokens.glassFillHover,
      hoverColor: McTokens.glassFill,
      focusColor: McTokens.accentSoft,
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: McTokens.accentStrong,
        scaffoldBackgroundColor: McTokens.bg,
        barBackgroundColor: Color(0xB80B0D12),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        McPalette.silverGlass,
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: McTokens.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleSpacing: McTokens.pagePadding,
        titleTextStyle: McText.titleLg,
        iconTheme: IconThemeData(color: McTokens.text, size: 20),
        actionsIconTheme: IconThemeData(color: McTokens.text, size: 20),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: McTokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(McTokens.cardRadius),
          side: const BorderSide(color: McTokens.line, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: McTokens.accentStrong,
          foregroundColor: McTokens.onAccent,
          disabledBackgroundColor: const Color(0x1FFFFFFF),
          disabledForegroundColor: McTokens.textFaint,
          elevation: 0,
          minimumSize: const Size(88, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: const StadiumBorder(),
          textStyle: McText.ui.semibold,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: McTokens.text,
          backgroundColor: McTokens.surfaceInset,
          disabledForegroundColor: McTokens.textFaint,
          side: const BorderSide(color: McTokens.lineStrong, width: 1),
          minimumSize: const Size(76, 38),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          shape: const StadiumBorder(),
          textStyle: McText.sub.copyWith(
            color: McTokens.text,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: McTokens.accent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: const StadiumBorder(),
          textStyle: McText.sub.copyWith(
            color: McTokens.accent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: McTokens.text,
          highlightColor: McTokens.glassFillActive,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: McTokens.surfaceInset,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: McText.body.copyWith(color: McTokens.textFaint),
        labelStyle: McText.sub.copyWith(color: McTokens.textMuted),
        floatingLabelStyle: McText.caption.copyWith(color: McTokens.accent),
        prefixIconColor: McTokens.textMuted,
        suffixIconColor: McTokens.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: McTokens.line, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: McTokens.line, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: McTokens.lineStrong, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: McTokens.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: McTokens.danger, width: 1.2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: McTokens.surfaceInset,
        selectedColor: McTokens.accentStrong,
        disabledColor: const Color(0x08FFFFFF),
        secondarySelectedColor: McTokens.accentStrong,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelStyle: McText.sub.copyWith(color: McTokens.textMuted),
        secondaryLabelStyle: McText.sub.copyWith(
          color: McTokens.onAccent,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: McTokens.line, width: 1),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xF01A1D26),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: McTokens.lineStrong, width: 1),
        ),
        titleTextStyle: McText.titleSm,
        contentTextStyle: McText.sub,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xF2151821),
        modalBackgroundColor: Color(0xF2151821),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        dragHandleColor: Color(0x47FFFFFF),
        dragHandleSize: Size(36, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(McTokens.sheetRadius),
          ),
          side: BorderSide(color: McTokens.line, width: 1),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xF21B1E28),
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: const Color(0xCC000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: McTokens.lineStrong, width: 1),
        ),
        textStyle: McText.sub.copyWith(color: McTokens.text),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xEB1F2330),
        contentTextStyle: McText.sub.copyWith(color: McTokens.text),
        actionTextColor: McTokens.accentStrong,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
        shape: const StadiumBorder(
          side: BorderSide(color: McTokens.lineStrong, width: 1),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: McTokens.textMuted,
        textColor: McTokens.text,
        titleTextStyle: McText.ui,
        subtitleTextStyle: McText.caption,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return const Color(0xB3F3F5F9);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return McTokens.ok;
          return const Color(0x29FFFFFF);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return McTokens.accentStrong;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(McTokens.onAccent),
        side: const BorderSide(color: McTokens.lineStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: McTokens.accentStrong,
        linearTrackColor: Color(0x24FFFFFF),
        circularTrackColor: Color(0x1AFFFFFF),
      ),
      dividerTheme: const DividerThemeData(
        color: McTokens.line,
        thickness: 1,
        space: 1,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: McTokens.surfaceSidebar,
        indicatorColor: McTokens.glassFillActive,
        selectedIconTheme: const IconThemeData(color: McTokens.text, size: 22),
        unselectedIconTheme:
            const IconThemeData(color: McTokens.textMuted, size: 22),
        selectedLabelTextStyle:
            McText.sub.copyWith(color: McTokens.text, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: McText.sub.copyWith(color: McTokens.textMuted),
      ),
    );
  }
}
