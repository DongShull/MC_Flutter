import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'mc_api.dart';
import 'models.dart';

String _errMsg(Object e) => e is ApiException ? e.friendlyMessage : '$e';

/// 个人信息控制器：me / 改昵称 / 改密码 / 上传头像 / 退出登录，自动同步到 `appSession`。
class ProfileController extends Notifier<AsyncValue<McSession?>> {
  @override
  AsyncValue<McSession?> build() {
    Future.microtask(load);
    return const AsyncValue.loading();
  }

  SettingsApi get _api => ref.read(settingsApiProvider);

  Future<void> load() async {
    if (state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    try {
      final res = await _api.meWithRaw();
      await appSession.updateFromMeJson(res.raw);
      state = AsyncValue.data(res.session);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 改昵称；成功后同步到 `appSession.saveProfile(...)` 与本地视图。
  Future<String?> rename(String nickname) async {
    try {
      final updated = await _api.updateProfile(nickname);
      if (updated.isNotEmpty) {
        await appSession.updateFromMeJson(updated);
        state = AsyncValue.data(McSession.fromJson(updated));
      } else {
        await appSession.saveProfile(username: nickname);
        await load();
      }
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  /// 改密码；返回 null 表示成功。
  Future<String?> changePassword(
    String oldPw,
    String newPw, {
    bool signOutPaired = false,
  }) async {
    try {
      final updated = await _api.changePassword(
        oldPassword: oldPw,
        newPassword: newPw,
        signOutPaired: signOutPaired,
      );
      if (updated.isNotEmpty) {
        await appSession.updateFromMeJson(updated);
        state = AsyncValue.data(McSession.fromJson(updated));
      }
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  /// 上传头像并同步至 `appSession`。
  Future<String?> uploadAvatar(String filePath) async {
    try {
      final updated = await _api.uploadAvatar(filePath);
      if (updated.isNotEmpty) {
        await appSession.updateFromMeJson(updated);
        state = AsyncValue.data(McSession.fromJson(updated));
      } else {
        await load();
      }
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  /// 退出当前账号（走 `logoutCurrentAccount`，支持兄弟账号自动切换）。
  Future<SavedAccountRef?> logoutCurrentAccount() async {
    try {
      final next = await ref
          .read(sessionStoreProvider)
          .logoutCurrentAccount(autoSwitchSibling: true);
      return next;
    } finally {
      state = const AsyncValue.data(null);
    }
  }
}

final profileProvider =
    NotifierProvider<ProfileController, AsyncValue<McSession?>>(
  ProfileController.new,
);

/// 设备页控制器：列表 / 显示全部 / 改名 / 注销 / 清理预览与执行。
class DevicesState {
  const DevicesState({
    this.items = const [],
    this.showAll = false,
    this.busy = false,
  });

  final List<LoginDevice> items;
  final bool showAll;
  final bool busy;

  DevicesState copyWith({
    List<LoginDevice>? items,
    bool? showAll,
    bool? busy,
  }) =>
      DevicesState(
        items: items ?? this.items,
        showAll: showAll ?? this.showAll,
        busy: busy ?? this.busy,
      );
}

class DevicesController extends Notifier<AsyncValue<DevicesState>> {
  @override
  AsyncValue<DevicesState> build() {
    Future.microtask(() => load());
    return const AsyncValue.loading();
  }

  SettingsApi get _api => ref.read(settingsApiProvider);

  Future<void> load({bool? showAll, bool silent = false}) async {
    final all = showAll ?? state.valueOrNull?.showAll ?? false;
    if (!silent) {
      state = AsyncValue.data(
        DevicesState(
          showAll: all,
          busy: true,
          items: state.valueOrNull?.items ?? const [],
        ),
      );
    }
    try {
      final items = await _api.devices(all: all);
      state = AsyncValue.data(DevicesState(items: items, showAll: all));
    } catch (e, st) {
      if (!silent || state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> setShowAll(bool value) => load(showAll: value);

  Future<void> toggleShowAll() =>
      load(showAll: !(state.valueOrNull?.showAll ?? false));

  Future<String?> rename(String id, String name) async {
    try {
      await _api.renameDevice(id, name);
      await load();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  Future<String?> revoke(String id) async {
    try {
      await _api.revokeDevice(id);
      await load();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  /// dryRun=true 返回「将注销 N 台」预览；false 真跑后刷新。
  Future<Object?> cleanup(
    int inactiveDays, {
    bool? all,
    bool dryRun = true,
  }) async {
    final effectiveAll = all ?? state.valueOrNull?.showAll ?? false;
    try {
      final view = await _api.cleanupDevices(
        inactiveDays: inactiveDays,
        all: effectiveAll,
        dryRun: dryRun,
      );
      if (!dryRun) await load();
      return view;
    } catch (e) {
      return _errMsg(e);
    }
  }
}

final devicesProvider =
    NotifierProvider<DevicesController, AsyncValue<DevicesState>>(
  DevicesController.new,
);

/// 播放策略控制器：加载 + 乐观更新（失败回滚）+ 静默刷新进度。
class PlaybackController extends Notifier<AsyncValue<PlaybackPolicy?>> {
  @override
  AsyncValue<PlaybackPolicy?> build() {
    Future.microtask(load);
    return const AsyncValue.loading();
  }

  SettingsApi get _api => ref.read(settingsApiProvider);

  Future<void> load({bool silent = false}) async {
    if (!silent && state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    try {
      state = AsyncValue.data(await _api.playbackPolicy());
    } catch (e, st) {
      if (!silent || state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<String?> updatePolicy({
    bool? softwareTranscodeEnabled,
    double? playedThresholdPercent,
    bool? playedUseOutro,
    bool? trickplayEnabled,
    bool? transcodeCacheEnabled,
    bool? reelClipsEnabled,
    String? cloudStreamMode,
  }) async {
    final prev = state.valueOrNull;
    if (prev == null) return null;
    final optimistic = prev.copyWith(
      softwareTranscodeEnabled: softwareTranscodeEnabled,
      playedThresholdPercent: playedThresholdPercent,
      playedUseOutro: playedUseOutro,
      trickplayEnabled: trickplayEnabled,
      transcodeCacheEnabled: transcodeCacheEnabled,
      reelClipsEnabled: reelClipsEnabled,
      cloudStreamMode: cloudStreamMode,
    );
    state = AsyncValue.data(optimistic);
    try {
      final saved = await _api.updatePlaybackPolicy(
        prev.toPatch(
          softwareTranscodeEnabled: softwareTranscodeEnabled,
          playedThresholdPercent: playedThresholdPercent,
          playedUseOutro: playedUseOutro,
          trickplayEnabled: trickplayEnabled,
          transcodeCacheEnabled: transcodeCacheEnabled,
          reelClipsEnabled: reelClipsEnabled,
          cloudStreamMode: cloudStreamMode,
        ),
      );
      state = AsyncValue.data(saved);
      return null;
    } catch (e) {
      state = AsyncValue.data(prev);
      return _errMsg(e);
    }
  }
}

final playbackProvider =
    NotifierProvider<PlaybackController, AsyncValue<PlaybackPolicy?>>(
  PlaybackController.new,
);

/// 维护页控制器（保留兼容外部引用）。
class MaintenanceState {
  const MaintenanceState({
    this.status,
    this.pending,
    this.storage,
  });

  final UpdateStatus? status;
  final PendingUpdate? pending;
  final StorageState? storage;
}

class MaintenanceController extends Notifier<AsyncValue<MaintenanceState>> {
  @override
  AsyncValue<MaintenanceState> build() {
    Future.microtask(load);
    return const AsyncValue.loading();
  }

  SettingsApi get _api => ref.read(settingsApiProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final results = await Future.wait<Object?>([
        _api.updateStatus(),
        _api.pendingUpdate().catchError((_) => null),
        _api.storage().catchError((_) => const StorageState()),
      ]);
      state = AsyncValue.data(
        MaintenanceState(
          status: results[0] as UpdateStatus,
          pending: results[1] as PendingUpdate?,
          storage: results[2] as StorageState,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> clean(String key, {String mode = 'all'}) async {
    try {
      await _api.cleanStorage(key, mode: mode);
      final s = await _api.storage();
      final cur = state.valueOrNull ?? const MaintenanceState();
      state = AsyncValue.data(
        MaintenanceState(
          status: cur.status,
          pending: cur.pending,
          storage: s,
        ),
      );
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }

  Future<String?> restart() async {
    try {
      await _api.restartApp();
      return null;
    } catch (e) {
      return _errMsg(e);
    }
  }
}

final maintenanceProvider =
    NotifierProvider<MaintenanceController, AsyncValue<MaintenanceState>>(
  MaintenanceController.new,
);
