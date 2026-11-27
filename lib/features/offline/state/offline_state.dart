import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/platform/download_channel.dart';
import 'models.dart';
import 'offline_packager.dart';
import 'offline_viewings.dart';

final offlineClientProvider = mcClientProvider;

/// 离线下载页 UI 状态。
class OfflineState {
  const OfflineState({
    this.units = const <DownloadUnit>[],
    this.items = const <int, OfflineItemSummary>{},
    this.progressByItem = const <int, Map<String, OfflineProgress>>{},
    this.otherOwnersBytes = 0,
    this.otherOwnersCount = 0,
    this.allowCellular = false,
    this.lastProfile,
    this.storage,
    this.error,
    this.loaded = false,
  });

  final List<DownloadUnit> units;
  final Map<int, OfflineItemSummary> items;
  final Map<int, Map<String, OfflineProgress>> progressByItem;
  final int otherOwnersBytes;
  final int otherOwnersCount;
  final bool allowCellular;
  final String? lastProfile;
  final StorageInfo? storage;
  final String? error;
  final bool loaded;

  OfflineState copyWith({
    List<DownloadUnit>? units,
    Map<int, OfflineItemSummary>? items,
    Map<int, Map<String, OfflineProgress>>? progressByItem,
    int? otherOwnersBytes,
    int? otherOwnersCount,
    bool? allowCellular,
    String? lastProfile,
    StorageInfo? storage,
    String? error,
    bool clearError = false,
    bool? loaded,
  }) =>
      OfflineState(
        units: units ?? this.units,
        items: items ?? this.items,
        progressByItem: progressByItem ?? this.progressByItem,
        otherOwnersBytes: otherOwnersBytes ?? this.otherOwnersBytes,
        otherOwnersCount: otherOwnersCount ?? this.otherOwnersCount,
        allowCellular: allowCellular ?? this.allowCellular,
        lastProfile: lastProfile ?? this.lastProfile,
        storage: storage ?? this.storage,
        error: clearError ? null : (error ?? this.error),
        loaded: loaded ?? this.loaded,
      );

  /// 正在进行中（含准备、排队、下载中、暂停、等待 Wi-Fi、等待转码、失败）按下载优先级排列。
  /// 正在下载的排最前，其余按 queueOrder 升序 / priority 降序 / 创建时间升序。
  List<DownloadUnit> get activeUnits {
    final active = units.where((u) => u.isActive).toList()
      ..sort((a, b) {
        final aRun = a.status == OfflineUnitStatus.running;
        final bRun = b.status == OfflineUnitStatus.running;
        if (aRun != bRun) return aRun ? -1 : 1;
        return _compareQueueOrder(a, b);
      });
    return active;
  }

  List<DownloadUnit> get doneUnits =>
      units.where((u) => u.status == OfflineUnitStatus.done).toList();

  List<DownloadUnit> get watchedUnits => doneUnits.where((u) {
        if (u.watched) return true;
        final itemId = u.mediaItemId;
        if (itemId == null) return false;
        return progressByItem[itemId]?[u.unitKey]?.played == true;
      }).toList();

