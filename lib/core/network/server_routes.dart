import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 路由线路三态（对齐 iOS `ServerRoutes.Route`）：
/// - `lan`: 本机与服务器同内网直连；
/// - `vpn`: 经 VPN 隧道连入内网地址（或匹配 VPN 网段）；
/// - `wan`: 公网/外网地址。
enum RouteKind {
  lan,
  vpn,
  wan;

  String get headerValue => name;

  static RouteKind? fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'lan':
        return RouteKind.lan;
      case 'vpn':
        return RouteKind.vpn;
      case 'wan':
        return RouteKind.wan;
      default:
        return null;
    }
  }
}

/// 地址簿里的单条候选端点。
class ServerRouteEndpoint {
  const ServerRouteEndpoint({required this.origin, required this.kind});

  factory ServerRouteEndpoint.fromJson(Map<String, dynamic> json) =>
      ServerRouteEndpoint(
        origin: ServerRoutes.normalizeOrigin((json['origin'] ?? '').toString()),
        kind: (json['kind'] ?? 'wan').toString() == 'lan' ? 'lan' : 'wan',
      );

  final String origin;

  /// `'lan'` 或 `'wan'`
  final String kind;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'origin': origin,
        'kind': kind,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerRouteEndpoint &&
          ServerRoutes.originKey(other.origin) ==
              ServerRoutes.originKey(origin) &&
          other.kind == kind;

  @override
  int get hashCode => Object.hash(ServerRoutes.originKey(origin), kind);
}

/// 按网络指纹记住的上次可用端点。
class RouteMemoryEntry {
  const RouteMemoryEntry({required this.fingerprint, required this.origin});

  factory RouteMemoryEntry.fromJson(Map<String, dynamic> json) =>
      RouteMemoryEntry(
        fingerprint: (json['fingerprint'] ?? '').toString(),
        origin: ServerRoutes.normalizeOrigin((json['origin'] ?? '').toString()),
      );

  final String fingerprint;
  final String origin;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fingerprint': fingerprint,
        'origin': origin,
      };
}

/// 单台服务器的地址簿与网络选路记忆（按登录地址持久化）。
class ServerRouteBook {
  const ServerRouteBook({
    required this.instanceId,
    required this.hostKey,
    required this.endpoints,
    this.lanSubnets = const <String>[],
    this.memory = const <RouteMemoryEntry>[],
  });

  factory ServerRouteBook.fromJson(Map<String, dynamic> json) =>
      ServerRouteBook(
        instanceId: (json['instance_id'] ?? json['instanceId'] ?? '').toString(),
        hostKey: (json['host_key'] ?? json['hostKey'] ?? '').toString(),
        endpoints: <ServerRouteEndpoint>[
          for (final item in (json['endpoints'] as List? ?? const <dynamic>[]))
            if (item is Map)
              ServerRouteEndpoint.fromJson(item.cast<String, dynamic>()),
        ].where((e) => e.origin.isNotEmpty).toList(),
        lanSubnets: <String>[
          for (final s in (json['lan_subnets'] as List? ??
              json['lanSubnets'] as List? ??
              const <dynamic>[]))
            s.toString(),
        ].where((s) => s.isNotEmpty).toList(),
        memory: <RouteMemoryEntry>[
          for (final item in (json['memory'] as List? ?? const <dynamic>[]))
            if (item is Map)
              RouteMemoryEntry.fromJson(item.cast<String, dynamic>()),
        ].where((m) => m.fingerprint.isNotEmpty && m.origin.isNotEmpty).toList(),
      );

  final String instanceId;
  final String hostKey;
  final List<ServerRouteEndpoint> endpoints;
  final List<String> lanSubnets;
  final List<RouteMemoryEntry> memory;

  ServerRouteBook copyWith({
    String? instanceId,
    String? hostKey,
    List<ServerRouteEndpoint>? endpoints,
    List<String>? lanSubnets,
    List<RouteMemoryEntry>? memory,
  }) =>
      ServerRouteBook(
        instanceId: instanceId ?? this.instanceId,
        hostKey: hostKey ?? this.hostKey,
        endpoints: endpoints ?? this.endpoints,
        lanSubnets: lanSubnets ?? this.lanSubnets,
        memory: memory ?? this.memory,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'instance_id': instanceId,
        'host_key': hostKey,
        'endpoints': endpoints.map((e) => e.toJson()).toList(),
        'lan_subnets': lanSubnets,
        'memory': memory.map((m) => m.toJson()).toList(),
      };
}

/// 某台服务器当前选中的地址与路线。
class ServerRouteCurrent {
  const ServerRouteCurrent({required this.origin, this.route});

  final String origin;
  final RouteKind? route;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerRouteCurrent &&
          ServerRoutes.originKey(other.origin) ==
              ServerRoutes.originKey(origin) &&
          other.route == route;

  @override
  int get hashCode => Object.hash(ServerRoutes.originKey(origin), route);
}

/// 本机单个网络接口（IPv4 主机序地址与掩码）。
class NetworkInterfaceInfo {
  const NetworkInterfaceInfo({
    required this.name,
    required this.address,
    this.netmask = 0xFFFFFF00,
  });

  final String name;
  final int address;
  final int netmask;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkInterfaceInfo &&
          other.name == name &&
          other.address == address &&
          other.netmask == netmask;

  @override
  int get hashCode => Object.hash(name, address, netmask);
}

enum NetworkInterfaceKind { physical, vpn, cellular, other }

/// 本机网络接口快照（对齐 iOS `NetworkSnapshot`）：
/// - 区分物理网卡（en*/wlan*/eth*）、蜂窝（pdp_ip*/rmnet*）、VPN（utun/tun/tap/wg/ppp/ipsec）；
/// - 剔除代理假 IP（`198.18.0.0/15`），不把出国代理 TUN 误当成回家 VPN；
/// - 生成网络指纹（物理网段 + VPN 隧道网段），切换 Wi-Fi/开关 VPN 时立即可感知。
class NetworkSnapshot {
  const NetworkSnapshot({
    this.physical = const <NetworkInterfaceInfo>[],
    this.vpn = const <NetworkInterfaceInfo>[],
    this.cellular = false,
  });

