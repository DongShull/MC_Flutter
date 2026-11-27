/// 设备登录二维码与配对码解析（1:1 对齐 iOS `PairingQRCode.swift`）。
///
/// 支持两种合法来源：
/// 1. 服务端 `verification_uri_complete`：`http(s)://<服务器>/activate?code=MCLW-XXXX`
///    （旧版服务端为 `/settings/devices?code=…`）；
/// 2. 只编了 `MCLW-XXXX`（或 `MCLWXXXX`）的纯配对码二维码。
///
/// 扫码校验时拒绝 Wi-Fi、付款码、普通网址等无关二维码；手输时 `normalize` 支持仅输入后 4 位（如 `7F3K` -> `MCLW-7F3K`）。
class PairingQrResult {
  const PairingQrResult({required this.code, this.host});

  /// 规整后的配对码（大写、始终带 `MCLW-` 前缀与连字符，如 `MCLW-7F3K`）。
  final String code;

  /// 二维码里携带的服务器 `host[:port]`（省略默认端口 80/443）；纯配对码时为 `null`。
  final String? host;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairingQrResult && other.code == code && other.host == host;

  @override
  int get hashCode => Object.hash(code, host);

  @override
  String toString() => 'PairingQrResult(code: $code, host: $host)';
}

abstract final class PairingQrParser {
  static final RegExp _separatorPattern = RegExp(r'[\s\-_－—–]+');
  static final RegExp _bodyPattern = RegExp(r'^[A-Z0-9]{4}$');

  /// 解析扫码得到的原始文本；不是 MovieClaw 设备配对码返回 `null`。
  static PairingQrResult? parse(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return null;

    // 纯文本扫码必须带 MCLW 前缀，避免随便扫到一个 4 位字母码被误认成配对码。
    if (raw.toUpperCase().startsWith('MCLW')) {
      final code = normalize(raw);
      if (code != null) return PairingQrResult(code: code);
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;

    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (!path.endsWith('/activate') && !path.endsWith('/settings/devices')) {
      return null;
    }

    final rawCode = uri.queryParameters['code'];
    if (rawCode == null || rawCode.trim().isEmpty) return null;
    final code = normalize(rawCode);
    if (code == null) return null;

    final host = uri.host;
    final isDefaultPort = !uri.hasPort ||
        (scheme == 'http' && uri.port == 80) ||
        (scheme == 'https' && uri.port == 443);
    final hostLabel = isDefaultPort ? host : '$host:${uri.port}';
    return PairingQrResult(code: code, host: hostLabel);
  }

  /// 规整配对码（对齐 iOS `PairingQRCode.normalize` 与 Web `normalizePairingCode`）：
  /// - 去掉空格与各类横线（`-` `_` `－` `—` `–`）并转大写；
  /// - `MCLW7F3K`、`mclw-7f3k`、`7F3K` 均规整为 `MCLW-7F3K`；
  /// - 正文必须恰好 4 位 ASCII 字母或数字，否则返回 `null`。
  static String? normalize(String raw) {
    final compact = raw.toUpperCase().replaceAll(_separatorPattern, '');
    final body = compact.length == 8 && compact.startsWith('MCLW')
        ? compact.substring(4)
        : compact;
    if (!_bodyPattern.hasMatch(body)) return null;
    return 'MCLW-$body';
  }
}
