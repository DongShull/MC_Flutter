import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../../core/api/mc_client.dart';
import 'models.dart';
import 'offline_packager.dart';

/// 一次本机播放观看记录（对齐 iOS OfflineViewing / API PlaybackViewingRecordIn）。
/// 先原子落盘到 `viewings/<viewingId>.json`，在线时批量补传到 `POST /api/v1/playback/viewings`，
/// 收到 2xx 确认后才删除/清脏标记。
class OfflineViewingRecord {
  OfflineViewingRecord({
    required this.viewingId,
    required this.mediaItemId,
    required this.season,
    required this.episode,
    required this.fileId,
    required this.startedAt,
    required this.updatedAt,
    required this.startPositionMs,
    required this.positionMs,
    required this.watchedMs,
    required this.completed,
    required this.ended,
    this.durationMs,
    this.dirty = true,
    this.launch,
  });

  final String viewingId;
  final int mediaItemId;
  final int season;
  final int episode;
  final int fileId;
  final DateTime startedAt;
  DateTime updatedAt;
  final int startPositionMs;
  int positionMs;
  int watchedMs;
  bool completed;
  bool ended;
  int? durationMs;
  bool dirty;
  final String? launch;

  Map<String, dynamic> toDiskJson() => {
        'format': 1,
        'viewingId': viewingId,
        'mediaItemId': mediaItemId,
        'season': season,
        'episode': episode,
        'fileId': fileId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'startPositionMs': startPositionMs,
        'positionMs': positionMs,
        'watchedMs': watchedMs,
        'completed': completed,
        'ended': ended,
        if (durationMs != null) 'durationMs': durationMs,
        'dirty': dirty,
        if (launch != null) 'launch': launch,
      };

  /// 转换为服务端 `POST /api/v1/playback/viewings` 协议格式（snake_case）。
  Map<String, dynamic> toApiJson() => {
        'viewing_id': viewingId,
        'media_item_id': mediaItemId,
        'season_number': season,
        'episode_number': episode,
        'file_id': fileId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'start_position_ms': startPositionMs,
        'position_ms': positionMs,
        'watched_ms': watchedMs,
        'completed': completed,
        'ended': ended,
        if (durationMs != null) 'duration_ms': durationMs,
      };

  factory OfflineViewingRecord.fromDiskJson(Map<String, dynamic> j) =>
      OfflineViewingRecord(
        viewingId: (j['viewingId'] ?? '').toString(),
        mediaItemId: ((j['mediaItemId'] ?? 0) as num).toInt(),
        season: ((j['season'] ?? 0) as num).toInt(),
        episode: ((j['episode'] ?? 0) as num).toInt(),
        fileId: ((j['fileId'] ?? 0) as num).toInt(),
        startedAt: DateTime.tryParse(j['startedAt']?.toString() ?? '') ??
            DateTime.now().toUtc(),
        updatedAt: DateTime.tryParse(j['updatedAt']?.toString() ?? '') ??
            DateTime.now().toUtc(),
        startPositionMs: ((j['startPositionMs'] ?? 0) as num).toInt(),
        positionMs: ((j['positionMs'] ?? 0) as num).toInt(),
        watchedMs: ((j['watchedMs'] ?? 0) as num).toInt(),
        completed: j['completed'] == true,
        ended: j['ended'] == true,
        durationMs: (j['durationMs'] as num?)?.toInt(),
        dirty: j['dirty'] != false,
        launch: j['launch']?.toString(),
      );

  bool sameSnapshot(OfflineViewingRecord other) =>
      viewingId == other.viewingId &&
      positionMs == other.positionMs &&
      watchedMs == other.watchedMs &&
      completed == other.completed &&
      ended == other.ended &&
      updatedAt.toUtc().toIso8601String() ==
          other.updatedAt.toUtc().toIso8601String();
}

/// 本机播放观看记录器（对齐 iOS OfflineViewingRecorder）：
/// - 每 10 秒 / 暂停 / 停止时落盘 `viewings/<id>.json`；
/// - 使用与服务端 `resolve_progress` 完全一致的阈值（<5% 不记续播点、>=90% 或距片尾 <=1s 标为已看完）；
/// - 同步更新本机 `progress.json` 并在在线时触发 `OfflineViewingUploader.flush`。
class OfflineViewingRecorder {
  OfflineViewingRecorder({
    required this.ownerDir,
    required int mediaItemId,
    required int season,
    required int episode,
    required int fileId,
    required int startPositionMs,
    int? durationMs,
    this.client,
    this.onProgressUpdated,
  }) : _record = OfflineViewingRecord(
          viewingId: generateUuidV4(),
          mediaItemId: mediaItemId,
          season: season,
          episode: episode,
          fileId: fileId,
          startedAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          startPositionMs: startPositionMs,
          positionMs: startPositionMs,
          watchedMs: 0,
          completed: false,
          ended: false,
          durationMs: durationMs,
          dirty: true,
          launch: OfflineViewingUploader.launchId,
        );

