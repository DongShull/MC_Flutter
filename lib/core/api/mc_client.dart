import 'package:dio/dio.dart';

import '../session/session_store.dart';
import 'api_exception.dart';

/// 三通道网络层（对齐 iOS 三 URLSession / 原 General|Live|Playback 三通道设计）：
/// - general：常规业务请求
/// - live：低延迟实时请求
/// - playback：播放链路专用（与播放会话共享连接语义）
enum Channel { general, live, playback }

class McClient {
  McClient({required SessionStore session, this.ua = 'MovieClaw-Flutter/0.1.0'})
      : _session = session {
    for (final c in Channel.values) {
      _dio[c] = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: c == Channel.general
            ? const Duration(seconds: 20)
            : const Duration(seconds: 10),
        headers: {'User-Agent': ua},
        validateStatus: (_) => true,
      ));
    }
  }

  final SessionStore _session;
  final String ua;
  final Map<Channel, Dio> _dio = {};

  /// 当前服务器基址（含 /api/v1 前缀的完整 URL 拼接由调用方给 path）。
  String get baseUrl => _session.baseUrl ?? '';

  Future<Response<Map<String, dynamic>>> get(
    Channel channel,
    String path, {
    Map<String, dynamic>? query,
  }) async =>
      _send(channel, 'GET', path, query: query);

  Future<Response<Map<String, dynamic>>> post(
    Channel channel,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async =>
      _send(channel, 'POST', path, body: body, query: query);

  Future<Response<Map<String, dynamic>>> put(
    Channel channel,
    String path, {
    Object? body,
  }) async =>
      _send(channel, 'PUT', path, body: body);

  Future<Response<Map<String, dynamic>>> delete(
    Channel channel,
    String path,
  ) async =>
      _send(channel, 'DELETE', path);

  Future<Response<Map<String, dynamic>>> _send(
    Channel channel,
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final dio = _dio[channel]!;
    final token = _session.token;
    final res = await dio.request<Map<String, dynamic>>(
      '$baseUrl$path',
      data: body,
      queryParameters: query,
      options: Options(
        method: method,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    return res;
  }

  /// 信封解包：非 ok 抛 ApiException，ok 返回 data。
  Future<T> unwrap<T>(
    Channel channel,
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final res = await _send(channel, method, path, body: body, query: query);
    final data = res.data;
    if (data == null) {
      throw ApiException('network.empty', '服务器返回为空', httpStatus: res.statusCode);
    }
    return unwrapEnvelope<T>(data);
  }
}
