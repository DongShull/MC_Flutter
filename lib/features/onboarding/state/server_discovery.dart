import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/server_routes.dart';

/// 局域网自动发现结果（对齐 iOS `ServerDiscovery.Found`）。
class DiscoveredServer {
  const DiscoveredServer({required this.origin, required this.name});

  final String origin;
  final String name;
}

/// 一条局域网发现应答（或同一来源 IP 合并后的结果）。
class DiscoveryReply {
  const DiscoveryReply({
    required this.addresses,
    required this.name,
    required this.source,
    this.native = false,
  });

  final List<String> addresses;
  final String name;
  final String source;
  final bool native;
}

/// 局域网自动发现与裸主机探测（1:1 对齐 iOS `Shared/Core/Networking/ServerDiscovery.swift`）：
/// - 枚举本机非回环 RFC1918 IPv4 网卡所在 `/24` 网段（最多 1024 个主机）；
/// - 向 UDP 7359 逐个单播发送 `"who is MovieClawServer?"` 与 `"who is JellyfinServer?"`
///   （每 16 个主机休眠 2ms 防止 `ENOBUFS`），最多 6 轮、轮间间隔 1.5s；
/// - 解析 `movieclaw.discovery` JSON `addresses`（含 Jellyfin 应答 `Address` 兼容），
///   附加 `http://<sourceIp>:<port>` 与兜底 `http://<sourceIp>:3000`；
/// - 并发请求 `GET /api/v1/health` 校验 HTTP 200 且 JSON `status == "ok"` 才确认是 MovieClaw。
abstract final class ServerDiscovery {
  static const int port = 7359;
  static const int defaultPort = 3000;
  static const List<String> queries = <String>[
    'who is MovieClawServer?',
    'who is JellyfinServer?',
  ];

