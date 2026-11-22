import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_error.dart';
import '../../../core/api/session_providers.dart';
import 'mc_api.dart';
import 'models.dart';

/// 个人信息控制器：me / 改昵称 / 改密码 / 退出登录。
class ProfileController extends Notifier<AsyncValue<McSession?>> {
  @override
  AsyncValue<McSession?> build() {
    Future.microtask(load);
    return const AsyncValue.loading();
  }

  SettingsApi get _api => ref.read(settingsApiProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _api.me());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 改昵称；成功后用返回的 me 刷新本地视图。
  Future<String?> rename(String nickname) async {
    try {
      await _api.updateProfile(nickname);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 改密码；返回 null 表示成功。
  Future<String?> changePassword(String oldPw, String newPw) async {
    try {
      await _api.changePassword(oldPassword: oldPw, newPassword: newPw);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 退出登录（清 token + 回登录页由调用方导航）。
  Future<void> logout() async {
    try {
      await ref.read(sessionStoreProvider).logout();
    } finally {
      state = const AsyncValue.data(null);
    }
  }
}

final profileProvider = NotifierProvider<ProfileController, AsyncValue<McSession?>>(
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

  Future<void> load({bool? showAll}) async {
    final all = showAll ?? state.valueOrNull?.showAll ?? false;
    state = AsyncValue.data(
        DevicesState(showAll: all, busy: true, items: state.valueOrNull?.items ?? const []));
    try {
      final items = await _api.devices(all: all);
      state = AsyncValue.data(DevicesState(items: items, showAll: all));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleShowAll() => load(showAll: !(state.valueOrNull?.showAll ?? false));

  Future<String?> rename(String id, String name) async {
    try {
      await _api.renameDevice(id, name);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> revoke(String id) async {
    try {
      await _api.revokeDevice(id);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// dryRun=true 返回「将注销 N 台」预览；false 真跑后刷新。
  Future<Object?> cleanup(int inactiveDays, {bool dryRun = true}) async {
    try {
      final view = await _api.cleanupDevices(inactiveDays: inactiveDays, dryRun: dryRun);
      if (!dryRun) await load();
      return view;
    } catch (e) {
      return e;
    }
  }
}

final devicesProvider =
    NotifierProvider<DevicesController, AsyncValue<DevicesState>>(DevicesController.new);

/// 播放策略控制器：加载 + 乐观更新（失败回滚）。
class PlaybackController extends Notifier<AsyncValue<PlaybackPolicy?>> {
  @override
  AsyncValue<PlaybackPolicy?> build() {
    Future.microtask(load);
    return const AsyncValue.loading();
  }

  SettingsApi get _api => ref.read(settingsApiProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _api.playbackPolicy());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setFlag({
    bool? softwareTranscodeEnabled,
    bool? trickplayEnabled,
    bool? transcodeCacheEnabled,
  }) async {
    final prev = state.valueOrNull;
    if (prev == null) return;
    final next = PlaybackPolicy(
      softwareTranscodeEnabled:
          softwareTranscodeEnabled ?? prev.softwareTranscodeEnabled,
      trickplayEnabled: trickplayEnabled ?? prev.trickplayEnabled,
      transcodeCacheEnabled: transcodeCacheEnabled ?? prev.transcodeCacheEnabled,
      hardwareAvailable: prev.hardwareAvailable,
      hwBackends: prev.hwBackends,
    );
    state = AsyncValue.data(next);
    try {
      await _api.updatePlaybackPolicy(prev.toPatch(
        softwareTranscodeEnabled: softwareTranscodeEnabled,
        trickplayEnabled: trickplayEnabled,
        transcodeCacheEnabled: transcodeCacheEnabled,
      ));
    } catch (_) {
      state = AsyncValue.data(prev); // 失败回滚
    }
  }
}

final playbackProvider =
    NotifierProvider<PlaybackController, AsyncValue<PlaybackPolicy?>>(PlaybackController.new);

/// 维护页控制器：版本 / 待更新 / 存储。
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
        _api.pendingUpdate(),
        _api.storage(),
      ]);
      state = AsyncValue.data(MaintenanceState(
        status: results[0] as UpdateStatus,
        pending: results[1] as PendingUpdate?,
        storage: results[2] as StorageState,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 清理一个登记目录后重算用量；返回错误文案或 null。
  Future<String?> clean(String key) async {
    try {
      await _api.cleanStorage(key);
      await _refreshStorage();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> restart() async {
    try {
      await _api.restartApp();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _refreshStorage() async {
    try {
      final s = await _api.storage();
      final cur = state.valueOrNull ?? const MaintenanceState();
      state = AsyncValue.data(MaintenanceState(
        status: cur.status,
        pending: cur.pending,
        storage: s,
      ));
    } catch (e) {
      McErrorLog.log(e, context: 'settings.loadStorage');
    }
  }
}

final maintenanceProvider = NotifierProvider<MaintenanceController,
    AsyncValue<MaintenanceState>>(MaintenanceController.new);
