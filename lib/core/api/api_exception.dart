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

/// /api/v1 统一信封：{success, code, message, data}。
/// 兼容大小写（服务端返回 code:"OK"）与 success 布尔字段；
/// 无信封裸数据（无 code 且无 success 键）原样通过。
T unwrapEnvelope<T>(Map<String, dynamic> body) {
  final raw = body['code'];
  final code = (raw ?? '').toString();
  final hasEnvelope = raw != null || body.containsKey('success');
  final ok = !hasEnvelope ||
      body['success'] == true ||
      code.toLowerCase() == 'ok' ||
      code == '0' ||
      code == '200' ||
      code.toLowerCase() == 'success';
  if (ok) {
    final data = body['data'];
    if (data == null) return body as T;
    return data as T;
  }
  throw ApiException(code, (body['message'] ?? '').toString());
}
