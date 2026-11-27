import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 账号隔离的页面快照磁盘缓存（对齐 iOS `Shared/Core/PageSnapshots.swift`）：
/// - 按 `SHA-256("$origin|$username")` 前 32 位 hex 划分独立子目录，多账号/多服务器互不串数据；
/// - 落在 `getApplicationCacheDirectory()/PageSnapshots/`，属于可再生缓存；
/// - `FLUTTER_TEST` 或无文件系统插件环境自动优雅回退到 `SharedPreferences`（及内存兜底）；
/// - 版本升级或 JSON 解码失败直接返回 null，不影响页面正常走网络加载。
class PageSnapshots {
  PageSnapshots._();

  /// 快照结构版本：结构不兼容升级时 +1，旧文件自动失效。
  static const int version = 1;

  static const String _prefPrefix = 'mc_page_snap_v$version:';
  static final Map<String, String> _memoryFallback = <String, String>{};

  static bool get _isTestEnv =>
      Platform.environment.containsKey('FLUTTER_TEST');

  static String _normalizeOrigin(String origin) {
    var v = origin.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    final uri = Uri.tryParse(v);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final scheme = uri.scheme.toLowerCase();
      final host = uri.host.toLowerCase();
      final hasDefaultPort = (scheme == 'http' && uri.port == 80) ||
          (scheme == 'https' && uri.port == 443) ||
          !uri.hasPort;
      return hasDefaultPort ? '$scheme://$host' : '$scheme://$host:${uri.port}';
    }
    return v.toLowerCase();
  }

  /// 主人键：规范化后的 `"$origin|$username"`。
  static String ownerKey({required String origin, required String username}) =>
      '${_normalizeOrigin(origin)}|${username.trim().toLowerCase()}';

  /// SHA-256 前 32 位十六进制目录名（对齐 iOS `String(digest.prefix(32))`）。
  static String ownerHash(String owner) {
    final digest = sha256.convert(utf8.encode(owner)).toString();
    return digest.substring(0, 32);
  }

  static Future<Directory?> _rootDir() async {
    if (_isTestEnv) return null;
    try {
      final cache = await getApplicationCacheDirectory();
      return Directory('${cache.path}${Platform.pathSeparator}PageSnapshots');
    } catch (_) {
      return null;
    }
  }

  static Future<Directory?> _accountDir(String owner) async {
    final root = await _rootDir();
    if (root == null) return null;
    return Directory('${root.path}${Platform.pathSeparator}${ownerHash(owner)}');
  }

  static String _fileName(String name) {
    final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '$safe.v$version.json';
  }

  static String _prefKey(String owner, String name) =>
      '$_prefPrefix${ownerHash(owner)}:${_fileName(name)}';

  static String _prefOwnerPrefix(String owner) =>
      '$_prefPrefix${ownerHash(owner)}:';

  /// 读取一份页面快照；不存在或反序列化失败返回 null。
  static Future<T?> read<T>(
    String name, {
    required String origin,
    required String username,
    required T Function(dynamic json) fromJson,
  }) async {
    if (origin.trim().isEmpty || username.trim().isEmpty) return null;
    final owner = ownerKey(origin: origin, username: username);
    final raw = await _readRaw(name, owner: owner);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// 读取 JSON 对象快照的便捷方法。
  static Future<Map<String, dynamic>?> readMap(
    String name, {
    required String origin,
    required String username,
  }) =>
      read<Map<String, dynamic>>(
        name,
        origin: origin,
        username: username,
        fromJson: (json) {
          if (json is Map<String, dynamic>) return json;
          if (json is Map) return json.cast<String, dynamic>();
          throw const FormatException('Expected JSON object');
        },
      );

  /// 写入一份页面快照（磁盘采用临时文件原子替换；失败静默忽略）。
  static Future<void> write(
    String name,
    Object? value, {
    required String origin,
    required String username,
  }) async {
    if (origin.trim().isEmpty || username.trim().isEmpty) return;
    final owner = ownerKey(origin: origin, username: username);
    String encoded;
    try {
      encoded = jsonEncode(value);
    } catch (_) {
      return;
    }
    await _writeRaw(name, encoded, owner: owner);
  }

  /// 清理指定账号的全部页面快照（退出、移除账号、令牌失效时调用）。
  static Future<void> clearForAccount({
    required String origin,
    required String username,
  }) async {
    if (origin.trim().isEmpty || username.trim().isEmpty) return;
    final owner = ownerKey(origin: origin, username: username);
    final dir = await _accountDir(owner);
    if (dir != null) {
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    }
    final prefix = _prefOwnerPrefix(owner);
    _memoryFallback.removeWhere((k, _) => k.startsWith(prefix));
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  /// 清理本机全部账号的所有页面快照（退出全部账号 / 重置状态）。
  static Future<void> clearAll() async {
    final root = await _rootDir();
    if (root != null) {
      try {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      } catch (_) {}
    }
    _memoryFallback.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((k) => k.startsWith(_prefPrefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  static Future<String?> _readRaw(String name, {required String owner}) async {
    final dir = await _accountDir(owner);
    if (dir != null) {
      try {
        final file = File('${dir.path}${Platform.pathSeparator}${_fileName(name)}');
        if (await file.exists()) {
          return await file.readAsString();
        }
        return null;
      } catch (_) {
        return null;
      }
    }
    final key = _prefKey(owner, name);
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(key);
      if (v != null) return v;
    } catch (_) {}
    return _memoryFallback[key];
  }

  static Future<void> _writeRaw(
    String name,
    String encoded, {
    required String owner,
  }) async {
    final dir = await _accountDir(owner);
    if (dir != null) {
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final targetPath =
            '${dir.path}${Platform.pathSeparator}${_fileName(name)}';
        final tmpFile = File('$targetPath.${DateTime.now().microsecondsSinceEpoch}.tmp');
        await tmpFile.writeAsString(encoded, flush: true);
        await tmpFile.rename(targetPath);
        return;
      } catch (_) {
        // 磁盘写失败降级不抛异常
      }
    }
    final key = _prefKey(owner, name);
    _memoryFallback[key] = encoded;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, encoded);
    } catch (_) {}
  }
}
