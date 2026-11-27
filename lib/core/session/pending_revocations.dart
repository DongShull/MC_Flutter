import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 待补注销的设备令牌条目。
class PendingRevocationEntry {
  const PendingRevocationEntry({required this.origin, required this.token});

  factory PendingRevocationEntry.fromJson(Map<String, dynamic> json) =>
      PendingRevocationEntry(
        origin: (json['origin'] ?? '').toString(),
        token: (json['token'] ?? '').toString(),
      );

  final String origin;
  final String token;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'origin': origin,
        'token': token,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingRevocationEntry &&
          other.origin == origin &&
          other.token == token;

  @override
  int get hashCode => Object.hash(origin, token);
}

/// 离线/弱网退出后的设备令牌补注销队列（对齐 iOS `Shared/Core/Networking/PendingRevocations.swift`）：
/// - 退出或移除账号时先立即尝试 `DELETE <origin>/api/v1/auth/devices/current`（5 秒超时）；
/// - 收到 2xx / 401 / 404 视为已注销或服务端已无此设备；
/// - 网络失败或服务端 5xx 时，把 `(origin, token)` 安全持久化到 `mc_pending_revocations`（最多 50 条）；
/// - 冷启动与回到前台时调用 `retryAll()` 自动补注销。
class PendingRevocations {
  PendingRevocations({
    FlutterSecureStorage? storage,
    Dio? dio,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            ),
        _dio = dio;

  static final PendingRevocations instance = PendingRevocations();

  static const String storageKey = 'mc_pending_revocations';
  static const int maxEntries = 50;

  final FlutterSecureStorage _storage;
  final Dio? _dio;
  bool _running = false;

  static String _normalizeOrigin(String origin) {
    var v = origin.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  /// 立即尝试向服务端注销令牌；网络不可达时写入待补注销队列并返回 `false`。
  Future<bool> enqueueAndRevoke(
    String origin,
    String token, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final cleanOrigin = _normalizeOrigin(origin);
    final cleanToken = token.trim();
    if (cleanOrigin.isEmpty || cleanToken.isEmpty) return true;

    final revoked = await _attemptRevoke(
      cleanOrigin,
      cleanToken,
      timeout: timeout,
    );
    if (revoked) return true;

    await _enqueue(cleanOrigin, cleanToken);
    return false;
  }

  /// 读取当前待补注销条目。
  Future<List<PendingRevocationEntry>> load() async {
    try {
      final raw = await _storage.read(key: storageKey);
      if (raw == null || raw.isEmpty) return const <PendingRevocationEntry>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <PendingRevocationEntry>[];
      return <PendingRevocationEntry>[
        for (final item in decoded)
          if (item is Map)
            PendingRevocationEntry.fromJson(item.cast<String, dynamic>()),
      ].where((e) => e.origin.isNotEmpty && e.token.isNotEmpty).toList();
    } catch (_) {
      return const <PendingRevocationEntry>[];
    }
  }

  /// 重试队列中所有待注销令牌；同一时刻仅运行一轮。
  Future<void> retryAll({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_running) return;
    final entries = await load();
    if (entries.isEmpty) return;

    _running = true;
    try {
      final doneTokens = <String>{};
      for (final entry in entries) {
        final uri = Uri.tryParse(entry.origin);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
          doneTokens.add(entry.token);
          continue;
        }
        final ok = await _attemptRevoke(
          _normalizeOrigin(entry.origin),
          entry.token,
          timeout: timeout,
        );
        if (ok) {
          doneTokens.add(entry.token);
        }
      }
      if (doneTokens.isNotEmpty) {
        // 重新读取再过滤，避免覆盖重试期间新增的条目
        final latest = await load();
        final remaining =
            latest.where((e) => !doneTokens.contains(e.token)).toList();
        await _save(remaining);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _enqueue(String origin, String token) async {
    final existing = (await load()).where((e) => e.token != token).toList();
    existing.add(PendingRevocationEntry(origin: origin, token: token));
    final capped = existing.length > maxEntries
        ? existing.sublist(existing.length - maxEntries)
        : existing;
    await _save(capped);
  }

  Future<void> _save(List<PendingRevocationEntry> entries) async {
    try {
      if (entries.isEmpty) {
        await _storage.delete(key: storageKey);
      } else {
        await _storage.write(
          key: storageKey,
          value: jsonEncode(entries.map((e) => e.toJson()).toList()),
        );
      }
    } catch (_) {}
  }

  Future<bool> _attemptRevoke(
    String origin,
    String token, {
    required Duration timeout,
  }) async {
    final client = _dio ??
        Dio(
          BaseOptions(
            connectTimeout: timeout,
            receiveTimeout: timeout,
            sendTimeout: timeout,
            validateStatus: (_) => true,
          ),
        );
    try {
      final res = await client.delete<dynamic>(
        '$origin/api/v1/auth/devices/current',
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      final status = res.statusCode ?? 0;
      // 2xx = 已注销；401 = 令牌早已失效；404 = 服务端已无此设备
      return (status >= 200 && status < 300) || status == 401 || status == 404;
    } catch (_) {
      return false;
    }
  }
}
