
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import 'models.dart';

/// offline 域复用全局 McClient 单例（统一走 McClient，对应 Kotlin McApi.kt offline 段）。
final offlineClientProvider = mcClientProvider;

/// 离线下载页 UI 状态。
class OfflineState {
  const OfflineState({
    this.units = const <DownloadUnit>[],
    this.allowCellular = false,
    this.storage,
    this.error,
  });

  final List<DownloadUnit> units;
  final bool allowCellular;
  final StorageInfo? storage;
  final String? error;

  OfflineState copyWith({
    List<DownloadUnit>? units,
    bool? allowCellular,
    StorageInfo? storage,
    String? error,
    bool clearError = false,
  }) =>
      OfflineState(
        units: units ?? this.units,
        allowCellular: allowCellular ?? this.allowCellular,
        storage: storage ?? this.storage,
        error: clearError ? null : (error ?? this.error),
      );

  /// 下载中的单元（含排队 / 等 Wi-Fi），按优先级排序。
  List<DownloadUnit> get activeUnits {
    final active = units.where((u) => u.isActive).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return active;
  }

  /// 已完成的单元。
  List<DownloadUnit> get doneUnits =>
      units.where((u) => u.status == OfflineUnitStatus.done).toList();

  /// 首页提示条口径：总速度。
  int get activeSpeedTotal => units.fold(
      0, (sum, u) => sum + (u.status == OfflineUnitStatus.running ? u.speedBps : 0));
}

/// 离线下载控制器：本机状态机 1:1（排队/下载中/暂停/等 Wi-Fi/完成/失败 + 优先级）。
/// 真实字节搬运走平台通道，见 TODO。
class OfflineController extends Notifier<OfflineState> {
  static const _cellularKey = 'offline_allow_cellular';

  /// 磁盘预留（对齐 Kotlin OFFLINE_RESERVE_BYTES ≈ 2GB）。
  static const reserveBytes = 2 * 1024 * 1024 * 1024;

  @override
  OfflineState build() {
    _restorePrefs();
    return const OfflineState();
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      allowCellular: prefs.getBool(_cellularKey) ?? false,
    );
  }

  /// 「使用蜂窝网络下载」开关（设置菜单 + waitingForWiFi 提示条共用）。
  Future<void> setAllowCellular(bool value) async {
    state = state.copyWith(allowCellular: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cellularKey, value);
    // 打开后，等待 Wi-Fi 的单元恢复排队；关闭则排队中的转回等 Wi-Fi。
    if (value) {
      _patchAll(OfflineUnitStatus.waitingWifi, OfflineUnitStatus.queued);
    } else {
      _patchAll(OfflineUnitStatus.queued, OfflineUnitStatus.waitingWifi);
    }
  }

  void _patchAll(OfflineUnitStatus from, OfflineUnitStatus to) {
    state = state.copyWith(
      units: state.units
          .map((u) => u.status == from ? u.copyWith(status: to) : u)
          .toList(),
    );
  }

  /// GET /api/v1/offline/manifest?file_id=：取某文件的离线清单。
  Future<OfflineManifest> manifest(String fileId) async {
    final body = await ref.read(offlineClientProvider).unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/offline/manifest',
          query: {'file_id': fileId},
        );
    return OfflineManifest.fromJson(body);
  }

  /// POST /api/v1/offline/profiles：按 500 一批提交所选档位（对齐 Kotlin 分 chunk）。
  Future<int> requestProfiles(
    String fileId,
    List<String> profileIds, {
    String scope = 'single',
  }) async {
    var accepted = 0;
    for (var i = 0; i < profileIds.length; i += 500) {
      final end = i + 500 > profileIds.length ? profileIds.length : i + 500;
      final chunk = profileIds.sublist(i, end);
      await ref.read(offlineClientProvider).unwrap<Map<String, dynamic>>(
            Channel.general,
            'POST',
            '/api/v1/offline/profiles',
            body: {'file_id': fileId, 'scope': scope, 'profiles': chunk},
          );
      accepted += chunk.length;
    }
    return accepted;
  }

  /// 开始下载（对齐 start：lead 文件 manifest -> 逐集 enqueue ->
  /// 反馈「已开始下载 N 集，M 集没能开始」）。实际字节搬运为平台通道 TODO。
  Future<String> startDownload(DownloadCandidate candidate) async {
    try {
      final data = await manifest(candidate.fileId);
      final count = data.episodes.isEmpty ? 1 : data.episodes.length;
      final now = DateTime.now().microsecondsSinceEpoch;
      final units = <DownloadUnit>[
        ...state.units,
        for (var i = 0; i < count; i++)
          DownloadUnit(
            id: '${candidate.fileId}-$now-$i',
            title: candidate.title,
            seasonEpisode:
                data.episodes.isEmpty ? null : '第 ${i + 1} 集',
            profileLabel: candidate.profiles.first.label,
          ),
      ];
      state = state.copyWith(units: units, clearError: true);
      return '已开始下载 $count 集';
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return '下载没能开始';
    }
  }

  /// 暂停 | 继续（对齐长按菜单）。
  void toggle(DownloadUnit unit) {
    final next = unit.status == OfflineUnitStatus.running
        ? OfflineUnitStatus.paused
        : OfflineUnitStatus.queued;
    _patch(unit.id, (u) => u.copyWith(status: next, speedBps: 0));
  }

  /// 取消下载。
  void cancel(DownloadUnit unit) {
    state = state.copyWith(
      units: state.units.where((u) => u.id != unit.id).toList(),
    );
  }

  /// 优先下载（提到最前 = 最高优先级）。
  void prioritize(DownloadUnit unit) {
    var top = 0;
    for (final u in state.units) {
      if (u.priority > top) top = u.priority;
    }
    _patch(unit.id, (u) => u.copyWith(priority: top + 1));
  }

  /// 拖动排序（对齐 Kotlin 拖动 -> 优先级）。
  void reorder(int oldIndex, int newIndex) {
    final active = state.activeUnits;
    if (oldIndex >= active.length) return;
    final moved = active[oldIndex];
    final order = [...active]..removeAt(oldIndex);
    var target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (target > order.length) target = order.length;
    if (target < 0) target = 0;
    order.insert(target, moved);
    final priorities = <String, int>{
      for (final pair in order.indexed) pair.$2.id: order.length - pair.$1,
    };
    state = state.copyWith(
      units: state.units
          .map((u) =>
              priorities.containsKey(u.id) && u.isActive
                  ? u.copyWith(priority: priorities[u.id]!)
                  : u)
          .toList(),
    );
  }

  /// 删除一个已下载副本（长按 / 建议卡）。只删本机副本，不动观看进度。
  void deleteDownloaded(DownloadUnit unit) {
    state = state.copyWith(
      units: state.units.where((u) => u.id != unit.id).toList(),
    );
  }

  /// 更新容量（实际数字由平台通道返回，先占位 TODO）。
  void updateStorage(StorageInfo info) {
    state = state.copyWith(storage: info);
  }

  void _patch(String id, DownloadUnit Function(DownloadUnit) fn) {
    state = state.copyWith(
      units: state.units.map((u) => u.id == id ? fn(u) : u).toList(),
    );
  }
}

final offlineProvider =
    NotifierProvider<OfflineController, OfflineState>(OfflineController.new);
