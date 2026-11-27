import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/designsystem/mc_chrome.dart';
import 'core/designsystem/theme.dart';
import 'core/l10n/mc_l10n.dart';
import 'core/router.dart';
import 'core/shell/command_palette.dart';

class McApp extends ConsumerWidget {
  const McApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(mcLanguageProvider);
    return MaterialApp.router(
      title: 'MovieClaw',
      debugShowCheckedModeBanner: false,
      theme: McTheme.dark(),
      darkTheme: McTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: language.locale,
      supportedLocales: McL10n.supportedLocales,
      localizationsDelegates: const [
        McL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const McScrollBehavior(),
      routerConfig: mcRouter,
      builder: (context, child) => McToastHost(
        child: McCommandPaletteHost(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