  final Directory ownerDir;
  final McClient? client;
  final Future<void> Function(OfflineProgress progress)? onProgressUpdated;

  final OfflineViewingRecord _record;
  DateTime? _lastTick;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  bool _currentlyPlayed = false;

  String get viewingId => _record.viewingId;

  /// 与服务端 `movieclaw_playback/progress.py resolve_progress` 完全一致的阈值：
  /// - 不足 5% 不记续播点；
  /// - >= 90% 或离片尾 <= 1 秒自动标为已看完（completed = true）；
  /// - 短于 5 分钟的视频过了 5% 即视为看完。
  static ({int positionMs, bool played}) resolveProgress({
    required int? positionMs,
    required int? runtimeMs,
    required bool currentlyPlayed,
  }) {
    if (positionMs == null) return (positionMs: 0, played: true);
    if (positionMs <= 0) return (positionMs: 0, played: currentlyPlayed);
    if (runtimeMs == null || runtimeMs <= 0) {
      return (positionMs: 0, played: true);
    }
    final pct = positionMs / runtimeMs * 100.0;
    if (pct < 5.0) return (positionMs: 0, played: currentlyPlayed);
    if (pct >= 90.0 || positionMs >= runtimeMs - 1000) {
      return (positionMs: 0, played: true);
    }
    if (runtimeMs < 300000) return (positionMs: 0, played: true);
    return (positionMs: positionMs, played: currentlyPlayed);
  }

  /// 播放器每秒回调一次：仅在播放中累计墙钟观看时长 `watchedMs`。
  Future<void> tick({
    required int positionMs,
    required bool playing,
    int? durationMs,
  }) async {
    final now = DateTime.now().toUtc();
    final wasPlaying = _lastTick != null;
    if (playing && _lastTick != null) {
      final delta = now.difference(_lastTick!).inMilliseconds;
      if (delta > 0) _record.watchedMs += delta;
    }
    _lastTick = playing ? now : null;
    if (wasPlaying && !playing) {
      _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
    }
    _record.positionMs = positionMs;
    _record.updatedAt = now;
    if (durationMs != null && durationMs > 0) {
      _record.durationMs = durationMs;
    }
    if (_record.durationMs != null && _record.durationMs! > 0) {
      final pct = positionMs / _record.durationMs! * 100.0;
      if (pct >= 90.0 || positionMs >= _record.durationMs! - 1000) {
        _record.completed = true;
      }
    }
    _record.dirty = true;
    if (now.difference(_lastSave).inSeconds >= 10) {
      await _save(send: true);
    }
  }

  Future<void> checkpoint() => _save(send: true);

  Future<void> finish({required int positionMs, bool completed = false}) async {
    final now = DateTime.now().toUtc();
    _record.positionMs = positionMs;
    if (_record.durationMs != null && _record.durationMs! > 0) {
      final pct = positionMs / _record.durationMs! * 100.0;
      if (pct >= 90.0 || positionMs >= _record.durationMs! - 1000) {
        _record.completed = true;
      }
    }
    _record.completed = _record.completed || completed;
    _record.ended = true;
    _record.updatedAt = now;
    _record.dirty = true;
    await _save(send: true);
  }

  Future<void> _save({required bool send}) async {
    _lastSave = DateTime.now().toUtc();
    final outcome = resolveProgress(
      positionMs: _record.completed ? null : _record.positionMs,
      runtimeMs: _record.durationMs,
      currentlyPlayed: _currentlyPlayed,
    );
    _currentlyPlayed = outcome.played;
    final localProgress = OfflineProgress(
      positionMs: outcome.positionMs,
      played: outcome.played,
      durationMs: _record.durationMs,
      updatedAt: _record.updatedAt,
    );
    await OfflineDisk.writeJson(
      OfflineDisk.viewingFile(ownerDir, _record.viewingId),
      _record.toDiskJson(),
    );
    await onProgressUpdated?.call(localProgress);
    if (send && client != null) {
      unawaited(
        OfflineViewingUploader.shared.flush(client: client!, ownerDir: ownerDir),
      );
    }
  }

  static final Random _rng = Random.secure();

  static String generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
    return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
        '${hex(4)}${hex(5)}-'
        '${hex(6)}${hex(7)}-'
        '${hex(8)}${hex(9)}-'
        '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
  }
}

/// 离线观看记录批量补传器（对齐 iOS OfflineViewingUploader）：
/// - 单并发防重入，收到新记录后自动再跑一轮；
/// - 每批最多 100 条发往 `POST /api/v1/playback/viewings`；
/// - 必须收到 2xx 且服务端返回 `results[].viewing_id` 确认后才清理磁盘文件，永不丢记录。
class OfflineViewingUploader {
  OfflineViewingUploader._();

  static final OfflineViewingUploader shared = OfflineViewingUploader._();

  /// 本次启动标识：用于识别上次崩溃/强退遗留的未结束播放记录并在补传前自动收尾。
  static final String launchId = OfflineViewingRecorder.generateUuidV4();

