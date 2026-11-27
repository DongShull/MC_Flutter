import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/server_routes.dart';

/// 播放网络环境（用于 `QualityMemory` 按片 + 按路由分记忆）。
enum PlaybackRouteEnv {
  home,
  away,
  unknown;

  String? get label => switch (this) {
        PlaybackRouteEnv.home => '内网',
        PlaybackRouteEnv.away => '外网',
        PlaybackRouteEnv.unknown => null,
      };

  static PlaybackRouteEnv current() {
    switch (ServerRoutes.instance.routeKind) {
      case RouteKind.lan:
        return PlaybackRouteEnv.home;
      case RouteKind.wan:
      case RouteKind.vpn:
        return PlaybackRouteEnv.away;
      case null:
        return PlaybackRouteEnv.unknown;
    }
  }
}

/// 持久化字幕样式偏好（字号比例 / 距底百分比 / 半透明黑底胶囊开关 / 时间轴偏移毫秒）。
@immutable
class SubtitleStylePrefs {
  const SubtitleStylePrefs({
    this.fontScale = 1.0,
    this.bottomMarginPercent = 8.0,
    this.backgroundPill = true,
    this.offsetMs = 0,
  });

  factory SubtitleStylePrefs.fromJson(Map<String, dynamic> json) {
    return SubtitleStylePrefs(
      fontScale: ((json['fontScale'] as num?)?.toDouble() ?? 1.0)
          .clamp(0.75, 1.6),
      bottomMarginPercent:
          ((json['bottomMarginPercent'] as num?)?.toDouble() ?? 8.0)
              .clamp(2.0, 28.0),
      backgroundPill: json['backgroundPill'] as bool? ?? true,
      offsetMs: (json['offsetMs'] as num?)?.toInt() ?? 0,
    );
  }

  final double fontScale;
  final double bottomMarginPercent;
  final bool backgroundPill;
  final int offsetMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fontScale': fontScale,
        'bottomMarginPercent': bottomMarginPercent,
        'backgroundPill': backgroundPill,
        'offsetMs': offsetMs,
      };

  SubtitleStylePrefs copyWith({
    double? fontScale,
    double? bottomMarginPercent,
    bool? backgroundPill,
    int? offsetMs,
  }) {
    return SubtitleStylePrefs(
      fontScale: (fontScale ?? this.fontScale).clamp(0.75, 1.6),
      bottomMarginPercent:
          (bottomMarginPercent ?? this.bottomMarginPercent).clamp(2.0, 28.0),
      backgroundPill: backgroundPill ?? this.backgroundPill,
      offsetMs: (offsetMs ?? this.offsetMs).clamp(-30000, 30000),
    );
  }
}

/// 访客分享本机续播记录（按 `shareSlug + mediaItemId + season + episode` 隔离）。
@immutable
class ShareLocalProgressRecord {
  const ShareLocalProgressRecord({
    required this.positionMs,
    this.audioTrack,
    this.subtitleTrack,
    required this.updatedAtMs,
  });

  factory ShareLocalProgressRecord.fromJson(Map<String, dynamic> json) {
    return ShareLocalProgressRecord(
      positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
      audioTrack: json['audioTrack']?.toString(),
      subtitleTrack: json['subtitleTrack']?.toString(),
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  final int positionMs;
  final String? audioTrack;
  final String? subtitleTrack;
  final int updatedAtMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'positionMs': positionMs,
        if (audioTrack != null) 'audioTrack': audioTrack,
        if (subtitleTrack != null) 'subtitleTrack': subtitleTrack,
        'updatedAtMs': updatedAtMs,
      };
}

/// 播放器本机持久化偏好（对齐 `PlayerPreferences.swift`）：
/// - `deviceId`：活动页区分设备会话的稳定标识；
/// - `QualityMemory`：按「影片 + 网络环境（home/away）」记画质上限（最多 300 条 LRU）；
/// - `SpeedMemory`：按影片记倍速（最多 300 条 LRU）；
/// - `SubtitleStylePrefs`：持久化字幕样式；
/// - `ShareLocalProgress`：访客分享本机进度与轨道记忆。
class PlayerPreferences {
  PlayerPreferences._();

