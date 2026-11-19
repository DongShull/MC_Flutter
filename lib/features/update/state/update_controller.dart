import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mc_api.dart';
import 'models.dart';

/// 更新检查 UI 状态（对齐 AppUpdateController.State）。
sealed class UpdateUiState {
  const UpdateUiState();
}

class UpdateIdle extends UpdateUiState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateUiState {
  const UpdateChecking();
}

class UpdateUpToDate extends UpdateUiState {
  const UpdateUpToDate(this.latest);
  final ClientReleaseView latest;
}

class UpdateAvailable extends UpdateUiState {
  const UpdateAvailable(this.release, this.source);
  final ClientReleaseView release;
  final UpdateSource source;
}

class UpdateFailed extends UpdateUiState {
  const UpdateFailed(this.message);
  final String message;
}

/// 手动/自动检查控制器（对齐 AppUpdateController：
/// 先官网后服务器兜底；「跳过这个版本」记录在本地，自动检查不再提示同一版）。
class UpdateController extends Notifier<UpdateUiState> {
  static const _skippedKey = 'update.skipped.build';

  @override
  UpdateUiState build() => const UpdateIdle();

  /// 手动检查：不看跳过记录，结果是什么就报什么。
  Future<void> checkManually() => _check(force: true, respectSkip: false);

  /// 自动检查：一天最多一次，且用户跳过的版本不再打扰。
  Future<void> autoCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('update.last.check');
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastMs != null &&
        now - lastMs < UpdatePolicy.autoCheckInterval.inMilliseconds) {
      return;
    }
    await prefs.setInt('update.last.check', now);
    await _check(force: false, respectSkip: true);
  }

  Future<void> _check({required bool force, required bool respectSkip}) async {
    state = const UpdateChecking();
    try {
      final (release, source) =
          await ref.read(updateApiProvider).latest(force: force);
      int? skipped;
      if (respectSkip) {
        final prefs = await SharedPreferences.getInstance();
        skipped = prefs.getInt(_skippedKey);
      }
      if (!UpdatePolicy.shouldPrompt(release, UpdatePolicy.currentBuild, skipped)) {
        state = UpdateUpToDate(release);
      } else {
        state = UpdateAvailable(release, source);
      }
    } catch (e) {
      state = UpdateFailed(_friendly(e));
    }
  }

  /// 跳过这个版本（对齐「跳过此版本」）。
  Future<void> skipCurrent(int build) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_skippedKey, build);
    state = const UpdateIdle();
  }

  void dismiss() => state = const UpdateIdle();

  static String _friendly(Object e) => switch (e) {
        final String s => s,
        _ => '更新检查失败，请稍后再试',
      };
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateUiState>(UpdateController.new);