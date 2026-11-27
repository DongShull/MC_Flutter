import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/server_routes.dart';
import '../session/session_store.dart';
import 'api_exception.dart';
import 'retry_interceptor.dart';

/// 三通道网络层（对齐 iOS 三 URLSession：shared / live / playback）。
enum Channel { general, live, playback }

/// 全局 401 未授权广播载荷（对齐 iOS `Notification.Name.apiUnauthorized`）：
/// 携带触发 401 的服务器地址与请求令牌，便于 `SessionStore` 精准校验只踢出当前失效令牌。
class UnauthorizedEvent {
  const UnauthorizedEvent({
    required this.origin,
    this.token,
    this.path,
  });

  final String origin;
  final String? token;
  final String? path;
}

dynamic _decodeJsonDynamic(String raw) => jsonDecode(raw);

class McClient {
  McClient({
    required SessionStore session,
    String? ua,
    String? baseUrlOverride,
  })  : _session = session,
        ua = ua ?? defaultUserAgent,
        _baseUrlOverride = baseUrlOverride {
    for (final c in Channel.values) {
      _dio[c] = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: c == Channel.general
              ? const Duration(seconds: 25)
              : const Duration(seconds: 12),
          headers: <String, String>{
            'User-Agent': this.ua,
            'Accept': 'application/json',
          },
          validateStatus: (_) => true,
        ),
      );
      _dio[c]!.interceptors.add(RetryInterceptor(_dio[c]!));
    }
  }

  static const String appVersion = '0.14.1';

  /// 可由应用层注入语言标签提供器（如接入 l10n 语言切换器）。
  static String Function()? acceptLanguageProvider;

  /// 可由应用层注入 IANA 时区提供器。
  static String Function()? timezoneProvider;

  static final StreamController<UnauthorizedEvent> _unauthorizedController =
      StreamController<UnauthorizedEvent>.broadcast();

  /// 全局 401 未授权事件流（排除登录/初始化/访客分享端点）。
  static Stream<UnauthorizedEvent> get onUnauthorized =>
      _unauthorizedController.stream;

  /// 实例便捷访问全局 401 事件流。
  Stream<UnauthorizedEvent> get unauthorizedStream => onUnauthorized;

  /// 平台准确的 User-Agent：`MovieClaw-Flutter/0.14.1 (<OS>; Flutter)`。
  static String get defaultUserAgent =>
      'MovieClaw-Flutter/$appVersion ($_platformLabel; Flutter)';

  static String get _platformLabel {
    if (kIsWeb) return 'Web';
    switch (Platform.operatingSystem) {
      case 'ios':
        return 'iOS';
      case 'android':
        return 'Android';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      case 'windows':
        return 'Windows';
      default:
        return Platform.operatingSystem;
    }
  }

  static String get currentAcceptLanguage {
    try {
      final provided = acceptLanguageProvider?.call().trim();
      if (provided != null && provided.isNotEmpty) return provided;
      final tag = PlatformDispatcher.instance.locale.toLanguageTag().trim();
      if (tag.isNotEmpty && tag.toLowerCase() != 'und') return tag;
    } catch (_) {}
    return 'zh-CN';
  }

  static String get currentTimezone {
    try {
      final provided = timezoneProvider?.call().trim();
      if (provided != null && provided.isNotEmpty) return provided;
      final tz = DateTime.now().timeZoneName.trim();
      if (tz.isNotEmpty) return tz;
    } catch (_) {}
    return 'UTC';
  }

  /// 这些接口的 401 不代表当前登录会话过期（对齐 iOS `APIClient.isAuthEndpoint`）：
  /// - 登录与初始化：401 代表密码错误；
  /// - 访客分享 `/api/v1/share/*`：401 代表需要分享密码或分享密码错误。
  static bool isAuthExemptPath(String? path) {
    if (path == null || path.isEmpty) return false;
    final clean = path.split('?').first;
    return clean.endsWith('/auth/login') ||
        clean.endsWith('/auth/device/login') ||
        clean.endsWith('/auth/bootstrap') ||
        clean.contains('/api/v1/share/');
  }

  /// 向全局广播一次 401 未授权事件（自动跳过豁免端点）。
  static void emitUnauthorized({
    required String origin,
    String? token,
    String? path,
  }) {
    if (isAuthExemptPath(path)) return;
    if (!_unauthorizedController.isClosed) {
      _unauthorizedController.add(
        UnauthorizedEvent(origin: origin, token: token, path: path),
      );
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

  Map<String, String> _requestHeaders({String? tokenOverride}) {
    final token = tokenOverride ?? _session.token;
    final routeHeader = ServerRoutes.instance.routeHeaderValue;
    return <String, String>{
      'User-Agent': ua,
      'Accept': 'application/json',
      'Accept-Language': currentAcceptLanguage,
      'X-MovieClaw-Timezone': currentTimezone,
      if (routeHeader != null && routeHeader.isNotEmpty)
        'X-MovieClaw-Route': routeHeader,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
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

  /// 不拆 `{success, code, message, data}` 信封的原始请求（如 `/api/v1/health`）。
  Future<T> raw<T>(
    Channel channel,
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Duration? timeout,
  }) async {
    final res = await _executeRequest(
      channel,
      method,
      path,
      body: body,
      query: query,
      timeout: timeout,
    );
    final decoded = await _decodeBodySafe(res);
    if (res.statusCode != null && res.statusCode! >= 400) {
      if (decoded is Map<String, dynamic>) {
        throw ApiException.fromResponseBody(decoded, httpStatus: res.statusCode);
      }
      throw ApiException(
        'http.${res.statusCode}',
        _nonJsonHttpMessage(res.statusCode, res.requestOptions.uri),
        httpStatus: res.statusCode,
      );
    }
    if (decoded == null) {
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
    return decoded as T;
  }

  Future<Response<Map<String, dynamic>>> _send(
    Channel channel,
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Duration? timeout,
  }) async {
    final res = await _executeRequest(
      channel,
      method,
      path,
      body: body,
      query: query,
      timeout: timeout,
    );
    final decoded = await _decodeBodySafe(res);
    Map<String, dynamic>? parsed;
    if (decoded is Map<String, dynamic>) {
      parsed = decoded;
    } else if (decoded is Map) {
      parsed = decoded.cast<String, dynamic>();
    } else if (decoded != null) {
      // 裸 JSON 数组等合法 JSON：包裹为 data 键保持 Map 响应兼容
      parsed = <String, dynamic>{'data': decoded};
    } else if (res.statusCode != null && res.statusCode! >= 400) {
      parsed = <String, dynamic>{
        'success': false,
        'code': 'http.${res.statusCode}',
        'message': _nonJsonHttpMessage(res.statusCode, res.requestOptions.uri),
      };
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

  /// Multipart 上传（头像、封面、字幕、插件包等）：自动拼 `$baseUrl` 并附带统一请求头与 401 监听。
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
    final parts = contentType.split('/');
    final form = FormData.fromMap(<String, dynamic>{
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
    final res = await _executeRequest(
      channel,
      'POST',
      path,
      body: form,
      query: query,
    );
    final decoded = await _decodeBodySafe(res);
    Map<String, dynamic>? data;
    if (decoded is Map<String, dynamic>) {
      data = decoded;
    } else if (decoded is Map) {
      data = decoded.cast<String, dynamic>();
    }
    if (data == null) {
      if (res.statusCode == 204 && null is T) return null as T;
      throw ApiException(
        res.statusCode != null && res.statusCode! >= 400
            ? 'http.${res.statusCode}'
            : 'network.empty',
        res.statusCode != null && res.statusCode! >= 400
            ? _nonJsonHttpMessage(res.statusCode, res.requestOptions.uri)
            : '服务器返回为空',
        httpStatus: res.statusCode,
      );
    }
    return unwrapEnvelope<T>(data, httpStatus: res.statusCode);
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
    return unwrapEnvelope<T>(data, httpStatus: res.statusCode);
  }

  // ── 内部执行、故障切换与安全 JSON 解析 ───────────────────────────────────

  Future<Response<dynamic>> _executeRequest(
    Channel channel,
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Duration? timeout,
  }) async {
    final dio = _dio[channel]!;
    final isAbsolute =
        path.startsWith('http://') || path.startsWith('https://');
    final usedOrigin = isAbsolute ? _originOf(path) : baseUrl;
    final url = isAbsolute ? path : '$usedOrigin$path';
    final usedToken = _session.token;

    Options buildOptions() => Options(
          method: method,
          headers: _requestHeaders(tokenOverride: usedToken),
          sendTimeout: timeout,
          receiveTimeout: timeout,
        );

    Response<dynamic> res;
    try {
      res = await dio.request<dynamic>(
        url,
        data: body,
        queryParameters: query,
        options: buildOptions(),
      );
    } on DioException catch (err) {
      // 硬连接错误：对幂等 GET/HEAD 触发一次 ServerRoutes.failover 并重发
      if (_shouldFailover(err, method) &&
          !isAbsolute &&
          _baseUrlOverride == null &&
          usedOrigin.isNotEmpty) {
        final nextOrigin = await ServerRoutes.instance.failover(
          usedOrigin,
          forServer: _session.baseUrl,
        );
        if (nextOrigin != null &&
            nextOrigin.isNotEmpty &&
            ServerRoutes.originKey(nextOrigin) !=
                ServerRoutes.originKey(usedOrigin)) {
          try {
            res = await dio.request<dynamic>(
              '$nextOrigin$path',
              data: body,
              queryParameters: query,
              options: buildOptions(),
            );
          } on DioException catch (retryErr) {
            throw ApiException.fromDioError(retryErr);
          }
        } else {
          throw ApiException.fromDioError(err);
        }
      } else {
        throw ApiException.fromDioError(err);
      }
    }

    if (res.statusCode == 401) {
      emitUnauthorized(
        origin: _session.baseUrl ?? usedOrigin,
        token: usedToken,
        path: res.requestOptions.uri.path,
      );
    }
    return res;
  }

  bool _shouldFailover(DioException err, String method) {
    final upper = method.toUpperCase();
    if (upper != 'GET' && upper != 'HEAD') return false;
    return err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.badCertificate;
  }

  /// 安全解析响应体：防止反向代理返回 502/504 HTML 页面导致未捕获 `FormatException`。
  Future<dynamic> _decodeBodySafe(Response<dynamic> res) async {
    final raw = res.data;
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is List) return raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        // 大响应走 isolate 解码，小响应直接同步解码避免 isolate 开销
        if (trimmed.length > 32 * 1024) {
          return await compute(_decodeJsonDynamic, trimmed);
        }
        return jsonDecode(trimmed);
      } on FormatException {
        final status = res.statusCode ?? 0;
        if (status >= 400) {
          throw ApiException(
            'http.$status',
            _nonJsonHttpMessage(status, res.requestOptions.uri),
            httpStatus: status,
          );
        }
        throw ApiException(
          'network.decoding',
          '服务器返回的内容不是有效的 JSON 格式（可能被代理或门户页面拦截）',
          httpStatus: res.statusCode,
        );
      }
    }
    return null;
  }

  static String _originOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return '';
    return ServerRoutes.normalizeOrigin(url);
  }

  static String _nonJsonHttpMessage(int? status, Uri uri) {
    final host = ServerRoutes.hostLabelOf(uri.toString());
    final hostRef = host.isNotEmpty ? '服务器 $host' : '服务器';
    switch (status) {
      case 401:
        return '登录已过期，请重新登录';
      case 403:
        return '没有权限执行此操作';
      case 404:
        return '接口不存在 (HTTP 404)';
      case 502:
        return '$hostRef网关错误 (HTTP 502)，请检查后端服务是否正常运行';
      case 503:
        return '$hostRef暂时不可用 (HTTP 503)，请稍后重试';
      case 504:
        return '$hostRef网关超时 (HTTP 504)，请稍后重试';
      default:
        return '$hostRef返回异常响应 (HTTP ${status ?? 0})';
    }
  }
}
