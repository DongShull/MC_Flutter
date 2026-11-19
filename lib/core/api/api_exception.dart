/// 服务端统一信封解包后的业务异常（对齐原 GeneralChannel 的 ApiException）。
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.httpStatus});

  final String code;
  final String message;
  final int? httpStatus;

  /// 中文友好错误映射（对齐原 friendlyMessage）。
  String get friendlyMessage {
    const map = <String, String>{
      'auth.unauthorized': '登录已过期，请重新登录',
      'auth.forbidden': '没有权限执行此操作',
      'server.not_initialized': '服务器还未初始化',
      'playback.consent_required': '该片源需要软件转码，请确认',
      'network.timeout': '网络超时，请重试',
    };
    return map[code] ?? message;
  }

  @override
  String toString() => 'ApiException($code, $message)';
}

/// /api/v1 统一信封：{code, message, data}。
T unwrapEnvelope<T>(Map<String, dynamic> body) {
  final code = (body['code'] ?? 'ok').toString();
  if (code == 'ok' || code == '0' || code == '200') {
    return body['data'] as T;
  }
  throw ApiException(code, (body['message'] ?? '').toString());
}
