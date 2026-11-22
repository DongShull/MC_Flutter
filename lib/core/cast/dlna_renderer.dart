import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dlna_discovery.dart';

/// DLNA MediaRenderer AVTransport 控制（SOAP/UPnP，纯 Dart 无三方依赖）：
/// SetAVTransportURI → Play / Pause / Stop。对齐 trim_cast_plugin 的 DLNA 直连面。
///
/// P3 走查修正（见 `docs/CAST_VERIFICATION.md`）：
/// - 此前 `_action` 收到 500（UPnP 动作错误，多为不支持该 URI）也不抛，
///   上层于是把失败当成功置 `casting=true`。现 `setUriAndPlay` 在动作
///   非 200 时抛错，`CastController.castTo` 才能据实置 `lastError`；
///   `play` / `pause` / `stop` 是尽力而为，返回是否成功，不抛。
/// - 新增 `getPositionInfo` / `getTransportState`（投屏进度与状态轮询，
///   播放页暂未接 UI，先供后续与测试使用）。
class DlnaRenderer {
  DlnaRenderer(this.device);

  final DlnaDevice device;

  static const _avt = 'urn:schemas-upnp-org:service:AVTransport:1';

  Future<void> setUriAndPlay(String url, {String? title}) async {
    final meta = buildDidl(url, title);
    final set = await _action('SetAVTransportURI',
        '<CurrentURI>${_esc(url)}</CurrentURI>'
        '<CurrentURIMetaData>${_esc(meta)}</CurrentURIMetaData>');
    if (!set) {
      throw HttpException(
          'DLNA SetAVTransportURI 失败（设备拒绝了该地址：$url）');
    }
    final played = await _action('Play', '<Speed>1</Speed>');
    if (!played) {
      throw const HttpException('DLNA Play 失败（设备未开始播放）');
    }
  }

  /// 尽力而为：返回 false = 设备报错或不可达，不抛。
  Future<bool> play() => _action('Play', '<Speed>1</Speed>');
  Future<bool> pause() => _action('Pause', '');
  Future<bool> stop() => _action('Stop', '');

  /// 当前播放位置与片长（`GetPositionInfo`）；设备不支持或不可达返回 null。
  Future<DlnaPosition?> getPositionInfo() async {
    final body = await _actionRaw('GetPositionInfo', '');
    if (body == null) return null;
    final rel = _tag(body, 'RelTime');
    final dur = _tag(body, 'TrackDuration');
    final uri = _tag(body, 'TrackURI');
    if (rel == null && dur == null) return null;
    return DlnaPosition(
      position: rel == null ? null : _parseUpnpTime(rel),
      duration: dur == null ? null : _parseUpnpTime(dur),
      trackUri: uri,
    );
  }

  /// 当前传输状态（`PLAYING` / `PAUSED_PLAYBACK` / `STOPPED` …）；
  /// 设备不支持或不可达返回 null。
  Future<String?> getTransportState() async {
    final body = await _actionRaw('GetTransportInfo', '');
    if (body == null) return null;
    return _tag(body, 'CurrentTransportState');
  }

  /// 发一个 AVTransport 动作；返回是否拿到 200（500 = UPnP 动作错误）。
  /// 网络异常同样返回 false（不抛），由调用方按“设备不可达”处理。
  Future<bool> _action(String action, String args) async {
    try {
      final body = await _actionRaw(action, args);
      return body != null;
    } catch (_) {
      return false;
    }
  }

  /// 发一个 AVTransport 动作并返回响应体；非 200 或网络异常返回 null。
  Future<String?> _actionRaw(String action, String args) async {
    final body = buildActionEnvelope(action, args);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client.postUrl(Uri.parse(device.controlUrl));
      req.headers.set('CONTENT-TYPE', 'text/xml; charset="utf-8"');
      req.headers.set('SOAPACTION', '"$_avt#$action"');
      req.add(body.codeUnits);
      final res = await req.close().timeout(const Duration(seconds: 5));
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) return null;
      return text;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// SOAP 信封（公开供测试校验；[args] 是 `<InstanceID>0</InstanceID>`
  /// 之后的子元素，调用方自行拼 XML 并转义）。
  static String buildActionEnvelope(String action, String args) =>
      '<?xml version="1.0" encoding="utf-8"?>'
      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
      's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
      '<s:Body><u:$action xmlns:u="$_avt">'
      '<InstanceID>0</InstanceID>$args</u:$action></s:Body></s:Envelope>';

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// 最小 DIDL-Lite 元数据（部分渲染器要求非空；公开供测试校验）。
  static String buildDidl(String url, String? title) {
    final t = _esc(title ?? 'MovieClaw');
    return '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
        '<item id="mc-1" restricted="0">'
        '<dc:title>$t</dc:title>'
        '<upnp:class>object.item.videoItem.movie</upnp:class>'
        '<res protocolInfo="http-get:*:video/*:*">${_esc(url)}</res>'
        '</item></DIDL-Lite>';
  }

  static String? _tag(String xml, String tag) {
    final m = RegExp('<$tag[^>]*>([\\s\\S]*?)</$tag>').firstMatch(xml);
    return m?.group(1)?.trim();
  }

  /// UPnP 时间 `H:MM:SS`（`NOT_IMPLEMENTED` 等非时间值返回 null）。
  static Duration? _parseUpnpTime(String text) {
    final parts = text.split(':');
    if (parts.length != 3) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final s = int.tryParse(parts[2]);
    if (h == null || m == null || s == null) return null;
    return Duration(hours: h, minutes: m, seconds: s);
  }
}

/// `GetPositionInfo` 的解析结果。
class DlnaPosition {
  const DlnaPosition({this.position, this.duration, this.trackUri});

  final Duration? position;
  final Duration? duration;
  final String? trackUri;
}
