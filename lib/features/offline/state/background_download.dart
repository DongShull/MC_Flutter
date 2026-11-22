/// 离线后台下载：安卓 WorkManager 的 Flutter 对等实现（P3）。
///
/// 安卓原生对照：`OfflineDownloadWorker`（WorkManager
/// `OneTimeWorkRequest` + 唯一名 `movieclaw-offline-downloads` +
/// 前台通知 + 网络约束 UNMETERED/CONNECTED）。Flutter 侧用
/// `workmanager` 插件（0.10.10）做同一件事：同一个唯一名、
/// 同一组网络约束、同一个前台通知文案口径。
///
/// 各端做法（诚实版）：
/// - **安卓**：`Workmanager.registerOneOffTask`（唯一名，
///   `ExistingWorkPolicy.keep`；改蜂窝设置时 `replace` 重排，
///   与 Kotlin `schedule(replace)` 一致）+ 前台服务通知
///   （`ForegroundServiceConfig`，长任务不被系统 10 分钟掐掉）。
///   约束：`allowCellular=false` → `NetworkType.unmetered`（只用 Wi-Fi），
///   `true` → `NetworkType.connected`。到期重试（失败未下完）
///   由调用方按最早重试时刻再排一次（见 `OfflineController`）。
/// - **iOS**：同一 `registerOneOffTask`，底层是 BGTaskScheduler
///   `BGProcessingTask`（标识见 `Info.plist` 的
///   `BGTaskSchedulerPermittedIdentifiers`）。iOS **不保证**执行时机
///   与时长（系统按电量/使用习惯调度，任务随时可被挂起），
///   且没有安卓式的前台通知；只能当“有机会就续下”，不能当
///   “切后台必下完”。另见 iOS 后台下载会话（`URLSession`
///   background）是原生另一条路，未接（见小结）。
/// - **web**：不支持。`workmanager_web` 是实验性 Service Worker
///   实现，本项目不启用；页面关掉下载即停，只能在页内用
///   纯 Dart 保底下载器续下。[schedule] 在 web 直接返回
///   [BackgroundScheduleResult.unsupportedWeb]，不假装已排。
/// - **鸿蒙**：Flutter 鸿蒙目标未验证（见 `docs/PLAYER_MATRIX.md`），
///   后台能力未确认。
///
/// 后台回调（`offlineBackgroundCallbackDispatcher`）里只做一件事：
/// 读 `SharedPreferences` 里的任务表（`offline_tasks_v2`，与
/// `OfflineController` 同一份），用**纯 Dart 保底下载器**
/// （`McFallbackDownloadManager`，`dart:io` HttpClient）把没下完的
/// 任务续完。刻意不用原生 `mc/native/download` 通道：后台 isolate
/// 没有 Activity，原生插件拿不到 `getExternalFilesDir` 的上下文，
/// 且原生下载器是前台进程内的线程池。已解析好的直链 URL 存在任务
/// 表里，后台不需要重新开播放会话、不需要登录态。
///
/// 真机验证：未验证（本机无安卓/iOS 设备；见 `docs/CAST_VERIFICATION.md`
/// 同款清单与小结）。`flutter test` 只覆盖纯 Dart 部分
/// （约束映射、任务表解析、续跑逻辑），见
/// `test/background_download_test.dart`。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/platform/download_channel.dart';

/// 与安卓原生相同的唯一作业名（`OfflineDownloadWorker.WORK`）。
const offlineBackgroundUniqueName = 'movieclaw-offline-downloads';

/// 后台任务名（Dart 回调里按它分发）。
const offlineBackgroundTaskName = 'mc-offline-download';

/// 任务表键（与 `OfflineController._tasksKey` 同一份）。
const offlineBackgroundTasksKey = 'offline_tasks_v2';

enum BackgroundScheduleResult {
  /// 已排入 WorkManager / BGTaskScheduler。
  scheduled,

  /// web：不支持后台下载（见文件头）。
  unsupportedWeb,

  /// 注册抛错（插件未初始化等），调用方记日志。
  failed,
}

/// 后台下载调度器（WorkManager 对等层）。
class OfflineBackgroundScheduler {
  OfflineBackgroundScheduler({Workmanager? workmanager})
      : _workmanager = workmanager ?? Workmanager();

  final Workmanager _workmanager;

  /// 约束映射（与 Kotlin `OfflineDownloadWorker.schedule` 同口径）：
  /// 不许蜂窝 → 只要不计费网络（Wi-Fi）；允许蜂窝 → 任何已连接网络。
  static NetworkType networkTypeFor(bool allowCellular) =>
      allowCellular ? NetworkType.connected : NetworkType.unmetered;

  /// 前台通知（与 Kotlin `foregroundInfo` 同口径：低重要性下载通道，
  /// 点通知回下载页；文案由系统按进度刷新，插件侧只给标题/正文模板）。
  static ForegroundServiceConfig get foregroundConfig =>
      ForegroundServiceConfig(
        notificationTitle: '下载',
        notificationText: '正在下载影片到手机',
        notificationChannelId: 'offline_downloads',
        notificationChannelName: '下载',
        notificationId: 0x0FF1,
        foregroundServiceType: ForegroundServiceType.dataSync,
      );

