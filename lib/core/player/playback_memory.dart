import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'player_service.dart';

/// 画质 / 倍速记忆（P2 移植自安卓 `android-core/playback/PlayerPreferences.kt`
/// 的 `QualityMemory` / `SpeedMemory`，与 `PlaybackRouting.kt` 的网络分档）。
///
/// 存储格式与安卓逐字节同口径，便于将来与原生端共用同一份偏好键：
/// - 画质键 `player.quality-by-title`：`{"home:123": [1080, 1730000000000]}`，
///   key = `网络:mediaItemId`，值 = `[maxHeight, 记录毫秒时间戳]`；
/// - 倍速键 `player.speed-by-title`：`{"123": [1.5, 1730000000000]}`。
/// - 只存“限了画质 / 非正常倍速”的选择，选回原画/常速就删掉；
///   最多 300 条，超出按最久没用的先丢。
/// - 画质按影片 × 网络环境记（在家选了 1080p，回到家打开还是原画）；
///   倍速只按影片记（同一部剧换集、下次再打开都保持）。
///
/// 与安卓的已知偏差：网络判定不做 DNS 解析（web 上 `dart:io` 不可用）。
/// 安卓 `PlaybackNetwork.of(host)` 会把局域网主机名解析成私网 IP 判为局域网；
/// 这里只看字面 host：IP 字面量按私网段判定，域名一律按外网算。
/// 局域网内用主机名访问服务器的极少数情况会被记到外网那一份记忆里。

/// 播放时的网络环境（安卓 `PlaybackNetwork` 的 Dart 移植）。
enum PlaybackNetwork {
  home('home', '局域网'),
  away('away', '外网'),
  unknown('unknown', '');

  const PlaybackNetwork(this.id, this.label);

  final String id;

  /// 人类可读标签；unknown 时为空（`RememberedChoices.notice` 不写环境）。
  final String label;

  /// 按服务器地址判定。只看字面 host，不做 DNS 解析（见文件头注释）。
  static PlaybackNetwork ofServerUrl(String? baseUrl) {
    final host = _hostOf(baseUrl);
    return ofHost(host);
  }

  static PlaybackNetwork ofHost(String? host) {
    if (host == null || host.isEmpty) return PlaybackNetwork.unknown;
    final h = host.toLowerCase();
    if (h == 'localhost' || h == '::1' || h == '[::1]') {
      return PlaybackNetwork.home;
    }
    final parts = h.split('.');
    if (parts.length == 4 && parts.every((p) => int.tryParse(p) != null)) {
      final o = parts.map(int.parse).toList();
      if (o[0] == 10) return PlaybackNetwork.home;
      if (o[0] == 172 && o[1] >= 16 && o[1] <= 31) {
        return PlaybackNetwork.home;
      }
      if (o[0] == 192 && o[1] == 168) return PlaybackNetwork.home;
      if (o[0] == 127) return PlaybackNetwork.home;
      return PlaybackNetwork.away;
    }
    // 域名：无法在不解析 DNS 的情况下判定，按外网算（见文件头注释）。
    return PlaybackNetwork.away;
  }

  static String? _hostOf(String? baseUrl) {
    if (baseUrl == null || baseUrl.isEmpty) return null;
    final uri = Uri.tryParse(baseUrl);
    return uri?.host.isNotEmpty == true ? uri!.host : null;
  }
}

/// 字符串键值存储的最小抽象（对应安卓 `PrefsStore`）。
/// [SharedPreferencesStringStore] 是正式实现；测试用 [MemoryStringStore]。
abstract class PrefsStringStore {
  String? read(String key);
  Future<void> write(String key, String? value);
}

/// [SharedPreferences] 实现（写透内存快照，读走快照）。
class SharedPreferencesStringStore implements PrefsStringStore {
  SharedPreferencesStringStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }
}

/// 内存实现（单测与无盘环境用；写操作同步落盘到内存表）。
class MemoryStringStore implements PrefsStringStore {
  final Map<String, String> _map = {};

  @override
  String? read(String key) => _map[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }
  }
}

/// 画质记忆：按影片 × 网络环境记 maxHeight（上限语义）。
class QualityMemory {
  QualityMemory(this._store, {int Function()? nowMs})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final PrefsStringStore _store;
  final int Function() _nowMs;

  static const int limit = 300;
  static const String storeKey = 'player.quality-by-title';

  /// 记住的画质上限；null = 没选过（或选回原画后已删除）。
  /// 不在 [QualityOption.all] 里的档位视为无效，返回 null。
  int? quality(int mediaItemId, PlaybackNetwork network) {
    final height = _entries()['${network.id}:$mediaItemId']?.$1;
    if (height == null) return null;
    final valid = QualityOption.all.any((o) => o.maxHeight == height);
    return valid ? height : null;
  }

