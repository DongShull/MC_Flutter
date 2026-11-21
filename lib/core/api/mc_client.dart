import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../session/session_store.dart';
import 'api_exception.dart';
import 'retry_interceptor.dart';

/// 三通道网络层（对齐 iOS 三 URLSession / 原 General|Live|Playback 三通道设计）：
/// - general：常规业务请求
/// - live：低延迟实时请求
/// - playback：播放链路专用（与播放会话共享连接语义）
enum Channel { general, live, playback }

/// compute() 包装：jsonDecode 签名带可选参数，不能直接当 ComputeCallback 用。
Map<String, dynamic> _decodeJson(String raw) => jsonDecode(raw) as Map<String, dynamic>;

class McClient {
  McClient({required SessionStore session, this.ua = 'MovieClaw-Flutter/0.1.0', String? baseUrlOverride})
      : _session = session,
        _baseUrlOverride = baseUrlOverride {
    for (final c in Channel.values) {
      _dio[c] = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: c == Channel.general
            ? const Duration(seconds: 20)
            : const Duration(seconds: 10),
        headers: {'User-Agent': ua},
        validateStatus: (_) => true,
      ));
      _dio[c]!.interceptors.add(RetryInterceptor(_dio[c]!));
    }
  }

  final SessionStore _session;
  final String ua;
  /// 登录前 session 尚无 baseUrl，用输入框地址显式覆盖（首次登录必需）。
  final String? _baseUrlOverride;
  final Map<Channel, Dio> _dio = {};


  /// 当前服务器基址（含 /api/v1 前缀的完整 URL 拼接由调用方给 path）。
  String get baseUrl => _baseUrlOverride ?? _session.baseUrl ?? '';

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
  /// multipart 上传（头像等；对应 Kotlin @Multipart）。返回解包后的 data。
  Future<T> postMultipart<T>(
    Channel channel,
    String path, {
    required String fileField,
    required String filePath,
    String fileName = 'avatar.jpg',
    String contentType = 'image/jpeg',
    Map<String, dynamic>? query,
  }) async {
    final dio = _dio[channel]!;
    final form = FormData.fromMap({
      fileField: await MultipartFile.fromFile(filePath,
          filename: fileName, contentType: DioMediaType(contentType.split('/')[0], contentType.split('/')[1])),
    });
    final res = await dio.post<Map<String, dynamic>>(path,
        data: form, queryParameters: query);
    final data = res.data;
    if (data == null) {
      throw ApiException('network.empty', '服务器返回为空', httpStatus: res.statusCode);
    }
    return unwrapEnvelope<T>(data);
  }

  Future<T> unwrap<T>(
    Channel channel,
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final res = await _send(channel, method, path, body: body, query: query);
    // 服务器 content-type 不规范时 dio 不反序列化（data 是 String）：
    // 大响应丢 compute() 在 isolate 里解析，主线程不卡（飞牛 Go 传输层的 Dart 侧对应物）。
    if (res.data is String) {
      res.data = await compute(_decodeJson, res.data as String);
    }
    final data = res.data;
    if (data == null) {
      throw ApiException('network.empty', '服务器返回为空', httpStatus: res.statusCode);
    }
    return unwrapEnvelope<T>(data);
  }
}
