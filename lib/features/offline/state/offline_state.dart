import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/platform/download_channel.dart';
import '../../../core/player/session/playback_session_api.dart';
import 'models.dart';

final offlineClientProvider = mcClientProvider;

/// 离线下载页 UI 状态。
class OfflineState {
  const OfflineState({
    this.units = const <DownloadUnit>[],
    this.otherOwnersBytes = 0,
    this.otherOwnersCount = 0,
    this.allowCellular = false,
    this.storage,
    this.error,
  });

  final List<DownloadUnit> units;
  final int otherOwnersBytes;
  final int otherOwnersCount;
  final bool allowCellular;
  final StorageInfo? storage;
  final String? error;

  OfflineState copyWith({
    List<DownloadUnit>? units,
    int? otherOwnersBytes,
    int? otherOwnersCount,
    bool? allowCellular,
    StorageInfo? storage,
    String? error,
    bool clearError = false,
  }) =>
      OfflineState(
        units: units ?? this.units,
        otherOwnersBytes: otherOwnersBytes ?? this.otherOwnersBytes,
        otherOwnersCount: otherOwnersCount ?? this.otherOwnersCount,
        allowCellular: allowCellular ?? this.allowCellular,
        storage: storage ?? this.storage,
        error: clearError ? null : (error ?? this.error),
      );

  List<DownloadUnit> get activeUnits {
    final active = units.where((u) => u.isActive).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return active;
  }

  List<DownloadUnit> get doneUnits =>
      units.where((u) => u.status == OfflineUnitStatus.done).toList();

  List<DownloadUnit> get watchedUnits =>
      doneUnits.where((u) => u.watched).toList();

  int get activeSpeedTotal => units.fold(
        0,
        (sum, u) =>
            sum + (u.status == OfflineUnitStatus.running ? u.speedBps : 0),
      );
}

class _StoredTask {
  _StoredTask({
    required this.id,
    required this.ownerKey,
    required this.fileId,
    required this.title,
    required this.url,
    required this.savePath,
    this.seasonEpisode,
    required this.profileLabel,
    this.priority = 0,
    this.watched = false,
  });

  final String id;
  final String ownerKey;
  final String fileId;
  final String title;
  final String url;
  final String savePath;
  final String? seasonEpisode;
  final String profileLabel;
  int priority;
  bool watched;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerKey': ownerKey,
        'fileId': fileId,
        'title': title,
        'url': url,
        'savePath': savePath,
        if (seasonEpisode != null) 'seasonEpisode': seasonEpisode,
        'profileLabel': profileLabel,
        'priority': priority,
        'watched': watched,
      };

  factory _StoredTask.fromJson(Map<String, dynamic> json) => _StoredTask(
        id: json['id'].toString(),
        ownerKey: (json['ownerKey'] ?? '').toString(),
        fileId: (json['fileId'] ?? '').toString(),
        title: json['title'].toString(),
        url: json['url'].toString(),
        savePath: json['savePath'].toString(),
        seasonEpisode: json['seasonEpisode']?.toString(),
        profileLabel: json['profileLabel'].toString(),
        priority: ((json['priority'] ?? 0) as num).toInt(),
        watched: json['watched'] == true,
      );
}

/// 真离线下载与本地播放状态机：
/// - 跨重启断点续传 + 鉴权 Header 透传；
/// - 本地 `file://` URI 零网络起播；
/// - 已看完离线副本标记与一键清理释放空间 + 联网补传观看记录（`POST /api/v1/playback/viewings`）；
/// - 账号隔离与跨账号离线占用清理。
class OfflineController extends Notifier<OfflineState> {
  static const _cellularKey = 'offline_allow_cellular';
  static const _tasksKey = 'offline_tasks_v2';
  static const reserveBytes = 2 * 1024 * 1024 * 1024;

  final Map<String, _StoredTask> _allTasks = {};
  final Map<String, StreamSubscription<McDownloadProgress>> _subs = {};
  final Map<String, ({int bytes, DateTime at})> _lastTick = {};