  static final Dio _probeDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 2500),
      receiveTimeout: const Duration(milliseconds: 2500),
      sendTimeout: const Duration(milliseconds: 2500),
      headers: const <String, String>{'Accept': 'application/json'},
      validateStatus: (_) => true,
    ),
  );

  /// 清理用户输入/粘贴的服务器地址：
  /// 替换中文标点、去空白、剥离粘贴的 `/login` 等路径/查询串/片段与默认 `:80`/`:443` 端口。
  static String normalizeServerOrigin(String raw) {
    var s = raw
        .trim()
        .replaceAll('：', ':')
        .replaceAll('。', '.')
        .replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return '';
    if (!s.contains('://')) {
      final hostPart = s.split('/').first.split('?').first.split('#').first;
      s = ServerRoutes.isPrivateHost(hostPart) ? 'http://$s' : 'https://$s';
    }
    final uri = Uri.tryParse(s);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      while (s.endsWith('/')) {
        s = s.substring(0, s.length - 1);
      }
      return s;
    }
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.contains(':') && !uri.host.startsWith('[')
        ? '[${uri.host}]'
        : uri.host.toLowerCase();
    final isDefaultPort = !uri.hasPort ||
        (scheme == 'http' && uri.port == 80) ||
        (scheme == 'https' && uri.port == 443);
    return isDefaultPort ? '$scheme://$host' : '$scheme://$host:${uri.port}';
  }

  /// 手动输入裸主机/IP（未写协议也未写端口，如 `192.168.1.10` 或 `nas.local`）时的候选探测列表：
  /// 按 `http://<host>:3000` -> `http://<host>` -> `https://<host>` 顺序返回。
  static List<String> manualAlternatives(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll('：', ':')
        .replaceAll('。', '.')
        .replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return const <String>[];
    final normalized = normalizeServerOrigin(cleaned);
    if (normalized.isEmpty) return const <String>[];

    // 用户已经写了协议或显式端口时，不再猜测其他方案。
    if (cleaned.contains('://')) return <String>[normalized];
    final probeUri = Uri.tryParse('http://$cleaned');
    if (probeUri == null || probeUri.host.isEmpty || probeUri.hasPort) {
      return <String>[normalized];
    }
    final host = probeUri.host.contains(':') && !probeUri.host.startsWith('[')
        ? '[${probeUri.host}]'
        : probeUri.host.toLowerCase();
    return <String>[
      'http://$host:$defaultPort',
      'http://$host',
      'https://$host',
    ];
  }

  /// 对裸主机输入并发探测 `/api/v1/health`，按优先级返回第一个确认是 MovieClaw 的地址；
  /// 若全部失败则返回标准规范化结果，交由登录流程给出明确错误。
  static Future<String> settleManualHost(String raw) async {
    final alternatives = manualAlternatives(raw);
    if (alternatives.isEmpty) return '';
    if (alternatives.length == 1) return alternatives.first;
    final verified = await firstMovieClaw(alternatives);
    return verified ?? normalizeServerOrigin(raw);
  }

  /// 局域网查找第一台可用 MovieClaw（最多 `rounds` 轮，轮间 `interval`）。
  static Future<DiscoveredServer?> findFirst({
    int rounds = 6,
    Duration interval = const Duration(milliseconds: 1500),
    bool Function()? isCancelled,
  }) async {
    final hosts = await localHosts();
    if (hosts.isEmpty) return null;

    for (var round = 0; round < rounds; round++) {
      if (isCancelled?.call() == true) return null;
      final replies = await _sweep(
        hosts: hosts,
        listenDuration: const Duration(milliseconds: 1200),
        isCancelled: isCancelled,
      );
      if (isCancelled?.call() == true) return null;
      for (final reply in mergeReplies(replies)) {
        final verified = await firstMovieClaw(candidatesFor(reply));
        if (verified != null) {
          return DiscoveredServer(origin: verified, name: reply.name);
        }
      }
      if (round < rounds - 1) {
        await Future<void>.delayed(interval);
      }
    }
    return null;
  }

  /// 解析单条 UDP 发现应答报文。
  static DiscoveryReply? parseReply(List<int> data, String sourceIp) {
    try {
      final decoded = jsonDecode(utf8.decode(data, allowMalformed: true));
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      String readName(String key) {
        final v = map[key]?.toString().trim() ?? '';
        return v.isEmpty ? 'MovieClaw' : v;
      }

      if (map['type']?.toString() == 'movieclaw.discovery') {
        final rawAddresses = map['addresses'];
        final addresses = <String>[
          if (rawAddresses is List)
            for (final item in rawAddresses)
              if (item is String && item.trim().isNotEmpty) item.trim(),
        ];
        return DiscoveryReply(
          addresses: addresses,
          name: readName('name'),
          source: sourceIp,
          native: true,
        );
      }
      final legacy = (map['Address'] ?? map['address'])?.toString().trim() ?? '';
      if (legacy.isEmpty) return null;
      return DiscoveryReply(
        addresses: <String>[legacy],
        name: readName('Name'),
        source: sourceIp,
        native: false,
      );
    } catch (_) {
      return null;
    }
  }

  /// 同一来源 IP 的多条应答合并（自家协议排前、去重地址）。
  static List<DiscoveryReply> mergeReplies(List<DiscoveryReply> replies) {
    final sources = <String>[];
    final grouped = <String, List<DiscoveryReply>>{};
    for (final r in replies) {
      if (!grouped.containsKey(r.source)) {
        sources.add(r.source);
        grouped[r.source] = <DiscoveryReply>[];
      }
      grouped[r.source]!.add(r);
    }
    final merged = <DiscoveryReply>[];
    for (final src in sources) {
      final group = grouped[src]!;
      final ordered = <DiscoveryReply>[
        ...group.where((r) => r.native),
        ...group.where((r) => !r.native),
      ];
      final addresses = <String>[];
      for (final r in ordered) {
        for (final addr in r.addresses) {
          if (!addresses.contains(addr)) addresses.add(addr);
        }
      }
      merged.add(
        DiscoveryReply(
          addresses: addresses,
          name: ordered.first.name,
          source: src,
          native: ordered.first.native,
        ),
      );
    }
    return merged;
  }

  /// 为一条应答构建候选地址列表（按可信度排序、去重）：
  /// 应答声明地址 -> 来源 IP + 应答中出现过的端口 -> 来源 IP + 默认 3000。
  static List<String> candidatesFor(DiscoveryReply reply) {
    final list = <String>[];
    void add(String raw) {
      final norm = normalizeServerOrigin(raw);
      if (norm.isNotEmpty && !list.contains(norm)) {
        list.add(norm);
      }
    }

    for (final addr in reply.addresses) {
      add(addr);
    }
    final ports = <int>[];
    for (final addr in reply.addresses) {
      final uri = Uri.tryParse(addr);
      if (uri != null && uri.hasPort && !ports.contains(uri.port)) {
        ports.add(uri.port);
      }
    }
    if (!ports.contains(defaultPort)) ports.add(defaultPort);
    for (final p in ports) {
      add('http://${reply.source}:$p');
    }
    return list;
  }

  /// 枚举本机私网 IPv4 网卡的 `/24` 网段主机列表（最多 1024 个）。
  static Future<List<int>> localHosts() async {
    try {
      final ifaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      final hosts = <int>[];
      final seen = <int>{};
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          final ip = ServerRoutes.parseIPv4(addr.address);
          if (ip == null) continue;
          if (!ServerRoutes.isRfc1918PrivateIp(ip)) continue;
          final kind = NetworkSnapshot.classifyInterface(
            iface.name,
            address: ip,
          );
          if (kind == NetworkInterfaceKind.cellular ||
              kind == NetworkInterfaceKind.vpn) {
            continue;
          }
          final network = ip & 0xFFFFFF00;
          for (var hostOctet = 1; hostOctet <= 254; hostOctet++) {
            final target = network | hostOctet;
            if (seen.add(target)) {
              hosts.add(target);
              if (hosts.length >= 1024) return hosts;
            }
          }
        }
      }
      return hosts;
    } catch (_) {
      return const <int>[];
    }
  }

  static Future<List<DiscoveryReply>> _sweep({
    required List<int> hosts,
    required Duration listenDuration,
    bool Function()? isCancelled,
  }) async {
    RawDatagramSocket? socket;
    final replies = <DiscoveryReply>[];
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        while (true) {
          final dg = socket?.receive();
          if (dg == null) break;
          final reply = parseReply(dg.data, dg.address.address);
          if (reply != null) {
            replies.add(reply);
          }
        }
      });

      final payloads = queries.map(utf8.encode).toList();
      for (var i = 0; i < hosts.length; i++) {
        if (isCancelled?.call() == true) break;
        final ipText = NetworkSnapshot.dottedIPv4(hosts[i]);
        final target = InternetAddress(ipText);
        for (final payload in payloads) {
          try {
            socket.send(payload, target, port);
          } catch (_) {
            // 忽略单个主机不可达或瞬时发送缓冲区满
          }
        }
        // 每 16 个主机（32 个包）让出 2ms，避免触发 ENOBUFS 丢包。
        if (i % 16 == 15) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      }

      if (isCancelled?.call() != true) {
        await Future<void>.delayed(listenDuration);
      }
      await sub.cancel();
    } catch (_) {
      // 无本地网络权限或沙盒限制时静默跳过。
    } finally {
      socket?.close();
    }
    return replies;
  }

  /// 并发探测候选地址，返回优先级最高（下标最小）且通过 `/api/v1/health` 验真的地址。
  static Future<String?> firstMovieClaw(List<String> candidates) async {
    if (candidates.isEmpty) return null;
    final checks = await Future.wait<int?>(
      List<Future<int?>>.generate(candidates.length, (i) async {
        final ok = await isMovieClaw(candidates[i]);
        return ok ? i : null;
      }),
    );
    int? best;
    for (final idx in checks) {
      if (idx != null && (best == null || idx < best)) {
        best = idx;
      }
    }
    return best == null ? null : candidates[best];
  }

  /// 校验 `GET <origin>/api/v1/health` 返回 HTTP 200 且 JSON `status == "ok"`。
  static Future<bool> isMovieClaw(String origin) async {
    try {
      final res = await _probeDio.get<dynamic>('$origin/api/v1/health');
      if (res.statusCode != 200) return false;
      final data = res.data;
      Map<String, dynamic>? map;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is Map) {
        map = data.cast<String, dynamic>();
      } else if (data is String && data.trim().startsWith('{')) {
        final decoded = jsonDecode(data);
        if (decoded is Map) map = decoded.cast<String, dynamic>();
      }
      return map?['status']?.toString() == 'ok';
    } catch (_) {
      return false;
    }
  }
}
