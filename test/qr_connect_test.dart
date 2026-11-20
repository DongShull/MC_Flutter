import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/features/onboarding/state/qr_connect.dart';

void main() {
  group('parseServerQr', () {
    test('常见 URL：http://host:port', () {
      expect(parseServerQr('http://192.168.1.10:8096')!.baseUrl,
          'http://192.168.1.10:8096');
    });
    test('https 无端口', () {
      expect(parseServerQr('https://example.com')!.baseUrl, 'https://example.com');
    });
    test('https 默认端口 443 不重复拼接', () {
      expect(parseServerQr('https://example.com:443')!.baseUrl, 'https://example.com');
    });
    test('带路径的 URL 保留路径', () {
      expect(parseServerQr('http://example.com:8096/subpath')!.baseUrl,
          'http://example.com:8096/subpath');
    });
    test('裸 host:port 补 http://', () {
      expect(parseServerQr('192.168.1.10:8096')!.baseUrl, 'http://192.168.1.10:8096');
    });
    test('JSON host/port', () {
      expect(parseServerQr('{"host":"nas.local","port":5666}')!.baseUrl,
          'http://nas.local:5666');
    });
    test('JSON ssl=true 走 https', () {
      expect(parseServerQr('{"host":"nas.local","port":443,"ssl":true}')!.baseUrl,
          'https://nas.local');
    });
    test('JSON scheme 字段', () {
      expect(parseServerQr('{"host":"nas.local","port":443,"scheme":"https"}')!.baseUrl,
          'https://nas.local');
    });
    test('JSON 端口为字符串', () {
      expect(parseServerQr('{"host":"1.2.3.4","port":"8080"}')!.baseUrl,
          'http://1.2.3.4:8080');
    });
    test('IPv6 加方括号', () {
      expect(parseServerQr('http://[::1]:8096')!.baseUrl, 'http://[::1]:8096');
    });
    test('空串与垃圾内容返回 null', () {
      expect(parseServerQr(''), isNull);
      expect(parseServerQr('   '), isNull);
      expect(parseServerQr('hello world'), isNull);
      expect(parseServerQr('{"port":8096}'), isNull);
    });
  });
}
