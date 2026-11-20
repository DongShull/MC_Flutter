import 'dart:async';
import 'dart:io';

import 'dlna_discovery.dart';

/// DLNA MediaRenderer AVTransport 控制（SOAP/UPnP，纯 Dart 无三方依赖）：
/// SetAVTransportURI → Play / Pause / Stop。对齐 trim_cast_plugin 的 DLNA 直连面。
class DlnaRenderer {
  DlnaRenderer(this.device);

  final DlnaDevice device;

  static const _avt = 'urn:schemas-upnp-org:service:AVTransport:1';

  Future<void> setUriAndPlay(String url, {String? title}) async {
    final meta = _didl(url, title);
    await _action('SetAVTransportURI',
        '<CurrentURI>${_esc(url)}</CurrentURI>'
        '<CurrentURIMetaData>${_esc(meta)}</CurrentURIMetaData>');
    await _action('Play', '<Speed>1</Speed>');
  }

  Future<void> play() => _action('Play', '<Speed>1</Speed>');
  Future<void> pause() => _action('Pause', '');
  Future<void> stop() => _action('Stop', '');

  Future<void> _action(String action, String args) async {
    final body = '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body><u:$action xmlns:u="$_avt">'
        '<InstanceID>0</InstanceID>$args</u:$action></s:Body></s:Envelope>';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client.postUrl(Uri.parse(device.controlUrl));
      req.headers.set('CONTENT-TYPE', 'text/xml; charset="utf-8"');
      req.headers.set('SOAPACTION', '"$_avt#$action"');
      req.add(body.codeUnits);
      final res = await req.close().timeout(const Duration(seconds: 5));
      await res.drain<void>();
      // 500 = UPnP 动作错误（多为不支持该 URI），这里不抛，交由上层 toast。
    } finally {
      client.close(force: true);
    }
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// 最小 DIDL-Lite 元数据（部分渲染器要求非空）。
  static String _didl(String url, String? title) {
    final t = _esc(title ?? 'MovieClaw');
    return '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
        '<item id="mc-1" restricted="0">'
        '<dc:title>$t</dc:title>'
        '<upnp:class>object.item.videoItem.movie</upnp:class>'
        '<res protocolInfo="http-get:*:video/*:*">$_esc(url)</res>'
        '</item></DIDL-Lite>';
  }
}
