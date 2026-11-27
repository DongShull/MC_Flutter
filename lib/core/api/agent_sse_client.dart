import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../network/server_routes.dart';
import '../session/session_store.dart';
import 'api_exception.dart';
import 'mc_client.dart';

/// 服务器推来的一条 SSE 事件（对齐 iOS `ServerEvent` 与 Kotlin `SseEvent`）。
class SseEvent {
  const SseEvent({required this.name, required this.data, this.id});

  /// `event:` 行的事件名；缺省帧（无名）为 `'message'`。
  final String name;
  final String data;
  final String? id;

  /// 将 `data` 解码为 JSON 对象（解码失败返回 null）。
  Map<String, dynamic>? decodeJson() {
    if (data.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return null;
  }
}

/// 服务器不支持 SSE（404 / 非 `text/event-stream` 响应）——调用方应回退轮询。
class SseUnsupportedException implements Exception {
  SseUnsupportedException(this.statusCode);

  final int? statusCode;

  @override
  String toString() => 'SseUnsupportedException(status: $statusCode)';
}

/// 严格按字节 `0x0A` (`\n`) 切行的 SSE 解析器（对齐 iOS `Shared/Core/Networking/EventStream.swift`）：
/// - 绝不使用 `LineSplitter` / 字符级分行，避免把 JSON 字符串内含的 Unicode 行分隔符
///   `U+2028` / `U+2029` / `U+0085` 误当行尾导致帧截断与 JSON 解析损坏；
/// - 仅认 LF (`0x0A`) 与可选的尾随 CR (`0x0D`)；
/// - 流结束时通过 `finish()` / `flush()` 吐出最后一条无尾随空行的事件。
class SseLineParser {
  final BytesBuilder _lineBuffer = BytesBuilder(copy: false);
  String? _id;
  String _event = 'message';
  final List<String> _data = <String>[];

  /// 喂入一块网络原始字节，按 `0x0A` 切行并产出已凑齐的全部事件。
  List<SseEvent> feedChunk(List<int> chunk) {
    final events = <SseEvent>[];
    var start = 0;
    for (var i = 0; i < chunk.length; i++) {
      if (chunk[i] == 0x0A) {
        if (i > start) {
          _lineBuffer.add(chunk.sublist(start, i));
        }
        final lineBytes = _lineBuffer.takeBytes();
        final ev = feedLine(lineBytes);
        if (ev != null) events.add(ev);
        start = i + 1;
      }
    }
    if (start < chunk.length) {
      _lineBuffer.add(chunk.sublist(start));
    }
    return events;
  }

  /// 喂入单行原始字节（不含 `0x0A`，可能以 `0x0D` 结尾）；遇到空行时返回凑齐的事件。
  SseEvent? feedLine(List<int> raw) {
    var end = raw.length;
    if (end > 0 && raw[end - 1] == 0x0D) {
      end--;
    }
    if (end == 0) {
      return flush();
    }
    final slice = end == raw.length ? raw : raw.sublist(0, end);
    final line = utf8.decode(slice, allowMalformed: true);
    if (line.startsWith(':')) return null;

    final colon = line.indexOf(':');
    final String field;
    String value;
    if (colon >= 0) {
      field = line.substring(0, colon);
      value = line.substring(colon + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }
    } else {
      field = line;
      value = '';
    }

    switch (field) {
      case 'event':
        _event = value;
      case 'data':
        _data.add(value);
      case 'id':
        _id = value;
      default:
        break;
    }
    return null;
  }

  /// 吐出当前缓冲区中已收集的事件并重置 `event`/`data`（保留 `id`）。
  SseEvent? flush() {
    final eventName = _event.isEmpty ? 'message' : _event;
    _event = 'message';
    if (_data.isEmpty) return null;
    final payload = _data.join('\n');
    _data.clear();
    return SseEvent(name: eventName, data: payload, id: _id);
  }

