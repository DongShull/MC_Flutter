import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/server_routes.dart';
import '../session/session_store.dart';
import 'api_exception.dart';
import 'retry_interceptor.dart';

/// 三通道网络层（对齐 iOS 三 URLSession / 原 General|Live|Playback 三通道设计）。
enum Channel { general, live, playback }

Map<String, dynamic> _decodeJson(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;

class McClient {
  McClient({
    required SessionStore session,
    this.ua = 'MovieClaw-Flutter/1.0.0',
    String? baseUrlOverride,
  })  : _session = session,
        _baseUrlOverride = baseUrlOverride {
    for (final c in Channel.values) {
      _dio[c] = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: c == Channel.general
              ? const Duration(seconds: 25)
              : const Duration(seconds: 12),
          headers: {'User-Agent': ua},
          validateStatus: (_) => true,
        ),
      );
      _dio[c]!.interceptors.add(RetryInterceptor(_dio[c]!));
    }
  }

  final SessionStore _session;
  final String ua;
  final String? _baseUrlOverride;
  final Map<Channel, Dio> _dio = {};

  String get baseUrl {
    final base = _baseUrlOverride ?? _session.baseUrl ?? '';
    if (_baseUrlOverride != null || base.isEmpty) return base;
    final routed = ServerRoutes.instance.currentOrigin();
    return routed.isEmpty ? base : routed;
  }

  Map<String, String> _authHeaders() {
    final token = _session.token;
    final routeKind = ServerRoutes.instance.kind;
    return <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (routeKind == 'lan' || routeKind == 'wan')
        'X-MovieClaw-Route': routeKind,
    };
  }

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
    Map<String, dynamic>? query,
  }) async =>
      _send(channel, 'PUT', path, body: body, query: query);

  Future<Response<Map<String, dynamic>>> patch(
    Channel channel,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async =>
      _send(channel, 'PATCH', path, body: body, query: query);

  Future<Response<Map<String, dynamic>>> delete(
    Channel channel,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async =>
      _send(channel, 'DELETE', path, body: body, query: query);

  Future<Response<Map<String, dynamic>>> _send(
    Channel channel,
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final dio = _dio[channel]!;
    final url = path.startsWith('http://') || path.startsWith('https://')
        ? path
        : '$baseUrl$path';
    final res = await dio.request<dynamic>(
      url,
      data: body,
      queryParameters: query,
      options: Options(method: method, headers: _authHeaders()),
    );
    Map<String, dynamic>? parsed;
    if (res.data is Map<String, dynamic>) {
      parsed = res.data as Map<String, dynamic>;
    } else if (res.data is Map) {
      parsed = (res.data as Map).cast<String, dynamic>();
    } else if (res.data is String && (res.data as String).trim().isNotEmpty) {
      parsed = await compute(_decodeJson, res.data as String);
    }
    return Response<Map<String, dynamic>>(
      data: parsed,
      requestOptions: res.requestOptions,
      statusCode: res.statusCode,
      statusMessage: res.statusMessage,
      isRedirect: res.isRedirect,
      redirects: res.redirects,
      extra: res.extra,
      headers: res.headers,
    );
  }

  /// Multipart 上传（头像、封面、插件包等）：自动拼 `$baseUrl` 并附带 Bearer 凭证。
  Future<T> postMultipart<T>(
    Channel channel,
    String path, {
    required String fileField,
    required String filePath,
    String fileName = 'avatar.jpg',
    String contentType = 'image/jpeg',
    Map<String, dynamic>? query,
    Map<String, dynamic>? extraFields,
  }) async {
    final dio = _dio[channel]!;
    final parts = contentType.split('/');
    final form = FormData.fromMap({
      if (extraFields != null) ...extraFields,
      fileField: await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: DioMediaType(
          parts.first,
          parts.length > 1 ? parts[1] : 'octet-stream',
        ),
      ),
    });
    final url = path.startsWith('http://') || path.startsWith('https://')
        ? path
        : '$baseUrl$path';
    final res = await dio.post<dynamic>(
      url,
      data: form,
      queryParameters: query,
      options: Options(headers: _authHeaders()),
    );
    Map<String, dynamic>? data;
    if (res.data is Map<String, dynamic>) {
      data = res.data as Map<String, dynamic>;
    } else if (res.data is Map) {
      data = (res.data as Map).cast<String, dynamic>();
    } else if (res.data is String && (res.data as String).trim().isNotEmpty) {
      data = await compute(_decodeJson, res.data as String);
    }
    if (data == null) {
      if (res.statusCode == 204 && null is T) return null as T;
      throw ApiException(
        'network.empty',
        '服务器返回为空',
        httpStatus: res.statusCode,
      );
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
    final data = res.data;
    if (data == null) {
      if (res.statusCode == 204) {
        if (<String, dynamic>{} is T) return <String, dynamic>{} as T;
        if (null is T) return null as T;
      }
      throw ApiException(
        'network.empty',
        '服务器返回为空 (HTTP ${res.statusCode})',
        httpStatus: res.statusCode,
      );
    }
    return unwrapEnvelope<T>(data);
  }
}
