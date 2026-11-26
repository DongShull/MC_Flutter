import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// 离线字节搬运平台通道（对齐飞牛 trim_native_download：
/// MethodChannel 'trim_native_download' + 每任务事件流 'trim_native_download/progress/<id>'，
/// 进度字段 received / currentLength / totalBytes 的口径也一并抄过来）。
///
/// 原生侧未实现（MissingPluginException）时自动降级为纯 Dart http 分块下载保底：
/// dart:io HttpClient + Range 断点续传（.part 半成品 + .part.meta 续传元数据），
/// 重启后再 start 同一任务会从已收字节处继续（服务器不支持 Range 则整段重下）。

/// 一次下载请求。
class McDownloadRequest {
  const McDownloadRequest({
    required this.id,
    required this.url,
    required this.savePath,
    this.headers = const {},
  });

  /// 任务唯一 id（调用方保证稳定，断点续传靠它对回 .part 文件）。
  final String id;
  final String url;
  final String savePath;
  final Map<String, String> headers;
}

/// 进度事件（字段名对齐飞牛 received / currentLength / totalBytes）。
class McDownloadProgress {
  const McDownloadProgress({
    required this.id,
    required this.receivedBytes,
    this.totalBytes,
    this.done = false,
    this.error,
  });

  final String id;
  final int receivedBytes;
  final int? totalBytes;

  /// true = 已落盘完成（savePath 就绪）或已取消。
  final bool done;

  /// 非 null = 本次任务以失败/取消收场（文案）。
  final String? error;

  double? get ratio =>
      totalBytes == null || totalBytes! <= 0
          ? null
          : (receivedBytes / totalBytes!).clamp(0.0, 1.0);

  factory McDownloadProgress.fromNative(String id, Object? raw) {
    final map = <String, Object?>{
      if (raw is Map) for (final e in raw.entries) e.key.toString(): e.value,
    };
    // 飞牛字段 received/currentLength 与常见 receivedBytes/totalBytes 命名都兼容。
    final received = (map['received'] ?? map['receivedBytes'] ?? 0) as num;
    final total = map['totalBytes'] ?? map['currentLength'] ?? map['total'];
    return McDownloadProgress(
      id: id,
      receivedBytes: received.toInt(),
      totalBytes: total is num ? total.toInt() : null,
      done: map['done'] == true || map['state']?.toString() == 'done',
      error: map['error']?.toString(),
    );
  }
}

/// 下载目录约定：原生通道给真实应用目录；拿不到时按环境变量 / 当前目录 / 临时目录
/// 逐级兜底（测试与桌面端可用 MC_OFFLINE_DIR 显式指定）。
abstract final class McDownloadPaths {
  static const _channel = MethodChannel('mc/native/download');

  static Future<Directory> resolve() async {
    try {
      final dir = await _channel.invokeMethod<String>('getDownloadDirectory');
      if (dir != null && dir.isNotEmpty) return Directory(dir);
    } catch (_) {
      // 原生未实现：走跨平台可写目录兜底。
    }
    final env = Platform.environment['MC_OFFLINE_DIR'];
    if (env != null && env.isNotEmpty) return Directory(env);

    // 优先使用各平台用户数据目录，避免 iOS/macOS 沙盒下 Directory.current == '/' 只读报错。
    final home = Platform.environment['HOME'];
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final xdgData = Platform.environment['XDG_DATA_HOME'];
    if (Platform.isWindows && localAppData != null && localAppData.isNotEmpty) {
      return Directory('$localAppData/MovieClaw/offline_downloads');
    }
    if ((Platform.isIOS || Platform.isMacOS) &&
        home != null &&
        home.isNotEmpty) {
      return Directory('$home/Documents/offline_downloads');
    }
    if (Platform.isLinux) {
      if (xdgData != null && xdgData.isNotEmpty) {
        return Directory('$xdgData/movieclaw/offline_downloads');
      }
      if (home != null && home.isNotEmpty) {
        return Directory('$home/.local/share/movieclaw/offline_downloads');
      }
    }
    try {
      final cwd = Directory.current.path;
      if (cwd != '/' && cwd.isNotEmpty) {
        return Directory('$cwd/offline_downloads');
      }
    } catch (_) {}
    return Directory('${Directory.systemTemp.path}/movieclaw_offline');
  }
}

