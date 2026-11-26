import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 内外双地址自动选连（Happy Eyeballs 并发竞速 + 实例身份锚校验）：
/// - 地址簿来自 `GET /api/v1/server/addresses`；
/// - 身份锚 = `/api/v1/health` 的 `instance_id`，杜绝异网私网重名主机串号或门户劫持；
/// - 内网候选立即并发起跑，外网候选延迟 250ms 并发起跑；首个通过校验者立即获胜，
///   若外网先响应而内网随后跑通，自动平滑升级到内网直连；
/// - 选路结论落盘，冷启动 0ms 直接复用上次最优地址。
class ServerRoutes extends ChangeNotifier {
  ServerRoutes._();

  static final ServerRoutes instance = ServerRoutes._();

  static const _storeName = 'movieclaw_routes';
  static const _probeTimeout = Duration(milliseconds: 2200);
  static const _wanDelay = Duration(milliseconds: 250);

  String loginOrigin = '';
  String current = '';
  String kind = 'login';
  String routeLabel = '';

  final List<String> _lanOrigins = [];
  final List<String> _wanOrigins = [];
  String _instanceId = '';
  bool _probing = false;
  bool _configured = false;
  bool _restoreDone = false;

  final FlutterSecureStorage _store = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  List<String> get lanCandidates => List.unmodifiable(_lanOrigins);
  List<String> get wanCandidates => List.unmodifiable(_wanOrigins);

