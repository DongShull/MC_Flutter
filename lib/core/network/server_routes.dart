import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/mc_error.dart';

/// 内外双地址自动选连（1:1 对齐鸿蒙 ServerRoutes.ets / iOS ServerRoutes）：
/// 登录地址只是这台服务器在这台设备上的**身份锚点**，真正发请求的地址按网络现场选。
/// - 地址簿来自 GET /server/addresses（旧服务器没有就只有登录地址）。
/// - 身份锚 = 登录地址 /api/v1/health 的 instance_id：候选探活回报同一个实例号才算同一台服务器。
/// - 内网先探、外网晚 250ms，先通过校验的先用。
/// - 选过的结论落盘：冷启动先用上次的地址（iOS 同款）。
class ServerRoutes extends ChangeNotifier {
  ServerRoutes._();

  static final ServerRoutes instance = ServerRoutes._();

  static const _storeName = 'movieclaw_routes';
  static const _probeTimeout = Duration(milliseconds: 2500);
  static const _wanDelay = Duration(milliseconds: 250);

  /// 登录地址（身份锚点；地址簿里没有可用项时也永远是兜底）。
  String loginOrigin = '';
  /// 当前路由（空 = 未配置/还在探，用登录地址）。
  String current = '';
  /// 当前路由类别：lan / wan / login。
  String kind = 'login';
  /// 「我的」页展示用：家里网络 / 外网（空 = 未配置）。
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

  /// EntryAbility.onCreate 对应：读回上次的选路结论（冷启动不用等探测）。
  Future<void> init() async {
    if (_restoreDone) return;
    _restoreDone = true;
    try {
      loginOrigin = await _store.read(key: '$_storeName.loginOrigin') ?? '';
      current = await _store.read(key: '$_storeName.current') ?? '';
      final storedKind =
          await _store.read(key: '$_storeName.kind') ?? '';
      kind = storedKind.isEmpty ? 'login' : storedKind;
      routeLabel = _labelOf(kind);
      notifyListeners();
    } catch (e) {
      // 落盘读不到就当没配置过（记日志，不静默）。
      McErrorLog.log(e, context: 'serverRoutes.restore');
    }
  }

