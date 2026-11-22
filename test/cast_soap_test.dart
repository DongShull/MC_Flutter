import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/cast/dlna_discovery.dart';
import 'package:mc_flutter/core/cast/dlna_renderer.dart';

/// flutter_test 默认把 HttpClient 换成返回 400 的假实现；
/// 投屏测试要走回环真服务器，先换回真实 HttpClient。
/// 注意：这里不能写 `HttpClient()`——构造器会再查
/// `HttpOverrides.global`，无限递归栈溢出；super 直接建真客户端。
/// 覆盖不是多余的：它把 flutter_test 的 400 假实现换回真客户端，
/// 只是写法上恰好是 super 调用。
// ignore_for_file: unnecessary_overrides
class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

String _envelope(String body) =>
    '<?xml version="1.0"?><s:Envelope '
    'xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">'
    '<s:Body>$body</s:Body></s:Envelope>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  group('SOAP 信封与 DIDL', () {
    test('buildActionEnvelope：动作名、InstanceID 与参数齐全', () {
      final env = DlnaRenderer.buildActionEnvelope(
          'SetAVTransportURI', '<CurrentURI>http://x/y.mp4</CurrentURI>');
      expect(env, contains('SetAVTransportURI'));
      expect(env, contains('<InstanceID>0</InstanceID>'));
      expect(env, contains('http://x/y.mp4'));
      expect(env, contains('urn:schemas-upnp-org:service:AVTransport:1'));
    });

    test('buildDidl：标题与地址里的 & < > 都转义', () {
      final didl = DlnaRenderer.buildDidl(
          'http://x/y.mp4?a=1&b=2', 'A&B <测试>');
      expect(didl, contains('A&amp;B &lt;测试&gt;'));
      expect(didl, contains('http://x/y.mp4?a=1&amp;b=2'));
      expect(didl, contains('object.item.videoItem.movie'));
      expect(didl, isNot(contains('A&B <')));
    });
  });

  group('假渲染器（回环 HttpServer）', () {
    late HttpServer server;
    late DlnaRenderer okRenderer;
    late DlnaRenderer failRenderer;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final action =
            (request.headers.value('SOAPACTION') ?? '').split('#').last;
        final fail = request.uri.path == '/fail/control';
        if (fail && action == 'SetAVTransportURI"') {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write(_envelope(
              '<s:Fault><faultstring>UPnPError 714</faultstring></s:Fault>'));
          await request.response.close();
          return;
        }
        switch (action) {
          case 'SetAVTransportURI"':
          case 'Play"':
          case 'Pause"':
          case 'Stop"':
            request.response.write(_envelope('<u:Response/>'));
          case 'GetPositionInfo"':
            request.response.write(_envelope(
                '<u:GetPositionInfoResponse>'
                '<RelTime>0:01:30</RelTime>'
                '<TrackDuration>0:10:00</TrackDuration>'
                '<TrackURI>http://x/y.mp4</TrackURI>'
                '</u:GetPositionInfoResponse>'));
          case 'GetTransportInfo"':
            request.response.write(_envelope(
                '<u:GetTransportInfoResponse>'
                '<CurrentTransportState>PLAYING</CurrentTransportState>'
                '</u:GetTransportInfoResponse>'));
          default:
            request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });
      String url(String path) =>
          'http://${server.address.address}:${server.port}$path';
      okRenderer = DlnaRenderer(DlnaDevice(
          location: url('/desc.xml'),
          usn: 'uuid:ok',
          friendlyName: 'Fake TV',
          controlUrl: url('/ok/control')));
      failRenderer = DlnaRenderer(DlnaDevice(
          location: url('/desc.xml'),
          usn: 'uuid:fail',
          friendlyName: 'Fail TV',
          controlUrl: url('/fail/control')));
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('setUriAndPlay 成功不抛；getPositionInfo 解析出 90 秒 / 600 秒',
        () async {
      await okRenderer.setUriAndPlay('http://x/y.mp4', title: '测试片');
      final pos = await okRenderer.getPositionInfo();
      expect(pos, isNotNull);
      expect(pos!.position, const Duration(seconds: 90));
      expect(pos.duration, const Duration(minutes: 10));
      expect(pos.trackUri, 'http://x/y.mp4');
      expect(await okRenderer.getTransportState(), 'PLAYING');
      expect(await okRenderer.pause(), isTrue);
      expect(await okRenderer.play(), isTrue);
      expect(await okRenderer.stop(), isTrue);
    });

    test('设备拒绝 SetAVTransportURI：setUriAndPlay 抛错', () async {
      await expectLater(
          failRenderer.setUriAndPlay('http://x/y.mp4'),
          throwsA(isA<HttpException>()));
    });

    test('设备不可达：getPositionInfo 返回 null，不抛', () async {
      final dead = DlnaRenderer(const DlnaDevice(
          location: 'http://127.0.0.1:1/desc.xml',
          usn: 'uuid:dead',
          friendlyName: 'Dead',
          controlUrl: 'http://127.0.0.1:1/control'));
      expect(await dead.getPositionInfo(), isNull);
      expect(await dead.getTransportState(), isNull);
      expect(await dead.pause(), isFalse);
    });
  });

  group('SSDP 发现', () {
    test('组播发送被禁（本沙箱）时返回空列表，不抛', () async {
      // 本沙箱禁组播发送（实测 SocketException Operation not permitted），
      // 端到端的假设备发现因此无法在此跑，见 P3.md；这里只断言
      // “没发现设备”是正常返回值而不是异常。
      final devices = await DlnaDiscovery.search(
          timeout: const Duration(seconds: 2));
      expect(devices, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