  /// 流到达 EOF 时调用：先消费残留的最后一行字节，再 `flush()` 产出尾随帧。
  List<SseEvent> finish() {
    final events = <SseEvent>[];
    if (_lineBuffer.isNotEmpty) {
      final ev = feedLine(_lineBuffer.takeBytes());
      if (ev != null) events.add(ev);
    }
    final tail = flush();
    if (tail != null) events.add(tail);
    return events;
  }
}

/// 通用 SSE 流客户端（对齐 iOS `APIClient.events`）：
/// 供 Agent（`/api/v1/agent/sessions/{id}/events`）、任务活动（`/api/v1/jobs/stream`）、
/// 资源搜索（`/api/v1/search/torrents/stream`）共用。
class McSseClient {
  McSseClient(
    this._session, {
    String? baseUrl,
    String? token,
  })  : _baseUrlOverride = baseUrl,
        _tokenOverride = token;

  final SessionStore _session;
  final String? _baseUrlOverride;
  final String? _tokenOverride;

  static const _baseBackoffMs = 800;
  static const _maxBackoffMs = 15000;

  String get _base {
    final override = _baseUrlOverride;
    if (override != null && override.isNotEmpty) {
      return ServerRoutes.normalizeOrigin(override);
    }
    final routed = ServerRoutes.instance.currentOrigin();
    if (routed.isNotEmpty) return routed;
    return ServerRoutes.normalizeOrigin(_session.baseUrl ?? '');
  }

  String? get _token => _tokenOverride ?? _session.token;

  /// 订阅一条通用 SSE 流：
  /// - 字节级 `0x0A` 分帧 + EOF `flush()`；
  /// - 附带 `User-Agent`、`Accept-Language`、`X-MovieClaw-Timezone`、`X-MovieClaw-Route`；
  /// - HTTP 401 立即触发全局 `McClient.emitUnauthorized` 并抛 `ApiException`；
  /// - `autoReconnect == true` 时在意外断流后携带 `Last-Event-ID` 指数退避续传。
  Stream<SseEvent> stream(
    String path, {
    Map<String, String>? query,
    String? lastEventId,
    Set<String>? terminalEvents,
    bool autoReconnect = true,
    int maxAttempts = 5,
    Duration connectTimeout = const Duration(seconds: 10),
  }) async* {
    final base = _base;
    final token = _token;
    if (base.isEmpty || token == null || token.isEmpty) {
      throw SseUnsupportedException(null);
    }

    final uri = _buildUri(base, path, query);
    var eventId = lastEventId;
    var attempt = 0;

    while (true) {
      var receivedTerminal = false;
      await for (final event in _once(
        uri: uri,
        origin: base,
        token: token,
        lastEventId: eventId,
        terminalEvents: terminalEvents,
        connectTimeout: connectTimeout,
      )) {
        yield event;
        if (event.id != null && event.id!.isNotEmpty) {
          eventId = event.id;
        }
        if (terminalEvents != null && terminalEvents.contains(event.name)) {
          receivedTerminal = true;
          return;
        }
      }
      if (receivedTerminal || !autoReconnect) return;

      attempt++;
      if (attempt >= maxAttempts) {
        throw SseUnsupportedException(null);
      }
      final delayMs = _baseBackoffMs * (1 << (attempt - 1));
      await Future<void>.delayed(
        Duration(milliseconds: delayMs > _maxBackoffMs ? _maxBackoffMs : delayMs),
      );
    }
  }