  Future<void> init() async {
    if (_restoreDone) return;
    _restoreDone = true;
    try {
      loginOrigin = await _store.read(key: '$_storeName.loginOrigin') ?? '';
      current = await _store.read(key: '$_storeName.current') ?? '';
      final storedKind = await _store.read(key: '$_storeName.kind') ?? '';
      kind = storedKind.isEmpty ? 'login' : storedKind;
      routeLabel = _labelOf(kind);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> configure(
    String origin,
    Future<ServerAddressesView?> Function() fetchBook,
  ) async {
    await init();
    if (loginOrigin.isNotEmpty && loginOrigin != origin) {
      current = '';
      kind = 'login';
      routeLabel = '';
      unawaited(_store.delete(key: '$_storeName.current'));
      unawaited(_store.delete(key: '$_storeName.kind'));
    }
    loginOrigin = origin;
    _configured = true;
    unawaited(_store.write(key: '$_storeName.loginOrigin', value: origin));
    notifyListeners();
    try {
      _instanceId = await probeInstance(origin) ?? '';
      ServerAddressesView? book;
      try {
        book = await fetchBook();
        if (_instanceId.isEmpty) _instanceId = book?.instanceId ?? '';
      } catch (_) {}
      _lanOrigins.clear();
      _wanOrigins.clear();
      var loginInBook = false;
      var loginKind = '';
      if (book != null) {
        for (final item in book.addresses) {
          final clean = _stripTrailingSlash(item.url);
          if (clean.isEmpty) continue;
          if (clean == origin) {
            loginKind = item.kind;
            loginInBook = true;
            continue;
          }
          if (item.kind == 'lan') {
            if (!_lanOrigins.contains(clean)) _lanOrigins.add(clean);
          } else if (!_wanOrigins.contains(clean)) {
            _wanOrigins.add(clean);
          }
        }
      }
      final loginIsLan =
          loginInBook ? loginKind == 'lan' : isPrivateHost(origin);
      if (loginIsLan) {
        if (!_lanOrigins.contains(origin)) _lanOrigins.insert(0, origin);
      } else if (!_wanOrigins.contains(origin)) {
        _wanOrigins.add(origin);
      }
      await pick();
    } catch (_) {
    } finally {
      notifyListeners();
    }
  }

  void reevaluate() {
    if (loginOrigin.isNotEmpty && _configured) unawaited(pick());
  }

  Future<void> reset() async {
    loginOrigin = '';
    current = '';
    kind = 'login';
    routeLabel = '';
    _lanOrigins.clear();
    _wanOrigins.clear();
    _instanceId = '';
    _configured = false;
    await _store.delete(key: '$_storeName.current');
    await _store.delete(key: '$_storeName.kind');
    await _store.delete(key: '$_storeName.loginOrigin');
    notifyListeners();
  }

  String currentOrigin([String fallback = '']) {
    if (current.isNotEmpty) return current;
    if (loginOrigin.isNotEmpty) return loginOrigin;
    return _stripTrailingSlash(fallback);
  }

  static String _stripTrailingSlash(String s) {
    var v = s.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  static bool isPrivateHost(String origin) {
    var rest = origin;
    final scheme = rest.indexOf('://');
    if (scheme >= 0) rest = rest.substring(scheme + 3);
    final slash = rest.indexOf('/');
    if (slash >= 0) rest = rest.substring(0, slash);
    final colon = rest.indexOf(':');
    final host = colon >= 0 ? rest.substring(0, colon) : rest;
    if (host == 'localhost' || host.endsWith('.local')) return true;
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return false;
    return a == 10 ||
        a == 127 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        (a == 100 && b >= 64 && b <= 127); // Tailscale / CGNAT
  }

  /// 真正并发竞速（Happy Eyeballs）：
  /// 内网立即并发探活，外网延迟 250ms 并发探活；首个非 null 立即生效；
  /// 若外网先赢而内网随后跑通，自动升级为内网。
  Future<void> pick() async {
    if (_probing || !_configured) return;
    _probing = true;
    try {
      if (_lanOrigins.isEmpty && _wanOrigins.isEmpty) {
        _apply(loginOrigin, 'login');
        return;
      }
      final lanFutures = <Future<String?>>[
        for (final o in _lanOrigins) _race(o),
      ];
      final wanFutures = <Future<String?>>[
        for (final o in _wanOrigins)
          Future<String?>.delayed(_wanDelay, () => _race(o)),
      ];
      final all = <Future<String?>>[...lanFutures, ...wanFutures];
      final firstWinner = await _firstNonNull(all);
      if (firstWinner != null) {
        _apply(firstWinner, _kindOf(firstWinner));
        // 若外网先返回，等待进行中的内网探测：一旦内网可达立即升级为家里网络。
        if (_kindOf(firstWinner) == 'wan' && lanFutures.isNotEmpty) {
          final lanWinner = await _firstNonNull(lanFutures);
          if (lanWinner != null) {
            _apply(lanWinner, 'lan');
          }
        }
      }
    } finally {
      _probing = false;
      notifyListeners();
    }
  }

  static Future<String?> _firstNonNull(List<Future<String?>> futures) {
    if (futures.isEmpty) return Future.value(null);
    final completer = Completer<String?>();
    var remaining = futures.length;
    for (final f in futures) {
      f.then((value) {
        if (value != null && !completer.isCompleted) {
          completer.complete(value);
          return;
        }
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }).catchError((_) {
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }
    return completer.future;
  }

  Future<String?> _race(String origin) async {
    final instance = await probeInstance(origin);
    if (instance == null) return null;
    if (_instanceId.isNotEmpty && instance != _instanceId) return null;
    return origin;
  }

  static Future<String?> probeInstance(String origin) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: _probeTimeout,
          receiveTimeout: _probeTimeout,
          validateStatus: (_) => true,
        ),
      );
      final res = await dio.get<Map<String, dynamic>>(
        '$origin/api/v1/health',
        options: Options(responseType: ResponseType.json),
      );
      if (res.statusCode != 200 || res.data == null) return null;
      if (res.data!['status'] != 'ok') return null;
      final id = res.data!['instance_id']?.toString() ?? '';
      return id.isEmpty ? 'ok' : id;
    } catch (_) {
      return null;
    }
  }

  void _apply(String origin, String newKind) {
    final changed = origin != current || newKind != kind;
    current = origin;
    kind = newKind;
    routeLabel = _labelOf(newKind);
    if (changed) {
      unawaited(_store.write(key: '$_storeName.current', value: origin));
      unawaited(_store.write(key: '$_storeName.kind', value: newKind));
    }
    notifyListeners();
  }

  String _kindOf(String origin) {
    if (_lanOrigins.contains(origin)) return 'lan';
    if (_wanOrigins.contains(origin)) return 'wan';
    return 'login';
  }

  String _labelOf(String k) {
    if (k == 'lan') return '家里网络';
    if (k == 'wan') return '外网';
    return '';
  }
}

class ServerAddressItem {
  const ServerAddressItem({required this.url, required this.kind});

  factory ServerAddressItem.fromJson(Map<String, dynamic> json) =>
      ServerAddressItem(
        url: (json['url'] ?? '').toString(),
        kind: (json['kind'] ?? 'wan').toString(),
      );

  final String url;
  final String kind;
}

class ServerAddressesView {
  const ServerAddressesView({
    required this.instanceId,
    required this.addresses,
    this.hostKey = '',
  });

  factory ServerAddressesView.fromJson(Map<String, dynamic> json) =>
      ServerAddressesView(
        instanceId: (json['instance_id'] ?? '').toString(),
        hostKey: (json['host_key'] ?? '').toString(),
        addresses: [
          for (final item in (json['addresses'] as List? ?? []))
            if (item is Map<String, dynamic>)
              ServerAddressItem.fromJson(item)
            else if (item is Map)
              ServerAddressItem.fromJson(item.cast<String, dynamic>()),
        ],
      );

  final String instanceId;
  final String hostKey;
  final List<ServerAddressItem> addresses;
}

final serverRoutesProvider = ChangeNotifierProvider<ServerRoutes>((ref) {
  return ServerRoutes.instance;
});
