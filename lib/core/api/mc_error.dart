import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exception.dart';

/// 错误分级（P1 核心层）：调用方不再需要猜异常是什么，所有错误先分级再处理。
///
/// - [McErrorKind.network]：连接失败 / DNS / 连接被拒（Dio connectionError、
///   SocketException）。可提示“服务器连不上”，可重试。
/// - [McErrorKind.timeout]：连接/发送/接收超时。可提示“网络超时”，可重试。
/// - [McErrorKind.tls]：证书校验失败（HandshakeException / Dio badCertificate）。
///   提示“证书有问题”，不要静默重试。
/// - [McErrorKind.auth]：401/403（令牌过期、无权限）。应走重新登录/刷新令牌，
///   不要当普通网络错重试。
/// - [McErrorKind.envelope]：服务端信封返回 success=false（业务错误，
///   如 playback.consent_required）。用 [ApiException.friendlyMessage] 展示。
/// - [McErrorKind.server]：5xx / 空响应 / 解析失败等其它服务端问题。
/// - [McErrorKind.unknown]：分不出来的，兜底。
enum McErrorKind { network, timeout, tls, auth, envelope, server, unknown }

/// 一条已分级的错误：原始异常 + 分级 + 可展示文案 + 是否可重试。
class McError {
  const McError({
    required this.kind,
    required this.message,
    this.code,
    this.httpStatus,
    this.cause,
  });

  /// 把任意异常分级。接受 DioException / ApiException / SocketException /
  /// HandshakeException / TimeoutException / HttpException 等。
  factory McError.classify(Object error, {StackTrace? stackTrace}) {
    if (error is McError) return error;
    if (error is ApiException) {
      final code = error.code;
      if (code == 'auth.unauthorized' || code == 'auth.forbidden') {
        return McError(
          kind: McErrorKind.auth,
          message: error.friendlyMessage,
          code: code,
          httpStatus: error.httpStatus,
          cause: error,
        );
      }
      if (code.startsWith('network.')) {
        final kind = code == 'network.timeout'
            ? McErrorKind.timeout
            : code == 'network.tls'
                ? McErrorKind.tls
                : McErrorKind.network;
        return McError(
          kind: kind,
          message: error.friendlyMessage,
          code: code,
          httpStatus: error.httpStatus,
          cause: error,
        );
      }
      return McError(
        kind: McErrorKind.envelope,
        message: error.friendlyMessage,
        code: code,
        httpStatus: error.httpStatus,
        cause: error,
      );
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return McError(
          kind: McErrorKind.auth,
          message: status == 401 ? '登录已过期，请重新登录' : '没有权限执行此操作',
          code: 'auth.unauthorized',
          httpStatus: status,
          cause: error,
        );
      }
      // 5xx 响应就是服务端错误，与 DioExceptionType 无关
      //（badResponse 之外，超时/取消等类型也可能带 5xx 响应）。
      if (status != null && status >= 500) {
        return McError(
          kind: McErrorKind.server,
          message: '服务器返回异常（HTTP $status）',
          code: 'network.server',
          httpStatus: status,
          cause: error,
        );
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return McError(
            kind: McErrorKind.timeout,
            message: '网络超时，请重试',
            code: 'network.timeout',
            httpStatus: status,
            cause: error,
          );
        case DioExceptionType.badCertificate:
          return McError(
            kind: McErrorKind.tls,
            message: '服务器证书校验失败，请检查服务器地址',
            code: 'network.tls',
            httpStatus: status,
            cause: error,
          );
        case DioExceptionType.connectionError:
          return _fromIoError(error.error, status, error);
        case DioExceptionType.badResponse:
          return McError(
            kind: (status != null && status >= 500)
                ? McErrorKind.server
                : McErrorKind.envelope,
            message: '服务器返回异常（HTTP $status）',
            code: 'network.bad_response',
            httpStatus: status,
            cause: error,
          );
        case DioExceptionType.cancel:
          return McError(
            kind: McErrorKind.unknown,
            message: '请求已取消',
            code: 'network.cancelled',
            httpStatus: status,
            cause: error,
          );
        case DioExceptionType.unknown:
          return _fromIoError(error.error, status, error);
      }
    }
    if (error is SocketException) {
      return _fromIoError(error, null, error);
    }
    if (error is HandshakeException) {
      return McError(
        kind: McErrorKind.tls,
        message: '服务器证书校验失败，请检查服务器地址',
        code: 'network.tls',
        cause: error,
      );
    }
    if (error is TimeoutException) {
      return const McError(
        kind: McErrorKind.timeout,
        message: '网络超时，请重试',
        code: 'network.timeout',
      );
    }
    return McError(
      kind: McErrorKind.unknown,
      message: error.toString(),
      cause: error,
    );
  }

  static McError _fromIoError(Object? ioError, int? status, Object cause) {
    final text = ioError.toString().toLowerCase();
    if (ioError is HandshakeException ||
        text.contains('certificate') ||
        text.contains('handshake') ||
        text.contains('tls') ||
        text.contains('ssl')) {
      return McError(
        kind: McErrorKind.tls,
        message: '服务器证书校验失败，请检查服务器地址',
        code: 'network.tls',
        httpStatus: status,
        cause: cause,
      );
    }
    if (text.contains('timed out') || text.contains('timeout')) {
      return McError(
        kind: McErrorKind.timeout,
        message: '网络超时，请重试',
        code: 'network.timeout',
        httpStatus: status,
        cause: cause,
      );
    }
    return McError(
      kind: McErrorKind.network,
      message: '无法连接服务器，请检查网络与服务器地址',
      code: 'network.unreachable',
      httpStatus: status,
      cause: cause,
    );
  }

  /// 把分级结果转回统一的 [ApiException]（McClient 层用：调用方只认 ApiException）。
  ApiException toApiException() => ApiException(
        code ?? 'network.error',
        message,
        httpStatus: httpStatus,
      );

  final McErrorKind kind;

  /// 展示用文案（已是中文友好文案）。
  final String message;

  /// 业务/传输错误码（如 auth.unauthorized / network.timeout）。
  final String? code;

  final int? httpStatus;

  /// 原始异常（排障用）。
  final Object? cause;

  /// 网络抖动类（可重试）：network / timeout / server(5xx)。
  bool get retryable =>
      kind == McErrorKind.network ||
      kind == McErrorKind.timeout ||
      kind == McErrorKind.server;

  @override
  String toString() => 'McError($kind, $code, $message)';
}

