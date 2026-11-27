import 'dart:math' as math;

import 'package:dio/dio.dart';

/// 传输层自愈拦截器（修复原先 `validateStatus: (_) => true` 导致 5xx 永不触发重试的问题）：
/// - 仅对幂等 `GET` / `HEAD` 请求生效；
/// - 同时拦截 `onResponse` 中的 500/502/503/504 与 `onError` 中的连接错误/超时/5xx；
/// - 指数退避（300ms / 600ms）+ 0~100ms 随机抖动，上限 `maxRetries = 2` 次；
/// - 4xx 业务语义永不重试。
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 2});

  final Dio _dio;
  final int maxRetries;
  final math.Random _rng = math.Random();

  static const Set<int> _retriableStatusCodes = <int>{500, 502, 503, 504};

  bool _isIdempotent(RequestOptions request) {
    final method = request.method.toUpperCase();
    return method == 'GET' || method == 'HEAD';
  }

  bool _isRetrySkipped(RequestOptions request) =>
      request.extra['skip_retry'] == true;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final request = response.requestOptions;
    final status = response.statusCode;
    final attempt = (request.extra['retry_count'] as int?) ?? 0;

    if (!_isRetrySkipped(request) &&
        _isIdempotent(request) &&
        status != null &&
        _retriableStatusCodes.contains(status) &&
        attempt < maxRetries) {
      request.extra['retry_count'] = attempt + 1;
      await _backoff(attempt);
      try {
        final retried = await _dio.fetch<dynamic>(request);
        handler.resolve(retried);
        return;
      } on DioException catch (e) {
        handler.next(
          e.response ?? response,
        );
        return;
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final status = err.response?.statusCode;
    final retriable = !_isRetrySkipped(request) &&
        _isIdempotent(request) &&
        (err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            (status != null && _retriableStatusCodes.contains(status)));
    final attempt = (request.extra['retry_count'] as int?) ?? 0;
    if (!retriable || attempt >= maxRetries) {
      handler.next(err);
      return;
    }
    request.extra['retry_count'] = attempt + 1;
    await _backoff(attempt);
    try {
      final response = await _dio.fetch<dynamic>(request);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<void> _backoff(int attempt) {
    final delayMs = 300 * (1 << attempt) + _rng.nextInt(100);
    return Future<void>.delayed(Duration(milliseconds: delayMs));
  }
}
