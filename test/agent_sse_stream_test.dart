
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/core/api/agent_sse_client.dart';
import 'package:mc_flutter/core/session/session_store.dart';

void main() {
  group('AgentSseClient.parseFrame', () {
    test('解析 id/event/data 帧', () {
      final f = AgentSseClient.parseFrame(
          'id: 7\nevent: text_delta\ndata: {"type":"text_delta","delta":"hi"}');
      expect(f, isNotNull);
      expect(f!.id, '7');
      expect(f.name, 'text_delta');
      expect(f.data, '{"type":"text_delta","delta":"hi"}');
    });

    test('多行 data 以换行拼接；无名帧为 message', () {
      final f = AgentSseClient.parseFrame('data: a\ndata: b');
      expect(f!.name, 'message');
      expect(f.data, 'a\nb');
    });

    test('CRLF 与注释心跳帧', () {
      expect(AgentSseClient.parseFrame(': ping\r\n'), isNull);
      final f = AgentSseClient.parseFrame(
          'event: agent_done\r\ndata: {"type":"agent_done"}\r\n');
      expect(f!.name, 'agent_done');
    });
  });

  group('AgentSseClient.events（本地 HTTP 服务器）', () {
    late HttpServer server;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async {
      await server.close(force: true);
    });

    /// 第一连接：发 text_delta 后裸断（模拟网络中断）；
    /// 第二连接：校验 Last-Event-ID 续传并发终态 agent_done。
    void serveReconnectFlow() {
      var requests = 0;
      server.listen((req) async {
        requests++;
        req.response.headers
            .set(HttpHeaders.contentTypeHeader, 'text/event-stream');
        if (requests == 1) {
          expect(req.headers.value(HttpHeaders.acceptHeader),
              'text/event-stream');
          req.response.add(utf8.encode(
              'id: 1\nevent: text_delta\ndata: {"type":"text_delta","delta":"hi"}\n\n'));
          await req.response.flush();
          await req.response.close(); // 裸断，无终态
        } else {
          expect(req.headers.value('last-event-id'), '1');
          req.response.add(utf8.encode(
              'id: 2\nevent: agent_done\ndata: {"type":"agent_done"}\n\n'));
          await req.response.flush();
          await req.response.close();
        }
      });
    }

    test('流式收帧 + 断线用 Last-Event-ID 重连至终态', () async {
      serveReconnectFlow();
      // 真实 SessionStore 实例（不发任何存储调用），基址/令牌走测试注入。
      final client = AgentSseClient(
        SessionStore(),
        baseUrl: 'http://127.0.0.1:${server.port}',
        token: 't',
      );
      final names = <String>[];
      await for (final ev
          in client.events('/api/v1/agent/sessions/s1/events')) {
        names.add(ev.name);
      }
      expect(names, ['text_delta', 'agent_done']);
    });

    test('端点 404 抛 SseUnsupportedException（触发调用方轮询回退）', () async {
      server.listen((req) async {
        req.response.statusCode = 404;
        await req.response.close();
      });
      final client = AgentSseClient(
        SessionStore(),
        baseUrl: 'http://127.0.0.1:${server.port}',
        token: 't',
      );
      await expectLater(
        client.events('/api/v1/agent/sessions/s1/events').toList(),
        throwsA(isA<SseUnsupportedException>()),
      );
    });

    test('未登录（无 token）直接不可用', () async {
      final client = AgentSseClient(
        SessionStore(),
        baseUrl: 'http://127.0.0.1:${server.port}',
      );
      await expectLater(
        client.events('/x').toList(),
        throwsA(isA<SseUnsupportedException>()),
      );
    });
  });
}
