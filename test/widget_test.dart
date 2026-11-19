import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/app.dart';
import 'package:mc_flutter/features/onboarding/pages/onboarding_page.dart';

void main() {
  testWidgets('McApp renders onboarding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: McApp()));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.text('MovieClaw'), findsOneWidget);
    expect(find.text('服务器地址'), findsOneWidget);
  });
}