  /// 记一次选择。`maxHeight == null`（原画）= 删掉这条记忆。
  /// 注意：安卓 `selectQuality` 在“上限不低于片源”时也记成原画；
  /// Flutter 拿不到片源高度，调用方（PlayerController）直接按用户选择记，
  /// 原画即删——见控制器注释。
  Future<void> remember(
    int? maxHeight,
    int mediaItemId,
    PlaybackNetwork network,
  ) async {
    final all = Map<String, (int, int)>.of(_entries());
    final key = '${network.id}:$mediaItemId';
    if (maxHeight != null) {
      all[key] = (maxHeight, _nowMs());
      if (all.length > limit) {
        final sorted = all.entries.toList()
          ..sort((a, b) => a.value.$2.compareTo(b.value.$2));
        for (final e in sorted.take(all.length - limit)) {
          all.remove(e.key);
        }
      }
    } else {
      all.remove(key);
    }
    await _persist(all);
  }

  Map<String, (int, int)> _entries() {
    final raw = _store.read(storeKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, (int, int)>{};
      for (final e in decoded.entries) {
        final v = e.value;
        if (v is List && v.length >= 2) {
          final height = (v[0] as num?)?.toInt();
          final at = (v[1] as num?)?.toInt() ?? 0;
          if (height != null) out[e.key.toString()] = (height, at);
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _persist(Map<String, (int, int)> all) {
    final obj = {for (final e in all.entries) e.key: [e.value.$1, e.value.$2]};
    return _store.write(storeKey, jsonEncode(obj));
  }
}

/// 倍速记忆：按影片记（只存非正常速度；选回 1.0 就删掉）。
class SpeedMemory {
  SpeedMemory(this._store, {int Function()? nowMs})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final PrefsStringStore _store;
  final int Function() _nowMs;

  static const int limit = 300;
  static const String storeKey = 'player.speed-by-title';

  /// 记住的倍速；null = 没记过。非法档位（不在 0.5–2.0 六档内）视为无效。
  double? speed(int mediaItemId) {
    final value = _entries()[mediaItemId.toString()]?.$1;
    if (value == null) return null;
    const allowed = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    if (value == 1.0 || !allowed.contains(value)) return null;
    return value;
  }

  /// 记一次选择。`speed == 1.0`（常速）= 删掉这条记忆。
  Future<void> remember(double speed, int mediaItemId) async {
    final all = Map<String, (double, int)>.of(_entries());
    final key = mediaItemId.toString();
    if (speed != 1.0) {
      all[key] = (speed, _nowMs());
      if (all.length > limit) {
        final sorted = all.entries.toList()
          ..sort((a, b) => a.value.$2.compareTo(b.value.$2));
        for (final e in sorted.take(all.length - limit)) {
          all.remove(e.key);
        }
      }
    } else {
      all.remove(key);
    }
    await _persist(all);
  }

  Map<String, (double, int)> _entries() {
    final raw = _store.read(storeKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, (double, int)>{};
      for (final e in decoded.entries) {
        final v = e.value;
        if (v is List && v.length >= 2) {
          final speed = (v[0] as num?)?.toDouble();
          final at = (v[1] as num?)?.toInt() ?? 0;
          if (speed != null) out[e.key.toString()] = (speed, at);
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _persist(Map<String, (double, int)> all) {
    final obj = {for (final e in all.entries) e.key: [e.value.$1, e.value.$2]};
    return _store.write(storeKey, jsonEncode(obj));
  }
}

/// 开播提示「已沿用上次的选择」（安卓 `RememberedChoices.notice` 移植）。
/// 各项传 null = 这一项是默认（或这次没沿用记忆），不提示；全部默认返回 null。
abstract final class RememberedChoices {
  static String? notice({
    int? quality,
    PlaybackNetwork? network,
    String? audio,
    String? subtitle,
    double? speed,
  }) {
    final parts = <String>[];
    if (quality != null) {
      final net = network?.label;
      parts.add(net != null && net.isNotEmpty
          ? '画质 $quality' 'p（$net）'
          : '画质 ${quality}p');
    }
    if (audio != null) parts.add('音轨 $audio');
    if (subtitle != null) parts.add('字幕 $subtitle');
    if (speed != null) {
      final s = speed.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      parts.add('倍速 $s×');
    }
    if (parts.isEmpty) return null;
    return '已沿用上次的选择：${parts.join('、')}';
  }
}

/// 两份记忆的成对加载器（控制器在起播前调一次；写操作走同一份 store）。
class PlaybackMemories {
  PlaybackMemories._(this.quality, this.speed);

  final QualityMemory quality;
  final SpeedMemory speed;

  /// 从 SharedPreferences 加载（正式路径）。
  static Future<PlaybackMemories> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesStringStore(prefs);
    return PlaybackMemories._(QualityMemory(store), SpeedMemory(store));
  }

  /// 内存 store（单测用）。
  static PlaybackMemories inMemory({int Function()? nowMs}) {
    final store = MemoryStringStore();
    return PlaybackMemories._(
      QualityMemory(store, nowMs: nowMs),
      SpeedMemory(store, nowMs: nowMs),
    );
  }
}
