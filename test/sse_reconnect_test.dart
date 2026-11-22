import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/core/api/sse_client.dart';
import 'package:mc_flutter/core/session/session_store.dart';

/// 统一 SSE 客户端（P1 核心层）：帧解析、指数退避、断线 Last-Event-ID 续传、
/// 404 回退轮询（SseUnsupportedException）。
void main() {
  group('SseClient.parseFrame', () {
    test('解析 id/event/data 帧', () {
      final f = SseClient.parseFrame(
          'id: 7\nevent: notification\ndata: {"id":7}');
      expect(f, isNotNull);
      expect(f!.id, '7');
      expect(f.name, 'notification');
      expect(f.data, '{"id":7}');
    });

    test('注释心跳帧返回 null；无名帧为 message', () {
      expect(SseClient.parseFrame(': heartbeat'), isNull);
      final f = SseClient.parseFrame('data: hello');
      expect(f!.name, 'message');
      expect(f.data, 'hello');
    });
  });

  group('SseClient.backoffMs', () {
    test('800ms 起翻倍，上限 15s', () {
      expect(SseClient.backoffMs(1), 800);
      expect(SseClient.backoffMs(2), 1600);
      expect(SseClient.backoffMs(3), 3200);
      expect(SseClient.backoffMs(5), 12800);
      expect(SseClient.backoffMs(10), 15000);
      expect(SseClient.backoffMs(100), 15000);
    });
  });

  group('SseClient.events（本地 HTTP 服务器）', () {
    late HttpServer server;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async {
      await server.close(force: true);
    });

    SseClient clientWithToken(String base) {
      final session = SessionStore();
      // 测试注入 token/baseUrl：SseClient 构造参数仅测试用。
      return SseClient(session, baseUrl: base, token: 'test-token');
    }

    test('断线重连携带 Last-Event-ID，续传后收到终态事件', () async {
      var requests = 0;
      String? secondLastEventId;
      server.listen((req) async {
        requests++;
        req.response.headers
            .set(HttpHeaders.contentTypeHeader, 'text/event-stream');
        if (requests == 1) {
          req.response.add(utf8.encode(
              'id: 1\nevent: notification\ndata: {"id":1}\n\n'));
          await req.response.flush();
          await req.response.close(); // 裸断，无终态
        } else {
          secondLastEventId = req.headers.value('Last-Event-ID');
          req.response.add(utf8.encode(
              'id: 2\nevent: notification\ndata: {"id":2}\n\n'
              'event: done\ndata: {}\n\n'));
          await req.response.flush();
          await req.response.close();
        }
      });

      final base = 'http://${server.address.host}:${server.port}';
      final events = await clientWithToken(base)
          .events('/api/v1/push/me/stream', terminalEvents: {'done'})
          .toList();
      expect(requests, 2);
      expect(secondLastEventId, '1');
      expect(events.map((e) => e.name), ['notification', 'notification', 'done']);
      expect(events[0].id, '1');
      expect(events[1].id, '2');
    });

    test('404 → SseUnsupportedException（调用方回退轮询）', () async {
      server.listen((req) async {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      });
      final base = 'http://${server.address.host}:${server.port}';
      expect(
        clientWithToken(base).events('/api/v1/push/me/stream').toList(),
        throwsA(isA<SseUnsupportedException>()),
      );
    });

    test('未登录（无 token）直接抛 SseUnsupportedException，不发请求', () async {
      var requests = 0;
      server.listen((_) async {
        requests++;
      });
      final base = 'http://${server.address.host}:${server.port}';
      final client = SseClient(SessionStore(), baseUrl: base);
      expect(
        client.events('/api/v1/push/me/stream').toList(),
        throwsA(isA<SseUnsupportedException>()),
      );
      expect(requests, 0);
    });
  });
}