/// 下载通道门面：全部调用先走原生，MissingPluginException（或原生声明
/// unsupported）时降级保底实现。降级是一次性决定，之后整会话都走保底。
abstract final class McDownloadChannel {
  static const _channel = MethodChannel('mc/native/download');

  static bool? _nativeAvailable;

  static final McFallbackDownloadManager _fallback =
      McFallbackDownloadManager();

  /// 原生侧是否可用（首次调用后确定；未确认前按可用处理）。
  static bool get nativeAvailable => _nativeAvailable ?? true;

  /// 测试用：重置降级判定。
  static void resetForTest() => _nativeAvailable = null;

  static bool get _useFallback => _nativeAvailable == false;

  /// 一次性探测原生侧是否接了 mc/native/download：
  /// MissingPluginException = 没接（降级保底）；其余任何应答（包括
  /// PlatformException / MissingMethodException）都说明原生插件存在。
  static Future<void> _probe() async {
    if (_nativeAvailable != null) return;
    try {
      await _channel.invokeMethod<String>('probeDownload');
      _nativeAvailable = true;
    } on MissingPluginException {
      _nativeAvailable = false;
    } on PlatformException {
      // 原生插件在，只是没实现 probe 这个方法：按可用走。
      _nativeAvailable = true;
    } catch (_) {
      _nativeAvailable = true;
    }
  }

  /// 开始 / 续传一个任务。立即返回，进度走 [progress]；幂等：同 id 重复 start 等价于继续。
  static Future<void> start(McDownloadRequest request) async {
    if (!_useFallback) {
      try {
        await _channel.invokeMethod<void>('startDownload', {
          'id': request.id,
          'url': request.url,
          'savePath': request.savePath,
          'headers': request.headers,
        });
        _nativeAvailable = true;
        return;
      } on MissingPluginException {
        _nativeAvailable = false;
      } on PlatformException catch (e) {
        if (e.code != 'unsupported') rethrow;
        _nativeAvailable = false;
      }
    }
    await _fallback.start(request);
  }

  static Future<void> pause(String id) async {
    if (!_useFallback) {
      try {
        await _channel.invokeMethod<void>('pauseDownload', {'id': id});
        return;
      } on MissingPluginException {
        _nativeAvailable = false;
      } on PlatformException catch (e) {
        if (e.code != 'unsupported') rethrow;
        _nativeAvailable = false;
      }
    }
    await _fallback.pause(id);
  }

  static Future<void> cancel(String id) async {
    if (!_useFallback) {
      try {
        await _channel.invokeMethod<void>('cancelDownload', {'id': id});
        return;
      } on MissingPluginException {
        _nativeAvailable = false;
      } on PlatformException catch (e) {
        if (e.code != 'unsupported') rethrow;
        _nativeAvailable = false;
      }
    }
    await _fallback.cancel(id);
  }

  /// 进度事件流（对齐飞牛每任务 EventChannel 'trim_native_download/progress/<id>'；
  /// 保底实现是内存流，订阅时先补发最近一次进度）。流结束 = 任务终结。
  ///
  /// EventChannel 订阅收到 MissingPluginException（原生侧未实现）时自动
  /// 切到保底内存流；单订阅语义（每个任务订阅一次）。
  static Stream<McDownloadProgress> progress(String id) {
    StreamSubscription<dynamic>? sub;
    var onFallback = _useFallback;
    late final StreamController<McDownloadProgress> ctrl;
    ctrl = StreamController<McDownloadProgress>(
      onListen: () {
        void followFallback() {
          onFallback = true;
          sub = _fallback.watch(id).listen(
                ctrl.add,
                onError: ctrl.addError,
                onDone: ctrl.close,
                cancelOnError: true,
              );
        }

        () async {
          // 先确认原生侧是否可用（探测一次），再挂对应事件源。
          await _probe();
          if (onFallback || _useFallback) {
            followFallback();
            return;
          }
          final event = EventChannel('mc/native/download/progress/$id')
              .receiveBroadcastStream();
          sub = event.listen(
            (raw) => ctrl.add(McDownloadProgress.fromNative(id, raw)),
            onError: (Object e) {
              if (e is MissingPluginException) {
                _nativeAvailable = false;
                sub?.cancel();
                followFallback();
              } else {
                ctrl.addError(e);
              }
            },
            onDone: ctrl.close,
            cancelOnError: false,
          );
        }();
      },
      onCancel: () => sub?.cancel(),
    );
    return ctrl.stream;
  }

