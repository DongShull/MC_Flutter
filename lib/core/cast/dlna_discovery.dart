import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../api/mc_error.dart';
/// DLNA/SSDP 设备发现（纯 Dart，对齐 UPnP DeviceArchitecture 1.1）：
/// M-SEARCH 组播 239.255.255.250:1900，收集 MediaRenderer 应答的 LOCATION/USN。
class DlnaDevice {
  const DlnaDevice({
    required this.location,
    required this.usn,
    required this.friendlyName,
    required this.controlUrl,
  });

  final String location; // 设备描述 XML 的 URL
  final String usn;
  final String friendlyName;

  /// AVTransport controlURL（绝对地址），SOAP 动作目标。
  final String controlUrl;

  @override
  bool operator ==(Object other) => other is DlnaDevice && other.usn == usn;
  @override
  int get hashCode => usn.hashCode;
}

class DlnaDiscovery {
  static const _ssdpAddr = '239.255.255.250';
  static const _ssdpPort = 1900;

  /// 搜索 [timeout] 毫秒，返回去重后的 MediaRenderer 列表（含 friendlyName
  /// 与 AVTransport controlURL 解析）。
  static Future<List<DlnaDevice>> search({
    Duration timeout = const Duration(milliseconds: 3000),
  }) async {
    final RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
    } on SocketException {
      return const [];
    }
    final found = <String, DlnaDevice>{};
    final locations = <String>{};
    try {
      socket.send(
        _msearch().codeUnits,
        InternetAddress(_ssdpAddr),
        _ssdpPort,
      );
      // 再发一次提升发现率
      socket.send(
        _msearch().codeUnits,
        InternetAddress(_ssdpAddr),
        _ssdpPort,
      );
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        final packet = await _nextPacket(socket, deadline.difference(DateTime.now()));
        if (packet == null) break;
        final text = String.fromCharCodes(packet);
        final location = _header(text, 'LOCATION');
        final usn = _header(text, 'USN');
        final st = _header(text, 'ST') ?? _header(text, 'NT');
        if (location == null || usn == null) continue;
        final isRenderer = st != null &&
            (st.contains('MediaRenderer') ||
                st.contains('AVTransport') ||
                st == 'upnp:rootdevice');
        if (!isRenderer || locations.contains(location)) continue;
        locations.add(location);
        final device = await _resolve(location, usn);
        if (device != null) found[usn] = device;
      }
    } finally {
      socket.close();
    }
    return found.values.toList();
  }

  static Future<List<int>?> _nextPacket(RawDatagramSocket socket, Duration wait) async {
    final completer = Completer<Datagram?>();
    late StreamSubscription sub;
    sub = socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final d = socket.receive();
        if (d != null) completer.complete(d);
      }
    });
    try {
      final d = await completer.future.timeout(wait, onTimeout: () => null);
      return d?.data;
    } finally {
      await sub.cancel();
    }
  }

  static String _msearch() => [
        'M-SEARCH * HTTP/1.1',
        'HOST: $_ssdpAddr:$_ssdpPort',
        'MAN: "ssdp:discover"',
        'MX: 2',
        'ST: urn:schemas-upnp-org:device:MediaRenderer:1',
        '', // CRLF 分隔
        '',
      ].join('\r\n');

  static String? _header(String text, String name) {
    for (final line in text.split('\r\n')) {
      final i = line.indexOf(':');
      if (i > 0 && line.substring(0, i).trim().toUpperCase() == name) {
        return line.substring(i + 1).trim();
      }
    }
    return null;
  }

  /// 拉设备描述 XML：取 friendlyName 与 AVTransport controlURL。
  static Future<DlnaDevice?> _resolve(String location, String usn) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final req = await client.getUrl(Uri.parse(location));
      final res = await req.close().timeout(const Duration(seconds: 4));
      final xml = await res.transform(utf8.decoder).join();
      client.close(force: true);
      if (res.statusCode != 200) return null;
      final name = _tag(xml, 'friendlyName') ?? 'DLNA 设备';
      final controlUrl = _avTransportControlUrl(xml);
      if (controlUrl == null) return null;
      return DlnaDevice(
        location: location,
        usn: usn,
        friendlyName: name,
        controlUrl: _absolute(location, controlUrl),
      );
    } catch (e) {
      McErrorLog.log(e, context: 'dlna.parseDevice');
      return null;
    }
  }

  static String? _avTransportControlUrl(String xml) {
    final serviceRe = RegExp(
      r'<service>([sS]*?)</service>',
      multiLine: true,
    );
    for (final m in serviceRe.allMatches(xml)) {
      final s = m.group(1)!;
      final type = _tag(s, 'serviceType') ?? '';
      if (type.contains('AVTransport')) return _tag(s, 'controlURL');
    }
    return null;
  }

  static String _absolute(String base, String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final b = Uri.parse(base);
    return b.resolve(path).toString();
  }

  static String? _tag(String xml, String tag) {
    final m = RegExp('<$tag[^>]*>([\\s\\S]*?)</$tag>').firstMatch(xml);
    return m?.group(1)?.trim();
  }
}