  Stream<SseEvent> _once({
    required Uri uri,
    required String origin,
    required String token,
    required String? lastEventId,
    required Set<String>? terminalEvents,
    required Duration connectTimeout,
  }) async* {
    final client = HttpClient();
    try {
      final req = await client.openUrl('GET', uri).timeout(connectTimeout);
      req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      req.headers.set(HttpHeaders.userAgentHeader, McClient.defaultUserAgent);
      req.headers.set(
        HttpHeaders.acceptLanguageHeader,
        McClient.currentAcceptLanguage,
      );
      req.headers.set('X-MovieClaw-Timezone', McClient.currentTimezone);
      final routeHeader = ServerRoutes.instance.routeHeaderValue;
      if (routeHeader != null && routeHeader.isNotEmpty) {
        req.headers.set('X-MovieClaw-Route', routeHeader);
      }
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (lastEventId != null && lastEventId.isNotEmpty) {
        req.headers.set('Last-Event-ID', lastEventId);
      }

      final res = await req.close().timeout(connectTimeout);

      if (res.statusCode == 401) {
        final msg = await _readErrorMessage(res);
        McClient.emitUnauthorized(
          origin: _session.baseUrl ?? origin,
          token: token,
          path: uri.path,
        );
        throw ApiException(
          'auth.unauthorized',
          msg ?? '登录已过期，请重新登录',
          httpStatus: 401,
        );
      }

      final contentType =
          res.headers.value(HttpHeaders.contentTypeHeader) ?? '';
      if (res.statusCode != 200 ||
          !contentType.toLowerCase().contains('text/event-stream')) {
        throw SseUnsupportedException(res.statusCode);
      }

      final parser = SseLineParser();
      await for (final chunk in res) {
        for (final event in parser.feedChunk(chunk)) {
          yield event;
          if (terminalEvents != null && terminalEvents.contains(event.name)) {
            return;
          }
        }
      }
      // 流 EOF 时 flush 尾随帧（即使末尾没有双换行）
      for (final event in parser.finish()) {
        yield event;
        if (terminalEvents != null && terminalEvents.contains(event.name)) {
          return;
        }
      }
    } on SseUnsupportedException {
      rethrow;
    } on ApiException {
      rethrow;
    } on Exception {
      // 网络抖动（超时/断连）：静默交由上层决定是否退避重连。
    } finally {
      client.close(force: true);
    }
  }

  static Uri _buildUri(String base, String path, Map<String, String>? query) {
    final raw = path.startsWith('http://') || path.startsWith('https://')
        ? path
        : (path.startsWith('/') ? '$base$path' : '$base/$path');
    final parsed = Uri.parse(raw);
    if (query == null || query.isEmpty) return parsed;
    final merged = <String, String>{
      ...parsed.queryParameters,
      ...query,
    };
    return parsed.replace(queryParameters: merged);
  }

  static Future<String?> _readErrorMessage(HttpClientResponse res) async {
    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in res) {
        builder.add(chunk);
        if (builder.length > 64 * 1024) break;
      }
      final text = utf8.decode(builder.takeBytes(), allowMalformed: true).trim();
      if (text.isEmpty) return null;
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return null;
  }
}

/// Agent 聊天流式客户端（100% 保持向后兼容，底层升级为 `McSseClient` + 字节级 `SseLineParser`）。
class AgentSseClient {
  /// [baseUrl]/[token] 仅测试注入用；缺省取全局 SessionStore。
  AgentSseClient(SessionStore session, {String? baseUrl, String? token})
      : _client = McSseClient(session, baseUrl: baseUrl, token: token);

  final McSseClient _client;

  static const _maxAttempts = 5;

  /// 终态事件名（对齐 EventStream.kt DEFAULT_TERMINAL）。
  static const terminalEvents = <String>{
    'done',
    'agent_done',
    'agent_error',
    'agent_cancelled',
  };

  /// 订阅一条 SSE 流直到终态事件或重试耗尽。
  /// [path] 为 API 相对路径（如 `/api/v1/agent/sessions/{id}/events`）。
  /// 服务器不支持该流式端点时抛 [SseUnsupportedException]。
  Stream<SseEvent> events(
    String path, {
    String? lastEventId,
    Map<String, String>? query,
    Set<String> terminalEvents = terminalEvents,
  }) =>
      _client.stream(
        path,
        query: query,
        lastEventId: lastEventId,
        terminalEvents: terminalEvents,
        autoReconnect: true,
        maxAttempts: _maxAttempts,
        connectTimeout: const Duration(seconds: 8),
      );

  /// 解析一个 SSE 帧（使用字节级 `SseLineParser`，兼容单测直接调用）。
  static SseEvent? parseFrame(String block) {
    final parser = SseLineParser();
    final events = parser.feedChunk(utf8.encode(block));
    if (events.isNotEmpty) return events.first;
    final tail = parser.finish();
    return tail.isEmpty ? null : tail.first;
  }
}