  final List<NetworkInterfaceInfo> physical;
  final List<NetworkInterfaceInfo> vpn;
  final bool cellular;

  bool get hasVpn => vpn.isNotEmpty;

  /// 有物理网卡或 VPN 才探测内网地址；纯蜂窝网络不试私网地址。
  bool get canReachPrivate => physical.isNotEmpty || vpn.isNotEmpty;

  /// 网络指纹：实体网卡网段（纯蜂窝为 `cellular`，无网为 `none`）+ `vpn:<网段>`。
  String get fingerprint {
    String net(NetworkInterfaceInfo iface) {
      final masked = iface.address & iface.netmask;
      final bits = _bitCount32(iface.netmask);
      return '${dottedIPv4(masked)}/$bits';
    }

    final physNets = physical.map(net).toList()..sort();
    final base = physNets.isEmpty
        ? (cellular ? 'cellular' : 'none')
        : physNets.join(',');
    final vpnNets = vpn.map((i) => 'vpn:${net(i)}').toList()..sort();
    return <String>[base, ...vpnNets].join(',');
  }

  /// 目标 IPv4 主机与本机某块实体网卡在同一网段。
  bool sameSubnet(String host) {
    final ip = ServerRoutes.parseIPv4(host);
    if (ip == null) return false;
    return physical.any(
      (i) =>
          i.netmask != 0 &&
          i.netmask != 0xFFFFFFFF &&
          (i.address & i.netmask) == (ip & i.netmask),
    );
  }

  /// 目标 IPv4 主机是否匹配某条 VPN 隧道网段。
  bool matchesVpnSubnet(String host) {
    final ip = ServerRoutes.parseIPv4(host);
    if (ip == null) return false;
    return vpn.any(
      (i) =>
          i.netmask != 0 &&
          i.netmask != 0xFFFFFFFF &&
          (i.address & i.netmask) == (ip & i.netmask),
    );
  }

  /// 本机实体网卡是否落在服务端声明的任意 `lanSubnets`（CIDR 如 `192.168.1.0/24`）内。
  bool physicalIn(List<String> subnets) {
    for (final subnet in subnets) {
      final parts = subnet.split('/');
      if (parts.length != 2) continue;
      final base = ServerRoutes.parseIPv4(parts[0].trim());
      final bits = int.tryParse(parts[1].trim());
      if (base == null || bits == null || bits < 0 || bits > 32) continue;
      final mask = bits == 0 ? 0 : (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF;
      if (physical.any((i) => (i.address & mask) == (base & mask))) {
        return true;
      }
    }
    return false;
  }

  /// 读取当前本机 IPv4 网卡快照（只读本机，不发网络请求）。
  static Future<NetworkSnapshot> current() async {
    try {
      final list = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      final physical = <NetworkInterfaceInfo>[];
      final vpn = <NetworkInterfaceInfo>[];
      var cellular = false;
      for (final iface in list) {
        for (final addr in iface.addresses) {
          final ip = ServerRoutes.parseIPv4(addr.address);
          if (ip == null) continue;
          // 忽略回环与未指定地址
          if ((ip >> 24) == 127 || ip == 0) continue;
          final info = NetworkInterfaceInfo(
            name: iface.name,
            address: ip,
            netmask: _defaultMaskFor(ip),
          );
          switch (classifyInterface(iface.name, address: ip)) {
            case NetworkInterfaceKind.physical:
              physical.add(info);
            case NetworkInterfaceKind.vpn:
              vpn.add(info);
            case NetworkInterfaceKind.cellular:
              cellular = true;
            case NetworkInterfaceKind.other:
              break;
          }
        }
      }
      return NetworkSnapshot(
        physical: physical,
        vpn: vpn,
        cellular: cellular,
      );
    } catch (_) {
      return const NetworkSnapshot();
    }
  }

  /// 网卡分类（对齐 iOS `NetworkSnapshot.kind(of:address:)` 并兼容 Android/Linux/Windows 网卡名）：
  /// - `en*` / `eth*` / `wlan*` / `wl*` / `wifi*` -> physical；
  /// - `pdp_ip*` / `rmnet*` / `ccmni*` / `wwan*` / `cell*` -> cellular；
  /// - `utun*` / `tun*` / `tap*` / `wg*` / `ppp*` / `ipsec*` / `tailscale*` / `zt*` ->
  ///   若地址位于代理 fake-ip 网段 `198.18.0.0/15` 则归为 `other`，否则 `vpn`。
  static NetworkInterfaceKind classifyInterface(
    String name, {
    int address = 0,
  }) {
    final lower = name.toLowerCase();
    if (lower.startsWith('en') ||
        lower.startsWith('eth') ||
        lower.startsWith('wlan') ||
        lower.startsWith('wl') ||
        lower.startsWith('wifi')) {
      return NetworkInterfaceKind.physical;
    }
    if (lower.startsWith('pdp_ip') ||
        lower.startsWith('rmnet') ||
        lower.startsWith('ccmni') ||
        lower.startsWith('wwan') ||
        lower.startsWith('cell')) {
      return NetworkInterfaceKind.cellular;
    }
    const vpnPrefixes = <String>[
      'utun',
      'tun',
      'tap',
      'wg',
      'ppp',
      'ipsec',
      'tailscale',
      'zt',
    ];
    if (vpnPrefixes.any(lower.startsWith)) {
      // 198.18.0.0/15 为代理 App TUN 模式 fake-ip，流量出公网而非回家 VPN
      if (isProxyFakeIp(address)) return NetworkInterfaceKind.other;
      return NetworkInterfaceKind.vpn;
    }
    return NetworkInterfaceKind.other;
  }

  /// 是否命中代理假 IP 网段 `198.18.0.0/15`。
  static bool isProxyFakeIp(int ip) => (ip >> 17) == (0xC612 >> 1);

  static int _defaultMaskFor(int ip) {
    // 100.64.0.0/10 (Tailscale/CGNAT) 用 /10 掩码，普通局域网默认 /24
    if (ServerRoutes.isCgnatIp(ip)) return 0xFFC00000;
    return 0xFFFFFF00;
  }

  static int _bitCount32(int value) {
    var v = value & 0xFFFFFFFF;
    var count = 0;
    while (v != 0) {
      count += v & 1;
      v >>= 1;
    }
    return count;
  }

  static String dottedIPv4(int ip) =>
      '${(ip >> 24) & 0xFF}.${(ip >> 16) & 0xFF}.${(ip >> 8) & 0xFF}.${ip & 0xFF}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkSnapshot &&
          other.cellular == cellular &&
          listEquals(other.physical, physical) &&
          listEquals(other.vpn, vpn);

  @override
  int get hashCode => Object.hash(
        cellular,
        Object.hashAll(physical),
        Object.hashAll(vpn),
      );
}

typedef RouteChangedCallback = void Function(String origin, RouteKind? route);

/// 内外双地址与 VPN 自动选连（对齐 iOS `Shared/Core/Networking/ServerRoutes.swift`）：
/// - 每台服务器独立维护一份 `ServerRouteBook`（按规范化 `loginOrigin` 键存储），跨服务器切换账号互不串号；
/// - Ed25519 主机公钥质询验签：`GET /api/v1/health?nonce=<18B base64url>`，校验
///   `x-movieclaw-spec-hash` 响应头 + 非空 `instance_id` 匹配 + `Ed25519(movieclaw-health\n$instanceId\n$nonce)`；
/// - 三态路线（`lan` / `vpn` / `wan`）与网卡指纹隔离，永不盲信旧 Wi-Fi 缓存的明文 `http://` 内网地址；
/// - Happy Eyeballs 并发竞速（内网 1.5s 立即起跑，外网延迟 250ms 起跑 5s）+ 故障切换 `failover()`。
class ServerRoutes extends ChangeNotifier {
  ServerRoutes({
    FlutterSecureStorage? storage,
    Future<NetworkSnapshot> Function()? networkProvider,
    Dio? probeDio,
    bool persistent = true,
  })  : _store = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            ),
        _networkProvider = networkProvider ?? NetworkSnapshot.current,
        _probeDio = probeDio,
        _persistent = persistent;

