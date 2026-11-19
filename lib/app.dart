import 'package:flutter/material.dart';

import 'core/designsystem/theme.dart';
import 'core/router.dart';

class McApp extends StatelessWidget {
  const McApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MovieClaw',
      theme: McTheme.light(),
      darkTheme: McTheme.dark(),
      routerConfig: mcRouter,
    );
  }
}
