import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_store.dart';
import 'mc_error.dart';
import 'session_providers.dart';

/// 共享 SSE 客户端（会话绑定，供各 feature 控制器复用；未登录时
/// SseClient.events() 抛 [SseUnsupportedException]，调用方回退轮询）。
final sseClientProvider =
    Provider<SseClient>((ref) => SseClient(ref.watch(sessionStoreProvider)));

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

/// 通用 SSE 客户端（P1 核心层，替代各处 Timer.periodic 轮询的首选通道）：
/// - EventSource 风格：GET + Accept: text/event-stream，dart:io HttpClient
///   streamed request，按空行分帧解析 id/event/data 行；
/// - 断线自动重连并回传 Last-Event-ID（服务端据此续传），指数退避
///   （800ms 起，翻倍，上限 15s，带抖动）；
/// - 服务器不支持（404/非 event-stream）或重试耗尽时抛
///   [SseUnsupportedException]，调用方回退轮询（轮询只是降级）。
/// - 已知服务端流式端点（见 Kotlin EventStream.kt / PushStream.kt）：
///   `/api/v1/push/me/stream?since=<id>`（通知）、`/api/v1/jobs/stream`、
///   `/api/v1/agent/sessions/{id}/events`、`/search/torrents/stream`。
class SseClient {
  /// [baseUrl]/[token] 仅测试注入用；缺省取全局 SessionStore。
  SseClient(this._session, {String? baseUrl, String? token})
      : _baseUrlOverride = baseUrl,
        _tokenOverride = token;

  final SessionStore _session;
  final String? _baseUrlOverride;
  final String? _tokenOverride;

  String get _base => _baseUrlOverride ?? _session.baseUrl ?? '';
  String? get _token => _tokenOverride ?? _session.token;

  static const _maxAttempts = 5;
  static const _baseBackoffMs = 800;
  static const _maxBackoffMs = 15000;

  /// 指数退避延迟（公开供单测）：第 [attempt] 次（从 1 计）重连前等待的毫秒数。
  /// 上限 15s；调用方可自行加抖动。
  /// 注意：先封顶再移位——`1 << (attempt - 1)` 在 attempt 很大时会溢出归零。
  static int backoffMs(int attempt) {
    if (attempt >= 6) return _maxBackoffMs;
    final delayMs = _baseBackoffMs * (1 << (attempt - 1));
    return delayMs > _maxBackoffMs ? _maxBackoffMs : delayMs;
  }

  /// 订阅一条 SSE 流直到终态事件或重试耗尽。
  /// [path] 为 API 相对路径（如 /api/v1/push/me/stream）。
  /// [terminalEvents] 为空表示永不因事件名终结（常驻流，如通知/任务流）；
  ///   非空时收到其中任一事件即正常收尾，不再重连。
  /// 服务器不支持该流式端点时抛 [SseUnsupportedException]。
  Stream<SseEvent> events(
    String path, {
    String? lastEventId,
    Set<String> terminalEvents = const {},
    Map<String, String>? query,
  }) async* {
    final base = _base;
    if (base.isEmpty || _token == null) {
      throw SseUnsupportedException(null); // 未登录时直接走轮询回退
    }
    final url = query == null || query.isEmpty
        ? '$base$path'
        : '$base$path?${query.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    var eventId = lastEventId;
    var attempt = 0;
    while (true) {
      await for (final event in _once(url, eventId, terminalEvents)) {
        yield event;
        if (event.id != null) eventId = event.id;
        if (terminalEvents.contains(event.name)) return;
      }
      // _once 正常结束：连接被服务器关闭（无终态）或网络中断 → 退避重连续传。
      attempt++;
      if (attempt >= _maxAttempts) {
        McErrorLog.log(
          'SSE $path 重试 $_maxAttempts 次耗尽，回退轮询',
          context: 'sse',
        );
        throw SseUnsupportedException(null); // 重试耗尽，交给调用方回退
      }
      await Future<void>.delayed(
        Duration(milliseconds: backoffMs(attempt)),
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
    } on Exception catch (e) {
      // 网络抖动（超时/断连）：记日志，交上层退避重连。
      McErrorLog.log(e, context: 'sse');
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
