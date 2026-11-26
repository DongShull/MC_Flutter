import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/designsystem/adaptive.dart';
import 'package:mc_flutter/core/session/session_store.dart';
import 'package:mc_flutter/core/shell/command_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mcDetectDeviceForm adaptive classification', () {
    test('27-inch 2560x1440 and 1080p monitors classify as tablet, never TV', () {
      expect(
        mcDetectDeviceForm(const Size(2560, 1440)),
        McDeviceForm.tablet,
      );
      expect(
        mcDetectDeviceForm(const Size(1920, 1080)),
        McDeviceForm.tablet,
      );
      expect(
        mcDetectDeviceForm(const Size(390, 844)),
        McDeviceForm.phone,
      );
      expect(
        mcDetectDeviceForm(const Size(1920, 1080), override: McDeviceForm.tv),
        McDeviceForm.tv,
      );
    });
  });

  group('McCommandPaletteHost (Cmd/Ctrl+K Spotlight)', () {
    setUp(() {
      appSession.debugSeed(baseUrl: 'https://mc.local', token: 'test-token');
      McCommandPaletteController.instance.close();
    });

    tearDown(() {
      McCommandPaletteController.instance.close();
      appSession.logoutForTest();
    });

    testWidgets('opens via controller, switches 3 search verticals, closes on Esc',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: McCommandPaletteHost(
              child: Scaffold(body: Text('Workspace Body')),
            ),
          ),
        ),
      );

      expect(find.text('Workspace Body'), findsOneWidget);

      McCommandPaletteController.instance.open();
      await tester.pumpAndSettle();

      expect(find.text('影视 (TMDB/豆瓣)'), findsOneWidget);
      expect(find.text('种子资源 (PT)'), findsOneWidget);
      expect(find.text('本地媒体库'), findsOneWidget);

      await tester.tap(find.text('种子资源 (PT)'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(McCommandPaletteController.instance.value, isFalse);
    });
  });
}
