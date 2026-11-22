import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/api/mc_error.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/session/session_store.dart';
import 'features/offline/state/background_download.dart';

Future<void> main() async {
  // release 模式默认构建异常=灰屏，改成可读红字（远程排障用）
  ErrorWidget.builder = (details) => Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: const Color(0xFFFFF3F3),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.topLeft,
          child: Text(
            '页面出错了，请截图反馈：\n\n(details.exception: ${details.exception})',
            style: const TextStyle(color: Color(0xFFB3261E), fontSize: 14),
          ),
        ),
      );
  // 分阶段启动（docs/design/09）：首帧前只做最小集，压白屏时间。
  await AppBootstrap.ensureMinimum();
  // 后台下载调度（P3：WorkManager 对等实现；web 跳过，失败只记日志）。
  try {
    OfflineBackgroundScheduler.initialize();
  } catch (e) {
    McErrorLog.log(e, context: 'main.backgroundInit');
  }
  // 启动即恢复会话（决定首屏是否跳过 onboarding，属首帧前最小集）。
  await appSession.restore();
  runZonedGuarded(() {
    runApp(const ProviderScope(child: McApp()));
    // 首帧真正栅格化后，再跑非首屏任务（会话恢复/预热钩子）。
    AppBootstrap.runAfterFirstFrame(() {
      debugPrint('mc_flutter: first frame rasterized, post-frame tasks done');
    });
  }, (error, stack) {
    // 全局兜底：按 P1 错误分级记日志（分级见 McError.classify），
    // 不再只有一行 debugPrint；上报钩子由 McErrorLog.reporter 接（P1 未接服务）。
    final classified = McError.classify(error);
    McErrorLog.log(classified, context: 'main.uncaught', stackTrace: stack);
  });
}