  static final PlayerPreferences instance = PlayerPreferences._();

  static const int maxMemoryEntries = 300;
  static const _kDeviceId = 'movieclaw.player.device-id';
  static const _kSubtitleStyle = 'movieclaw.player.subtitle-style';
  static const _kQualityByTitle = 'movieclaw.player.quality-by-title';
  static const _kSpeedByTitle = 'movieclaw.player.speed-by-title';
  static const _kShareProgressPrefix = 'movieclaw.share.progress.';

  SharedPreferences? _prefs;
  String? _deviceId;
  SubtitleStylePrefs _subtitleStyle = const SubtitleStylePrefs();

  Future<SharedPreferences?> _ensurePrefs() async {
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
    return _prefs;
  }

  /// 初始化并加载常用缓存。
  Future<void> ensureLoaded() async {
    final prefs = await _ensurePrefs();
    if (prefs == null) return;
    _deviceId = prefs.getString(_kDeviceId);
    if (_deviceId == null ||
        !RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(_deviceId!)) {
      _deviceId = _generateDeviceId();
      await prefs.setString(_kDeviceId, _deviceId!);
    }
    final rawStyle = prefs.getString(_kSubtitleStyle);
    if (rawStyle != null && rawStyle.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawStyle);
        if (decoded is Map) {
          _subtitleStyle = SubtitleStylePrefs.fromJson(
            decoded.cast<String, dynamic>(),
          );
        }
      } catch (_) {}
    }
  }

  String get deviceId {
    _deviceId ??= _generateDeviceId();
    return _deviceId!;
  }

  SubtitleStylePrefs get subtitleStyle => _subtitleStyle;

  Future<void> saveSubtitleStyle(SubtitleStylePrefs style) async {
    _subtitleStyle = style;
    final prefs = await _ensurePrefs();
    await prefs?.setString(_kSubtitleStyle, jsonEncode(style.toJson()));
  }

  // ── QualityMemory（按片 + 按路由环境，最多 300 条 LRU） ────────────────

  Future<String?> getQualityTier({
    required int mediaItemId,
    required PlaybackRouteEnv route,
  }) async {
    final prefs = await _ensurePrefs();
    if (prefs == null) return null;
    final entries = _readTimedMap(prefs, _kQualityByTitle);
    final key = '${route.name}:$mediaItemId';
    final entry = entries[key];
    if (entry == null) return null;
    final h = entry.$1.round();
    return switch (h) {
      1080 => '1080p',
      720 => '720p',
      480 => '480p',
      _ => null,
    };
  }

  Future<void> rememberQualityTier({
    required int mediaItemId,
    required PlaybackRouteEnv route,
    required String? tier,
  }) async {
    final prefs = await _ensurePrefs();
    if (prefs == null) return;
    final entries = _readTimedMap(prefs, _kQualityByTitle);
    final key = '${route.name}:$mediaItemId';
    final height = switch (tier) {
      '1080p' => 1080.0,
      '720p' => 720.0,
      '480p' => 480.0,
      _ => null,
    };
    if (height == null) {
      entries.remove(key);
    } else {
      entries[key] = (
        height,
        DateTime.now().millisecondsSinceEpoch.toDouble(),
      );
      _pruneLru(entries);
    }
    await _writeTimedMap(prefs, _kQualityByTitle, entries);
  }

  // ── SpeedMemory（按片，最多 300 条 LRU） ────────────────────────────────

  Future<double?> getSpeed({required int mediaItemId}) async {
    final prefs = await _ensurePrefs();
    if (prefs == null) return null;
    final entries = _readTimedMap(prefs, _kSpeedByTitle);
    final entry = entries['$mediaItemId'];
    if (entry == null) return null;
    final speed = entry.$1;
    if (speed == 1.0 || speed < 0.5 || speed > 2.0) return null;
    return speed;
  }

  Future<void> rememberSpeed({
    required int mediaItemId,
    required double speed,
  }) async {
    final prefs = await _ensurePrefs();
    if (prefs == null) return;
    final entries = _readTimedMap(prefs, _kSpeedByTitle);
    final key = '$mediaItemId';
    if ((speed - 1.0).abs() < 0.01) {
      entries.remove(key);
    } else {
      entries[key] = (
        speed,
        DateTime.now().millisecondsSinceEpoch.toDouble(),
      );
      _pruneLru(entries);
    }
    await _writeTimedMap(prefs, _kSpeedByTitle, entries);
  }

  // ── ShareLocalProgress ──────────────────────────────────────────────────

  String _shareKey(
    String shareSlug,
    int mediaItemId,
    int season,
    int episode,
  ) =>
      '$_kShareProgressPrefix$shareSlug.$mediaItemId.${season}x$episode';

  Future<ShareLocalProgressRecord?> readShareProgress({
    required String shareSlug,
    required int mediaItemId,
    int season = 0,
    int episode = 0,
  }) async {
    final prefs = await _ensurePrefs();
    final raw = prefs?.getString(_shareKey(shareSlug, mediaItemId, season, episode));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return ShareLocalProgressRecord.fromJson(
          decoded.cast<String, dynamic>(),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> writeShareProgress({
    required String shareSlug,
    required int mediaItemId,
    int season = 0,
    int episode = 0,
    int? positionMs,
    int? durationMs,
    String? audioTrack,
    String? subtitleTrack,
  }) async {
    final prefs = await _ensurePrefs();
    if (prefs == null) return;
    final prev = await readShareProgress(
      shareSlug: shareSlug,
      mediaItemId: mediaItemId,
      season: season,
      episode: episode,
    );
    var resolvedPos = positionMs ?? prev?.positionMs ?? 0;
    if (durationMs != null &&
        durationMs > 0 &&
        (resolvedPos * 10 >= durationMs * 9 || resolvedPos >= durationMs - 1000)) {
      resolvedPos = 0;
    }
    final record = ShareLocalProgressRecord(
      positionMs: math.max(0, resolvedPos),
      audioTrack: audioTrack ?? prev?.audioTrack,
      subtitleTrack: subtitleTrack ?? prev?.subtitleTrack,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(
      _shareKey(shareSlug, mediaItemId, season, episode),
      jsonEncode(record.toJson()),
    );
  }

  // ── 内部工具 ────────────────────────────────────────────────────────────

  Map<String, (double, double)> _readTimedMap(
    SharedPreferences prefs,
    String key,
  ) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, (double, double)>{};
      decoded.forEach((k, v) {
        if (v is List && v.length >= 2) {
          final a = (v[0] as num?)?.toDouble();
          final b = (v[1] as num?)?.toDouble();
          if (a != null && b != null) {
            out[k.toString()] = (a, b);
          }
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeTimedMap(
    SharedPreferences prefs,
    String key,
    Map<String, (double, double)> map,
  ) async {
    final encoded = <String, List<double>>{
      for (final e in map.entries) e.key: [e.value.$1, e.value.$2],
    };
    await prefs.setString(key, jsonEncode(encoded));
  }

  void _pruneLru(Map<String, (double, double)> map) {
    if (map.length <= maxMemoryEntries) return;
    final sortedKeys = map.keys.toList()
      ..sort((a, b) => map[a]!.$2.compareTo(map[b]!.$2));
    final toRemove = map.length - maxMemoryEntries;
    for (var i = 0; i < toRemove; i++) {
      map.remove(sortedKeys[i]);
    }
  }

  static String _generateDeviceId() {
    final rng = math.Random.secure();
    final bytes = List<int>.generate(10, (_) => rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'flutter-$hex';
  }
}
