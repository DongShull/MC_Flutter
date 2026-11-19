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

/// 启动/运行期错误环形缓冲（飞牛无对应公开面，属通用兜底；
/// 未来接崩溃上报时直接读这里）。
class BootstrapErrorLog {
  BootstrapErrorLog._();

  static const maxSize = 50;
  static final List<String> _entries = [];

  static void record(String message) {
    if (_entries.length >= maxSize) _entries.removeAt(0);
    _entries.add(message);
  }

  static List<String> get entries => List.unmodifiable(_entries);
}
