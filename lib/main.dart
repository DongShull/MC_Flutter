import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/bootstrap/app_bootstrap.dart';

Future<void> main() async {
  // 分阶段启动（docs/design/09）：首帧前只做最小集，压白屏时间。
  await AppBootstrap.ensureMinimum();
  runZonedGuarded(() {
    runApp(const ProviderScope(child: McApp()));
    // 首帧真正栅格化后，再跑非首屏任务（会话恢复/预热钩子）。
    AppBootstrap.runAfterFirstFrame(() {
      debugPrint('mc_flutter: first frame rasterized, post-frame tasks done');
    });
  }, (error, stack) {
    debugPrint('uncaught zone error: $error\n$stack');
  });
}
