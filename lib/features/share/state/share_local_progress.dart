import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 分享访客本机续播进度与轨道偏好（1:1 对齐 iOS `ShareLocalProgress` / Web `local-progress.ts`）：
/// 访客没有成员身份，播放进度绝不落服务端，按 `slug + mediaItemId + season x episode` 存在本机 `SharedPreferences`。
class ShareLocalProgressRecord {
  const ShareLocalProgressRecord({
    required this.positionMs,
    this.audioTrack,
    this.subtitleTrack,
    required this.updatedAt,
  });

  final int positionMs;
  final String? audioTrack;
  final String? subtitleTrack;
  final double updatedAt;

  Map<String, dynamic> toJson() => {
        'positionMs': positionMs,
        if (audioTrack != null) 'audioTrack': audioTrack,
        if (subtitleTrack != null) 'subtitleTrack': subtitleTrack,
        'updatedAt': updatedAt,
      };

  factory ShareLocalProgressRecord.fromJson(Map<String, dynamic> j) =>
      ShareLocalProgressRecord(
        positionMs: ((j['positionMs'] ?? 0) as num).toInt(),
        audioTrack: j['audioTrack']?.toString(),
        subtitleTrack: j['subtitleTrack']?.toString(),
        updatedAt: ((j['updatedAt'] ?? 0) as num).toDouble(),
      );
}

abstract final class ShareLocalProgress {
  static String _key(
    String slug,
    int mediaItemId,
    int season,
    int episode,
  ) =>
      'movieclaw.share.progress.$slug.$mediaItemId.${season}x$episode';

  static Future<ShareLocalProgressRecord?> read({
    required String slug,
    required int mediaItemId,
    int season = 0,
    int episode = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(slug, mediaItemId, season, episode));
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

  static Future<void> write({
    required String slug,
    required int mediaItemId,
    int season = 0,
    int episode = 0,
    int? positionMs,
    String? audioTrack,
    String? subtitleTrack,
  }) async {
    final previous = await read(
      slug: slug,
      mediaItemId: mediaItemId,
      season: season,
      episode: episode,
    );
    final pos = positionMs ?? previous?.positionMs ?? 0;
    final record = ShareLocalProgressRecord(
      positionMs: pos < 0 ? 0 : pos,
      audioTrack: audioTrack ?? previous?.audioTrack,
      subtitleTrack: subtitleTrack ?? previous?.subtitleTrack,
      updatedAt: DateTime.now().millisecondsSinceEpoch / 1000.0,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(slug, mediaItemId, season, episode),
      jsonEncode(record.toJson()),
    );
  }
}

/// 分享链接工具集（1:1 对齐 iOS `ShareLinkKit` / `ShareItemView` 格式化口径）。
abstract final class ShareLinkKit {
  /// 相对到期倒计时：「3 天后失效」/「5 小时后失效」/「12 分钟后失效」/「已失效」。
  static String expiryHint(String? expiresAt, {DateTime? now}) {
    if (expiresAt == null || expiresAt.trim().isEmpty) return '长期有效';
    final date = DateTime.tryParse(expiresAt.trim());
    if (date == null) return '已失效';
    final ref = now ?? DateTime.now().toUtc();
    final remainingSeconds = date.toUtc().difference(ref).inSeconds;
    if (remainingSeconds <= 0) return '已失效';
    final hours = remainingSeconds / 3600.0;
    if (hours >= 47) return '${(hours / 24.0).round()} 天后失效';
    if (hours >= 1) return '${hours.floor()} 小时后失效';
    final mins = (remainingSeconds / 60.0).floor();
    return '${mins < 1 ? 1 : mins} 分钟后失效';
  }

  /// 分辨率文案（同 Web `formatVideoResolution`）。
  static String resolutionLabel(String resolution) {
    final normalized = resolution.trim().toLowerCase();
    final allDigits =
        normalized.isNotEmpty && RegExp(r'^\d+$').hasMatch(normalized);
    final key = allDigits ? '${normalized}p' : normalized;
    const labels = {
      '4320p': '8K',
      '2160p': '4K',
      '1440p': '2K',
      '1080p': '1080p',
      '720p': '720p',
      '4k': '4K',
      '2k': '2K',
    };
    return labels[key] ?? resolution;
  }

  /// 片长文案（「52 分钟」/「2 小时 8 分钟」）。
  static String runtimeLabel(int minutes) {
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest > 0 ? '$hours 小时 $rest 分钟' : '$hours 小时';
  }

  /// 解析 `/s/:slug/play/:unit` 的 unit 段（如 `s01e05` / `S1E5` / `movie`）。
  static ({int? season, int? episode}) parsePlayUnit(String? unit) {
    if (unit == null || unit.trim().isEmpty) {
      return (season: null, episode: null);
    }
    final m = RegExp(r'^s(\d+)e(\d+)$', caseSensitive: false)
        .firstMatch(unit.trim());
    if (m != null) {
      return (
        season: int.tryParse(m.group(1)!),
        episode: int.tryParse(m.group(2)!),
      );
    }
    return (season: null, episode: null);
  }
}