  String get _currentOwner {
    final s = ref.read(sessionStoreProvider);
    return '${s.baseUrl ?? ''}|${s.username}';
  }

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
    unawaited(refreshStorage());
  }

  Future<void> _restoreTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tasksKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map((e) => _StoredTask.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (list.isEmpty) return;
      final owner = _currentOwner;
      final restored = <DownloadUnit>[];
      final pending = <_StoredTask>[];
      var otherBytes = 0;
      var otherCount = 0;

      for (final t in list) {
        _allTasks[t.id] = t;
        final file = File(t.savePath);
        final finished = await file.exists();
        final belongsToCurrent =
            t.ownerKey.isEmpty || t.ownerKey == owner || owner == '|';
        if (!belongsToCurrent) {
          if (finished) {
            otherCount++;
            otherBytes += await file.length();
          }
          continue;
        }
        restored.add(
          DownloadUnit(
            id: t.id,
            title: t.title,
            seasonEpisode: t.seasonEpisode,
            profileLabel: t.profileLabel,
            status: finished ? OfflineUnitStatus.done : OfflineUnitStatus.queued,
            priority: t.priority,
            savePath: t.savePath,
            watched: t.watched,
          ),
        );
        if (!finished) pending.add(t);
      }
      state = state.copyWith(
        units: restored,
        otherOwnersBytes: otherBytes,
        otherOwnersCount: otherCount,
      );
      for (final t in pending) {
        await _launch(t);
      }
    } catch (_) {}
  }

  Future<void> _persistTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode([
      for (final t in _allTasks.values) t.toJson(),
    ]);
    await prefs.setString(_tasksKey, encoded);
  }

  String? localPlayUri(DownloadUnit unit) {
    final p = unit.savePath ?? _allTasks[unit.id]?.savePath;
    if (p == null || p.isEmpty) return null;
    return File(p).uri.toString();
  }

  /// 标记离线副本已看完，并在在线时同步一条观看记录到服务端。
  Future<void> markUnitWatched(DownloadUnit unit, {bool watched = true}) async {
    final task = _allTasks[unit.id];
    if (task != null) {
      task.watched = watched;
      await _persistTasks();
      final fid = int.tryParse(task.fileId);
      if (watched && fid != null) {
        unawaited(
          ref
              .read(offlineClientProvider)
              .unwrap<dynamic>(
                Channel.general,
                'POST',
                '/api/v1/playback/viewings',
                body: {
                  'items': [
                    {
                      'file_id': fid,
                      'completed': true,
                      'watched_at': DateTime.now().toUtc().toIso8601String(),
                    },
                  ],
                },
              )
              .catchError((_) => null),
        );
      }
    }
    _patch(unit.id, (u) => u.copyWith(watched: watched));
  }

  /// 一键清理所有已看完的离线副本。
  Future<int> clearWatchedDownloads() async {
    final watched = state.watchedUnits;
    for (final u in watched) {
      await deleteDownloaded(u);
    }
    return watched.length;
  }

  /// 一键清理本机其他账号遗留的离线下载文件。
  Future<void> clearOtherOwnersDownloads() async {
    final owner = _currentOwner;
    final toRemove = _allTasks.values
        .where((t) => t.ownerKey.isNotEmpty && t.ownerKey != owner)
        .toList();
    for (final t in toRemove) {
      _allTasks.remove(t.id);
      final f = File(t.savePath);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    await _persistTasks();
    state = state.copyWith(otherOwnersBytes: 0, otherOwnersCount: 0);
  }

  Future<void> setAllowCellular(bool value) async {
    state = state.copyWith(allowCellular: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cellularKey, value);
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

  Future<OfflineManifest> manifest(String fileId) async {
    final body = await ref
        .read(offlineClientProvider)
        .unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/offline/manifest',
          query: {'file_id': fileId},
        );
    return OfflineManifest.fromJson(body);
  }

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

  Future<String> startDownload(DownloadCandidate candidate) async {
    try {
      List<String> fileIds;
      if (candidate.fullSeasonSelected && candidate.seasonFileIds.isNotEmpty) {
        fileIds = candidate.seasonFileIds;
      } else {
        try {
          final data = await manifest(candidate.fileId);
          fileIds = candidate.fullSeasonSelected
              ? _resolveFileIds(candidate.fileId, data.episodes)
              : <String>[candidate.fileId];
        } catch (_) {
          fileIds = <String>[candidate.fileId];
        }
      }
      final dir = await McDownloadPaths.resolve();
      final now = DateTime.now().microsecondsSinceEpoch;
      final owner = _currentOwner;
      var started = 0;
      var failedCount = 0;
      final newUnits = <DownloadUnit>[];
      for (var i = 0; i < fileIds.length; i++) {
        final id = 'dl-${fileIds[i]}-$now-$i';
        final label = fileIds.length > 1 ? '第 ${i + 1} 集' : candidate.subtitle;
        final url = await _resolveStreamUrl(fileIds[i], candidate.profiles);
        if (url == null) {
          failedCount++;
          continue;
        }
        final savePath = '${dir.path}/$id.mp4';
        final task = _StoredTask(
          id: id,
          ownerKey: owner,
          fileId: fileIds[i],
          title: candidate.title,
          url: url,
          savePath: savePath,
          seasonEpisode: label,
          profileLabel: candidate.profiles.first.label,
        );
        _allTasks[id] = task;
        newUnits.add(
          DownloadUnit(
            id: id,
            title: candidate.title,
            seasonEpisode: label,
            profileLabel: task.profileLabel,
            savePath: savePath,
          ),
        );
        started++;
      }
      if (newUnits.isNotEmpty) {
        state = state.copyWith(
          units: [...state.units, ...newUnits],
          clearError: true,
        );
        await _persistTasks();
        for (final u in newUnits) {
          final task = _allTasks[u.id];
          if (task != null) await _launch(task);
        }
      }
      if (failedCount > 0) {
        state = state.copyWith(
          error: '已开始下载 $started 项，$failedCount 项没能开始',
        );
        return '已开始下载 $started 项，$failedCount 项没能开始';
      }
      return '已加入离线缓存队列（$started 项）';
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return '下载没能开始：$e';
    }
  }

  List<String> _resolveFileIds(String leadId, List<String> episodes) {
    final ids = <String>[];
    for (final e in episodes) {
      final normalized = int.tryParse(e) != null ? e : null;
      if (normalized != null) ids.add(normalized);
    }
    return ids.isEmpty ? <String>[leadId] : ids;
  }

  Future<String?> _resolveStreamUrl(
    String fileId,
    List<DownloadProfile> profiles,
  ) async {
    try {
      final id = int.tryParse(fileId);
      if (id == null) return null;
      final client = ref.read(offlineClientProvider);
      final api = PlaybackSessionApi(client);
      final session = await api.start(
        fileId: id,
        maxTier: profiles.first.id,
        capability: {
          'is_mobile': true,
          'native_hls': false,
          'universal': true,
          'download': true,
          'tier': profiles.first.id,
        },
      );
      if (!session.playable || session.streamUrl == null) return null;
      final raw = session.streamUrl!;
      if (raw.startsWith('/')) {
        final origin = ServerRoutes.instance.currentOrigin(client.baseUrl);
        return '$origin$raw';
      }
      return raw;
    } catch (_) {
      return null;
    }
  }

  Future<void> _launch(_StoredTask task) async {
    if (_subs.containsKey(task.id)) return;
    _lastTick[task.id] = (bytes: 0, at: DateTime.now());
    _subs[task.id] = McDownloadChannel.progress(task.id).listen(
      (p) => _onProgress(task, p),
      onError: (Object e) => _onFailed(task, e.toString()),
    );
    _patch(task.id, (u) => u.copyWith(status: OfflineUnitStatus.running));
    await McDownloadChannel.start(
      McDownloadRequest(
        id: task.id,
        url: task.url,
        savePath: task.savePath,
        headers: mcImageHeaders(),
      ),
    );
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
      _patch(
        task.id,
        (u) => u.copyWith(
          status: OfflineUnitStatus.done,
          progress: 1,
          speedBps: 0,
        ),
      );
      return;
    }
    final ratio = p.ratio;
    _patch(
      task.id,
      (u) => u.copyWith(
        status: OfflineUnitStatus.running,
        progress: ratio ?? u.progress,
        speedBps: speed < 0 ? 0 : speed,
      ),
    );
  }

  void _onFailed(_StoredTask task, String message) {
    _subs.remove(task.id)?.cancel();
    _lastTick.remove(task.id);
    _patch(
      task.id,
      (u) => u.copyWith(
        status: OfflineUnitStatus.failed,
        speedBps: 0,
      ),
    );
    state = state.copyWith(error: message);
  }

  DownloadUnit? _unit(String id) {
    for (final u in state.units) {
      if (u.id == id) return u;
    }
    return null;
  }

  Future<void> toggle(DownloadUnit unit) async {
    final task = _allTasks[unit.id];
    if (unit.status == OfflineUnitStatus.running) {
      await McDownloadChannel.pause(unit.id);
      _patch(
        unit.id,
        (u) => u.copyWith(status: OfflineUnitStatus.paused, speedBps: 0),
      );
      return;
    }
    if (task != null) {
      if (await File(task.savePath).exists()) {
        _patch(unit.id, (u) => u.copyWith(status: OfflineUnitStatus.done));
        return;
      }
      _patch(unit.id, (u) => u.copyWith(status: OfflineUnitStatus.queued));
      await _launch(task);
    } else {
      _patch(
        unit.id,
        (u) => u.copyWith(status: OfflineUnitStatus.queued, speedBps: 0),
      );
    }
  }

  Future<void> cancel(DownloadUnit unit) async {
    await McDownloadChannel.cancel(unit.id);
    _subs.remove(unit.id)?.cancel();
    _lastTick.remove(unit.id);
    final task = _allTasks.remove(unit.id);
    if (task != null) {
      await McDownloadChannel.removePartial(task.savePath);
      final file = File(task.savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await _persistTasks();
    }
    state = state.copyWith(
      units: state.units.where((u) => u.id != unit.id).toList(),
    );
  }

  void prioritize(DownloadUnit unit) {
    var top = 0;
    for (final u in state.units) {
      if (u.priority > top) top = u.priority;
    }
    _patch(unit.id, (u) => u.copyWith(priority: top + 1));
    final task = _allTasks[unit.id];
    if (task != null) {
      task.priority = top + 1;
      unawaited(_persistTasks());
    }
  }

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
          .map(
            (u) => priorities.containsKey(u.id) && u.isActive
                ? u.copyWith(priority: priorities[u.id]!)
                : u,
          )
          .toList(),
    );
    var dirty = false;
    for (final entry in priorities.entries) {
      final task = _allTasks[entry.key];
      if (task != null && task.priority != entry.value) {
        task.priority = entry.value;
        dirty = true;
      }
    }
    if (dirty) unawaited(_persistTasks());
  }

  Future<void> deleteDownloaded(DownloadUnit unit) async {
    final task = _allTasks.remove(unit.id);
    if (task != null) {
      final file = File(task.savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await _persistTasks();
    }
    state = state.copyWith(
      units: state.units.where((u) => u.id != unit.id).toList(),
    );
  }

  Future<Map<String, int>> downloadedFileBytes() async {
    final out = <String, int>{};
    for (final u in state.doneUnits) {
      final path = u.savePath ?? _allTasks[u.id]?.savePath;
      if (path == null) continue;
      final file = File(path);
      if (await file.exists()) {
        out[u.id] = await file.length();
      }
    }
    return out;
  }

  void updateStorage(StorageInfo info) {
    state = state.copyWith(storage: info);
  }

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
    } catch (_) {}
  }

  void _patch(String id, DownloadUnit Function(DownloadUnit) fn) {
    state = state.copyWith(
      units: state.units.map((u) => u.id == id ? fn(u) : u).toList(),
    );
  }
}

final offlineProvider =
    NotifierProvider<OfflineController, OfflineState>(OfflineController.new);
