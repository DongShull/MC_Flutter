import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 离线字节搬运平台通道（MethodChannel 'mc/native/download' +
/// 每任务事件流 'mc/native/download/progress/<id>'）。
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
    this.allowCellular,
  });

  /// 任务唯一 id（调用方保证稳定，断点续传靠它对回 .part 文件）。
  final String id;
  final String url;
  final String savePath;
  final Map<String, String> headers;

  /// 是否允许蜂窝网络（null 时沿用全局设置）。
  final bool? allowCellular;
}

/// 进度事件（字段名兼容 received/currentLength 与 receivedBytes/totalBytes，
/// 并支持透传 HTTP 503 服务端转码排队头 Retry-After / x-export-wait / x-export-ahead）。
class McDownloadProgress {
  const McDownloadProgress({
    required this.id,
    required this.receivedBytes,
    this.totalBytes,
    this.done = false,
    this.error,
    this.httpStatus,
    this.retryAfterSeconds,
    this.exportWait,
    this.exportAhead,
  });

  final String id;
  final int receivedBytes;
  final int? totalBytes;

  /// true = 已落盘完成（savePath 就绪）或已取消。
  final bool done;

  /// 非 null = 本次任务以失败/取消收场（文案）。
  final String? error;

  /// HTTP 失败状态码（如 503 / 401 / 404 / 422）。
  final int? httpStatus;

  /// 服务端 503 返回的 Retry-After（秒）。
  final int? retryAfterSeconds;

  /// 服务端 503 返回的 x-export-wait（queue / transcoder）。
  final String? exportWait;

  /// 服务端 503 返回的 x-export-ahead（前面排队个数）。
  final int? exportAhead;

  double? get ratio =>
      totalBytes == null || totalBytes! <= 0
          ? null
          : (receivedBytes / totalBytes!).clamp(0.0, 1.0);

  factory McDownloadProgress.fromNative(String id, Object? raw) {
    final map = <String, Object?>{
      if (raw is Map) for (final e in raw.entries) e.key.toString(): e.value,
    };
    final received = (map['received'] ?? map['receivedBytes'] ?? 0) as num;
    final total = map['totalBytes'] ?? map['currentLength'] ?? map['total'];
    final statusRaw = map['httpStatus'] ?? map['statusCode'];
    final retryRaw = map['retryAfter'] ?? map['retryAfterSeconds'];
    final aheadRaw = map['exportAhead'] ?? map['exportsAhead'];
    return McDownloadProgress(
      id: id,
      receivedBytes: received.toInt(),
      totalBytes: total is num ? total.toInt() : null,
      done: map['done'] == true || map['state']?.toString() == 'done',
      error: map['error']?.toString(),
      httpStatus: statusRaw is num
          ? statusRaw.toInt()
          : int.tryParse(statusRaw?.toString() ?? ''),
      retryAfterSeconds: retryRaw is num
          ? retryRaw.toInt()
          : int.tryParse(retryRaw?.toString() ?? ''),
      exportWait: map['exportWait']?.toString(),
      exportAhead: aheadRaw is num
          ? aheadRaw.toInt()
          : int.tryParse(aheadRaw?.toString() ?? ''),
    );
  }
}

/// 离线存储目录约定（对齐 iOS OfflineDisk.root：`<ApplicationSupport>/Offline/<sha256(origin|username)>/`）：
/// 绝不在生产环境落入 `Directory.systemTemp`（系统随时清理 tmp 导致已下载影片丢失）。
/// 仅在 `FLUTTER_TEST` 环境下 `path_provider` 抛 `MissingPluginException` 时优雅兜底。
abstract final class McDownloadPaths {
  static const _channel = MethodChannel('mc/native/download');

  static const Set<String> _knownExtensions = {
    'mp4',
    'mkv',
    'm4v',
    'mov',
    'ts',
    'm2ts',
    'avi',
    'webm',
    'flv',
    'wmv',
    'mpg',
    'mpeg',
    'iso',
    'rmvb',
  };

