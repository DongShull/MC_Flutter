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

/// 信封解包核心：ok 时返回 `data`（可能为 null），非 ok 抛 [ApiException]。
/// 无信封裸数据（无 code 且无 success 键）原样返回 data（即整个 body 里没有
/// data 键时返回 null，由调用方按裸数据处理）。
dynamic decodeEnvelope(Map<String, dynamic> body) {
  final raw = body['code'];
  final code = (raw ?? '').toString();
  final hasEnvelope = raw != null || body.containsKey('success');
  final ok = !hasEnvelope ||
      body['success'] == true ||
      code.toLowerCase() == 'ok' ||
      code == '0' ||
      code == '200' ||
      code.toLowerCase() == 'success';
  if (!ok) {
    throw ApiException(code, (body['message'] ?? '').toString());
  }
  return body['data'];
}

/// /api/v1 统一信封：{success, code, message, data}。
/// 兼容大小写（服务端返回 code:"OK"）与 success 布尔字段；
/// 无信封裸数据（无 code 且无 success 键）原样通过。
T unwrapEnvelope<T>(Map<String, dynamic> body) {
  final data = decodeEnvelope(body);
  if (data == null) return body as T;
  return data as T;
}
