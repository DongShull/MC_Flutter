import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 分阶段启动（对齐飞牛 EndWarmUpFrame 思路，docs/design/09 §3.1）。
/// 首帧前只做最小集；首帧栅格化完成后再跑非首屏任务，压白屏时间。

class AppBootstrap {
  AppBootstrap._();

  /// main() 里调用：首帧前的最小初始化（当前为空——router/theme 都是纯构造）。
  static Future<void> ensureMinimum() async {
    WidgetsFlutterBinding.ensureInitialized();
  }

  /// 首帧栅格化后执行的非首屏任务。
  /// [postFrameTasks]：会话恢复、后台轮询装配等，逐个吞错避免拖垮启动。
  static void runAfterFirstFrame(void Function() postFrameTasks) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // 等真正栅格化完（不止 build 完），再交出主线程。
      WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) {
        try {
          postFrameTasks();
        } catch (e) {
          debugPrint('bootstrap post-frame task failed: $e');
        }
      });
    });
  }
}
