import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/core/api/api_exception.dart';
import 'package:mc_flutter/core/api/mc_error.dart';

/// 统一错误分级（P1 核心层）：McError.classify 覆盖网络 / 超时 / TLS /
/// 鉴权 / 业务信封 / 服务端，并给出 retryable 判定。
void main() {
  group('McError.classify', () {
    test('SocketException → network，可重试', () {
      final e = McError.classify(
        const SocketException('Failed host lookup'),
      );
      expect(e.kind, McErrorKind.network);
      expect(e.retryable, isTrue);
    });

    test('TimeoutException → timeout，可重试', () {
      final e = McError.classify(
        TimeoutException('connect', const Duration(seconds: 8)),
      );
      expect(e.kind, McErrorKind.timeout);
      expect(e.retryable, isTrue);
    });

    test('HandshakeException → tls，不可重试', () {
      final e = McError.classify(
        const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
      );
      expect(e.kind, McErrorKind.tls);
      expect(e.retryable, isFalse);
    });

    test('ApiException auth.* → auth，不可重试', () {
      final e = McError.classify(
        const ApiException('auth.unauthorized', '登录已过期', httpStatus: 401),
      );
      expect(e.kind, McErrorKind.auth);
      expect(e.code, 'auth.unauthorized');
      expect(e.retryable, isFalse);
    });

    test('ApiException 业务码 → envelope，不可重试', () {
      final e = McError.classify(
        const ApiException('library.not_found', '媒体库不存在'),
      );
      expect(e.kind, McErrorKind.envelope);
      expect(e.code, 'library.not_found');
      expect(e.retryable, isFalse);
    });

    test('ApiException network.timeout → timeout，可重试', () {
      final e = McError.classify(
        const ApiException('network.timeout', '网络超时'),
      );
      expect(e.kind, McErrorKind.timeout);
      expect(e.retryable, isTrue);
    });

    test('DioException 401/403 → auth；5xx → server，可重试', () {
      final auth = McError.classify(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 401,
          ),
        ),
      );
      expect(auth.kind, McErrorKind.auth);

      final server = McError.classify(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 503,
          ),
        ),
      );
      expect(server.kind, McErrorKind.server);
      expect(server.retryable, isTrue);
    });

    test('未知异常 → unknown，不可重试', () {
      final e = McError.classify(StateError('boom'));
      expect(e.kind, McErrorKind.unknown);
      expect(e.retryable, isFalse);
    });

    test('已分级的 McError 原样通过', () {
      const original = McError(
        kind: McErrorKind.tls,
        message: 'tls',
        code: 'network.tls',
      );
      expect(McError.classify(original), same(original));
    });
  });

  group('McErrorLog.log', () {
    test('不抛错，且 reporter 钩子收到分级后的错误', () {
      McError? seen;
      String? seenContext;
      McErrorLog.reporter = (e, context, _) {
        seen = e;
        seenContext = context;
      };
      addTearDown(() => McErrorLog.reporter = null);

      McErrorLog.log(
        const SocketException('down'),
        context: 'test.network',
      );
      expect(seen, isNotNull);
      expect(seen!.kind, McErrorKind.network);
      expect(seenContext, 'test.network');
    });
  });
}