  static final ServerRoutes instance = ServerRoutes();

  static const _storeName = 'movieclaw_routes';
  static const _booksKey = 'movieclaw_routes.books_v2';
  static const _lanTimeout = Duration(milliseconds: 1500);
  static const _wanTimeout = Duration(milliseconds: 5000);
  static const _wanDelay = Duration(milliseconds: 250);
  static const _memoryLimit = 8;

  final FlutterSecureStorage _store;
  final Future<NetworkSnapshot> Function() _networkProvider;
  final Dio? _probeDio;
  final bool _persistent;
  final math.Random _secureRng = math.Random.secure();

  final Map<String, ServerRouteBook> _books = <String, ServerRouteBook>{};
  final Map<String, ServerRouteCurrent> _currentByServer =
      <String, ServerRouteCurrent>{};
  final Map<String, Future<void>> _selecting = <String, Future<void>>{};

  String _activeServerKey = '';
  String loginOrigin = '';
  String _lastFingerprint = '';
  bool _restoreDone = false;
  int _generation = 0;
  RouteChangedCallback? _routeChangedCallback;

  /// 当前激活服务器的实际请求地址。
  String get current {
    final hit = _currentByServer[_activeServerKey];
    if (hit != null && hit.origin.isNotEmpty) return hit.origin;
    return loginOrigin;
  }

  /// 当前激活服务器的路线枚举（未探测/旧服务器无地址簿时为 null）。
  RouteKind? get routeKind => _currentByServer[_activeServerKey]?.route;

  /// 发送在 `X-MovieClaw-Route` 请求头中的值（`'lan'` / `'vpn'` / `'wan'` / `null`）。
  String? get routeHeaderValue => routeKind?.headerValue;

  /// 兼容旧字段：`'lan'` / `'vpn'` / `'wan'` / `'login'`。
  String get kind => routeKind?.headerValue ?? 'login';

  /// 面向 UI 展示的中文路线文案。
  String get routeLabel => labelOf(routeKind);

  List<String> get lanCandidates {
    final book = _books[_activeServerKey];
    if (book == null) return const <String>[];
    return List.unmodifiable(
      book.endpoints.where((e) => e.kind == 'lan').map((e) => e.origin),
    );
  }

  List<String> get wanCandidates {
    final book = _books[_activeServerKey];
    if (book == null) return const <String>[];
    return List.unmodifiable(
      book.endpoints.where((e) => e.kind != 'lan').map((e) => e.origin),
    );
  }

  void setRouteChangedCallback(RouteChangedCallback? callback) {
    _routeChangedCallback = callback;
  }

