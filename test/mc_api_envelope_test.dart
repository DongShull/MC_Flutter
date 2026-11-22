import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/core/api/api_exception.dart';
import 'package:mc_flutter/core/api/mc_api.dart';
import 'package:mc_flutter/core/api/mc_client.dart';
import 'package:mc_flutter/core/session/session_store.dart';

/// McApi 信封解包（P1 核心层）：本地 HTTP 服务器模拟服务端信封，
/// 验证类型化方法把 {code, message, data} 正确拆成模型 / 列表 / 异常。
void main() {
  group('decodeEnvelope（纯函数）', () {
    test('ok 信封返回 data', () {
      expect(
        decodeEnvelope({'code': 0, 'message': 'ok', 'data': {'a': 1}}),
        {'a': 1},
      );
      expect(
        decodeEnvelope({'code': 'OK', 'message': 'ok', 'data': [1, 2]}),
        [1, 2],
      );
    });

    test('data 为 null 时返回 null（不抛错，由调用方定语义）', () {
      expect(
        decodeEnvelope({'code': 0, 'message': 'ok', 'data': null}),
        isNull,
      );
    });

    test('非 ok 信封抛 ApiException（code 与 message 原样带出）', () {
      expect(
        () => decodeEnvelope({'code': '40001', 'message': 'bad', 'data': null}),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', '40001')
            .having((e) => e.message, 'message', 'bad')),
      );
    });

    test('无信封裸数据原样通过（health 等裸端点）', () {
      expect(decodeEnvelope({'status': 'ok'}), isNull); // 无 data 键 → null
      expect(
        decodeEnvelope({'status': 'ok', 'data': {'x': 1}}),
        {'x': 1},
      );
    });
  });

  group('McApi 经本地服务器解包', () {
    late HttpServer server;
    late McApi api;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = 'http://${server.address.host}:${server.port}';
      api = McApi(
        McClient(session: SessionStore(), baseUrlOverride: base),
      );
    });

    tearDown(() async {
      await server.close(force: true);
    });

    void serve(Map<String, dynamic> Function(HttpRequest req) handler) {
      server.listen((req) async {
        final body = handler(req);
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(body));
        await req.response.close();
      });
    }

    Map<String, dynamic> envelope(Object? data, {Object code = 0}) =>
        {'code': code, 'message': 'ok', 'data': data};

    test('me()：ok 信封 data 解成 SessionView', () async {
      serve((req) {
        expect(req.uri.path, '/api/v1/auth/me');
        return envelope({
          'username': 'dongshu',
          'nickname': '东叔',
          'role': 'admin',
        });
      });
      final me = await api.me();
      expect(me.toJson()['username'], 'dongshu');
      expect(me.toJson()['role'], 'admin');
    });

    test('me()：data 为 null 抛 network.empty（不是静默 null）', () async {
      serve((_) => envelope(null));
      expect(
        api.me(),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'network.empty')),
      );
    });

    test('me()：业务信封错误抛 ApiException（code 原样）', () async {
      serve((_) => envelope(null, code: 'auth.unauthorized'));
      expect(
        api.me(),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'auth.unauthorized')),
      );
    });

    test('libraries()：data 列表解成模型列表；非列表 data 返回空列表', () async {
      serve((_) => envelope([
            {'id': 1, 'name': '电影'},
            {'id': 2, 'name': '剧集'},
          ]));
      final libs = await api.libraries();
      expect(libs.length, 2);
      expect(libs.map((l) => l.toJson()['id']), [1, 2]);

      await server.close(force: true);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = 'http://${server.address.host}:${server.port}';
      api = McApi(McClient(session: SessionStore(), baseUrlOverride: base));
      serve((_) => envelope({'unexpected': 'object'}));
      expect(await api.libraries(), isEmpty);
    });

    test('health()：裸 JSON（非信封）不经过信封解包', () async {
      serve((req) {
        expect(req.uri.path, '/api/v1/health');
        return {'status': 'ok', 'instance_id': 'inst-1'};
      });
      final health = await api.health();
      expect(health.toJson()['status'], 'ok');
    });
  });
}
