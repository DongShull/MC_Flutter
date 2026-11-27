import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/api/mc_client.dart';
import 'core/api/server_addresses_api.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/designsystem/mc_chrome.dart';
import 'core/designsystem/theme.dart';
import 'core/l10n/mc_l10n.dart';
import 'core/navigation/external_media_link.dart';
import 'core/network/server_routes.dart';
import 'core/push/push_center.dart';
import 'core/router.dart';
import 'core/session/pending_revocations.dart';
import 'core/session/session_store.dart';
import 'features/root/state/main_tab_bus.dart';

AppLifecycleListener? _lifecycleListener;
StreamSubscription<UnauthorizedEvent>? _unauthorizedSub;
StreamSubscription<PushTapTarget>? _pushTapSub;

Future<void> _refreshSessionProfileSilently() async {
  final origin = appSession.baseUrl;
  if (!appSession.isReady || origin == null || origin.isEmpty) return;
  try {
    final client = McClient(session: appSession);
    final me = await client
        .unwrap<Map<String, dynamic>>(Channel.general, 'GET', '/api/v1/auth/me')
        .timeout(const Duration(seconds: 8));
    final expected = appSession.accountUsername;
    final actual = (me['username'] ?? '').toString().trim().toLowerCase();
    if (expected.isEmpty || actual.isEmpty || actual == expected) {
      await appSession.updateFromMeJson(me);
    }
  } catch (_) {
    // 401 已由 McClient.onUnauthorized 统一处理；网络错误保持本地缓存状态。
  }
}

Future<void> _handlePushTap(PushTapTarget target) async {
  if (!appSession.isReady) {
    PushCenter.instance.consumePendingTap();
    return;
  }
  final curOrigin = SessionStore.normalizeOrigin(appSession.baseUrl ?? '');
  final curUser = SessionStore.normalizeUsername(appSession.accountUsername);
  final targetOrigin = SessionStore.normalizeOrigin(target.login.origin);
  final targetUser = SessionStore.normalizeUsername(target.login.username);

  if (targetOrigin.isNotEmpty &&
      targetUser.isNotEmpty &&
      (targetOrigin != curOrigin || targetUser != curUser)) {
    final switched = await appSession.switchAccount(
      origin: targetOrigin,
      username: targetUser,
    );
    if (!switched) {
      PushCenter.instance.consumePendingTap();
      McToast.error('「${target.login.accountName}」登录已失效，请重新登录');
      return;
    }
    unawaited(_refreshSessionProfileSilently());
  }

  PushCenter.instance.consumePendingTap();
  final openPath = target.openPath;
  if (openPath == null || openPath.isEmpty) return;
  final resolved = AppWebPathResolver.resolveDetailed(openPath);
  if (resolved == null) return;
  if (resolved.location.startsWith('/home') && resolved.tabIndex != null) {
    const tabs = MainTab.values;
    if (resolved.tabIndex! >= 0 && resolved.tabIndex! < tabs.length) {
      MainTabBus.instance.open(tabs[resolved.tabIndex!]);
    }
    mcRouter.go('/home');
    return;
  }
  mcRouter.push(resolved.location);
}

Future<void> main() async {
  // Release 模式构建异常兜底：统一采用纯黑银玻璃可读面板。
  ErrorWidget.builder = (details) => Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: McTokens.bg,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: McTokens.surfaceRaised,
                borderRadius: BorderRadius.circular(McTokens.cardRadius),
                border: Border.all(color: McTokens.lineStrong),
              ),
              child: Text(
                '组件渲染异常：\n\n${details.exception}',
                style: McText.caption.copyWith(color: McTokens.danger),
              ),
            ),
          ),
        ),
      );

  await AppBootstrap.ensureMinimum();

  if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
    try {
      MediaKit.ensureInitialized();
    } catch (_) {}
  }

  McClient.acceptLanguageProvider = () =>
      McAppLanguage.fromLocale(McL10n.current.locale).acceptLanguageHeader;

  await Future.wait([
    appSession.restore(),
    ServerRoutes.instance.init(),
  ]);

  await _unauthorizedSub?.cancel();
  _unauthorizedSub = McClient.onUnauthorized.listen((event) {
    final currentLoc = mcRouter.routeInformationProvider.value.uri.toString();
    unawaited(
      appSession.handleUnauthorized(
        origin: event.origin,
        rejectedToken: event.token,
        currentLocation:
            currentLoc.startsWith('/onboarding') ? null : currentLoc,
      ),
    );
  });

  await _pushTapSub?.cancel();
  _pushTapSub = PushCenter.instance.onTap.listen((target) {
    unawaited(_handlePushTap(target));
  });

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('uncaught platform error: $error\n$stack');
    return true;
  };

  runApp(const ProviderScope(child: McApp()));

  AppBootstrap.runAfterFirstFrame(() {
    _lifecycleListener ??= AppLifecycleListener(
      onResume: () {
        ServerRoutes.instance.reevaluate();
        unawaited(_refreshSessionProfileSilently());
        unawaited(PendingRevocations.instance.retryAll());
        unawaited(() async {
          await PushCenter.instance.refreshPushInfo();
          await PushCenter.instance.sync();
        }());
      },
    );

    unawaited(PendingRevocations.instance.retryAll());
    unawaited(() async {
      await PushCenter.instance.start();
      if (appSession.isReady) {
        await PushCenter.instance.sync();
      }
      final pendingTap = PushCenter.instance.pendingTap;
      if (pendingTap != null && appSession.isReady) {
        await _handlePushTap(pendingTap);
      }
    }());

    final origin = appSession.baseUrl;
    if (appSession.isReady && origin != null && origin.isNotEmpty) {
      final bootClient = McClient(session: appSession, baseUrlOverride: origin);
      unawaited(
        ServerRoutes.instance.activate(
          origin,
          token: appSession.token,
          fetchBook: () => fetchServerAddresses(bootClient),
        ),
      );
      unawaited(_refreshSessionProfileSilently());
    }
  });
}
