
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../network/server_routes.dart';
import '../session/session_store.dart';

/// 服务器推来的一条 SSE 事件（对齐 Kotlin core/network/EventStream.kt 的 SseEvent）。
class SseEvent {
  const SseEvent({required this.name, required this.data, this.id});

  /// event: 行的事件名；缺省帧（无名）为 'message'。
  final String name;
  final String data;
  final String? id;
}

/// 服务器不支持 SSE（404/非 event-stream 响应）——调用方应回退轮询，
/// 且本会话内不必再试流式。
class SseUnsupportedException implements Exception {
  SseUnsupportedException(this.statusCode);

  final int? statusCode;

  @override
  String toString() => 'SseUnsupportedException(status: $statusCode)';
}

/// Agent 聊天流式客户端（agent 域专用，避免与既有 mc_client.dart 撞名）：
/// - EventSource 风格：GET + Accept: text/event-stream，dart:io HttpClient
///   streamed request，按空行分帧解析 id/event/data 行；
/// - 断线自动重连并回传 Last-Event-ID（服务端据此续传）；
/// - 收到终态事件后正常收尾，不再重连（对齐 Kotlin DEFAULT_TERMINAL）。
class AgentSseClient {
  /// [baseUrl]/[token] 仅测试注入用；缺省取全局 SessionStore。
  AgentSseClient(this._session, {String? baseUrl, String? token})
      : _baseUrlOverride = baseUrl,
        _tokenOverride = token;

  final SessionStore _session;
  final String? _baseUrlOverride;
  final String? _tokenOverride;

  String get _base {
    final override = _baseUrlOverride;
    if (override != null && override.isNotEmpty) {
      return override;
    }
    final routed = ServerRoutes.instance.currentOrigin();
    if (routed.isNotEmpty) return routed;
    return _session.baseUrl ?? '';
  }
  String? get _token => _tokenOverride ?? _session.token;

  static const _maxAttempts = 5;
  static const _baseBackoffMs = 800;
  static const _maxBackoffMs = 15000;

  /// 终态事件名（对齐 EventStream.kt DEFAULT_TERMINAL）。
  static const terminalEvents = <String>{
    'done',
    'agent_done',
    'agent_error',
    'agent_cancelled',
  };

  /// 订阅一条 SSE 流直到终态事件或重试耗尽。
  /// [path] 为 API 相对路径（如 /api/v1/agent/sessions/{id}/events）。
  /// 服务器不支持该流式端点时抛 [SseUnsupportedException]。
  Stream<SseEvent> events(
    String path, {
    String? lastEventId,
    Set<String> terminalEvents = terminalEvents,
  }) async* {
    final base = _base;
    if (base.isEmpty || _token == null) {
      throw SseUnsupportedException(null); // 未登录时直接走轮询回退
    }
    var eventId = lastEventId;
    var attempt = 0;
    while (true) {
      await for (final event in _once('$base$path', eventId, terminalEvents)) {
        yield event;
        if (event.id != null) eventId = event.id;
        if (terminalEvents.contains(event.name)) return;
      }
      // _once 正常结束：连接被服务器关闭（无终态）或网络中断 → 退避重连续传。
      attempt++;
      if (attempt >= _maxAttempts) {
        throw SseUnsupportedException(null); // 重试耗尽，交给调用方回退
      }
      final delayMs = _baseBackoffMs * (1 << (attempt - 1));
      await Future<void>.delayed(
        Duration(milliseconds: delayMs > _maxBackoffMs ? _maxBackoffMs : delayMs),
      );
    }
  }

  /// 单次连接：成功打开后逐帧 yield；打开失败区分「不支持」与「网络抖动」。
  Stream<SseEvent> _once(
    String url,
    String? lastEventId,
    Set<String> terminalEvents,
  ) async* {
    final client = HttpClient();
    try {
      final req = await client
          .openUrl('GET', Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      req.headers.set('Authorization', 'Bearer $_token');
      if (lastEventId != null) req.headers.set('Last-Event-ID', lastEventId);
      final res = await req.close().timeout(const Duration(seconds: 8));
      final contentType =
          res.headers.value(HttpHeaders.contentTypeHeader) ?? '';
      if (res.statusCode != 200 ||
          !contentType.contains('text/event-stream')) {
        // 404 / 非流式响应：服务器没有这条 SSE 端点 → 明确不支持，不重试。
        throw SseUnsupportedException(res.statusCode);
      }

      const decoder = Utf8Decoder(allowMalformed: true);
      var buffer = '';
      await for (final chunk in res) {
        buffer += decoder.convert(chunk);
        var sep = buffer.indexOf('\n\n');
        while (sep >= 0) {
          final frame = parseFrame(buffer.substring(0, sep));
          buffer = buffer.substring(sep + 2);
          sep = buffer.indexOf('\n\n');
          if (frame == null) continue; // 注释心跳 / 空帧
          yield frame;
          if (terminalEvents.contains(frame.name)) return;
        }
      }
      // 流被服务器关闭：剩余残帧丢弃，由上层重连续传。
    } on SseUnsupportedException {
      rethrow;
    } on Exception {
      // 网络抖动（超时/断连）：静默交上层退避重连。
    } finally {
      client.close(force: true);
    }
  }

  /// 解析一个 SSE 帧：id / event / data 行；多行 data 以换行拼接。
  /// 纯注释帧（冒号开头心跳）返回 null。公开供单测直测。
  static SseEvent? parseFrame(String block) {
    var id = '';
    var name = '';
    final data = <String>[];
    for (final rawLine in block.split('\n')) {
      final line = rawLine.endsWith('\r')
          ? rawLine.substring(0, rawLine.length - 1)
          : rawLine;
      if (line.startsWith(':') || line.isEmpty) continue;
      if (line.startsWith('id:')) {
        id = line.substring(3).trim();
      } else if (line.startsWith('event:')) {
        name = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      }
    }
    if (data.isEmpty && name.isEmpty && id.isEmpty) return null;
    return SseEvent(
      name: name.isEmpty ? 'message' : name,
      data: data.join('\n'),
      id: id.isEmpty ? null : id,
    );
  }
}
