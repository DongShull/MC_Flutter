import 'dart:io';

import 'package:dio/dio.dart';

/// 422 请求校验失败的单条字段明细（对齐 iOS `APIErrorBody.Detail`）。
class ApiValidationDetail {
  const ApiValidationDetail({required this.location, this.message});

  factory ApiValidationDetail.fromJson(Map<String, dynamic> json) {
    final locRaw = json['location'] ?? json['loc'];
    final loc = <String>[];
    if (locRaw is List) {
      for (final item in locRaw) {
        if (item != null) loc.add(item.toString());
      }
    }
    return ApiValidationDetail(
      location: loc,
      message: (json['message'] ?? json['msg'])?.toString(),
    );
  }

  /// 字段路径，如 `['body', 'client', 'kind']`。
  final List<String> location;
  final String? message;

  /// 去掉最外层 `body` / `query` / `path` / `header` 前缀后的逻辑字段路径。
  List<String> get fieldPath {
    const wrappers = <String>{'body', 'query', 'path', 'header'};
    var start = 0;
    while (start < location.length && wrappers.contains(location[start])) {
      start++;
    }
    return location.sublist(start);
  }
}

/// 服务端统一信封解包后的业务异常与网络异常（对齐 iOS `APIError` 与 `APIErrorBody`）。
class ApiException implements Exception {
  const ApiException(
    this.code,
    this.message, {
    this.httpStatus,
    this.messageKey,
    this.details = const <ApiValidationDetail>[],
    this.isNetworkError = false,
    this.isTimeout = false,
  });

  /// 从错误响应 JSON 解析（提取 `code` / `message` / `message_key` / `details`）。
  factory ApiException.fromResponseBody(
    Map<String, dynamic> body, {
    int? httpStatus,
  }) {
    final rawCode = (body['code'] ?? '').toString().trim();
    final messageKey =
        (body['message_key'] ?? body['messageKey'])?.toString().trim();
    final rawMessage =
        (body['message'] ?? body['detail'] ?? '').toString().trim();
    final detailsRaw = body['details'];
    final details = <ApiValidationDetail>[
      if (detailsRaw is List)
        for (final item in detailsRaw)
          if (item is Map)
            ApiValidationDetail.fromJson(item.cast<String, dynamic>()),
    ];
    final effectiveCode = rawCode.isNotEmpty
        ? rawCode
        : (httpStatus != null ? 'http.$httpStatus' : 'unknown');
    final effectiveMessage = rawMessage.isNotEmpty
        ? rawMessage
        : _defaultHttpMessage(httpStatus);
    return ApiException(
      effectiveCode,
      effectiveMessage,
      httpStatus: httpStatus,
      messageKey: (messageKey != null && messageKey.isNotEmpty)
          ? messageKey
          : null,
      details: details,
    );
  }

