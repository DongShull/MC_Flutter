import 'package:flutter/material.dart';

import 'core/designsystem/mc_chrome.dart';
import 'core/designsystem/theme.dart';
import 'core/router.dart';

class McApp extends StatelessWidget {
  const McApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MovieClaw',
      debugShowCheckedModeBanner: false,
      theme: McTheme.dark(),
      darkTheme: McTheme.dark(),
      themeMode: ThemeMode.dark,
      scrollBehavior: const McScrollBehavior(),
      routerConfig: mcRouter,
      builder: (context, child) => McToastHost(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