  /// 删除半成品（.part / .part.meta），供取消与重下使用。
  static Future<void> removePartial(String savePath) =>
      _fallback.removePartial(savePath);

  /// 本机存储容量（原生 capacity → {freeBytes, totalBytes}）。
  /// 原生未实现（MissingPluginException / 非 Android 平台）时返回 null，
  /// 调用方保持占位行为。
  static Future<({int freeBytes, int totalBytes})?> capacity() async {
    if (_useFallback) return null;
    try {
      final raw = await _channel.invokeMethod<Object?>('capacity');
      _nativeAvailable = true;
      if (raw is Map) {
        final map = <String, Object?>{
          for (final e in raw.entries) e.key.toString(): e.value,
        };
        final free = (map['freeBytes'] ?? map['free']) as num?;
        final total = (map['totalBytes'] ?? map['total']) as num?;
        if (free != null && total != null) {
          return (freeBytes: free.toInt(), totalBytes: total.toInt());
        }
      }
      return null;
    } on MissingPluginException {
      _nativeAvailable = false;
      return null;
    } on PlatformException catch (e) {
      if (e.code != 'unsupported') rethrow;
      _nativeAvailable = false;
      return null;
    }
  }

  /// 删除本机文件（原生 delete(path) → bool）。
  /// 原生未实现时降级为 dart:io 直接删除；删除失败返回 false，不抛异常。
  static Future<bool> delete(String path) async {
    if (_useFallback) return _deleteLocal(path);
    try {
      final ok = await _channel.invokeMethod<bool>('delete', {'path': path});
      _nativeAvailable = true;
      return ok ?? false;
    } on MissingPluginException {
      _nativeAvailable = false;
    } on PlatformException catch (e) {
      if (e.code != 'unsupported') return false;
      _nativeAvailable = false;
    } catch (_) {
      return false;
    }
    return _deleteLocal(path);
  }

  static Future<bool> _deleteLocal(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// 纯 Dart 保底下载器：HttpClient + Range 断点续传。
///
/// 半成品落在 `<savePath>.part`，续传元数据在 `<savePath>.part.meta`
/// （json：url / received / totalBytes）。重启后对同一 savePath 再 start
/// 即从 received 处继续；服务器不支持 Range（非 206 应答）时整段重下。
class McFallbackDownloadManager {
  McFallbackDownloadManager();

  final Map<String, _FallbackTask> _tasks = {};

  /// 订阅某任务进度；保底实现里这是带最近值回放的内存流。
  Stream<McDownloadProgress> watch(String id) {
    final task = _tasks.putIfAbsent(id, () => _FallbackTask(id));
    return task.watch();
  }

  Future<void> start(McDownloadRequest request) async {
    var task = _tasks[request.id];
    if (task == null || task.terminated) {
      task = _FallbackTask(request.id);
      _tasks[request.id] = task;
    }
    // 立即返回；异常通过进度流（error 字段）上报。
    unawaited(task.run(request));
  }

  Future<void> pause(String id) => _tasks[id]?.pause() ?? Future.value();

  Future<void> cancel(String id) => _tasks[id]?.cancel() ?? Future.value();

  Future<void> removePartial(String savePath) async {
    for (final suffix in ['.part', '.part.meta']) {
      final f = File('$savePath$suffix');
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {
          // 删不掉就留着，下次覆盖。
        }
      }
    }
  }
}

/// 单个保底任务的状态机：idle → running → (paused | done | failed)。
class _FallbackTask {
  _FallbackTask(this.id);

  final String id;
  final StreamController<McDownloadProgress> _events =
      StreamController<McDownloadProgress>.broadcast();

  McDownloadProgress? _last;
  HttpClient? _client;
  bool _stop = false;
  bool _cancel = false;

  /// done 或 error 已上报，任务终结（续跑要换新控制器）。
  bool get terminated => _events.isClosed;

  void _emit(McDownloadProgress p) {
    _last = p;
    if (!_events.isClosed) _events.add(p);
    if (p.done || p.error != null) _events.close();
  }

