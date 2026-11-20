import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/player/session/playback_session_api.dart';
import '../../../core/platform/download_channel.dart';
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

/// 一条持久化下载任务（断点续传跨重启的关键：url + savePath 稳定，
/// 保底实现靠 <savePath>.part / .part.meta 从已收字节处继续）。
class _StoredTask {
  _StoredTask({
    required this.id,
    required this.title,
    required this.url,
    required this.savePath,
    this.seasonEpisode,
    required this.profileLabel,
    this.priority = 0,
  });

  final String id;
  final String title;
  final String url;
  final String savePath;
  final String? seasonEpisode;
  final String profileLabel;
  int priority;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'savePath': savePath,
        if (seasonEpisode != null) 'seasonEpisode': seasonEpisode,
        'profileLabel': profileLabel,
        'priority': priority,
      };

  factory _StoredTask.fromJson(Map<String, dynamic> json) => _StoredTask(
        id: json['id'].toString(),
        title: json['title'].toString(),
        url: json['url'].toString(),
        savePath: json['savePath'].toString(),
        seasonEpisode: json['seasonEpisode']?.toString(),
        profileLabel: json['profileLabel'].toString(),
        priority: ((json['priority'] ?? 0) as num).toInt(),
      );
}

/// 离线下载控制器：本机状态机 1:1（排队/下载中/暂停/等 Wi-Fi/完成/失败 + 优先级）。
/// 字节搬运走 core/platform/download_channel.dart（原生 mc/native/download 通道，
/// 原生未实现时纯 Dart 分块下载保底，Range 断点续传跨重启）。
class OfflineController extends Notifier<OfflineState> {
  static const _cellularKey = 'offline_allow_cellular';
  static const _tasksKey = 'offline_tasks_v2';

  /// 磁盘预留（对齐 Kotlin OFFLINE_RESERVE_BYTES ≈ 2GB）。
  static const reserveBytes = 2 * 1024 * 1024 * 1024;