/// 统一错误日志：静默 catch 的替代品。
///
/// - 之前 `catch (_) {}` / `catch (_) { return null; }` 的位置，一律改为
///   `McErrorLog.log(e, context: '...')` 再返回兜底值：兜底行为保留，
///   但错误不再无声消失。
/// - [reporter] 是未来接上报通道（崩溃上报/服务端日志）的钩子；未接之前
///   只在 debug 下输出，release 下静默（避免刷屏）。
class McErrorLog {
  McErrorLog._();

  /// 可选的上报钩子（由 main 注入；P1 暂不接任何上报服务）。
  static void Function(McError error, String context, StackTrace? stack)?
      reporter;

  static void log(
    Object error, {
    String context = '',
    StackTrace? stackTrace,
    McErrorKind? kind,
  }) {
    final classified = error is McError
        ? error
        : McError.classify(error, stackTrace: stackTrace);
    final effective = kind == null
        ? classified
        : McError(
            kind: kind,
            message: classified.message,
            code: classified.code,
            httpStatus: classified.httpStatus,
            cause: classified.cause,
          );
    final label = context.isEmpty ? 'mc' : 'mc:$context';
    debugPrint('$label ${effective.kind.name}: ${effective.message}'
        '${effective.code == null ? '' : ' (${effective.code})'}'
        '${effective.cause == null ? '' : ' | cause: ${effective.cause}'}');
    reporter?.call(effective, context, stackTrace);
  }
}