  /// 将 Dio 底层传输异常映射为可执行、带 `host:port` 的中文说明（对齐 iOS `APIClient.networkMessage`）。
  factory ApiException.fromDioError(DioException error) {
    final uri = error.requestOptions.uri;
    final host = _hostLabel(uri);
    final hostRef = host.isNotEmpty ? '服务器 $host' : '服务器';

    if (error.type == DioExceptionType.badResponse && error.response != null) {
      final status = error.response!.statusCode;
      final data = error.response!.data;
      if (data is Map) {
        return ApiException.fromResponseBody(
          data.cast<String, dynamic>(),
          httpStatus: status,
        );
      }
      return ApiException(
        'http.${status ?? 0}',
        _httpMessageWithHost(status, hostRef),
        httpStatus: status,
      );
    }

    if (error.type == DioExceptionType.cancel) {
      return const ApiException(
        'network.cancelled',
        '请求已取消',
        isNetworkError: true,
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiException(
        'network.timeout',
        '连接$hostRef超时：请检查网络状态或确认服务地址是否正确',
        isNetworkError: true,
        isTimeout: true,
      );
    }

    if (error.type == DioExceptionType.badCertificate) {
      return ApiException(
        'network.tls',
        '$hostRef的 HTTPS 证书不受信任或已过期，请检查证书配置',
        isNetworkError: true,
      );
    }

    final inner = error.error;
    final detail = '${inner ?? error.message ?? ''}'.toLowerCase();
    if (inner is HandshakeException ||
        inner is TlsException ||
        detail.contains('handshake') ||
        detail.contains('certificate') ||
        detail.contains('tls')) {
      return ApiException(
        'network.tls',
        '与$hostRef建立加密连接失败：请确认 HTTPS 端口与证书配置',
        isNetworkError: true,
      );
    }
    if (detail.contains('failed host lookup') ||
        detail.contains('no address associated') ||
        detail.contains('name or service not known')) {
      return ApiException(
        'network.dns',
        '找不到$hostRef：请检查域名拼写或当前网络 DNS 设置',
        isNetworkError: true,
      );
    }
    if (detail.contains('connection refused')) {
      return ApiException(
        'network.refused',
        '$hostRef拒绝连接：请确认 MovieClaw 服务已启动且端口正确',
        isNetworkError: true,
      );
    }
    if (detail.contains('network is unreachable') ||
        detail.contains('no route to host') ||
        detail.contains('software caused connection abort')) {
      return ApiException(
        'network.offline',
        '当前网络不可达，无法访问$hostRef：请检查 Wi-Fi、蜂窝网络或 VPN',
        isNetworkError: true,
      );
    }
    if (detail.contains('connection reset') ||
        detail.contains('connection closed')) {
      return ApiException(
        'network.connection_lost',
        '与$hostRef的连接意外中断，请稍后重试',
        isNetworkError: true,
      );
    }
    if (inner is SocketException) {
      return ApiException(
        'network.socket',
        '无法连接到$hostRef：请检查服务器地址和当前网络',
        isNetworkError: true,
      );
    }

    return ApiException(
      'network.failed',
      '请求$hostRef失败：请检查网络连接后重试',
      isNetworkError: true,
    );
  }

  final String code;
  final String message;
  final int? httpStatus;
  final String? messageKey;
  final List<ApiValidationDetail> details;
  final bool isNetworkError;
  final bool isTimeout;

  bool get isUnauthorized =>
      httpStatus == 401 ||
      code == 'auth.unauthorized' ||
      messageKey == 'auth.unauthorized';

  /// 中文友好错误映射（含 422 校验错误字段详情与旧版服务器不支持客户端类型的专项提示）。
  String get friendlyMessage {
    if (code == 'VALIDATION_ERROR' || httpStatus == 422) {
      final validationMsg = _formatValidationMessage();
      if (validationMsg != null) return validationMsg;
    }

    const map = <String, String>{
      'auth.unauthorized': '登录已过期，请重新登录',
      'auth.forbidden': '没有权限执行此操作',
      'server.not_initialized': '服务器还未初始化',
      'playback.consent_required': '该片源需要软件转码，请确认',
      'network.timeout': '网络超时，请重试',
    };
    if (messageKey != null && map.containsKey(messageKey)) {
      return map[messageKey]!;
    }
    if (map.containsKey(code)) {
      return map[code]!;
    }
    if (message.isNotEmpty) return message;
    return _defaultHttpMessage(httpStatus);
  }

  String? _formatValidationMessage() {
    for (final d in details) {
      final path = d.fieldPath;
      if (path.length >= 2 &&
          path[path.length - 1] == 'kind' &&
          path[path.length - 2] == 'client') {
        return '当前服务器版本过旧，暂不支持此客户端类型，请先升级 MovieClaw 服务器';
      }
    }
    for (final d in details) {
      final path = d.fieldPath;
      if (path.isNotEmpty) {
        final field = path.join('.');
        final reason = (d.message != null && d.message!.trim().isNotEmpty)
            ? '：${d.message!.trim()}'
            : '';
        return '参数「$field」不合法$reason';
      }
    }
    if (message.isNotEmpty &&
        message.toLowerCase() != 'request validation failed') {
      return message;
    }
    return '请求参数不被当前服务器接受，请检查客户端与服务器版本是否匹配';
  }

  static String _hostLabel(Uri uri) {
    if (uri.host.isEmpty) return '';
    final isDefaultPort = !uri.hasPort ||
        (uri.scheme == 'http' && uri.port == 80) ||
        (uri.scheme == 'https' && uri.port == 443);
    return isDefaultPort ? uri.host : '${uri.host}:${uri.port}';
  }

  static String _defaultHttpMessage(int? status) {
    if (status == null) return '请求失败，请稍后重试';
    switch (status) {
      case 401:
        return '登录已过期，请重新登录';
      case 403:
        return '没有权限执行此操作';
      case 404:
        return '请求的接口不存在 (HTTP 404)';
      case 502:
        return '服务器网关异常 (HTTP 502)，请检查反向代理或后端服务状态';
      case 503:
        return '服务器暂时不可用 (HTTP 503)，请稍后重试';
      case 504:
        return '服务器网关超时 (HTTP 504)，请稍后重试';
      default:
        return '服务器返回错误 (HTTP $status)';
    }
  }

  static String _httpMessageWithHost(int? status, String hostRef) {
    if (status == 502 || status == 503 || status == 504) {
      return '$hostRef暂时不可用 (HTTP $status)，请检查后端服务或反向代理状态';
    }
    return _defaultHttpMessage(status);
  }

  @override
  String toString() => 'ApiException($code, $message)';
}

/// /api/v1 统一信封：`{success, code, message, message_key, details, data}`。
/// 兼容大小写（服务端返回 code:"OK"）与 success 布尔字段；
/// 无信封裸数据（无 code 且无 success 键）在 2xx 时原样通过。
T unwrapEnvelope<T>(Map<String, dynamic> body, {int? httpStatus}) {
  final raw = body['code'];
  final code = (raw ?? '').toString();
  final hasEnvelope = raw != null || body.containsKey('success');
  final isHttpError = httpStatus != null && httpStatus >= 400;
  final ok = !isHttpError &&
      (!hasEnvelope ||
          body['success'] == true ||
          code.toLowerCase() == 'ok' ||
          code == '0' ||
          code == '200' ||
          code.toLowerCase() == 'success');
  if (ok) {
    final data = body['data'];
    if (data == null) return body as T;
    return data as T;
  }
  throw ApiException.fromResponseBody(body, httpStatus: httpStatus);
}