  /// 已下载条目列表（离线媒体库用）：按最近下载时间降序。
  List<OfflineItemSummary> get downloadedItems {
    final doneIds = <int>{};
    for (final u in doneUnits) {
      if (u.playable && u.mediaItemId != null && u.mediaItemId! > 0) {
        doneIds.add(u.mediaItemId!);
      }
    }
    final list = <OfflineItemSummary>[];
    for (final id in doneIds) {
      final summary = items[id];
      if (summary != null) {
        list.add(summary);
      } else {
        final first = doneUnits.firstWhere((u) => u.mediaItemId == id);
        list.add(
          OfflineItemSummary(
            mediaItemId: id,
            libraryId: first.libraryId ?? 0,
            libraryName: first.libraryName ?? '媒体库',
            libraryKind: first.libraryKind ?? first.kind,
            kind: first.kind,
            title: first.title,
            year: first.year,
            posterUrl: first.posterUrl,
            backdropUrl: first.backdropUrl,
            addedAt: first.completedAt ?? first.createdAt ?? DateTime.now(),
          ),
        );
      }
    }
    list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  /// 查询某单元前面还有多少个仍在队列中的任务。
  int queueAheadOf(String unitId) {
    final list = activeUnits;
    final idx = list.indexWhere((u) => u.id == unitId);
    if (idx <= 0) return 0;
    var count = 0;
    for (var i = 0; i < idx; i++) {
      if (list[i].inQueue) count++;
    }
    return count;
  }

  bool canPrioritize(String unitId) {
    final list = activeUnits;
    final idx = list.indexWhere((u) => u.id == unitId);
    if (idx < 0) return false;
    return !list[idx].inQueue || queueAheadOf(unitId) > 0;
  }

  DownloadUnit? unitForFile(int fileId) {
    for (final u in units) {
      if (u.fileId == fileId) return u;
    }
    return null;
  }

  DownloadUnit? unitForEpisode({
    required int mediaItemId,
    int season = 0,
    int episode = 0,
  }) {
    DownloadUnit? fallback;
    for (final u in units) {
      if (u.mediaItemId == mediaItemId &&
          u.seasonNumber == season &&
          u.episodeNumber == episode) {
        if (u.playable) return u;
        fallback ??= u;
      }
    }
    return fallback;
  }

  OfflineProgress? localProgress(int mediaItemId, int season, int episode) =>
      progressByItem[mediaItemId]?['$season-$episode'];

  int get activeSpeedTotal => units.fold(
        0,
        (sum, u) =>
            sum + (u.status == OfflineUnitStatus.running ? u.speedBps : 0),
      );

  static int _compareQueueOrder(DownloadUnit a, DownloadUnit b) {
    if (a.queueOrder != null && b.queueOrder != null) {
      final cmp = a.queueOrder!.compareTo(b.queueOrder!);
      if (cmp != 0) return cmp;
    } else if (a.queueOrder != null) {
      return -1;
    } else if (b.queueOrder != null) {
      return 1;
    }
    if (a.priority != b.priority) {
      return b.priority.compareTo(a.priority);
    }
    final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
    final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
    if (aTime != bTime) return aTime.compareTo(bTime);
    final s = a.seasonNumber.compareTo(b.seasonNumber);
    if (s != 0) return s;
    return a.episodeNumber.compareTo(b.episodeNumber);
  }
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
    this.profile = 'original',
    this.fileExtension = 'mkv',
    this.exportId,
    this.mediaItemId = 0,
    this.libraryId = 0,
    this.libraryName = '媒体库',
    this.libraryKind = 'movie',
    this.kind = 'movie',
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.posterUrl,
    this.backdropUrl,
    this.stillUrl,
    this.year,
    this.expectedBytes = 0,
    this.receivedBytes = 0,
    this.priority = 0,
    this.queueOrder,
    this.watched = false,
    this.paused = false,
    this.needsPrepare = false,
    this.createdAtMs,
    this.completedAtMs,
  });

  final String id;
  final String ownerKey;
  final String fileId;
  String title;
  String url;
  String savePath;
  String? seasonEpisode;
  final String profileLabel;
  final String profile;
  String fileExtension;
  String? exportId;
  int mediaItemId;
  int libraryId;
  String libraryName;
  String libraryKind;
  String kind;
  int seasonNumber;
  int episodeNumber;
  String? posterUrl;
  String? backdropUrl;
  String? stillUrl;
  int? year;
  int expectedBytes;
  int receivedBytes;
  int priority;
  double? queueOrder;
  bool watched;
  bool paused;
  bool needsPrepare;
  int? createdAtMs;
  int? completedAtMs;

  int get fileIdInt => int.tryParse(fileId) ?? 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerKey': ownerKey,
        'fileId': fileId,
        'title': title,
        'url': url,
        'savePath': savePath,
        if (seasonEpisode != null) 'seasonEpisode': seasonEpisode,
        'profileLabel': profileLabel,
        'profile': profile,
        'fileExtension': fileExtension,
        if (exportId != null) 'exportId': exportId,
        'mediaItemId': mediaItemId,
        'libraryId': libraryId,
        'libraryName': libraryName,
        'libraryKind': libraryKind,
        'kind': kind,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        if (posterUrl != null) 'posterUrl': posterUrl,
        if (backdropUrl != null) 'backdropUrl': backdropUrl,
        if (stillUrl != null) 'stillUrl': stillUrl,
        if (year != null) 'year': year,
        'expectedBytes': expectedBytes,
        'receivedBytes': receivedBytes,
        'priority': priority,
        if (queueOrder != null) 'queueOrder': queueOrder,
        'watched': watched,
        'paused': paused,
        'needsPrepare': needsPrepare,
        if (createdAtMs != null) 'createdAtMs': createdAtMs,
        if (completedAtMs != null) 'completedAtMs': completedAtMs,
      };

  factory _StoredTask.fromJson(Map<String, dynamic> json) => _StoredTask(
        id: json['id'].toString(),
        ownerKey: (json['ownerKey'] ?? '').toString(),
        fileId: (json['fileId'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
        savePath: (json['savePath'] ?? '').toString(),
        seasonEpisode: json['seasonEpisode']?.toString(),
        profileLabel: (json['profileLabel'] ?? '原画').toString(),
        profile: (json['profile'] ?? 'original').toString(),
        fileExtension: (json['fileExtension'] ?? 'mkv').toString(),
        exportId: json['exportId']?.toString(),
        mediaItemId: ((json['mediaItemId'] ?? 0) as num).toInt(),
        libraryId: ((json['libraryId'] ?? 0) as num).toInt(),
        libraryName: (json['libraryName'] ?? '媒体库').toString(),
        libraryKind: (json['libraryKind'] ?? 'movie').toString(),
        kind: (json['kind'] ?? 'movie').toString(),
        seasonNumber: ((json['seasonNumber'] ?? 0) as num).toInt(),
        episodeNumber: ((json['episodeNumber'] ?? 0) as num).toInt(),
        posterUrl: json['posterUrl']?.toString(),
        backdropUrl: json['backdropUrl']?.toString(),
        stillUrl: json['stillUrl']?.toString(),
        year: (json['year'] as num?)?.toInt(),
        expectedBytes: ((json['expectedBytes'] ?? 0) as num).toInt(),
        receivedBytes: ((json['receivedBytes'] ?? 0) as num).toInt(),
        priority: ((json['priority'] ?? 0) as num).toInt(),
        queueOrder: (json['queueOrder'] as num?)?.toDouble(),
        watched: json['watched'] == true,
        paused: json['paused'] == true,
        needsPrepare: json['needsPrepare'] == true,
        createdAtMs: (json['createdAtMs'] as num?)?.toInt(),
        completedAtMs: (json['completedAtMs'] as num?)?.toInt(),
      );
}

/// 真离线下载、离线打包与本地播放状态机（1:1 对齐 iOS OfflineDownloader + OfflineStore）：
/// - 持久化目录 `<ApplicationSupport>/Offline/<sha256(origin|username)>/`（绝不写 `tmp/`）；
/// - 真实后端离线协议：`POST /api/v1/offline/profiles`、`GET /api/v1/offline/manifest`、
///   `POST /api/v1/offline/exports`、HTTP 503 转码排队自动轮询、原文件容器扩展名保留；
/// - 严格单活动串行下载队列 + `prioritize`/`reorder` 队头抢占；
/// - `OfflinePackager` 完整落盘元数据、分集、字幕、ASS 字体、章节/跳过片段与去重图片；
/// - `OfflineViewingUploader` 经 `POST /api/v1/playback/viewings` 批量补传观看记录（持久化至 2xx）。
class OfflineController extends Notifier<OfflineState> {
  static const _cellularKey = 'offline_allow_cellular';
  static const _lastProfileKey = 'offline_last_profile';
  static const _tasksKey = 'offline_tasks_v2';
  static const reserveBytes = 2 * 1024 * 1024 * 1024;

  final Map<String, _StoredTask> _allTasks = {};
  final Map<String, StreamSubscription<McDownloadProgress>> _subs = {};
  final Map<String, ({int bytes, DateTime at})> _lastTick = {};
  final Map<String, Timer> _retryTimers = {};
  final Set<String> _preempting = {};

  String? _activeDownloadId;
  String? _preparingId;

  String get _currentOrigin {
    final s = ref.read(sessionStoreProvider);
    final raw = ServerRoutes.instance.currentOrigin(s.baseUrl ?? '').trim();
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  String get _currentUsername => ref.read(sessionStoreProvider).username.trim();

  String get _currentOwner {
    final s = ref.read(sessionStoreProvider);
    return '${s.baseUrl ?? ''}|${s.username}';
  }

  Future<Directory> _ownerDir() => McDownloadPaths.resolveForOwner(
        origin: _currentOrigin,
        username: _currentUsername,
      );

  @override
  OfflineState build() {
    ref.onDispose(() {
      for (final sub in _subs.values) {
        sub.cancel();
      }
      _subs.clear();
      for (final timer in _retryTimers.values) {
        timer.cancel();
      }
      _retryTimers.clear();
    });
    _restorePrefs();
    return const OfflineState();
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final allowCell = prefs.getBool(_cellularKey) ?? false;
    final lastProf = prefs.getString(_lastProfileKey);
    await McDownloadChannel.setAllowCellular(allowCell);
    state = state.copyWith(
      allowCellular: allowCell,
      lastProfile: lastProf,
    );
    await _restoreTasks();
    unawaited(refreshStorage());
    unawaited(flushViewings());
  }

  Future<void> _restoreTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tasksKey);
    final ownerDir = await _ownerDir();
    final items = <int, OfflineItemSummary>{};
    final progressByItem = <int, Map<String, OfflineProgress>>{};

    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List<dynamic>)
            .whereType<Map>()
            .map((e) => _StoredTask.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final owner = _currentOwner;
        final restored = <DownloadUnit>[];
        var otherBytes = 0;
        var otherCount = 0;
        final itemIds = <int>{};

        for (final t in list) {
          _allTasks[t.id] = t;
          final file = File(t.savePath);
          final finished = t.savePath.isNotEmpty && await file.exists();
          final belongsToCurrent =
              t.ownerKey.isEmpty || t.ownerKey == owner || owner == '|';
          if (!belongsToCurrent) {
            if (finished) {
              otherCount++;
              otherBytes += await file.length();
            }
            continue;
          }
          var received = t.receivedBytes;
          if (finished) {
            try {
              received = await file.length();
            } catch (_) {}
          } else {
            final part = File('${t.savePath}.part');
            if (await part.exists()) {
              try {
                received = await part.length();
              } catch (_) {}
            }
          }
          if (t.mediaItemId > 0) itemIds.add(t.mediaItemId);
          final status = finished
              ? OfflineUnitStatus.done
              : t.paused
                  ? OfflineUnitStatus.paused
                  : t.needsPrepare
                      ? OfflineUnitStatus.preparing
                      : OfflineUnitStatus.queued;
          final expected =
              t.expectedBytes > 0 ? t.expectedBytes : (finished ? received : 0);
          final prog = finished
              ? 1.0
              : (expected > 0 ? (received / expected).clamp(0.0, 1.0) : 0.0);

          restored.add(
            DownloadUnit(
              id: t.id,
              title: t.title,
              seasonEpisode: t.seasonEpisode,
              profileLabel: t.profileLabel,
              status: status,
              progress: prog,
              priority: t.priority,
              totalBytes: expected > 0 ? expected : null,
              savePath: t.savePath,
              watched: t.watched,
              mediaItemId: t.mediaItemId > 0 ? t.mediaItemId : null,
              fileId: t.fileIdInt > 0 ? t.fileIdInt : null,
              libraryId: t.libraryId > 0 ? t.libraryId : null,
              libraryName: t.libraryName,
              libraryKind: t.libraryKind,
              kind: t.kind,
              seasonNumber: t.seasonNumber,
              episodeNumber: t.episodeNumber,
              profile: t.profile,
              fileExtension: t.fileExtension,
              exportId: t.exportId,
              posterUrl: t.posterUrl,
              backdropUrl: t.backdropUrl,
              stillUrl: t.stillUrl,
              year: t.year,
              receivedBytes: received,
              expectedBytes: expected,
              createdAt: t.createdAtMs != null
                  ? DateTime.fromMillisecondsSinceEpoch(t.createdAtMs!)
                  : null,
              completedAt: t.completedAtMs != null
                  ? DateTime.fromMillisecondsSinceEpoch(t.completedAtMs!)
                  : null,
              queueOrder: t.queueOrder,
            ),
          );
        }

        // 读取每部片磁盘上的 summary.json 与 progress.json，并加载离线图片索引。
        for (final itemId in itemIds) {
          final sumMap = await OfflineDisk.readJsonMap(
            OfflineDisk.summaryFile(ownerDir, itemId),
          );
          if (sumMap != null) {
            items[itemId] = OfflineItemSummary.fromJson(sumMap);
          }
          final progMap = await OfflineDisk.readJsonMap(
            OfflineDisk.progressFile(ownerDir, itemId),
          );
          if (progMap != null) {
            progressByItem[itemId] = {
              for (final e in progMap.entries)
                if (e.value is Map)
                  e.key: OfflineProgress.fromJson(
                    (e.value as Map).cast<String, dynamic>(),
                  ),
            };
          }
        }
        await OfflineImages.shared.load(ownerDir, itemIds);

        state = state.copyWith(
          units: restored,
          items: items,
          progressByItem: progressByItem,
          otherOwnersBytes: otherBytes,
          otherOwnersCount: otherCount,
          loaded: true,
        );
        // 严格串行调度：仅启动队头一个准备/下载任务。
        unawaited(_scheduleNext());
        return;
      } catch (_) {}
    }
    state = state.copyWith(loaded: true);
  }

  Future<void> _persistTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode([
      for (final t in _allTasks.values) t.toJson(),
    ]);
    await prefs.setString(_tasksKey, encoded);
  }

  Future<void> _rememberLastProfile(String profile) async {
    state = state.copyWith(lastProfile: profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastProfileKey, profile);
  }

  // MARK: - 真实离线后端协议 API

  /// 批量查询可选下载档位与真实预计大小：`POST /api/v1/offline/profiles`（每批最多 500 个）。
  /// 旧服务器返回 404/405 时自动退回逐个拉取 `fetchManifest`。
  Future<Map<int, OfflineFileProfiles>> fetchProfiles(
    List<int> fileIds,
  ) async {
    final unique = <int>[];
    for (final id in fileIds) {
      if (id > 0 && !unique.contains(id)) unique.add(id);
    }
    if (unique.isEmpty) return const {};

    final client = ref.read(offlineClientProvider);
    final out = <int, OfflineFileProfiles>{};
    var useLegacy = false;

    for (var i = 0; i < unique.length; i += 500) {
      final end = (i + 500 > unique.length) ? unique.length : i + 500;
      final chunk = unique.sublist(i, end);
      try {
        final body = await client.unwrap<Map<String, dynamic>>(
          Channel.general,
          'POST',
          '/api/v1/offline/profiles',
          body: {'file_ids': chunk},
        );
        final files = (body['files'] as List?) ?? const [];
        for (final raw in files.whereType<Map>()) {
          final entry =
              OfflineFileProfiles.fromJson(raw.cast<String, dynamic>());
          if (entry.fileId > 0) out[entry.fileId] = entry;
        }
      } on ApiException catch (e) {
        if (e.httpStatus == 404 || e.httpStatus == 405) {
          useLegacy = true;
          break;
        }
        rethrow;
      }
    }

    if (useLegacy) {
      for (final id in unique) {
        try {
          final m = await fetchManifest(id);
          out[id] = m.toFileProfiles();
        } catch (_) {}
      }
    }
    return out;
  }

  /// 获取单个文件的完整离线清单：
  /// 优先调用 `GET /api/v1/offline/manifest?file_id=<fileId>`（对齐 OpenAPI `Endpoints.swift`），
  /// 若服务端以路径参数路由返回 404/405，自动兼容回退 `GET /api/v1/offline/manifest/<fileId>`。
  Future<OfflineManifest> fetchManifest(int fileId) async {
    final client = ref.read(offlineClientProvider);
    try {
      final body = await client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/offline/manifest',
        query: {'file_id': fileId},
      );
      return OfflineManifest.fromJson(body);
    } on ApiException catch (e) {
      if (e.httpStatus == 404 || e.httpStatus == 405) {
        final body = await client.unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/offline/manifest/$fileId',
        );
        return OfflineManifest.fromJson(body);
      }
      rethrow;
    }
  }

  /// 兼容旧调用签名。
  Future<OfflineManifest> manifest(String fileId) {
    final id = int.tryParse(fileId);
    if (id == null) {
      throw const ApiException('offline.invalid_file_id', '无效的文件 ID');
    }
    return fetchManifest(id);
  }

  /// 为转码档（1080p / 720p / 480p）创建或复用服务端 MP4 导出任务：`POST /api/v1/offline/exports`。
  Future<OfflineExportInfo> startExport(
    int fileId,
    String profile, {
    String? audioTrack,
  }) async {
    final body = await ref
        .read(offlineClientProvider)
        .unwrap<Map<String, dynamic>>(
          Channel.general,
          'POST',
          '/api/v1/offline/exports',
          body: {
            'file_id': fileId,
            'profile': profile,
            if (audioTrack != null && audioTrack.isNotEmpty)
              'audio_track': audioTrack,
          },
        );
    return OfflineExportInfo.fromJson(body);
  }

  /// 查询导出任务状态与排队位置：`GET /api/v1/offline/exports/<exportId>`。
  Future<OfflineExportInfo?> getExport(String exportId) async {
    try {
      final body = await ref
          .read(offlineClientProvider)
          .unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/offline/exports/$exportId',
          );
      return OfflineExportInfo.fromJson(body);
    } catch (_) {
      return null;
    }
  }

  /// 下载完成后通知服务端回收导出：`DELETE /api/v1/offline/exports/<exportId>`。
  Future<void> releaseExport(String exportId) async {
    try {
      await ref.read(offlineClientProvider).unwrap<dynamic>(
            Channel.general,
            'DELETE',
            '/api/v1/offline/exports/$exportId',
          );
    } catch (_) {}
  }

  String _contentUrlForOriginal(int fileId) {
    final origin = _currentOrigin;
    return '$origin/api/v1/offline/files/$fileId/content';
  }

  String _contentUrlForExport(OfflineExportInfo export) {
    final origin = _currentOrigin;
    final raw = export.contentUrl.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '$origin$raw';
    return '$origin/api/v1/offline/exports/${export.exportId}/content';
  }

  // MARK: - 发起与入队

  /// 由完整 `OfflineManifest` 与选中档位直接开始下载（首集或单片主路径）。
  Future<void> startFromManifest({
    required OfflineManifest manifest,
    required DownloadProfile profile,
    String? fallbackTitle,
  }) async {
    if (manifest.unavailableReason != null &&
        manifest.unavailableReason!.isNotEmpty) {
      throw ApiException('offline.unavailable', manifest.unavailableReason!);
    }
    final fileId = manifest.fileIdInt;
    if (fileId <= 0) {
      throw const ApiException('offline.invalid_file_id', '无效的文件 ID');
    }

    // 同文件同档位已在下载或已下完：不重复下载。
    final existing = state.unitForFile(fileId);
    if (existing != null &&
        existing.profile == profile.id &&
        existing.status != OfflineUnitStatus.failed &&
        !existing.damaged) {
      return;
    }
    // 换档位时先移除旧单元。
    if (existing != null) {
      await cancel(existing);
    }

    final ownerDir = await _ownerDir();
    final itemId = manifest.mediaItemId > 0 ? manifest.mediaItemId : fileId;
    final isOriginal = profile.id == 'original';
    final ext = McDownloadPaths.sanitizeExtension(
      manifest.container,
      isTranscode: !isOriginal,
    );
    final saveFile = OfflineDisk.mediaFile(ownerDir, itemId, fileId, ext);
    final title = manifest.itemTitle.isNotEmpty
        ? manifest.itemTitle
        : (fallbackTitle ?? '未命名影片');
    final season = manifest.seasonNumber;
    final episode = manifest.episodeNumber;
    final seasonEpisode = _formatSeasonEpisode(
      kind: manifest.itemKind,
      season: season,
      episode: episode,
    );
    final now = DateTime.now();
    final id = 'dl-$fileId-${now.microsecondsSinceEpoch}';

    final summary = OfflineItemSummary(
      mediaItemId: itemId,
      libraryId: manifest.libraryId,
      libraryName: manifest.libraryName,
      libraryKind: manifest.libraryKind,
      kind: manifest.itemKind,
      title: title,
      year: manifest.itemYear,
      posterUrl: manifest.itemPosterUrl,
      backdropUrl: manifest.itemBackdropUrl,
      addedAt: now,
    );
    await OfflineDisk.writeJson(
      OfflineDisk.summaryFile(ownerDir, itemId),
      summary.toJson(),
    );

    final task = _StoredTask(
      id: id,
      ownerKey: _currentOwner,
      fileId: fileId.toString(),
      title: title,
      url: isOriginal ? _contentUrlForOriginal(fileId) : '',
      savePath: saveFile.path,
      seasonEpisode: seasonEpisode,
      profileLabel: profile.label,
      profile: profile.id,
      fileExtension: ext,
      mediaItemId: itemId,
      libraryId: manifest.libraryId,
      libraryName: manifest.libraryName,
      libraryKind: manifest.libraryKind,
      kind: manifest.itemKind,
      seasonNumber: season,
      episodeNumber: episode,
      posterUrl: manifest.itemPosterUrl,
      backdropUrl: manifest.itemBackdropUrl,
      stillUrl: manifest.episodeStillUrl,
      year: manifest.itemYear,
      expectedBytes: profile.expectedBytes > 0
          ? profile.expectedBytes
          : manifest.sizeBytes,
      needsPrepare: true,
      createdAtMs: now.millisecondsSinceEpoch,
    );
    _allTasks[id] = task;

    final unit = DownloadUnit(
      id: id,
      title: title,
      seasonEpisode: seasonEpisode,
      profileLabel: profile.label,
      status: OfflineUnitStatus.preparing,
      totalBytes: task.expectedBytes > 0 ? task.expectedBytes : null,
      savePath: saveFile.path,
      mediaItemId: itemId,
      fileId: fileId,
      libraryId: manifest.libraryId,
      libraryName: manifest.libraryName,
      libraryKind: manifest.libraryKind,
      kind: manifest.itemKind,
      seasonNumber: season,
      episodeNumber: episode,
      profile: profile.id,
      fileExtension: ext,
      posterUrl: manifest.itemPosterUrl,
      backdropUrl: manifest.itemBackdropUrl,
      stillUrl: manifest.episodeStillUrl,
      year: manifest.itemYear,
      expectedBytes: task.expectedBytes,
      createdAt: now,
    );

    final nextItems = Map<int, OfflineItemSummary>.from(state.items)
      ..[itemId] = summary;
    state = state.copyWith(
      units: [...state.units, unit],
      items: nextItems,
      clearError: true,
    );
    await _rememberLastProfile(profile.id);
    await _persistTasks();

    // 立即打包当前清单（若无其他准备中任务），打包完成后交给串行调度器。
    unawaited(_prepareTask(task, givenManifest: manifest));
  }

  /// 批量下载除首集外的其余集：凭 `OfflineFileProfiles` 立即入队，
  /// 由串行调度器逐集拉取完整清单、打包元数据/字幕/剧照并下载。
  Future<void> enqueueFromProfile({
    required OfflineFileProfiles entry,
    required DownloadProfile profile,
    required String title,
    String kind = 'tv',
    int libraryId = 0,
    String libraryName = '媒体库',
    String? posterUrl,
    String? backdropUrl,
    int? year,
  }) async {
    if (entry.unavailableReason != null &&
        entry.unavailableReason!.isNotEmpty) {
      throw ApiException('offline.unavailable', entry.unavailableReason!);
    }
    final existing = state.unitForFile(entry.fileId);
    if (existing != null &&
        existing.profile == profile.id &&
        existing.status != OfflineUnitStatus.failed &&
        !existing.damaged) {
      return;
    }
    if (existing != null) {
      await cancel(existing);
    }

    final ownerDir = await _ownerDir();
    final itemId = entry.mediaItemId > 0 ? entry.mediaItemId : entry.fileId;
    final isOriginal = profile.id == 'original';
    final ext = McDownloadPaths.sanitizeExtension(
      entry.container,
      isTranscode: !isOriginal,
    );
    final saveFile = OfflineDisk.mediaFile(ownerDir, itemId, entry.fileId, ext);
    final seasonEpisode = _formatSeasonEpisode(
      kind: kind,
      season: entry.seasonNumber,
      episode: entry.episodeNumber,
    );
    final now = DateTime.now();
    final id = 'dl-${entry.fileId}-${now.microsecondsSinceEpoch}';

    final task = _StoredTask(
      id: id,
      ownerKey: _currentOwner,
      fileId: entry.fileId.toString(),
      title: title,
      url: isOriginal ? _contentUrlForOriginal(entry.fileId) : '',
      savePath: saveFile.path,
      seasonEpisode: seasonEpisode,
      profileLabel: profile.label,
      profile: profile.id,
      fileExtension: ext,
      mediaItemId: itemId,
      libraryId: libraryId,
      libraryName: libraryName,
      libraryKind: kind,
      kind: kind,
      seasonNumber: entry.seasonNumber,
      episodeNumber: entry.episodeNumber,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      year: year,
      expectedBytes: profile.expectedBytes,
      needsPrepare: true,
      createdAtMs: now.millisecondsSinceEpoch,
    );
    _allTasks[id] = task;

    final unit = DownloadUnit(
      id: id,
      title: title,
      seasonEpisode: seasonEpisode,
      profileLabel: profile.label,
      status: OfflineUnitStatus.preparing,
      totalBytes: task.expectedBytes > 0 ? task.expectedBytes : null,
      savePath: saveFile.path,
      mediaItemId: itemId,
      fileId: entry.fileId,
      libraryId: libraryId,
      libraryName: libraryName,
      libraryKind: kind,
      kind: kind,
      seasonNumber: entry.seasonNumber,
      episodeNumber: entry.episodeNumber,
      profile: profile.id,
      fileExtension: ext,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      year: year,
      expectedBytes: task.expectedBytes,
      createdAt: now,
    );

    state = state.copyWith(
      units: [...state.units, unit],
      clearError: true,
    );
    await _rememberLastProfile(profile.id);
    await _persistTasks();
    unawaited(_scheduleNext());
  }

  /// 兼容旧 `DownloadCandidate` 入口（detail_page.dart）：
  /// 走真实 `POST /api/v1/offline/profiles` + `GET /api/v1/offline/manifest` + `POST /api/v1/offline/exports`，
  /// 绝不调用 `/playback/sessions`，且使用真实季集编号。
  Future<String> startDownload(DownloadCandidate candidate) async {
    try {
      final rawIds = candidate.fullSeasonSelected &&
              candidate.seasonFileIds.isNotEmpty
          ? candidate.seasonFileIds
          : <String>[candidate.fileId];
      final fileIds = <int>[
        for (final s in rawIds)
          if (int.tryParse(s) != null) int.parse(s),
      ];
      if (fileIds.isEmpty) {
        return '下载没能开始：无效的文件编号';
      }
      final preferredProfileId = candidate.profiles.isNotEmpty
          ? candidate.profiles.first.id
          : (state.lastProfile ?? 'original');
      final profileMap = await fetchProfiles(fileIds);
      final leadId = fileIds.first;
      final leadManifest = await fetchManifest(leadId);
      final leadProfile = _pickProfile(
        preferredProfileId,
        leadManifest.profiles.isNotEmpty
            ? leadManifest.profiles
            : candidate.profiles,
      );
      if (leadProfile == null) {
        return leadManifest.unavailableReason ?? '该文件暂不支持离线下载';
      }
      await startFromManifest(
        manifest: leadManifest,
        profile: leadProfile,
        fallbackTitle: candidate.title,
      );
      var started = 1;
      var skipped = 0;
      for (final fid in fileIds.skip(1)) {
        final entry = profileMap[fid];
        if (entry == null || entry.unavailableReason != null) {
          skipped++;
          continue;
        }
        final chosen = _pickProfile(preferredProfileId, entry.profiles);
        if (chosen == null) {
          skipped++;
          continue;
        }
        try {
          await enqueueFromProfile(
            entry: entry,
            profile: chosen,
            title: leadManifest.itemTitle.isNotEmpty
                ? leadManifest.itemTitle
                : candidate.title,
            kind: leadManifest.itemKind,
            libraryId: leadManifest.libraryId,
            libraryName: leadManifest.libraryName,
            posterUrl: leadManifest.itemPosterUrl,
            backdropUrl: leadManifest.itemBackdropUrl,
            year: leadManifest.itemYear,
          );
          started++;
        } catch (_) {
          skipped++;
        }
      }
      if (skipped > 0) {
        return '已开始下载 $started 项，$skipped 项跳过';
      }
      return started > 1 ? '已加入离线缓存队列（$started 项）' : '已开始离线下载';
    } on ApiException catch (e) {
      state = state.copyWith(error: e.friendlyMessage);
      return '下载没能开始：${e.friendlyMessage}';
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return '下载没能开始：$e';
    }
  }

  DownloadProfile? _pickProfile(
    String preferredId,
    List<DownloadProfile> options,
  ) {
    if (options.isEmpty) return null;
    for (final p in options) {
      if (p.id == preferredId) return p;
    }
    return options.first;
  }

  // MARK: - 准备阶段（OfflinePackager + 转码导出）

  Future<void> _prepareTask(
    _StoredTask task, {
    OfflineManifest? givenManifest,
  }) async {
    if (_preparingId != null) return;
    _preparingId = task.id;
    try {
      final manifest = givenManifest ?? await fetchManifest(task.fileIdInt);
      if (!_allTasks.containsKey(task.id)) return;

      final ownerDir = await _ownerDir();
      final client = ref.read(offlineClientProvider);

      // 补齐批量入队时缺失的标题/剧照/真实季集信息。
      if (manifest.itemTitle.isNotEmpty) task.title = manifest.itemTitle;
      if (manifest.mediaItemId > 0) task.mediaItemId = manifest.mediaItemId;
      if (manifest.libraryId > 0) task.libraryId = manifest.libraryId;
      task.libraryName = manifest.libraryName;
      task.libraryKind = manifest.libraryKind;
      task.kind = manifest.itemKind;
      task.seasonNumber = manifest.seasonNumber;
      task.episodeNumber = manifest.episodeNumber;
      task.seasonEpisode = _formatSeasonEpisode(
        kind: manifest.itemKind,
        season: manifest.seasonNumber,
        episode: manifest.episodeNumber,
      );
      task.posterUrl ??= manifest.itemPosterUrl;
      task.backdropUrl ??= manifest.itemBackdropUrl;
      task.stillUrl ??= manifest.episodeStillUrl;
      task.year ??= manifest.itemYear;

      final isOriginal = task.profile == 'original';
      task.fileExtension = McDownloadPaths.sanitizeExtension(
        manifest.container,
        isTranscode: !isOriginal,
      );
      final targetMedia = OfflineDisk.mediaFile(
        ownerDir,
        task.mediaItemId > 0 ? task.mediaItemId : task.fileIdInt,
        task.fileIdInt,
        task.fileExtension,
      );
      task.savePath = targetMedia.path;

      // 1. 打包元数据、分集、字幕、ASS 字体、章节/跳过片段及去重海报/剧照
      await OfflinePackager(
        client: client,
        ownerDir: ownerDir,
        manifest: manifest,
        profile: task.profile,
      ).run();

      // 同步服务端初始续播点（若本机尚未记录进度）
      if (manifest.resumePositionMs != null &&
          manifest.resumePositionMs! > 0 &&
          state.localProgress(
                task.mediaItemId,
                task.seasonNumber,
                task.episodeNumber,
              ) ==
              null) {
        await recordLocalProgress(
          mediaItemId: task.mediaItemId,
          season: task.seasonNumber,
          episode: task.episodeNumber,
          positionMs: manifest.resumePositionMs!,
          played: false,
          durationMs: manifest.durationMs,
        );
      }

      if (!_allTasks.containsKey(task.id)) return;

      // 2. 解析真实视频下载地址：原画直连 /offline/files/<id>/content；
      //    转码档通过 POST /api/v1/offline/exports 获取 MP4 导出地址（绝不下载 .m3u8）。
      if (isOriginal) {
        task.url = _contentUrlForOriginal(task.fileIdInt);
        if (task.expectedBytes <= 0 && manifest.sizeBytes > 0) {
          task.expectedBytes = manifest.sizeBytes;
        }
      } else {
        final export = await startExport(
          task.fileIdInt,
          task.profile,
          audioTrack: manifest.defaultAudio,
        );
        if (!_allTasks.containsKey(task.id)) return;
        task.exportId = export.exportId;
        task.url = _contentUrlForExport(export);
        if (export.expectedBytes > 0) {
          task.expectedBytes = export.expectedBytes;
        }
      }

      task.needsPrepare = false;
      await _persistTasks();

      _patch(
        task.id,
        (u) => u.copyWith(
          status: task.paused
              ? OfflineUnitStatus.paused
              : OfflineUnitStatus.queued,
          savePath: task.savePath,
          fileExtension: task.fileExtension,
          exportId: task.exportId,
          totalBytes: task.expectedBytes > 0 ? task.expectedBytes : null,
          expectedBytes: task.expectedBytes,
          seasonEpisode: task.seasonEpisode,
          seasonNumber: task.seasonNumber,
          episodeNumber: task.episodeNumber,
          mediaItemId: task.mediaItemId,
          libraryId: task.libraryId,
          libraryName: task.libraryName,
          libraryKind: task.libraryKind,
          kind: task.kind,
          posterUrl: task.posterUrl,
          backdropUrl: task.backdropUrl,
          stillUrl: task.stillUrl,
          year: task.year,
          clearError: true,
          clearTranscodeWait: true,
        ),
      );
    } on ApiException catch (e) {
      final retryable =
          e.httpStatus != 400 && e.httpStatus != 403 && e.httpStatus != 404 && e.httpStatus != 422;
      _markFailed(
        task,
        e.friendlyMessage,
        retryable: retryable,
        httpStatus: e.httpStatus,
      );
    } catch (e) {
      _markFailed(task, e.toString(), retryable: true);
    } finally {
      if (_preparingId == task.id) _preparingId = null;
      unawaited(_scheduleNext());
    }
  }

  // MARK: - 严格串行调度与抢占

  Future<void> _scheduleNext() async {
    // 1. 若当前没有在准备的单元，优先准备排在最前的 `preparing` 单元（一次只准备一个）。
    if (_preparingId == null) {
      final preparingCandidates = state.units
          .where((u) => u.status == OfflineUnitStatus.preparing)
          .toList()
        ..sort(OfflineState._compareQueueOrder);
      if (preparingCandidates.isNotEmpty) {
        final nextPrep = _allTasks[preparingCandidates.first.id];
        if (nextPrep != null) {
          unawaited(_prepareTask(nextPrep));
        }
      }
    }

    // 2. 若当前已有正在下载的单元，严格维持单活动并发（除非被 prioritize/reorder 主动抢占）。
    if (_activeDownloadId != null) {
      final active = _unit(_activeDownloadId!);
      if (active != null && active.status == OfflineUnitStatus.running) {
        return;
      }
      _activeDownloadId = null;
    }

    // 3. 挑出优先级最高的 `queued` 单元开始下载。
    final readyCandidates = state.units
        .where((u) => u.status == OfflineUnitStatus.queued)
        .toList()
      ..sort(OfflineState._compareQueueOrder);
    if (readyCandidates.isEmpty) return;

    final headUnit = readyCandidates.first;
    final headTask = _allTasks[headUnit.id];
    if (headTask == null) return;
    if (headTask.needsPrepare || headTask.url.isEmpty) {
      _patch(headTask.id, (u) => u.copyWith(status: OfflineUnitStatus.preparing));
      if (_preparingId == null) unawaited(_prepareTask(headTask));
      return;
    }
    await _launch(headTask);
  }

  Future<void> _launch(_StoredTask task) async {
    if (_subs.containsKey(task.id)) return;
    _activeDownloadId = task.id;
    _lastTick[task.id] = (bytes: task.receivedBytes, at: DateTime.now());
    _subs[task.id] = McDownloadChannel.progress(task.id).listen(
      (p) => _onProgress(task, p),
      onError: (Object e) => _onTransportError(task, e.toString()),
    );
    _patch(
      task.id,
      (u) => u.copyWith(
        status: OfflineUnitStatus.running,
        clearError: true,
        clearTranscodeWait: true,
      ),
    );
    await McDownloadChannel.start(
      McDownloadRequest(
        id: task.id,
        url: task.url,
        savePath: task.savePath,
        headers: mcImageHeaders(),
        allowCellular: state.allowCellular,
      ),
    );
  }

  void _onProgress(_StoredTask task, McDownloadProgress p) {
    if (_preempting.contains(task.id)) return;
    if (p.error != null) {
      if (p.error == 'waiting_wifi') {
        _subs.remove(task.id)?.cancel();
        _lastTick.remove(task.id);
        if (_activeDownloadId == task.id) _activeDownloadId = null;
        _patch(
          task.id,
          (u) => u.copyWith(
            status: OfflineUnitStatus.waitingWifi,
            speedBps: 0,
          ),
        );
        return;
      }
      unawaited(_handleProgressError(task, p));
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

    task.receivedBytes = p.receivedBytes;
    if (p.totalBytes != null && p.totalBytes! > 0) {
      task.expectedBytes = p.totalBytes!;
    }

    if (p.done) {
      _subs.remove(task.id)?.cancel();
      _lastTick.remove(task.id);
      if (_activeDownloadId == task.id) _activeDownloadId = null;
      task.completedAtMs = now.millisecondsSinceEpoch;
      task.paused = false;
      unawaited(_persistTasks());
      if (task.exportId != null && task.exportId!.isNotEmpty) {
        unawaited(releaseExport(task.exportId!));
      }
      _patch(
        task.id,
        (u) => u.copyWith(
          status: OfflineUnitStatus.done,
          progress: 1.0,
          speedBps: 0,
          receivedBytes: p.receivedBytes,
          expectedBytes: p.totalBytes ?? p.receivedBytes,
          totalBytes: p.totalBytes ?? p.receivedBytes,
          completedAt: now,
          clearError: true,
          clearTranscodeWait: true,
        ),
      );
      unawaited(refreshStorage());
      unawaited(_scheduleNext());
      return;
    }

    final ratio = p.ratio ??
        (task.expectedBytes > 0
            ? (p.receivedBytes / task.expectedBytes).clamp(0.0, 1.0)
            : null);
    _patch(
      task.id,
      (u) => u.copyWith(
        status: OfflineUnitStatus.running,
        progress: ratio ?? u.progress,
        receivedBytes: p.receivedBytes,
        expectedBytes:
            p.totalBytes != null && p.totalBytes! > 0 ? p.totalBytes : null,
        totalBytes:
            p.totalBytes != null && p.totalBytes! > 0 ? p.totalBytes : null,
        speedBps: speed < 0 ? 0 : speed,
      ),
    );
  }

  Future<void> _handleProgressError(
    _StoredTask task,
    McDownloadProgress p,
  ) async {
    _subs.remove(task.id)?.cancel();
    _lastTick.remove(task.id);
    if (_activeDownloadId == task.id) _activeDownloadId = null;

    final errText = p.error ?? '下载失败';
    if (errText == 'Download was cancelled') return;

    final status = p.httpStatus ?? _extractHttpStatus(errText);

    // HTTP 503：服务端转码排队（Retry-After / x-export-wait / x-export-ahead）。
    if (status == 503) {
      var wait = p.exportWait;
      var ahead = p.exportAhead;
      final retrySec = (p.retryAfterSeconds ?? 15).clamp(5, 180);

      // 若原生通道未透传自定义响应头，主动查一次 GET /api/v1/offline/exports/<id> 拿精确排队位置。
      if (ahead == null &&
          wait == null &&
          task.exportId != null &&
          task.exportId!.isNotEmpty) {
        final info = await getExport(task.exportId!);
        if (info != null) {
          ahead = info.queuePosition;
          if (info.status == 'queued') wait = 'queue';
        }
      }
      final note = transcodeWaitNote(wait: wait, ahead: ahead);
      final retryAt = DateTime.now().add(Duration(seconds: retrySec));
      _patch(
        task.id,
        (u) => u.copyWith(
          status: OfflineUnitStatus.waitingTranscode,
          speedBps: 0,
          transcodeWait: note,
          retryable: true,
          nextRetryAt: retryAt,
          clearError: true,
        ),
      );
      _scheduleRetryTimer(task, Duration(seconds: retrySec));
      unawaited(_scheduleNext());
      return;
    }

    // 404 / 410：转码导出被服务端回收，清空 exportId 回到准备阶段重建导出。
    if ((status == 404 || status == 410) && task.profile != 'original') {
      task.exportId = null;
      task.needsPrepare = true;
      await _persistTasks();
      _markFailed(task, '转码导出已过期，稍后自动重建', retryable: true, httpStatus: status);
      unawaited(_scheduleNext());
      return;
    }

    final retryable = status == null ||
        status == 401 ||
        status >= 500 ||
        status == 408 ||
        status == 429;
    final friendly = switch (status) {
      401 => '登录状态已失效，重新登录后继续下载',
      403 => '当前账号无权下载此视频',
      404 => '服务器上的视频文件不存在',
      422 => '服务器转码失败',
      _ => errText,
    };
    _markFailed(task, friendly, retryable: retryable, httpStatus: status);
    unawaited(_scheduleNext());
  }

  void _onTransportError(_StoredTask task, String message) {
    _subs.remove(task.id)?.cancel();
    _lastTick.remove(task.id);
    if (_activeDownloadId == task.id) _activeDownloadId = null;
    _markFailed(task, message, retryable: true);
    unawaited(_scheduleNext());
  }

  void _markFailed(
    _StoredTask task,
    String message, {
    required bool retryable,
    int? httpStatus,
  }) {
    final prev = _unit(task.id);
    final attempts = (prev?.attempts ?? 0) + 1;
    DateTime? retryAt;
    if (retryable) {
      const steps = [30, 120, 600, 1800, 3600];
      final delaySec = steps[(attempts - 1).clamp(0, steps.length - 1)];
      retryAt = DateTime.now().add(Duration(seconds: delaySec));
      _scheduleRetryTimer(task, Duration(seconds: delaySec));
    }
    _patch(
      task.id,
      (u) => u.copyWith(
        status: OfflineUnitStatus.failed,
        speedBps: 0,
        error: message,
        retryable: retryable,
        attempts: attempts,
        nextRetryAt: retryAt,
        clearTranscodeWait: true,
      ),
    );
    state = state.copyWith(error: message);
  }

  void _scheduleRetryTimer(_StoredTask task, Duration delay) {
    _retryTimers.remove(task.id)?.cancel();
    _retryTimers[task.id] = Timer(delay, () {
      _retryTimers.remove(task.id);
      if (!_allTasks.containsKey(task.id)) return;
      final unit = _unit(task.id);
      if (unit == null) return;
      if (unit.status != OfflineUnitStatus.waitingTranscode &&
          !(unit.status == OfflineUnitStatus.failed && unit.retryable)) {
        return;
      }
      final nextStatus = task.needsPrepare
          ? OfflineUnitStatus.preparing
          : OfflineUnitStatus.queued;
      _patch(
        task.id,
        (u) => u.copyWith(
          status: nextStatus,
          clearNextRetryAt: true,
        ),
      );
      unawaited(_scheduleNext());
    });
  }

  static int? _extractHttpStatus(String text) {
    final match = RegExp(r'HTTP\s+(\d{3})').firstMatch(text);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// 对齐 iOS `OfflineDownloader.transcodeWaitNote`。
  static String transcodeWaitNote({String? wait, int? ahead}) {
    if (wait == 'transcoder') return '等待转码器空闲';
    if (ahead != null && ahead > 0) return '等待服务器转码，前面还有 $ahead 个';
    if (wait == 'queue') return '即将开始转码';
    return '等待服务器转码';
  }

  // MARK: - 队列操作：暂停 / 继续 / 取消 / 优先下载（抢占）/ 拖拽排序（抢占）

  Future<void> toggle(DownloadUnit unit) async {
    final task = _allTasks[unit.id];
    if (unit.status == OfflineUnitStatus.running) {
      await _pauseUnit(unit.id, userPaused: true);
      unawaited(_scheduleNext());
      return;
    }
    if (task != null) {
      if (task.savePath.isNotEmpty && await File(task.savePath).exists()) {
        _patch(unit.id, (u) => u.copyWith(status: OfflineUnitStatus.done));
        return;
      }
      task.paused = false;
      await _persistTasks();
      _retryTimers.remove(unit.id)?.cancel();
      final nextStatus = (task.needsPrepare ||
              (task.profile != 'original' &&
                  (task.exportId == null || task.exportId!.isEmpty)))
          ? OfflineUnitStatus.preparing
          : OfflineUnitStatus.queued;
      _patch(
        unit.id,
        (u) => u.copyWith(
          status: nextStatus,
          clearError: true,
          clearTranscodeWait: true,
          clearNextRetryAt: true,
        ),
      );
      await _scheduleNext();
    } else {
      _patch(
        unit.id,
        (u) => u.copyWith(status: OfflineUnitStatus.queued, speedBps: 0),
      );
    }
  }

  Future<void> _pauseUnit(String id, {required bool userPaused}) async {
    _preempting.add(id);
    try {
      await McDownloadChannel.pause(id);
      await _subs.remove(id)?.cancel();
      _lastTick.remove(id);
      if (_activeDownloadId == id) _activeDownloadId = null;
      final task = _allTasks[id];
      if (task != null) {
        task.paused = userPaused;
        await _persistTasks();
      }
      _patch(
        id,
        (u) => u.copyWith(
          status: userPaused
              ? OfflineUnitStatus.paused
              : OfflineUnitStatus.queued,
          speedBps: 0,
        ),
      );
    } finally {
      _preempting.remove(id);
    }
  }

  Future<void> cancel(DownloadUnit unit) async {
    _retryTimers.remove(unit.id)?.cancel();
    await McDownloadChannel.cancel(unit.id);
    await _subs.remove(unit.id)?.cancel();
    _lastTick.remove(unit.id);
    if (_activeDownloadId == unit.id) _activeDownloadId = null;
    if (_preparingId == unit.id) _preparingId = null;

    final task = _allTasks.remove(unit.id);
    if (task != null) {
      await McDownloadChannel.removePartial(task.savePath);
      final file = File(task.savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await _cleanupUnitDiskDir(task);
      await _persistTasks();
    }
    state = state.copyWith(
      units: state.units.where((u) => u.id != unit.id).toList(),
    );
    unawaited(refreshStorage());
    unawaited(_scheduleNext());
  }

  /// 优先下载（带抢占）：把目标单元移到队头；若目标可立即下载且与当前正在下载的不同，
  /// 立即暂停当前下载（保留 `.part` 续传进度并退回 `queued`），马上开始新的队头！
  void prioritize(DownloadUnit unit) {
    unawaited(_prioritizeAsync(unit));
  }

  Future<void> _prioritizeAsync(DownloadUnit unit) async {
    final active = state.activeUnits;
    final orderedIds = <String>[
      unit.id,
      for (final u in active)
        if (u.id != unit.id) u.id,
    ];
    final task = _allTasks[unit.id];
    if (task != null &&
        (unit.status == OfflineUnitStatus.paused ||
            (unit.status == OfflineUnitStatus.failed &&
                !unit.waitingForTranscode))) {
      task.paused = false;
      final nextStatus = task.needsPrepare
          ? OfflineUnitStatus.preparing
          : OfflineUnitStatus.queued;
      _patch(
        unit.id,
        (u) => u.copyWith(
          status: nextStatus,
          clearError: true,
          clearTranscodeWait: true,
        ),
      );
    }
    await _applyQueueOrder(orderedIds);
  }

  /// 拖拽调整下载顺序（带抢占）：队头变更时立即暂停当前活动任务并切换到新队头。
  void reorder(int oldIndex, int newIndex) {
    final active = state.activeUnits;
    if (oldIndex < 0 || oldIndex >= active.length) return;
    final moved = active[oldIndex];
    final order = [...active]..removeAt(oldIndex);
    var target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (target > order.length) target = order.length;
    if (target < 0) target = 0;
    order.insert(target, moved);
    unawaited(_applyQueueOrder([for (final u in order) u.id]));
  }

  Future<void> _applyQueueOrder(List<String> orderedActiveIds) async {
    final orderMap = <String, double>{};
    final priorityMap = <String, int>{};
    for (var i = 0; i < orderedActiveIds.length; i++) {
      final id = orderedActiveIds[i];
      orderMap[id] = i.toDouble();
      priorityMap[id] = orderedActiveIds.length - i;
    }

    state = state.copyWith(
      units: state.units.map((u) {
        if (!orderMap.containsKey(u.id)) return u;
        return u.copyWith(
          queueOrder: orderMap[u.id],
          priority: priorityMap[u.id],
        );
      }).toList(),
    );

    for (final entry in orderMap.entries) {
      final t = _allTasks[entry.key];
      if (t != null) {
        t.queueOrder = entry.value;
        t.priority = priorityMap[entry.key]!;
      }
    }
    await _persistTasks();

    // 抢占判定：按新顺序排在最前的可执行单元不是当前正在下的单元 → 暂停当前，立即切新队头。
    final candidates = state.units
        .where(
          (u) =>
              u.status == OfflineUnitStatus.queued ||
              u.status == OfflineUnitStatus.running,
        )
        .toList()
      ..sort(OfflineState._compareQueueOrder);
    final newHead = candidates.isNotEmpty ? candidates.first : null;
    if (newHead != null &&
        _activeDownloadId != null &&
        _activeDownloadId != newHead.id) {
      await _pauseUnit(_activeDownloadId!, userPaused: false);
    }
    await _scheduleNext();
  }

  // MARK: - 蜂窝策略

  Future<void> setAllowCellular(bool value) async {
    state = state.copyWith(allowCellular: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cellularKey, value);
    await McDownloadChannel.setAllowCellular(value);
    if (value) {
      _patchAll(OfflineUnitStatus.waitingWifi, OfflineUnitStatus.queued);
      unawaited(_scheduleNext());
    } else if (_activeDownloadId != null) {
      // 关掉蜂窝后若原生会话在蜂窝上运行，交由原生层与下次调度处理。
    }
  }

  void _patchAll(OfflineUnitStatus from, OfflineUnitStatus to) {
    state = state.copyWith(
      units: state.units
          .map((u) => u.status == from ? u.copyWith(status: to) : u)
          .toList(),
    );
  }

  // MARK: - 本地播放 / 离线进度 / OfflineViewings 补传

  String? localPlayUri(DownloadUnit unit) {
    final p = unit.savePath ?? _allTasks[unit.id]?.savePath;
    if (p == null || p.isEmpty) return null;
    final f = File(p);
    if (!f.existsSync()) return null;
    return f.uri.toString();
  }

  File? localImageFile(String? url) => OfflineImages.shared.localFileFor(url);

  Future<OfflinePlaybackSpec?> loadPlaybackSpec(DownloadUnit unit) async {
    final itemId = unit.mediaItemId ?? unit.fileId;
    final fileId = unit.fileId;
    if (itemId == null || fileId == null) return null;
    final ownerDir = await _ownerDir();
    final map = await OfflineDisk.readJsonMap(
      OfflineDisk.playbackFile(ownerDir, itemId, fileId),
    );
    return map == null ? null : OfflinePlaybackSpec.fromJson(map);
  }

  Future<Map<String, dynamic>?> loadItemDetailJson(int mediaItemId) async {
    final ownerDir = await _ownerDir();
    return OfflineDisk.readJsonMap(
      OfflineDisk.itemDetailFile(ownerDir, mediaItemId),
    );
  }

  Future<Map<String, dynamic>?> loadSeasonJson(
    int mediaItemId,
    int season,
  ) async {
    final ownerDir = await _ownerDir();
    return OfflineDisk.readJsonMap(
      OfflineDisk.seasonFile(ownerDir, mediaItemId, season),
    );
  }

  /// 创建本机离线播放观看记录器（播放器每秒 tick、暂停/退出自动落盘并补传）。
  Future<OfflineViewingRecorder?> createViewingRecorder({
    required DownloadUnit unit,
    required int startPositionMs,
    int? durationMs,
  }) async {
    final itemId = unit.mediaItemId;
    final fileId = unit.fileId;
    if (itemId == null || fileId == null) return null;
    final ownerDir = await _ownerDir();
    return OfflineViewingRecorder(
      ownerDir: ownerDir,
      mediaItemId: itemId,
      season: unit.seasonNumber,
      episode: unit.episodeNumber,
      fileId: fileId,
      startPositionMs: startPositionMs,
      durationMs: durationMs,
      client: ref.read(offlineClientProvider),
      onProgressUpdated: (prog) => recordLocalProgress(
        mediaItemId: itemId,
        season: unit.seasonNumber,
        episode: unit.episodeNumber,
        positionMs: prog.positionMs,
        played: prog.played,
        durationMs: prog.durationMs,
      ),
    );
  }

  /// 写入本机续播进度到 `progress.json` 并同步更新「已看完」标记。
  Future<void> recordLocalProgress({
    required int mediaItemId,
    required int season,
    required int episode,
    required int positionMs,
    required bool played,
    int? durationMs,
  }) async {
    if (mediaItemId <= 0) return;
    final ownerDir = await _ownerDir();
    final key = '$season-$episode';
    final existing = Map<String, OfflineProgress>.from(
      state.progressByItem[mediaItemId] ?? const {},
    );
    existing[key] = OfflineProgress(
      positionMs: positionMs,
      played: played,
      durationMs: durationMs,
      updatedAt: DateTime.now().toUtc(),
    );
    final nextMap = Map<int, Map<String, OfflineProgress>>.from(
      state.progressByItem,
    )..[mediaItemId] = existing;

    final updatedUnits = state.units.map((u) {
      if (u.mediaItemId == mediaItemId &&
          u.seasonNumber == season &&
          u.episodeNumber == episode &&
          played &&
          !u.watched) {
        final t = _allTasks[u.id];
        if (t != null) t.watched = true;
        return u.copyWith(watched: true);
      }
      return u;
    }).toList();

    state = state.copyWith(
      units: updatedUnits,
      progressByItem: nextMap,
    );
    await OfflineDisk.writeJson(
      OfflineDisk.progressFile(ownerDir, mediaItemId),
      {for (final e in existing.entries) e.key: e.value.toJson()},
    );
    await _persistTasks();
  }

  /// 标记离线副本已看完：落盘到 `viewings/` 并通过 `POST /api/v1/playback/viewings` 持久化同步。
  Future<void> markUnitWatched(DownloadUnit unit, {bool watched = true}) async {
    final task = _allTasks[unit.id];
    if (task != null) {
      task.watched = watched;
      await _persistTasks();
      final itemId = task.mediaItemId;
      final fid = task.fileIdInt;
      if (itemId > 0) {
        await recordLocalProgress(
          mediaItemId: itemId,
          season: task.seasonNumber,
          episode: task.episodeNumber,
          positionMs: 0,
          played: watched,
        );
      }
      if (watched && fid > 0 && itemId > 0) {
        final ownerDir = await _ownerDir();
        await OfflineViewingUploader.shared.recordCompleted(
          ownerDir: ownerDir,
          mediaItemId: itemId,
          season: task.seasonNumber,
          episode: task.episodeNumber,
          fileId: fid,
          client: ref.read(offlineClientProvider),
        );
      }
    }
    _patch(unit.id, (u) => u.copyWith(watched: watched));
  }

  /// 立即将磁盘上待补传的本机观看记录发往 `POST /api/v1/playback/viewings`。
  Future<void> flushViewings() async {
    try {
      final ownerDir = await _ownerDir();
      await OfflineViewingUploader.shared.flush(
        client: ref.read(offlineClientProvider),
        ownerDir: ownerDir,
      );
    } catch (_) {}
  }

  // MARK: - 删除与清理

  Future<void> deleteDownloaded(DownloadUnit unit) async {
    final task = _allTasks.remove(unit.id);
    if (task != null) {
      final file = File(task.savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await McDownloadChannel.removePartial(task.savePath);
      await _cleanupUnitDiskDir(task);
      await _persistTasks();
    }
    state = state.copyWith(
      units: state.units.where((u) => u.id != unit.id).toList(),
    );
    unawaited(refreshStorage());
  }

  Future<void> deleteItem(int mediaItemId) async {
    final matching =
        state.units.where((u) => u.mediaItemId == mediaItemId).toList();
    for (final u in matching) {
      if (u.isActive) {
        await cancel(u);
      } else {
        await deleteDownloaded(u);
      }
    }
    final nextItems = Map<int, OfflineItemSummary>.from(state.items)
      ..remove(mediaItemId);
    final nextProg =
        Map<int, Map<String, OfflineProgress>>.from(state.progressByItem)
          ..remove(mediaItemId);
    OfflineImages.shared.forget(mediaItemId);
    state = state.copyWith(items: nextItems, progressByItem: nextProg);
  }

  Future<void> _cleanupUnitDiskDir(_StoredTask task) async {
    if (task.mediaItemId <= 0 || task.fileIdInt <= 0) return;
    final ownerDir = await _ownerDir();
    final remainingForItem = _allTasks.values
        .any((t) => t.ownerKey == task.ownerKey && t.mediaItemId == task.mediaItemId);
    if (!remainingForItem) {
      await OfflineDisk.removeDir(OfflineDisk.itemDir(ownerDir, task.mediaItemId));
      OfflineImages.shared.forget(task.mediaItemId);
    } else {
      await OfflineDisk.removeDir(
        OfflineDisk.unitDir(ownerDir, task.mediaItemId, task.fileIdInt),
      );
    }
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
    unawaited(refreshStorage());
  }

  /// 登出时清理当前账号全部本机离线下载。
  Future<void> deleteCurrentOwnerAll() async {
    final all = List<DownloadUnit>.from(state.units);
    for (final u in all) {
      if (u.isActive) {
        await cancel(u);
      } else {
        await deleteDownloaded(u);
      }
    }
    final ownerDir = await _ownerDir();
    await OfflineDisk.removeDir(ownerDir);
    OfflineImages.shared.reset();
    state = state.copyWith(units: const [], items: const {}, progressByItem: const {});
    unawaited(refreshStorage());
  }

  /// 退出全部设备时清理本机所有账号离线下载。
  Future<void> deleteAllOwners() async {
    await deleteCurrentOwnerAll();
    await clearOtherOwnersDownloads();
    final root = await McDownloadPaths.resolve();
    await OfflineDisk.removeDir(root);
    unawaited(refreshStorage());
  }

  // MARK: - 存储统计

  Future<Map<String, int>> downloadedFileBytes() async {
    final out = <String, int>{};
    for (final u in state.doneUnits) {
      final path = u.savePath ?? _allTasks[u.id]?.savePath;
      if (path == null) continue;
      final file = File(path);
      if (await file.exists()) {
        try {
          out[u.id] = await file.length();
        } catch (_) {}
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

  // MARK: - 工具

  DownloadUnit? _unit(String id) {
    for (final u in state.units) {
      if (u.id == id) return u;
    }
    return null;
  }

  void _patch(String id, DownloadUnit Function(DownloadUnit) fn) {
    state = state.copyWith(
      units: state.units.map((u) => u.id == id ? fn(u) : u).toList(),
    );
  }

  static String? _formatSeasonEpisode({
    required String kind,
    required int season,
    required int episode,
  }) {
    if (kind != 'tv' && season == 0 && episode == 0) return null;
    if (season == 0 && episode > 0) return '特别篇 第 $episode 集';
    if (season > 0 && episode > 0) return '第 $season 季 第 $episode 集';
    return null;
  }
}

final offlineProvider =
    NotifierProvider<OfflineController, OfflineState>(OfflineController.new);