  /// 订阅：先补发最近一次进度，再跟随后续事件直到终结。
  Stream<McDownloadProgress> watch() async* {
    final snapshot = _last;
    if (snapshot != null) yield snapshot;
    if (_events.isClosed) return;
    await for (final p in _events.stream) {
      yield p;
      if (p.done || p.error != null) return;
    }
  }

  Future<void> pause() async {
    _stop = true;
  }

  Future<void> cancel() async {
    _cancel = true;
    _stop = true;
  }

  Future<void> run(McDownloadRequest request) async {
    _stop = false;
    _cancel = false;
    final save = File(request.savePath);
    await save.parent.create(recursive: true);
    final partPath = '${request.savePath}.part';
    final metaPath = '$partPath.meta';

    var received = 0;
    int? total;
    final part = File(partPath);
    final metaFile = File(metaPath);

    // —— 断点续传：读回上次进度 ——
    if (await part.exists() && await metaFile.exists()) {
      try {
        final meta =
            jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        if (meta['url']?.toString() == request.url) {
          received = ((meta['received'] ?? 0) as num).toInt();
          final t = meta['totalBytes'];
          total = t is num ? t.toInt() : null;
        }
      } catch (_) {
        received = 0;
      }
    }
    // 半成品损坏（比记录短）或 URL 已变：整段重下。
    if (received > 0 &&
        (!await part.exists() || await part.length() < received)) {
      received = 0;
      total = null;
    }

    try {
      final client = _client = HttpClient();
      client.userAgent = 'MovieClaw-Flutter/0.1.0';
      final req = await client.getUrl(Uri.parse(request.url));
      request.headers.forEach(req.headers.set);
      if (received > 0) {
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$received-');
      }
      final res = await req.close();
      if (received > 0 && res.statusCode != HttpStatus.partialContent) {
        // 服务器不支持续传：从头再来。
        received = 0;
        total = null;
      }
      if (res.statusCode >= 400) {
        throw HttpException('HTTP ${res.statusCode} for ${request.url}');
      }
      final contentLength = res.contentLength;
      if (received == 0 && contentLength > 0) {
        total = contentLength;
      } else if (total == null && contentLength > 0) {
        total = received + contentLength;
      }
      final sink = await part.open(
        mode: received > 0 ? FileMode.append : FileMode.writeOnly,
      );
      try {
        await for (final chunk in res) {
          if (_stop) break;
          await sink.writeFrom(chunk);
          received += chunk.length;
          _emit(McDownloadProgress(
            id: id,
            receivedBytes: received,
            totalBytes: total,
          ));
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      _client?.close(force: true);
      _client = null;

      if (_cancel) {
        await _cleanup(part, metaFile);
        _emit(McDownloadProgress(
          id: id,
          receivedBytes: 0,
          done: true,
          error: 'Download was cancelled',
        ));
        return;
      }
      if (_stop) {
        // 暂停：写回续传元数据，等下次 start 继续。
        await _writeMeta(metaFile, request.url, received, total);
        return;
      }
      // —— 完成：.part 原子改名落盘 ——
      if (await metaFile.exists()) await metaFile.delete();
      if (await save.exists()) await save.delete();
      await part.rename(request.savePath);
      _emit(McDownloadProgress(
        id: id,
        receivedBytes: received,
        totalBytes: total ?? received,
        done: true,
      ));
    } catch (e) {
      _client?.close(force: true);
      _client = null;
      if (_cancel) {
        await _cleanup(part, metaFile);
        _emit(McDownloadProgress(
          id: id,
          receivedBytes: 0,
          done: true,
          error: 'Download was cancelled',
        ));
        return;
      }
      // 失败：留存 .part 供重启/重试续传，报错收场。
      if (received > 0) await _writeMeta(metaFile, request.url, received, total);
      _emit(McDownloadProgress(
        id: id,
        receivedBytes: received,
        totalBytes: total,
        error: e.toString(),
      ));
    }
  }

  Future<void> _writeMeta(
    File meta,
    String url,
    int received,
    int? total,
  ) async {
    try {
      await meta.writeAsString(jsonEncode({
        'url': url,
        'received': received,
        'totalBytes': total,
      }));
    } catch (_) {
      // 写元数据失败只影响续传精度，不影响任务本身。
    }
  }

  Future<void> _cleanup(File part, File meta) async {
    _client?.close(force: true);
    _client = null;
    for (final f in [part, meta]) {
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {
          // 留给下次覆盖。
        }
      }
    }
  }
}
