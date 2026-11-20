import 'package:go_router/go_router.dart';
import 'pages/onboarding_page.dart';
import 'pages/splash_page.dart';

/// onboarding 模块路由（挂载到 core/router.dart）。
const routeOnboarding = '/onboarding';
/// 启动页：已登录启动直达，短暂展示身份后进主界面。
const routeSplash = '/splash';

final List<GoRoute> routes = [
  GoRoute(path: routeOnboarding, builder: (context, state) => const OnboardingPage()),
  GoRoute(path: routeSplash, builder: (context, state) => const SplashPage()),
];