  /// 读取持久化地址簿（冷启动调用，幂等）。
  Future<void> init() async {
    if (_restoreDone) return;
    _restoreDone = true;
    if (!_persistent) return;
    try {
      final rawBooks = await _store.read(key: _booksKey);
      if (rawBooks != null && rawBooks.isNotEmpty) {
        final decoded = jsonDecode(rawBooks);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is Map) {
              _books[k.toString()] =
                  ServerRouteBook.fromJson(v.cast<String, dynamic>());
            }
          });
        }
      }
      final savedLogin = await _store.read(key: '$_storeName.loginOrigin');
      if (savedLogin != null && savedLogin.isNotEmpty) {
        loginOrigin = normalizeOrigin(savedLogin);
        _activeServerKey = originKey(loginOrigin);
        final book = _books[_activeServerKey];
        if (book != null) {
          final net = await _networkProvider();
          _lastFingerprint = net.fingerprint;
          final guess = optimisticGuess(
            book: book,
            loginOrigin: loginOrigin,
            net: net,
          );
          if (guess != null) {
            _currentByServer[_activeServerKey] = guess;
          }
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  /// 激活某台服务器的路由地址簿（冷启动、登录、切换账号）：
  /// 先用本机受信任记忆零延迟预选，再在后台竞速验签并刷新地址簿。
  Future<void> activate(
    String origin, {
    String? token,
    Future<ServerAddressesView?> Function()? fetchBook,
  }) async {
    await init();
    final normOrigin = normalizeOrigin(origin);
    if (normOrigin.isEmpty) return;
    final key = originKey(normOrigin);

    loginOrigin = normOrigin;
    _activeServerKey = key;
    if (_persistent) {
      unawaited(_store.write(key: '$_storeName.loginOrigin', value: normOrigin));
    }

    final net = await _networkProvider();
    _lastFingerprint = net.fingerprint;

    final existingBook = _books[key];
    if (existingBook != null) {
      final next = regrounded(
        _currentByServer[key],
        book: existingBook,
        loginOrigin: normOrigin,
        net: net,
      );
      if (next != null) {
        _currentByServer[key] = next;
      } else {
        _currentByServer.remove(key);
      }
    }
    notifyListeners();

    if (existingBook != null) {
      unawaited(_select(normOrigin));
    }

    if (fetchBook != null) {
      await _refreshBook(normOrigin, fetchBook);
    } else if (token != null && token.isNotEmpty) {
      unawaited(
        _refreshBook(
          normOrigin,
          () => _fetchAddressesDirectly(normOrigin, token),
        ),
      );
    }
  }

  /// 兼容旧签名：配置当前服务器地址簿并启动竞速。
  Future<void> configure(
    String origin,
    Future<ServerAddressesView?> Function() fetchBook,
  ) =>
      activate(origin, fetchBook: fetchBook);

  /// 网络环境可能变化（回到前台、网卡变更）时重新评估路线。
  void reevaluate() {
    if (loginOrigin.isEmpty) return;
    unawaited(_handleNetworkCheck());
  }

  Future<void> _handleNetworkCheck() async {
    final normOrigin = loginOrigin;
    if (normOrigin.isEmpty) return;
    final key = originKey(normOrigin);
    final book = _books[key];
    if (book == null) return;

    final net = await _networkProvider();
    final fpChanged =
        _lastFingerprint.isNotEmpty && _lastFingerprint != net.fingerprint;
    _lastFingerprint = net.fingerprint;

    if (fpChanged) {
      final prev = _currentByServer[key];
      final next = regrounded(
        prev,
        book: book,
        loginOrigin: normOrigin,
        net: net,
      );
      if (next != prev) {
        if (next != null) {
          _currentByServer[key] = next;
        } else {
          _currentByServer.remove(key);
        }
        _emitRouteChanged(currentOrigin(normOrigin), routeKind);
      }
    }
    await _select(normOrigin, rerun: fpChanged);
  }

  /// 当前地址发生硬错误（断连、DNS 失败、超时、证书异常）时执行故障切换：
  /// 排除失败地址并重新竞速；若选出不同地址则立即返回新地址供调用方重试。
  Future<String?> failover(String failedOrigin, {String? forServer}) async {
    final targetServer =
        normalizeOrigin(forServer?.isNotEmpty == true ? forServer! : loginOrigin);
    if (targetServer.isEmpty) return null;
    final key = originKey(targetServer);
    if (!_books.containsKey(key)) return null;

    final failedKey = originKey(failedOrigin);
    await _select(targetServer, excludingKey: failedKey, rerun: true);
    final selected = originFor(targetServer);
    if (originKey(selected) != failedKey) {
      return selected;
    }
    return null;
  }

  /// 把任意指向本服务器已知地址的 URL 重写为当前最优地址（保留路径、查询串与片段）；
  /// 不认识的地址原样返回。
  String rewrite(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return url;
    final urlKey = originKey(url);
    String? targetOrigin;

    final direct = _currentByServer[urlKey];
    if (direct != null) {
      targetOrigin = direct.origin;
    } else {
      for (final entry in _books.entries) {
        final matched = entry.key == urlKey ||
            entry.value.endpoints.any((e) => originKey(e.origin) == urlKey);
        if (matched) {
          targetOrigin = _currentByServer[entry.key]?.origin;
          break;
        }
      }
    }

    if (targetOrigin == null || originKey(targetOrigin) == urlKey) {
      return url;
    }
    final targetUri = Uri.tryParse(targetOrigin);
    if (targetUri == null || !targetUri.hasScheme || targetUri.host.isEmpty) {
      return url;
    }
    final rewritten = uri.replace(
      scheme: targetUri.scheme,
      host: targetUri.host,
      port: targetUri.hasPort
          ? targetUri.port
          : (targetUri.scheme == 'https' ? 443 : 80),
    );
    // 去掉默认端口以保持规范 URL
    final normalizedPrefix = normalizeOrigin(targetOrigin);
    final pathAndMore = StringBuffer();
    if (rewritten.path.isNotEmpty) pathAndMore.write(rewritten.path);
    if (rewritten.hasQuery) pathAndMore.write('?${rewritten.query}');
    if (rewritten.hasFragment) pathAndMore.write('#${rewritten.fragment}');
    return '$normalizedPrefix$pathAndMore';
  }

  /// 返回某台服务器所有已知地址的 `host[:port]` 集合（供扫码设备批准做跨服务器校验）。
  Set<String> hostLabels(String serverOrigin) {
    final norm = normalizeOrigin(serverOrigin);
    final result = <String>{};
    final loginLabel = hostLabelOf(norm);
    if (loginLabel.isNotEmpty) result.add(loginLabel);
    final book = _books[originKey(norm)];
    if (book != null) {
      for (final ep in book.endpoints) {
        final label = hostLabelOf(ep.origin);
        if (label.isNotEmpty) result.add(label);
      }
    }
    return result;
  }

  /// 判断 URL 是否属于指定服务器（登录地址、当前地址或地址簿中任一地址）。
  bool belongsToServer(String url, String serverOrigin) {
    final target = originKey(url);
    if (target.isEmpty) return false;
    final key = originKey(serverOrigin);
    if (target == key) return true;
    final currentEntry = _currentByServer[key];
    if (currentEntry != null && originKey(currentEntry.origin) == target) {
      return true;
    }
    final book = _books[key];
    if (book == null) return false;
    return book.endpoints.any((e) => originKey(e.origin) == target);
  }

  /// 查询指定服务器当前选用的地址；未选出时返回该服务器的登录地址。
  String originFor(String serverOrigin) {
    final norm = normalizeOrigin(serverOrigin);
    if (norm.isEmpty) return '';
    return _currentByServer[originKey(norm)]?.origin ?? norm;
  }

  /// 查询指定服务器当前的路线枚举。
  RouteKind? routeFor(String serverOrigin) =>
      _currentByServer[originKey(normalizeOrigin(serverOrigin))]?.route;

  /// 获取当前激活服务器的请求地址（兼容旧签名）。
  String currentOrigin([String fallback = '']) {
    if (_activeServerKey.isNotEmpty) {
      final hit = _currentByServer[_activeServerKey];
      if (hit != null && hit.origin.isNotEmpty) return hit.origin;
    }
    if (loginOrigin.isNotEmpty) return loginOrigin;
    return normalizeOrigin(fallback);
  }

  /// 兼容旧调用：触发当前激活服务器的竞速探测。
  Future<void> pick() async {
    if (loginOrigin.isEmpty) return;
    await _select(loginOrigin);
  }

  /// 清空当前激活路由与全部持久化地址簿。
  Future<void> reset() async {
    _activeServerKey = '';
    loginOrigin = '';
    _lastFingerprint = '';
    _books.clear();
    _currentByServer.clear();
    _selecting.clear();
    if (_persistent) {
      try {
        await _store.delete(key: _booksKey);
        await _store.delete(key: '$_storeName.current');
        await _store.delete(key: '$_storeName.kind');
        await _store.delete(key: '$_storeName.loginOrigin');
      } catch (_) {}
    }
    notifyListeners();
  }

  @visibleForTesting
  void installBook(String serverOrigin, ServerRouteBook book) {
    final norm = normalizeOrigin(serverOrigin);
    final key = originKey(norm);
    _books[key] = book;
    if (_activeServerKey.isEmpty) {
      _activeServerKey = key;
      loginOrigin = norm;
    }
  }

  @visibleForTesting
  void setCurrentForTest(String serverOrigin, ServerRouteCurrent? value) {
    final key = originKey(normalizeOrigin(serverOrigin));
    if (value == null) {
      _currentByServer.remove(key);
    } else {
      _currentByServer[key] = value;
    }
  }

  ServerRouteBook? bookFor(String serverOrigin) =>
      _books[originKey(normalizeOrigin(serverOrigin))];

  // ── 内部地址簿刷新与并发竞速 ──────────────────────────────────────────────

  Future<void> _refreshBook(
    String serverOrigin,
    Future<ServerAddressesView?> Function() fetchBook,
  ) async {
    ServerAddressesView? view;
    try {
      view = await fetchBook();
    } catch (_) {
      return;
    }
    if (view == null) return;
    final key = originKey(serverOrigin);
    final endpoints = <ServerRouteEndpoint>[];
    for (final item in view.addresses) {
      final norm = normalizeOrigin(item.url);
      if (norm.isEmpty) continue;
      final ep = ServerRouteEndpoint(
        origin: norm,
        kind: item.kind == 'lan' ? 'lan' : 'wan',
      );
      if (!endpoints.contains(ep)) {
        endpoints.add(ep);
      }
    }
    // 登录地址始终在候选列表中
    if (!endpoints.any((e) => originKey(e.origin) == key)) {
      endpoints.add(
        ServerRouteEndpoint(
          origin: serverOrigin,
          kind: guessKind(serverOrigin),
        ),
      );
    }

    final previous = _books[key];
    final nextBook = ServerRouteBook(
      instanceId: view.instanceId,
      hostKey: view.hostKey,
      endpoints: endpoints,
      lanSubnets: view.lanSubnets,
      memory: previous?.memory ?? const <RouteMemoryEntry>[],
    );

    final changed = previous == null ||
        previous.instanceId != nextBook.instanceId ||
        previous.hostKey != nextBook.hostKey ||
        !setEquals(previous.endpoints.toSet(), nextBook.endpoints.toSet());

    _books[key] = nextBook;
    await _persistBooks();

    if (changed || _currentByServer[key] == null) {
      await _select(serverOrigin, rerun: true);
    }
  }

  Future<ServerAddressesView?> _fetchAddressesDirectly(
    String serverOrigin,
    String token,
  ) async {
    final target = originFor(serverOrigin);
    final dio = _probeDio ??
        Dio(
          BaseOptions(
            connectTimeout: _wanTimeout,
            receiveTimeout: _wanTimeout,
            validateStatus: (_) => true,
          ),
        );
    try {
      final res = await dio.get<dynamic>(
        '$target/api/v1/server/addresses',
        options: Options(
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      if (res.statusCode != 200) return null;
      final raw = res.data;
      Map<String, dynamic>? map;
      if (raw is Map<String, dynamic>) {
        map = raw;
      } else if (raw is Map) {
        map = raw.cast<String, dynamic>();
      } else if (raw is String && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) map = decoded.cast<String, dynamic>();
      }
      if (map == null) return null;
      final payload = map['data'] is Map
          ? (map['data'] as Map).cast<String, dynamic>()
          : map;
      return ServerAddressesView.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> _select(
    String serverOrigin, {
    String? excludingKey,
    bool rerun = false,
  }) {
    final key = originKey(serverOrigin);
    final running = _selecting[key];
    if (running != null && !rerun) return running;

    final mine = ++_generation;
    final task = () async {
      if (running != null) {
        try {
          await running;
        } catch (_) {}
      }
      await _race(serverOrigin, excludingKey: excludingKey);
      if (_generation == mine) {
        _selecting.remove(key);
      }
    }();
    _selecting[key] = task;
    return task;
  }

  Future<void> _race(String serverOrigin, {String? excludingKey}) async {
    final key = originKey(serverOrigin);
    final book = _books[key];
    if (book == null) return;

    final net = await _networkProvider();
    _lastFingerprint = net.fingerprint;

    final list = candidates(book: book, net: net)
        .where((ep) => originKey(ep.origin) != excludingKey)
        .toList();
    if (list.isEmpty) return;

    final lan = list.where((e) => e.kind == 'lan').toList();
    final wan = list.where((e) => e.kind != 'lan').toList();

    final lanFutures = <Future<ServerRouteEndpoint?>>[
      for (final ep in lan)
        _probeEndpoint(ep, book: book, timeout: _lanTimeout)
            .then((ok) => ok ? ep : null),
    ];
    final wanFutures = <Future<ServerRouteEndpoint?>>[
      for (final ep in wan)
        () async {
          if (lan.isNotEmpty) await Future<void>.delayed(_wanDelay);
          final ok = await _probeEndpoint(ep, book: book, timeout: _wanTimeout);
          return ok ? ep : null;
        }(),
    ];

    final all = <Future<ServerRouteEndpoint?>>[...lanFutures, ...wanFutures];
    final firstWinner = await _firstNonNull(all);
    if (firstWinner == null) return;

    _adopt(firstWinner, serverOrigin: serverOrigin, book: book, net: net);

    // 若外网先响应，继续等待进行中的内网探测：一旦内网验签通过立即平滑升级。
    if (firstWinner.kind != 'lan' && lanFutures.isNotEmpty) {
      final lanWinner = await _firstNonNull(lanFutures);
      if (lanWinner != null) {
        _adopt(lanWinner, serverOrigin: serverOrigin, book: book, net: net);
      }
    }
  }

  void _adopt(
    ServerRouteEndpoint endpoint, {
    required String serverOrigin,
    required ServerRouteBook book,
    required NetworkSnapshot net,
  }) {
    final key = originKey(serverOrigin);
    final route = classifyRoute(endpoint: endpoint, book: book, net: net);
    final next = ServerRouteCurrent(origin: endpoint.origin, route: route);
    final prev = _currentByServer[key];
    final changed = prev != next;
    _currentByServer[key] = next;

    final stored = _books[key];
    if (stored != null) {
      final updatedMemory = stored.memory
          .where((m) => m.fingerprint != net.fingerprint)
          .toList()
        ..add(
          RouteMemoryEntry(
            fingerprint: net.fingerprint,
            origin: endpoint.origin,
          ),
        );
      final trimmed = updatedMemory.length > _memoryLimit
          ? updatedMemory.sublist(updatedMemory.length - _memoryLimit)
          : updatedMemory;
      _books[key] = stored.copyWith(memory: trimmed);
      unawaited(_persistBooks());
    }

    if (changed && key == _activeServerKey) {
      _emitRouteChanged(next.origin, next.route);
    } else if (changed) {
      notifyListeners();
    }
  }

  void _emitRouteChanged(String origin, RouteKind? route) {
    notifyListeners();
    try {
      _routeChangedCallback?.call(origin, route);
    } catch (_) {}
  }

  Future<void> _persistBooks() async {
    if (!_persistent) return;
    try {
      final encoded = jsonEncode(
        _books.map((k, v) => MapEntry<String, dynamic>(k, v.toJson())),
      );
      await _store.write(key: _booksKey, value: encoded);
    } catch (_) {}
  }

  // ── 探测与 Ed25519 主机验签 ───────────────────────────────────────────────

  Future<bool> _probeEndpoint(
    ServerRouteEndpoint endpoint, {
    required ServerRouteBook book,
    required Duration timeout,
  }) async {
    final nonce = generateNonce(_secureRng);
    final dio = _probeDio ??
        Dio(
          BaseOptions(
            connectTimeout: timeout,
            receiveTimeout: timeout,
            sendTimeout: timeout,
            validateStatus: (_) => true,
          ),
        );
    try {
      final res = await dio.get<dynamic>(
        '${endpoint.origin}/api/v1/health',
        queryParameters: <String, dynamic>{'nonce': nonce},
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
          headers: const <String, String>{'Accept': 'application/json'},
        ),
      );
      if (res.statusCode != 200) return false;
      final hasSpecHeader =
          res.headers.value('x-movieclaw-spec-hash') != null &&
              res.headers.value('x-movieclaw-spec-hash')!.isNotEmpty;
      Map<String, dynamic>? health;
      if (res.data is Map<String, dynamic>) {
        health = res.data as Map<String, dynamic>;
      } else if (res.data is Map) {
        health = (res.data as Map).cast<String, dynamic>();
      } else if (res.data is String && (res.data as String).trim().isNotEmpty) {
        final decoded = jsonDecode(res.data as String);
        if (decoded is Map) health = decoded.cast<String, dynamic>();
      }
      if (health == null) return false;
      return await verifyHealthProof(
        health: health,
        nonce: nonce,
        book: book,
        hasSpecHashHeader: hasSpecHeader,
      );
    } catch (_) {
      return false;
    }
  }

  /// 生成 18 字节密码学安全随机 base64url（无填充）质询 nonce。
  static String generateNonce([math.Random? rng]) {
    final random = rng ?? math.Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// 三关身份校验（对齐 iOS `ServerRoutes.verify`）：
  /// 1. `book.instanceId` 与 `health['instance_id']` 均不可为空且必须完全一致；
  /// 2. 必须存在 `x-movieclaw-spec-hash` 响应头（`hasSpecHashHeader`）；
  /// 3. 若地址簿含 `hostKey`，使用 Ed25519 校验 `health['proof']` 对 UTF-8
  ///    `"movieclaw-health\n$instanceId\n$nonce"` 的签名。
  static Future<bool> verifyHealthProof({
    required Map<String, dynamic> health,
    required String nonce,
    required ServerRouteBook book,
    bool hasSpecHashHeader = true,
  }) async {
    if (!hasSpecHashHeader) return false;
    final expectedId = book.instanceId.trim();
    final actualId = (health['instance_id'] ?? '').toString().trim();
    // 绝不把空 instance_id 视为验证通过！
    if (expectedId.isEmpty || actualId.isEmpty || actualId != expectedId) {
      return false;
    }
    final status = health['status']?.toString();
    if (status != null && status.isNotEmpty && status != 'ok') {
      return false;
    }
    if (book.hostKey.trim().isEmpty) {
      return true;
    }
    final proof = (health['proof'] ?? '').toString().trim();
    if (proof.isEmpty) return false;

    final keyBytes = decodeBase64Url(book.hostKey.trim());
    final sigBytes = decodeBase64Url(proof);
    if (keyBytes == null ||
        sigBytes == null ||
        keyBytes.length != 32 ||
        sigBytes.length != 64) {
      return false;
    }
    try {
      final algorithm = Ed25519();
      final publicKey = SimplePublicKey(keyBytes, type: KeyPairType.ed25519);
      final signature = Signature(sigBytes, publicKey: publicKey);
      final message = utf8.encode('movieclaw-health\n$expectedId\n$nonce');
      return await algorithm.verify(message, signature: signature);
    } catch (_) {
      return false;
    }
  }

  /// base64url（支持无填充）解码。
  static List<int>? decodeBase64Url(String input) {
    try {
      return base64Url.decode(base64Url.normalize(input));
    } catch (_) {
      return null;
    }
  }

  /// 兼容旧静态探测辅助：返回非空 `instance_id`；空 `instance_id` 不再伪造 `'ok'`。
  static Future<String?> probeInstance(String origin) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: _lanTimeout,
          receiveTimeout: _lanTimeout,
          validateStatus: (_) => true,
        ),
      );
      final res = await dio.get<dynamic>(
        '${normalizeOrigin(origin)}/api/v1/health',
        options: Options(headers: const <String, String>{'Accept': 'application/json'}),
      );
      if (res.statusCode != 200) return null;
      Map<String, dynamic>? map;
      if (res.data is Map<String, dynamic>) {
        map = res.data as Map<String, dynamic>;
      } else if (res.data is Map) {
        map = (res.data as Map).cast<String, dynamic>();
      } else if (res.data is String && (res.data as String).trim().isNotEmpty) {
        final decoded = jsonDecode(res.data as String);
        if (decoded is Map) map = decoded.cast<String, dynamic>();
      }
      if (map == null || map['status'] != 'ok') return null;
      final id = (map['instance_id'] ?? '').toString().trim();
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  // ── 纯函数规则（可直接单元测试）──────────────────────────────────────────

  /// 这一轮参与竞速的候选：纯蜂窝网络时不试内网地址。
  static List<ServerRouteEndpoint> candidates({
    required ServerRouteBook book,
    required NetworkSnapshot net,
  }) =>
      book.endpoints
          .where((e) => e.kind != 'lan' || net.canReachPrivate)
          .toList();

  /// 冷启动/网络切换时的零延迟乐观预选（对齐 iOS `ServerRoutes.optimisticGuess`）：
  /// - 仅信任登录地址或 HTTPS 地址，绝不盲信其它网络记忆中的明文 `http://` 内网地址；
  /// - 仅当当前网络指纹命中记忆且目标受信任时才复用上次地址；
  /// - 未经探测验签时不标注 `vpn`（route 置 null）。
  static ServerRouteCurrent? optimisticGuess({
    required ServerRouteBook book,
    required String loginOrigin,
    required NetworkSnapshot net,
  }) {
    final normLogin = normalizeOrigin(loginOrigin);
    final loginKey = originKey(normLogin);
    final usable = candidates(book: book, net: net);

    bool trusted(ServerRouteEndpoint ep) {
      if (originKey(ep.origin) == loginKey) return true;
      final uri = Uri.tryParse(ep.origin);
      return uri?.scheme.toLowerCase() == 'https';
    }

    RouteMemoryEntry? remembered;
    for (var i = book.memory.length - 1; i >= 0; i--) {
      if (book.memory[i].fingerprint == net.fingerprint) {
        remembered = book.memory[i];
        break;
      }
    }
    if (remembered != null) {
      final rememberedKey = originKey(remembered.origin);
      for (final ep in usable) {
        if (originKey(ep.origin) == rememberedKey && trusted(ep)) {
          return ServerRouteCurrent(
            origin: ep.origin,
            route: classifyRoute(endpoint: ep, book: book, net: net),
          );
        }
      }
    }

    ServerRouteEndpoint? loginEp;
    for (final ep in usable) {
      if (originKey(ep.origin) == loginKey) {
        loginEp = ep;
        break;
      }
    }

    var loginLooksAway = true;
    if (loginEp != null) {
      final host = Uri.tryParse(loginEp.origin)?.host ?? '';
      loginLooksAway = loginEp.kind == 'lan' &&
          parseIPv4(host) != null &&
          !net.sameSubnet(host);
    }

    ServerRouteCurrent unverified(ServerRouteEndpoint ep) {
      final r = classifyRoute(endpoint: ep, book: book, net: net);
      return ServerRouteCurrent(
        origin: ep.origin,
        route: r == RouteKind.vpn ? null : r,
      );
    }

    if (loginEp != null && !loginLooksAway) {
      return unverified(loginEp);
    }
    for (final ep in usable) {
      if (ep.kind != 'lan' && trusted(ep)) {
        return ServerRouteCurrent(origin: ep.origin, route: RouteKind.wan);
      }
    }
    return loginEp != null ? unverified(loginEp) : null;
  }

  /// 网络变化后当场重定路线（不留上个网络的内网地址或 `vpn` 状态）。
  static ServerRouteCurrent? regrounded(
    ServerRouteCurrent? current, {
    required ServerRouteBook book,
    required String loginOrigin,
    required NetworkSnapshot net,
  }) {
    final guess = optimisticGuess(
      book: book,
      loginOrigin: loginOrigin,
      net: net,
    );
    if (guess != null) return guess;
    if (current == null) return null;
    final curKey = originKey(current.origin);
    final stillCandidate = candidates(book: book, net: net)
        .any((ep) => originKey(ep.origin) == curKey);
    return stillCandidate ? current : null;
  }

  /// 端点路线分类（`lan` / `vpn` / `wan`）：
  /// - CGNAT/Tailscale `100.64.0.0/10` 绝不归为纯 `lan`：匹配 VPN 或有 VPN 时为 `vpn`，否则 `wan`；
  /// - `kind == 'lan'` 且为 IPv4：与实体网卡同网段 -> `lan`；否则有 VPN -> `vpn`；无 VPN -> `lan`（多 VLAN 路由器转发）；
  /// - `kind == 'lan'` 且为内网域名：实体网卡在 `lanSubnets` 内 -> `lan`；否则有 VPN -> `vpn`，无 VPN -> `wan`。
  static RouteKind classifyRoute({
    required ServerRouteEndpoint endpoint,
    required ServerRouteBook book,
    required NetworkSnapshot net,
  }) {
    final host = Uri.tryParse(endpoint.origin)?.host ?? '';
    final ip = parseIPv4(host);
    if (ip != null && isCgnatIp(ip)) {
      return (net.matchesVpnSubnet(host) || net.hasVpn)
          ? RouteKind.vpn
          : RouteKind.wan;
    }
    if (endpoint.kind != 'lan') return RouteKind.wan;
    if (ip != null) {
      if (net.sameSubnet(host)) return RouteKind.lan;
      return net.hasVpn ? RouteKind.vpn : RouteKind.lan;
    }
    if (net.physicalIn(book.lanSubnets)) return RouteKind.lan;
    return net.hasVpn ? RouteKind.vpn : RouteKind.wan;
  }

  /// 猜测地址属于 `'lan'` 还是 `'wan'`：
  /// `100.64.0.0/10`（CGNAT / Tailscale）不归类为纯 `'lan'`。
  static String guessKind(String origin) {
    final host = _extractHost(origin).toLowerCase();
    if (host.isEmpty) return 'wan';
    final ip = parseIPv4(host);
    if (ip != null) {
      if (isCgnatIp(ip)) return 'wan';
      return (isRfc1918PrivateIp(ip) ||
              (ip >> 24) == 127 ||
              (ip >> 16) == 0xA9FE)
          ? 'lan'
          : 'wan';
    }
    const suffixes = <String>[
      '.local',
      '.lan',
      '.home.arpa',
      '.internal',
      '.localdomain',
    ];
    return (!host.contains('.') || suffixes.any(host.endsWith)) ? 'lan' : 'wan';
  }

  /// 判断主机是否为私网地址（RFC1918 / 回环 / 链路本地 / 本地后缀；不含 CGNAT `100.64.0.0/10`）。
  static bool isPrivateHost(String origin) => guessKind(origin) == 'lan';

  /// 是否为 `100.64.0.0/10`（CGNAT / Tailscale）。
  static bool isCgnatIp(int ip) => (ip >> 22) == ((100 << 2) | 1);

  /// 是否为 RFC1918 私有地址（10/8, 172.16/12, 192.168/16）。
  static bool isRfc1918PrivateIp(int ip) {
    final a = (ip >> 24) & 0xFF;
    final b = (ip >> 16) & 0xFF;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }

  /// 解析点分十进制 IPv4 为无符号 32 位整数；非法返回 null。
  static int? parseIPv4(String text) {
    final parts = text.trim().split('.');
    if (parts.length != 4) return null;
    var result = 0;
    for (final p in parts) {
      if (p.isEmpty) return null;
      final octet = int.tryParse(p);
      if (octet == null || octet < 0 || octet > 255) return null;
      result = (result << 8) | octet;
    }
    return result;
  }

  /// 规范化 origin：只保留 `scheme://host[:nonDefaultPort]`，去尾斜杠。
  static String normalizeOrigin(String raw) {
    var v = raw.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    final uri = Uri.tryParse(v);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return v;
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final isDefaultPort = !uri.hasPort ||
        (scheme == 'http' && uri.port == 80) ||
        (scheme == 'https' && uri.port == 443);
    return isDefaultPort ? '$scheme://$host' : '$scheme://$host:${uri.port}';
  }

  /// 比较用规范键：`scheme://host:port`（补齐默认端口）。
  static String originKey(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return raw.trim().toLowerCase();
    }
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final port = uri.hasPort ? uri.port : (scheme == 'https' ? 443 : 80);
    return '$scheme://$host:$port';
  }

  /// 提取 `host[:port]`（去掉协议与默认端口），供报错提示与跨服扫码校验使用。
  static String hostLabelOf(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return '';
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final isDefaultPort = !uri.hasPort ||
        (scheme == 'http' && uri.port == 80) ||
        (scheme == 'https' && uri.port == 443);
    return isDefaultPort ? host : '$host:${uri.port}';
  }

  static String labelOf(RouteKind? route) {
    switch (route) {
      case RouteKind.lan:
        return '家里网络';
      case RouteKind.vpn:
        return 'VPN';
      case RouteKind.wan:
        return '外网';
      case null:
        return '';
    }
  }

  static String _extractHost(String origin) {
    final uri = Uri.tryParse(origin.trim());
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    var rest = origin.trim();
    final scheme = rest.indexOf('://');
    if (scheme >= 0) rest = rest.substring(scheme + 3);
    final slash = rest.indexOf('/');
    if (slash >= 0) rest = rest.substring(0, slash);
    final colon = rest.indexOf(':');
    return colon >= 0 ? rest.substring(0, colon) : rest;
  }

  static Future<T?> _firstNonNull<T>(List<Future<T?>> futures) {
    if (futures.isEmpty) return Future<T?>.value(null);
    final completer = Completer<T?>();
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
    this.lanSubnets = const <String>[],
  });

  factory ServerAddressesView.fromJson(Map<String, dynamic> json) =>
      ServerAddressesView(
        instanceId: (json['instance_id'] ?? '').toString(),
        hostKey: (json['host_key'] ?? '').toString(),
        lanSubnets: <String>[
          for (final s in (json['lan_subnets'] as List? ?? const <dynamic>[]))
            s.toString(),
        ].where((s) => s.isNotEmpty).toList(),
        addresses: <ServerAddressItem>[
          for (final item in (json['addresses'] as List? ?? const <dynamic>[]))
            if (item is Map<String, dynamic>)
              ServerAddressItem.fromJson(item)
            else if (item is Map)
              ServerAddressItem.fromJson(item.cast<String, dynamic>()),
        ],
      );

  final String instanceId;
  final String hostKey;
  final List<String> lanSubnets;
  final List<ServerAddressItem> addresses;
}

final serverRoutesProvider = ChangeNotifierProvider<ServerRoutes>((ref) {
  return ServerRoutes.instance;
});
