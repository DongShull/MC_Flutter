import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/api/mc_client.dart';
import 'core/api/server_addresses_api.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/designsystem/theme.dart';
import 'core/network/server_routes.dart';
import 'core/session/session_store.dart';

AppLifecycleListener? _lifecycleListener;

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
  if ((Platform.isLinux || Platform.isWindows) &&
      !Platform.environment.containsKey('FLUTTER_TEST')) {
    try {
      MediaKit.ensureInitialized();
    } catch (_) {}
  }
  await Future.wait([
    appSession.restore(),
    ServerRoutes.instance.init(),
  ]);

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('uncaught platform error: $error\n$stack');
    return true;
  };

  runApp(const ProviderScope(child: McApp()));

  AppBootstrap.runAfterFirstFrame(() {
    _lifecycleListener ??= AppLifecycleListener(
      onResume: () => ServerRoutes.instance.reevaluate(),
    );
    final origin = appSession.baseUrl;
    if (appSession.isReady && origin != null && origin.isNotEmpty) {
      final bootClient = McClient(session: appSession, baseUrlOverride: origin);
      unawaited(
        ServerRoutes.instance.configure(
          origin,
          () => fetchServerAddresses(bootClient),
        ),
      );
    }
  });
}
