import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/server_routes.dart';

/// 片段画质选项（对齐 iOS `ReelsQuality.swift`）。
class ReelQualityOption {
  const ReelQualityOption({
    required this.maxHeight,
    required this.label,
    required this.hint,
  });

  /// `null` = 原画（直出原文件），其余为转码上限高度（1080 / 720 / 480）。
  final int? maxHeight;
  final String label;
  final String hint;

  static const List<ReelQualityOption> all = [
    ReelQualityOption(maxHeight: null, label: '原画', hint: '直出原片，最快起播'),
    ReelQualityOption(maxHeight: 1080, label: '1080p', hint: '高清转码，约 6 Mbps'),
    ReelQualityOption(maxHeight: 720, label: '720p', hint: '流畅省流，约 3 Mbps'),
    ReelQualityOption(maxHeight: 480, label: '480p', hint: '弱网极速，约 1.5 Mbps'),
  ];
}

/// 四象限网络画质决策与持久化（`home`/`away` × `wifi`/`cellular`，对齐 `ReelsQuality.swift`）：
/// - 内网 Wi-Fi（`home_wifi` / `wifi`）：默认原画（`null`）；
/// - 外网或蜂窝（`away_wifi` / `away_cellular` / `home_cellular` / `cellular`）：默认 `720p`；
/// - 用户手动切换后按当前四象限网络键持久化（`0` 表示用户明确选了原画，与「未选过走默认」区分）。
class ReelsQuality {
  const ReelsQuality._();

  static const _prefKey = 'movieclaw.reels.quality-by-network';

  static String label(int? maxHeight) {
    for (final opt in ReelQualityOption.all) {
      if (opt.maxHeight == maxHeight) return opt.label;
    }
    return maxHeight == null ? '原画' : '${maxHeight}p';
  }

  /// 当前四象限网络键：`home_wifi` | `home_cellular` | `away_wifi` | `away_cellular`
  static Future<String> currentNetworkKey() async {
    final route = ServerRoutes.instance.routeKind;
    final snap = await NetworkSnapshot.current();
    final isCellularOnly = snap.cellular && snap.physical.isEmpty;
    final link = isCellularOnly ? 'cellular' : 'wifi';
    final env = switch (route) {
      RouteKind.lan => 'home',
      RouteKind.wan || RouteKind.vpn => 'away',
      null => isCellularOnly ? 'away' : 'home',
    };
    return '${env}_$link';
  }

  /// 读取当前网络象限对应的画质上限（`null` = 原画）。
  static Future<int?> current() async {
    final key = await currentNetworkKey();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded.containsKey(key)) {
          final v = (decoded[key] as num?)?.toInt();
          if (v != null) return v > 0 ? v : null;
        }
      }
    } catch (_) {}
    // 外网或蜂窝默认 720p，家里 Wi-Fi 默认原画
    if (key.startsWith('away_') || key.endsWith('_cellular')) {
      return 720;
    }
    return null;
  }

  /// 持久化当前网络象限的画质选择（`null` 存为 `0` 以便覆盖外网默认 720p）。
  static Future<void> remember(int? maxHeight) async {
    final key = await currentNetworkKey();
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, int>{};
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is num) map[k.toString()] = v.toInt();
          });
        }
      }
      map[key] = maxHeight ?? 0;
      await prefs.setString(_prefKey, jsonEncode(map));
    } catch (_) {}
  }
}

/// 兼容旧名：对外返回当前生效的画质文案。
class NetworkTier {
  const NetworkTier._();

  static Future<String> current() async =>
      ReelsQuality.label(await ReelsQuality.current());
}