  /// 登录/恢复会话后配置并选路：拉地址簿 → 记身份锚 → 并发探活选一个。
  /// 失败静默（选不出来就继续用登录地址，行为与旧版一致）。
  Future<void> configure(String origin, Future<ServerAddressesView?> Function() fetchBook) async {
    await init();
    // 换了一台服务器：上一台的结论（current/kind）必须清掉。
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
      // 身份锚：登录地址的实例号（探不通就用空串——候选实例校验放行，退化为纯可达性选路）。
      _instanceId = await probeInstance(origin) ?? '';
      ServerAddressesView? book;
      try {
        book = await fetchBook();
        if (_instanceId.isEmpty) _instanceId = book?.instanceId ?? '';
      } catch (e) {
        // 旧服务器没有地址簿：只有登录地址可用（记日志，不静默）。
        McErrorLog.log(e, context: 'serverRoutes.fetchBook');
      }
      _lanOrigins.clear();
      _wanOrigins.clear();
      var loginInBook = false;
      var loginKind = '';
      if (book != null) {
        for (final item in book.addresses) {
          if (item.url == origin) {
            loginKind = item.kind;
            loginInBook = true;
            continue;
          }
          if (item.kind == 'lan') {
            if (!_lanOrigins.contains(item.url)) _lanOrigins.add(item.url);
          } else if (!_wanOrigins.contains(item.url)) {
            _wanOrigins.add(item.url);
          }
        }
      }
      // 登录地址按地址簿的 kind 归类；地址簿没登记时用私网地址判断兜底。
      final loginIsLan =
          loginInBook ? loginKind == 'lan' : isPrivateHost(origin);
      if (loginIsLan) {
        _lanOrigins.insert(0, origin);
      } else if (!_wanOrigins.contains(origin)) {
        _wanOrigins.add(origin);
      }
      await pick();
    } catch (e) {
      // 选路失败保持登录地址（记日志，不静默）。
      McErrorLog.log(e, context: 'serverRoutes.pick');
    } finally {
      notifyListeners();
    }
  }

  /// 网络变了 / 回前台核实：重新探一遍（正在探就不重叠）。
  void reevaluate() {
    if (loginOrigin.isNotEmpty) unawaited(pick());
  }

  /// 退出登录：清结论（下一次登录重新配）。
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

  /// 当前生效地址（未配置/还在探 = 登录地址）。McClient.baseUrl 用。
  String currentOrigin() {
    if (current.isNotEmpty) return current;
    return loginOrigin;
  }

  /// 登录地址是不是私网（10/8、172.16/12、192.168/16）。
  static bool isPrivateHost(String origin) {
    var rest = origin;
    final scheme = rest.indexOf('://');
    if (scheme >= 0) rest = rest.substring(scheme + 3);
    final slash = rest.indexOf('/');
    if (slash >= 0) rest = rest.substring(0, slash);
    final colon = rest.indexOf(':');
    final host = colon >= 0 ? rest.substring(0, colon) : rest;
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return false;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }

  /// 并发探活选路：内网候选先起跑，外网候选晚 [wanDelayMs]；
  /// 每个候选探 /api/v1/health，实例号对得上才算过；第一个过的赢。
  Future<void> pick() async {
    if (_probing || !_configured) return;
    _probing = true;
    try {
      final races = <Future<String?>>[
        for (final o in _lanOrigins) _race(o),
      ];
      if (_wanOrigins.isNotEmpty) {
        races.add(Future.delayed(_wanDelay, () async {
          for (final o in _wanOrigins) {
            final ok = await _race(o);
            if (ok != null) return ok;
          }
          return null;
        }));
      }
      if (races.isEmpty) {
        _apply(loginOrigin, 'login');
        return;
      }
      // 第一个成功通过身份校验的候选胜出；全部失败保持原路由不动（可能只是暂时断网）。
      String? winner;
      for (final r in races) {
        final v = await r;
        if (v != null) {
          winner = v;
          break;
        }
      }
      if (winner != null) {
        _apply(winner, _kindOf(winner));
      }
    } finally {
      _probing = false;
      notifyListeners();
    }
  }

  Future<String?> _race(String origin) async {
    final instance = await probeInstance(origin);
    if (instance == null) return null;
    if (_instanceId.isNotEmpty && instance != _instanceId) return null;
    return origin;
  }

  /// 探 /api/v1/health：可达且 status ok 时返回 instance_id，否则 null。
  static Future<String?> probeInstance(String origin) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: _probeTimeout,
        receiveTimeout: _probeTimeout,
        validateStatus: (_) => true,
      ));
      final res = await dio.get<Map<String, dynamic>>(
        '$origin/api/v1/health',
        options: Options(responseType: ResponseType.json),
      );
      if (res.statusCode != 200 || res.data == null) return null;
      if (res.data!['status'] != 'ok') return null;
      final id = res.data!['instance_id']?.toString() ?? '';
      return id.isEmpty ? null : id;
    } catch (e) {
      McErrorLog.log(e, context: 'serverRoutes.probeInstance');
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

/// GET /server/addresses 的响应（与鸿蒙 ServerAddressesView 对齐）。
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
  const ServerAddressesView({required this.instanceId, required this.addresses});

  factory ServerAddressesView.fromJson(Map<String, dynamic> json) =>
      ServerAddressesView(
        instanceId: (json['instance_id'] ?? '').toString(),
        addresses: [
          for (final item in (json['addresses'] as List? ?? []))
            if (item is Map<String, dynamic>) ServerAddressItem.fromJson(item),
        ],
      );

  final String instanceId;
  final List<ServerAddressItem> addresses;
}

/// 壳层/服务器卡 watch 用。
final serverRoutesProvider = ChangeNotifierProvider<ServerRoutes>((ref) {
  return ServerRoutes.instance;
});
