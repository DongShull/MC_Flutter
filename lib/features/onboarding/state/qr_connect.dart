// 扫码连服务器（task6）与配对码解析：
// - `parseServerQr`：解析服务器分享二维码（JSON 或 URL）；
// - `PairingQrParser`：解析设备登录配对二维码（对齐 iOS `PairingQRCode.swift`）。
import 'dart:convert';

export '../../../core/auth/pairing_qr_parser.dart'
    show PairingQrParser, PairingQrResult;

/// 解析成功的结果：规范化后的服务器基础地址（scheme://host[:port][/path]）。
class QrServerInfo {
  final String baseUrl;
  const QrServerInfo(this.baseUrl);

  @override
  String toString() => baseUrl;
}

/// 解析二维码文本；失败返回 null。
QrServerInfo? parseServerQr(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  // 1) JSON：{"host": "...", "port": 8096, "scheme"?: "http", "ssl"?: bool}
  if (text.startsWith('{')) {
    try {
      final obj = jsonDecode(text);
      if (obj is Map) {
        final host = (obj['host'] ?? obj['Host'])?.toString().trim() ?? '';
        if (host.isEmpty) return null;
        final port = obj['port'] ?? obj['Port'];
        final scheme = _schemeOf(obj);
        final portNum = port == null ? null : int.tryParse(port.toString());
        final path = (obj['path'] ?? '').toString().trim();
        final sb = StringBuffer('$scheme://');
        sb.write(_wrapIpv6(host));
        if (portNum != null && portNum > 0 && portNum != _defaultPort(scheme)) {
          sb.write(':$portNum');
        }
        if (path.isNotEmpty && path != '/') {
          sb.write(path.startsWith('/') ? path : '/$path');
        }
        return QrServerInfo(sb.toString());
      }
    } on FormatException {
      return null;
    }
  }

  // 2) URL：有 scheme 直接解析；无 scheme 的 host[:port][/path] 补 http://
  if (RegExp(r'\s').hasMatch(text)) return null; // 带空白的一律不是地址
  var urlText = text;
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(urlText)) {
    // 裸 host[:port]，或形如 //host:port
    if (urlText.startsWith('//')) {
      urlText = 'http:${urlText.substring(2)}';
    } else {
      urlText = 'http://$urlText';
    }
  }
  final uri = Uri.tryParse(urlText);
  if (uri == null || uri.host.isEmpty) return null;
  final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme.toLowerCase();
  final sb = StringBuffer('$scheme://');
  sb.write(_wrapIpv6(uri.host));
  if (uri.port != 0 && uri.port != _defaultPort(scheme)) {
    sb.write(':${uri.port}');
  }
  final path = uri.path;
  if (path.isNotEmpty && path != '/') sb.write(path);
  return QrServerInfo(sb.toString());
}

String _schemeOf(Map obj) {
  final scheme =
      (obj['scheme'] ?? obj['protocol'])?.toString().trim().toLowerCase() ?? '';
  if (scheme == 'https' || scheme == 'http') return scheme;
  final ssl = obj['ssl'] ?? obj['secure'];
  if (ssl == true || ssl == 1 || ssl == '1' || ssl == 'true') return 'https';
  return 'http';
}

int? _defaultPort(String scheme) =>
    scheme == 'https' ? 443 : (scheme == 'http' ? 80 : null);

/// IPv6 地址加方括号，便于拼 URL。
String _wrapIpv6(String host) =>
    host.contains(':') && !host.startsWith('[') ? '[$host]' : host;
