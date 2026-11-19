import 'dart:math' as math;

import 'package:dio/dio.dart';

/// 传输层自愈拦截器（对齐飞牛 trim_http_client 的重试思想，docs/design/09 §2）：
/// 仅幂等 GET；连接类错误/5xx 重试，指数退避（300ms/600ms）+ 抖动，上限 2 次。
/// 4xx（业务语义）永不重试。
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 2});

  final Dio _dio;
  final int maxRetries;
  final math.Random _rng = math.Random();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final code = err.response?.statusCode;
    final retriable = request.method == 'GET' &&
        (err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            (code != null && code >= 500));
    final attempt = (request.extra['retry_count'] as int?) ?? 0;
    if (!retriable || attempt >= maxRetries) {
      handler.next(err);
      return;
    }
    request.extra['retry_count'] = attempt + 1;
    // 指数退避 + 抖动，避免惊群。
    final delay = Duration(milliseconds: 300 * (1 << attempt) + _rng.nextInt(100));
    await Future<void>.delayed(delay);
    try {
      final response = await _dio.fetch<void>(request);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