  /// 在 `main()` 里调一次（`runApp` 之前）；web 跳过。
  static void initialize() {
    if (kIsWeb) return;
    Workmanager().initialize(offlineBackgroundCallbackDispatcher);
  }

  /// 确保有后台作业排着（有未完成下载时调；KEEP 口径：已排着就不动）。
  /// [delay]：到点才重试的失败按最早重试时刻再排一次时用。
  Future<BackgroundScheduleResult> schedule({
    required bool allowCellular,
    Duration delay = Duration.zero,
    bool replace = false,
  }) async {
    if (kIsWeb) return BackgroundScheduleResult.unsupportedWeb;
    try {
      await _workmanager.registerOneOffTask(
        offlineBackgroundUniqueName,
        offlineBackgroundTaskName,
        initialDelay: delay,
        constraints:
            Constraints(networkType: networkTypeFor(allowCellular)),
        existingWorkPolicy:
            replace ? ExistingWorkPolicy.replace : ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
        foregroundServiceConfig: foregroundConfig,
      );
      return BackgroundScheduleResult.scheduled;
    } catch (e) {
      debugPrint('offline background schedule failed: $e');
      return BackgroundScheduleResult.failed;
    }
  }

  /// 没活了就取消排着的作业（与 Kotlin “drive 返回 null 即不再排” 对应）。
  Future<void> cancel() async {
    if (kIsWeb) return;
    try {
      await _workmanager.cancelByUniqueName(offlineBackgroundUniqueName);
    } catch (e) {
      debugPrint('offline background cancel failed: $e');
    }
  }
}

/// 后台入口（`@pragma('vm:entry-point')`：tree-shaking 不许裁掉）。
/// 只续跑任务表里没下完的任务；返回 false = 还有失败，系统按退避重试。
@pragma('vm:entry-point')
void offlineBackgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != offlineBackgroundTaskName) return false;
    try {
      return await resumePendingDownloads();
    } catch (e) {
      debugPrint('offline background task failed: $e');
      return false;
    }
  });
}

/// 续跑任务表里没下完的任务（纯 Dart，可单测；后台回调与前台
/// “应用启动恢复”共用同一函数）。
///
/// - 已落盘（`savePath` 存在）→ 跳过；
/// - 其余 → 用保底下载器从 `.part` 续传到完成；
/// - 全部成功返回 true；任一失败返回 false（系统按退避重试）。
/// [overallTimeout]：后台任务总时长上限（安卓 worker 约 10 分钟），
/// 超时未跑完返回 false，剩下的下次再跑。
Future<bool> resumePendingDownloads({
  SharedPreferences? prefs,
  McFallbackDownloadManager? downloader,
  Duration overallTimeout = const Duration(minutes: 9),
}) async {
  final store = prefs ?? await SharedPreferences.getInstance();
  final manager = downloader ?? McFallbackDownloadManager();
  final raw = store.getString(offlineBackgroundTasksKey);
  if (raw == null || raw.isEmpty) return true;
  final List<dynamic> list;
  try {
    list = jsonDecode(raw) as List<dynamic>;
  } catch (_) {
    return true;
  }
  final pending = <McDownloadRequest>[];
  for (final e in list) {
    if (e is! Map<String, dynamic>) continue;
    final id = e['id']?.toString();
    final url = e['url']?.toString();
    final savePath = e['savePath']?.toString();
    if (id == null || url == null || savePath == null) continue;
    if (await File(savePath).exists()) continue;
    pending.add(McDownloadRequest(id: id, url: url, savePath: savePath));
  }
  if (pending.isEmpty) return true;
  // 每个任务跑到终结；单个失败记 false 但不抛，让其余任务跑完。
  // 总时长超限返回 false，剩下的下次再跑。
  try {
    final results = await Future.wait([
      for (final req in pending)
        _runToCompletion(manager, req).then(
              (_) => true,
              onError: (_) => false,
            ),
    ]).timeout(overallTimeout);
    return results.every((r) => r);
  } on TimeoutException {
    return false;
  }
}

/// 跑一个任务到终结（done 或 error）；失败抛错，交给调用方记 false。
Future<void> _runToCompletion(
    McFallbackDownloadManager manager, McDownloadRequest request) async {
  final terminal = Completer<void>();
  final sub = manager.watch(request.id).listen(
    (p) {
      if (p.done && p.error == null) {
        if (!terminal.isCompleted) terminal.complete();
      } else if (p.error != null) {
        if (!terminal.isCompleted) {
          terminal.completeError(StateError(p.error!));
        }
      }
    },
    onError: (Object e) {
      if (!terminal.isCompleted) terminal.completeError(e);
    },
  );
  await manager.start(request);
  try {
    await terminal.future;
  } finally {
    await sub.cancel();
  }
}
