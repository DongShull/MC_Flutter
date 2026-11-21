import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mc_flutter/core/router.dart';
import 'package:mc_flutter/core/session/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main shell renders library page at /home', (tester) async {
    appSession.debugSeed(baseUrl: 'https://demo.example', token: 't');
    addTearDown(appSession.logoutForTest);

    mcRouter.go('/home');
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: mcRouter),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('媒体库'), findsWidgets,
        reason: 'main shell must show LibraryHomePage (default tab)');
  });
}