  final Map<String, _StoredTask> _tasks = {};
  final Map<String, StreamSubscription<McDownloadProgress>> _subs = {};
  final Map<String, ({int bytes, DateTime at})> _lastTick = {};

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
    await _restoreTasks();
    // 容量走原生通道（拿不到就保持占位）。
    unawaited(refreshStorage());
  }

  /// 重启恢复：已落盘的副本 → done；没下完的 → 排队并自动续传（
  /// 通道保底实现带 Range，从 .part 已收字节处继续）。
  Future<void> _restoreTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tasksKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => _StoredTask.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isEmpty) return;
      final restored = <DownloadUnit>[];
      final pending = <_StoredTask>[];
      for (final t in list) {
        final file = File(t.savePath);
        final finished = await file.exists();
        restored.add(DownloadUnit(
          id: t.id,
          title: t.title,
          seasonEpisode: t.seasonEpisode,
          profileLabel: t.profileLabel,
          status: finished ? OfflineUnitStatus.done : OfflineUnitStatus.queued,
          priority: t.priority,
        ));
        _tasks[t.id] = t;
        if (!finished) pending.add(t);
      }
      state = state.copyWith(units: [...restored, ...state.units]);
      for (final t in pending) {
        await _launch(t);
      }
    } catch (_) {
      // 恢复失败不阻塞页面：当作没有历史任务。
    }
  }

  Future<void> _persistTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode([
      for (final t in _tasks.values) t.toJson(),
    ]);
    await prefs.setString(_tasksKey, encoded);
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

  /// 开始下载：lead 文件 manifest -> 逐集开会话拿 streamUrl -> 走下载通道搬运字节。
  /// 反馈口径对齐 Kotlin：「已开始下载 N 集」/「…，M 集没能开始」。
  Future<String> startDownload(DownloadCandidate candidate) async {
    try {
      final data = await manifest(candidate.fileId);
      final fileIds = _resolveFileIds(candidate.fileId, data.episodes);
      final dir = await McDownloadPaths.resolve();
      final now = DateTime.now().microsecondsSinceEpoch;
      var started = 0;
      var failedCount = 0;
      final newUnits = <DownloadUnit>[];
      for (var i = 0; i < fileIds.length; i++) {
        final id = 'dl-${fileIds[i]}-$now-$i';
        final label = data.episodes.isEmpty ? null : '第 ${i + 1} 集';
        final url = await _resolveStreamUrl(fileIds[i], candidate.profiles);
        if (url == null) {
          failedCount++;
          continue;
        }
        final task = _StoredTask(
          id: id,
          title: candidate.title,
          url: url,
          savePath: '${dir.path}/$id.mp4',
          seasonEpisode: label,
          profileLabel: candidate.profiles.first.label,
        );
        _tasks[id] = task;
        newUnits.add(DownloadUnit(
          id: id,
          title: candidate.title,
          seasonEpisode: label,
          profileLabel: task.profileLabel,
        ));
        started++;
      }
      if (newUnits.isNotEmpty) {
        state = state.copyWith(
          units: [...state.units, ...newUnits],
          clearError: true,
        );
        await _persistTasks();
        for (final u in newUnits) {
          final task = _tasks[u.id];
          if (task != null) await _launch(task);
        }
      }
      if (failedCount > 0) {
        state = state.copyWith(
          error: '已开始下载 $started 集，$failedCount 集没能开始',
        );
        return '已开始下载 $started 集，$failedCount 集没能开始';
      }
      return '已开始下载 $started 集';
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return '下载没能开始';
    }
  }

  /// manifest 的 episodes 是 file id 列表；解析不出就用 lead 文件本身。
  List<String> _resolveFileIds(String leadId, List<String> episodes) {
    final ids = <String>[];
    for (final e in episodes) {
      final normalized = int.tryParse(e) != null ? e : null;
      if (normalized != null) ids.add(normalized);
    }
    return ids.isEmpty ? <String>[leadId] : ids;
  }

  /// 开播放会话（download capability）换直链 streamUrl；拿不到返回 null。
  Future<String?> _resolveStreamUrl(
    String fileId,
    List<DownloadProfile> profiles,
  ) async {
    try {
      final id = int.tryParse(fileId);
      if (id == null) return null;
      final api = PlaybackSessionApi(ref.read(offlineClientProvider));
      final session = await api.start(
        fileId: id,
        capability: {
          'is_mobile': true,
          'native_hls': false,
          'universal': true,
          'download': true,
          'tier': profiles.first.id,
        },
      );
      return session.playable ? session.streamUrl : null;
    } catch (_) {
      return null;
    }
  }

  /// 启动一个任务：订阅进度流 + 调通道 start（保底实现自动从 .part 续传）。
  Future<void> _launch(_StoredTask task) async {
    if (_subs.containsKey(task.id)) return;
    _lastTick[task.id] = (bytes: 0, at: DateTime.now());
    _subs[task.id] = McDownloadChannel.progress(task.id).listen(
      (p) => _onProgress(task, p),
      onError: (Object e) => _onFailed(task, e.toString()),
    );
    _patch(task.id, (u) => u.copyWith(status: OfflineUnitStatus.running));
    await McDownloadChannel.start(McDownloadRequest(
      id: task.id,
      url: task.url,
      savePath: task.savePath,
      headers: const {},
    ));
  }

  void _onProgress(_StoredTask task, McDownloadProgress p) {
    if (p.error != null) {
      _onFailed(task, p.error!);
      return;
    }
    final prev = _lastTick[task.id];
    var speed = 0;
    final now = DateTime.now();
    if (prev != null) {
      final dt = now.difference(prev.at).inMilliseconds;
      if (dt > 200) {
        speed = ((p.receivedBytes - prev.bytes) * 1000 / dt).round();
        _lastTick[task.id] = (bytes: p.receivedBytes, at: now);
      } else {
        speed = _unit(task.id)?.speedBps ?? 0;
      }
    } else {
      _lastTick[task.id] = (bytes: p.receivedBytes, at: now);
    }
    if (p.done) {
      _subs.remove(task.id)?.cancel();
      _lastTick.remove(task.id);
      _patch(task.id, (u) => u.copyWith(
            status: OfflineUnitStatus.done,
            progress: 1,
            speedBps: 0,
          ));
      return;
    }
    final ratio = p.ratio;
    _patch(task.id, (u) => u.copyWith(
          status: OfflineUnitStatus.running,
          progress: ratio ?? u.progress,
          speedBps: speed < 0 ? 0 : speed,
        ));
  }

  void _onFailed(_StoredTask task, String message) {
    _subs.remove(task.id)?.cancel();
    _lastTick.remove(task.id);
    _patch(task.id, (u) => u.copyWith(
          status: OfflineUnitStatus.failed,
          speedBps: 0,
        ));
    state = state.copyWith(error: message);
  }

  DownloadUnit? _unit(String id) {
    for (final u in state.units) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// 暂停 | 继续（对齐长按菜单）。继续 = 再 start，通道保底实现自动断点续传。
  Future<void> toggle(DownloadUnit unit) async {
    final task = _tasks[unit.id];
    if (unit.status == OfflineUnitStatus.running) {
      await McDownloadChannel.pause(unit.id);
      _patch(unit.id, (u) => u.copyWith(status: OfflineUnitStatus.paused, speedBps: 0));
      return;
    }
    if (task != null) {
      if (await File(task.savePath).exists()) {
        // 已完成的副本不重复下。
        _patch(unit.id, (u) => u.copyWith(status: OfflineUnitStatus.done));
        return;
      }
      _patch(unit.id, (u) => u.copyWith(status: OfflineUnitStatus.queued));
      await _launch(task);
    } else {
      _patch(unit.id, (u) => u.copyWith(status: OfflineUnitStatus.queued, speedBps: 0));
    }
  }

  /// 取消下载：停任务 + 删半成品 + 移除条目。
  Future<void> cancel(DownloadUnit unit) async {
    await McDownloadChannel.cancel(unit.id);
    _subs.remove(unit.id)?.cancel();
    _lastTick.remove(unit.id);
    final task = _tasks.remove(unit.id);
    if (task != null) {
      await McDownloadChannel.removePartial(task.savePath);
      final file = File(task.savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // 删不掉（被占用等）先留着，列表已移除。
        }
      }
      await _persistTasks();
    }
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
    final task = _tasks[unit.id];
    if (task != null) {
      task.priority = top + 1;
      unawaited(_persistTasks());
    }
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
    var dirty = false;
    for (final entry in priorities.entries) {
      final task = _tasks[entry.key];
      if (task != null && task.priority != entry.value) {
        task.priority = entry.value;
        dirty = true;
      }
    }
    if (dirty) unawaited(_persistTasks());
  }

  /// 删除一个已下载副本（长按 / 建议卡）。只删本机副本，不动观看进度。
  Future<void> deleteDownloaded(DownloadUnit unit) async {
    final task = _tasks.remove(unit.id);
    if (task != null) {
      final file = File(task.savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // 留给下次清理。
        }
      }
      await _persistTasks();
    }
    state = state.copyWith(
      units: state.units.where((u) => u.id != unit.id).toList(),
    );
  }

  /// 更新容量（实际数字由平台通道返回，先占位 TODO）。
  void updateStorage(StorageInfo info) {
    state = state.copyWith(storage: info);
  }

  /// 从原生通道（mc/native/download 的 capacity）刷新本机容量展示。
  /// 原生未实现（MissingPluginException / 非 Android 平台）时保持占位：
  /// storage 维持 null，页面继续显示占位文案。
  Future<void> refreshStorage() async {
    try {
      final cap = await McDownloadChannel.capacity();
      if (cap == null) return;
      state = state.copyWith(
        storage: StorageInfo(
          availableBytes: cap.freeBytes,
          totalBytes: cap.totalBytes,
        ),
      );
    } catch (_) {
      // 拿不到真实容量就走占位，不阻塞页面。
    }
  }

  void _patch(String id, DownloadUnit Function(DownloadUnit) fn) {
    state = state.copyWith(
      units: state.units.map((u) => u.id == id ? fn(u) : u).toList(),
    );
  }
}

final offlineProvider =
    NotifierProvider<OfflineController, OfflineState>(OfflineController.new);
