import 'package:go_router/go_router.dart';
import 'pages/onboarding_page.dart';

/// onboarding 模块路由（挂载到 core/router.dart）。
const routeOnboarding = '/onboarding';

final List<GoRoute> routes = [
  GoRoute(path: routeOnboarding, builder: (context, state) => const OnboardingPage()),
];