  /// 计算账号目录隔离哈希（SHA-256 前 16 字节 = 32 位十六进制，对齐 iOS `OfflineOwner.key`）。
  static String ownerHash(String origin, String username) {
    final normalizedOrigin = origin.trim().replaceAll(RegExp(r'/+$'), '');
    final raw = '$normalizedOrigin|${username.trim()}';
    final digest = sha256.convert(utf8.encode(raw)).bytes;
    final buf = StringBuffer();
    for (var i = 0; i < 16 && i < digest.length; i++) {
      buf.write(digest[i].toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  /// 根据服务端容器名或文件名保留真实扩展名（绝不强写死 `.mp4`）。
  static String sanitizeExtension(
    String? containerOrFilename, {
    bool isTranscode = false,
  }) {
    if (isTranscode) return 'mp4';
    var raw = (containerOrFilename ?? '').trim().toLowerCase();
    if (raw.contains('.')) {
      raw = raw.split('.').last;
    }
    if (raw == 'matroska') return 'mkv';
    if (_knownExtensions.contains(raw)) return raw;
    final cleaned = raw.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleaned.isEmpty) return 'mkv';
    return cleaned.length > 5 ? cleaned.substring(0, 5) : cleaned;
  }

  /// 解析离线根目录：
  /// 1. 显式环境变量 `MC_OFFLINE_DIR`（桌面/测试覆盖）
  /// 2. 原生通道 `getDownloadDirectory`（iOS 返回 Application Support/Offline 并标 excludedFromBackup）
  /// 3. `path_provider` `getApplicationSupportDirectory()` + `/Offline`
  /// 4. 平台用户数据目录兜底（仅在 MissingPluginException 时）
  /// 5. 仅在 `FLUTTER_TEST` 环境下无法获取上述目录时才允许退回 `Directory.systemTemp`
  static Future<Directory> resolve({String? ownerKey}) async {
    final root = await _resolveRoot();
    final target = (ownerKey != null && ownerKey.isNotEmpty)
        ? Directory('${root.path}/$ownerKey')
        : root;
    if (!await target.exists()) {
      try {
        await target.create(recursive: true);
      } catch (_) {}
    }
    return target;
  }

  /// 按服务器地址与用户名解析账号隔离目录：`<appSupport>/Offline/<sha256(origin|username)>/`。
  static Future<Directory> resolveForOwner({
    required String origin,
    required String username,
  }) {
    final hash = ownerHash(origin, username);
    return resolve(ownerKey: hash);
  }

  static Future<Directory> _resolveRoot() async {
    final env = Platform.environment['MC_OFFLINE_DIR'];
    if (env != null && env.isNotEmpty) return Directory(env);

    try {
      final dir = await _channel.invokeMethod<String>('getDownloadDirectory');
      if (dir != null && dir.isNotEmpty) return Directory(dir);
    } catch (_) {
      // 原生未实现，继续走 path_provider 持久化目录。
    }

    try {
      final appSupport = await getApplicationSupportDirectory();
      return Directory('${appSupport.path}/Offline');
    } on MissingPluginException {
      // 测试环境或桌面未注册插件时走平台用户目录兜底。
    } catch (_) {
      // 其他异常也尝试平台用户目录兜底。
    }

    final home = Platform.environment['HOME'];
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final xdgData = Platform.environment['XDG_DATA_HOME'];
    if (Platform.isWindows &&
        localAppData != null &&
        localAppData.isNotEmpty) {
      return Directory('$localAppData/MovieClaw/Offline');
    }
    if ((Platform.isIOS || Platform.isMacOS) &&
        home != null &&
        home.isNotEmpty) {
      return Directory('$home/Library/Application Support/MovieClaw/Offline');
    }
    if (Platform.isLinux) {
      if (xdgData != null && xdgData.isNotEmpty) {
        return Directory('$xdgData/movieclaw/Offline');
      }
      if (home != null && home.isNotEmpty) {
        return Directory('$home/.local/share/movieclaw/Offline');
      }
    }

    // 仅在 FLUTTER_TEST 下兜底到 systemTemp，避免污染生产沙盒或数据丢失。
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Directory('${Directory.systemTemp.path}/movieclaw_offline_test');
    }
    try {
      final cwd = Directory.current.path;
      if (cwd != '/' && cwd.isNotEmpty) {
        return Directory('$cwd/Offline');
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
  static bool _allowCellular = false;

  static final McFallbackDownloadManager _fallback =
      McFallbackDownloadManager();

  /// 原生侧是否可用（首次调用后确定；未确认前按可用处理）。
  static bool get nativeAvailable => _nativeAvailable ?? true;

  /// 当前是否允许蜂窝网络下载。
  static bool get allowCellular => _allowCellular;

  /// 测试用：重置降级判定。
  static void resetForTest() {
    _nativeAvailable = null;
    _allowCellular = false;
    _fallback.setAllowCellular(false);
  }

  static bool get _useFallback => _nativeAvailable == false;

  /// 一次性探测原生侧是否接了 mc/native/download。
  static Future<void> _probe() async {
    if (_nativeAvailable != null) return;
    try {
      await _channel.invokeMethod<String>('probeDownload');
      _nativeAvailable = true;
    } on MissingPluginException {
      _nativeAvailable = false;
    } on PlatformException {
      _nativeAvailable = true;
    } catch (_) {
      _nativeAvailable = true;
    }
  }

  /// 同步蜂窝网络下载策略到原生 iOS URLSession 与 Dart 保底下载器。
  static Future<void> setAllowCellular(bool allow) async {
    _allowCellular = allow;
    _fallback.setAllowCellular(allow);
    if (_useFallback) return;
    try {
      await _channel.invokeMethod<void>('setAllowCellular', {
        'allow': allow,
        'allowCellular': allow,
      });
      _nativeAvailable = true;
    } on MissingPluginException {
      _nativeAvailable = false;
    } on PlatformException catch (e) {
      if (e.code != 'unsupported') rethrow;
      _nativeAvailable = false;
    }
  }

  /// 开始 / 续传一个任务。立即返回，进度走 [progress]；幂等：同 id 重复 start 等价于继续。
  static Future<void> start(McDownloadRequest request) async {
    final cellular = request.allowCellular ?? _allowCellular;
    if (!_useFallback) {
      try {
        await _channel.invokeMethod<void>('startDownload', {
          'id': request.id,
          'url': request.url,
          'savePath': request.savePath,
          'headers': request.headers,
          'allowCellular': cellular,
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

  /// 进度事件流（每任务 EventChannel 'mc/native/download/progress/<id>'；
  /// 保底实现是带最近值回放的内存流）。流结束 = 任务终结。
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

  /// 删除半成品（.part / .part.meta / .resume），供取消与重下使用。
  static Future<void> removePartial(String savePath) =>
      _fallback.removePartial(savePath);

  /// 本机存储容量（优先走原生 capacity → {freeBytes, totalBytes}；
  /// 原生不可用或返回 null 时降级读取本机离线目录所在分区真实容量）。
  static Future<({int freeBytes, int totalBytes})?> capacity() async {
    if (!_useFallback) {
      try {
        final raw = await _channel.invokeMethod<Object?>('capacity');
        _nativeAvailable = true;
        if (raw is Map) {
          final map = <String, Object?>{
            for (final e in raw.entries) e.key.toString(): e.value,
          };
          final free = (map['freeBytes'] ?? map['free']) as num?;
          final total = (map['totalBytes'] ?? map['total']) as num?;
          if (free != null && total != null && total > 0) {
            return (freeBytes: free.toInt(), totalBytes: total.toInt());
          }
        }
      } on MissingPluginException {
        _nativeAvailable = false;
      } on PlatformException catch (e) {
        if (e.code != 'unsupported') rethrow;
        _nativeAvailable = false;
      } catch (_) {}
    }
    return _fallbackCapacity();
  }

  /// 计算离线根目录所在分区的真实总容量与可用容量（Linux/macOS 通过 `df -Pk`，其他环境兜底）。
  static Future<({int freeBytes, int totalBytes})?> _fallbackCapacity() async {
    try {
      final dir = await McDownloadPaths.resolve();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      if (Platform.isLinux || Platform.isMacOS || Platform.isAndroid) {
        final res = await Process.run('df', ['-Pk', dir.path]);
        if (res.exitCode == 0) {
          final lines = res.stdout
              .toString()
              .trim()
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();
          if (lines.length >= 2) {
            final cols = lines.last.split(RegExp(r'\s+'));
            // POSIX df -Pk: Filesystem 1024-blocks Used Available Capacity Mounted
            if (cols.length >= 4) {
              final totalKb = int.tryParse(cols[1]);
              final availKb = int.tryParse(cols[3]);
              if (totalKb != null && availKb != null && totalKb > 0) {
                return (
                  freeBytes: availKb * 1024,
                  totalBytes: totalKb * 1024,
                );
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// 递归统计目录占用字节数（存储页「MovieClaw 下载」及「其他账号」占用统计）。
  static Future<int> directorySizeBytes(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
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

/// 纯 Dart 保底下载器：HttpClient + Range 断点续传 + 蜂窝策略感知 + 503 排队头透传。
///
/// 半成品落在 `<savePath>.part`，续传元数据在 `<savePath>.part.meta`
/// （json：url / received / totalBytes）。重启后对同一 savePath 再 start
/// 即从 received 处继续；服务器不支持 Range（非 206 应答）时整段重下。
class McFallbackDownloadManager {
  McFallbackDownloadManager();

  final Map<String, _FallbackTask> _tasks = {};
  bool _allowCellular = false;

  bool get allowCellular => _allowCellular;

  void setAllowCellular(bool allow) {
    _allowCellular = allow;
  }

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
    unawaited(
      task.run(
        request,
        allowCellular: request.allowCellular ?? _allowCellular,
      ),
    );
  }

  Future<void> pause(String id) => _tasks[id]?.pause() ?? Future.value();

  Future<void> cancel(String id) => _tasks[id]?.cancel() ?? Future.value();

  Future<void> removePartial(String savePath) async {
    for (final suffix in ['.part', '.part.meta', '.resume']) {
      final f = File('$savePath$suffix');
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
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

  /// 探测当前设备是否处于仅蜂窝网络（无 Wi-Fi / 以太网 / 回环）。
  /// 桌面端及本地回环地址（127.0.0.1 / localhost）默认放行以免误伤局域网或单元测试。
  Future<bool> _isBlockedByCellularPolicy(
    String url,
    bool allowCellular,
  ) async {
    if (allowCellular) return false;
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase() ?? '';
    if (host == '127.0.0.1' || host == 'localhost' || host == '::1') {
      return false;
    }
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final ifaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );
      if (ifaces.isEmpty) return false;
      var hasWifiOrLan = false;
      var hasCellular = false;
      for (final iface in ifaces) {
        final name = iface.name.toLowerCase();
        if (name.startsWith('en') ||
            name.startsWith('wlan') ||
            name.startsWith('eth') ||
            name.startsWith('wifi')) {
          hasWifiOrLan = true;
        } else if (name.startsWith('pdp_ip') ||
            name.startsWith('rmnet') ||
            name.startsWith('ccmni') ||
            name.startsWith('wwan')) {
          hasCellular = true;
        }
      }
      return hasCellular && !hasWifiOrLan;
    } catch (_) {
      return false;
    }
  }

  Future<void> run(
    McDownloadRequest request, {
    required bool allowCellular,
  }) async {
    _stop = false;
    _cancel = false;

    if (await _isBlockedByCellularPolicy(request.url, allowCellular)) {
      _emit(McDownloadProgress(
        id: id,
        receivedBytes: 0,
        error: 'waiting_wifi',
      ));
      return;
    }

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
      client.connectionTimeout = const Duration(seconds: 20);
      client.idleTimeout = const Duration(seconds: 120);
      client.userAgent = 'MovieClaw-Flutter/0.14.1';
      final req = await client.getUrl(Uri.parse(request.url));
      request.headers.forEach(req.headers.set);
      if (received > 0) {
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$received-');
      }
      final res = await req.close();
      if (received > 0 && res.statusCode != HttpStatus.partialContent) {
        received = 0;
        total = null;
      }
      if (res.statusCode >= 400) {
        final retryAfter =
            int.tryParse(res.headers.value('retry-after')?.trim() ?? '');
        final exportWait = res.headers.value('x-export-wait')?.trim();
        final exportAhead =
            int.tryParse(res.headers.value('x-export-ahead')?.trim() ?? '');
        // 消费并丢弃错误响应体，避免 socket 泄漏。
        await res.drain<void>();
        _client?.close(force: true);
        _client = null;
        _emit(McDownloadProgress(
          id: id,
          receivedBytes: received,
          totalBytes: total,
          error: 'HTTP ${res.statusCode} for ${request.url}',
          httpStatus: res.statusCode,
          retryAfterSeconds: retryAfter,
          exportWait: exportWait,
          exportAhead: exportAhead,
        ));
        return;
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
    } catch (_) {}
  }

  Future<void> _cleanup(File part, File meta) async {
    _client?.close(force: true);
    _client = null;
    for (final f in [part, meta]) {
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }
}
