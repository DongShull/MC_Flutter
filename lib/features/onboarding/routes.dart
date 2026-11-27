import 'package:go_router/go_router.dart';
import 'pages/onboarding_page.dart';
import 'pages/qr_scan_page.dart';
import 'pages/splash_page.dart';

/// onboarding 模块路由（挂载到 core/router.dart）。
const routeOnboarding = '/onboarding';

/// 启动页：显式导航时可用，瞬间快进进入主界面。
const routeSplash = '/splash';

/// 扫码连接服务器（task6）：仅由登录页 push 使用。
const routeQrScan = '/onboarding/qr-scan';

final List<GoRoute> routes = [
  GoRoute(
    path: routeOnboarding,
    builder: (context, state) => OnboardingPage(
      mode: state.uri.queryParameters['mode'],
      prefillServer: state.uri.queryParameters['server'],
      prefillUsername: state.uri.queryParameters['username'],
    ),
  ),
  GoRoute(path: routeSplash, builder: (context, state) => const SplashPage()),
  GoRoute(path: routeQrScan, builder: (context, state) => const QrScanPage()),
  // 原样带回配对二维码（批准登录配对码扫码用，按 PairingQrParser 严格校验）。
  GoRoute(
    path: '/onboarding/qr-scan/raw',
    builder: (context, state) => const QrScanPage(popRaw: true),
  ),
];