  bool _inFlight = false;
  bool _again = false;

  /// 手动标已看时写入一条已完成观看记录并立即尝试补传（离线时留在盘上等联网补传）。
  Future<void> recordCompleted({
    required Directory ownerDir,
    required int mediaItemId,
    required int season,
    required int episode,
    required int fileId,
    int? durationMs,
    McClient? client,
  }) async {
    final now = DateTime.now().toUtc();
    final record = OfflineViewingRecord(
      viewingId: OfflineViewingRecorder.generateUuidV4(),
      mediaItemId: mediaItemId,
      season: season,
      episode: episode,
      fileId: fileId,
      startedAt: now,
      updatedAt: now,
      startPositionMs: 0,
      positionMs: durationMs ?? 0,
      watchedMs: durationMs ?? 0,
      completed: true,
      ended: true,
      durationMs: durationMs,
      dirty: true,
      launch: launchId,
    );
    await OfflineDisk.writeJson(
      OfflineDisk.viewingFile(ownerDir, record.viewingId),
      record.toDiskJson(),
    );
    if (client != null) {
      unawaited(flush(client: client, ownerDir: ownerDir));
    }
  }

  Future<void> flush({
    required McClient client,
    required Directory ownerDir,
  }) async {
    if (_inFlight) {
      _again = true;
      return;
    }
    _inFlight = true;
    try {
      do {
        _again = false;
        await _send(client: client, ownerDir: ownerDir);
      } while (_again);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _send({
    required McClient client,
    required Directory ownerDir,
  }) async {
    final dir = OfflineDisk.viewingsDir(ownerDir);
    if (!await dir.exists()) return;

    final records = <OfflineViewingRecord>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final map = await OfflineDisk.readJsonMap(entity);
      if (map == null) continue;
      final rec = OfflineViewingRecord.fromDiskJson(map);
      if (rec.viewingId.isEmpty || rec.mediaItemId <= 0) continue;
      if (!rec.ended && rec.launch != launchId) {
        rec.ended = true;
        rec.dirty = true;
        try {
          await OfflineDisk.writeJson(entity, rec.toDiskJson());
        } catch (_) {}
      }
      if (rec.dirty) records.add(rec);
    }
    if (records.isEmpty) return;

    // 每批最多 100 条发送至 POST /api/v1/playback/viewings
    for (var i = 0; i < records.length; i += 100) {
      final end = (i + 100 > records.length) ? records.length : i + 100;
      final batch = records.sublist(i, end);
      try {
        final res = await client.unwrap<Map<String, dynamic>>(
          Channel.general,
          'POST',
          '/api/v1/playback/viewings',
          body: {
            'sent_at': DateTime.now().toUtc().toIso8601String(),
            'records': [for (final r in batch) r.toApiJson()],
          },
        );
        final acknowledged = <String>{};
        final rawResults = (res['results'] as List?) ?? const [];
        for (final item in rawResults.whereType<Map>()) {
          final id = (item['viewing_id'] ?? item['viewingId'])?.toString();
          if (id != null && id.isNotEmpty) acknowledged.add(id);
        }
        // 兼容返回空对象但 HTTP 2xx 的服务端实现：若 results 字段不存在且无异常则视整批确认。
        if (acknowledged.isEmpty && !res.containsKey('results')) {
          acknowledged.addAll(batch.map((r) => r.viewingId));
        }

        var hasNewer = false;
        for (final sent in batch) {
          if (!acknowledged.contains(sent.viewingId)) continue;
          final file = OfflineDisk.viewingFile(ownerDir, sent.viewingId);
          final latestMap = await OfflineDisk.readJsonMap(file);
          if (latestMap == null) continue;
          final current = OfflineViewingRecord.fromDiskJson(latestMap);
          if (!current.sameSnapshot(sent)) {
            hasNewer = true;
            continue;
          }
          if (current.ended) {
            try {
              await file.delete();
            } catch (_) {}
          } else {
            current.dirty = false;
            try {
              await OfflineDisk.writeJson(file, current.toDiskJson());
            } catch (_) {}
          }
        }
        if (hasNewer) _again = true;
      } catch (_) {
        // 网络不可达或非 2xx：保留磁盘文件，等待下次联网重试。
        return;
      }
    }
  }

  /// 查询指定条目/集是否仍有未确认的本机观看记录（避免在线进度覆盖本机新进度）。
  Future<bool> hasPending({
    required Directory ownerDir,
    required int mediaItemId,
    required int season,
    required int episode,
  }) async {
    final dir = OfflineDisk.viewingsDir(ownerDir);
    if (!await dir.exists()) return false;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final map = await OfflineDisk.readJsonMap(entity);
      if (map == null) continue;
      final rec = OfflineViewingRecord.fromDiskJson(map);
      if (rec.dirty &&
          rec.mediaItemId == mediaItemId &&
          rec.season == season &&
          rec.episode == episode) {
        return true;
      }
    }
    return false;
  }
}
