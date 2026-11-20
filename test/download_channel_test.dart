import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/platform/download_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    McDownloadChannel.resetForTest();
    // TestWidgetsFlutterBinding 会把所有 HttpClient 打成 400 mock；
    // 这里测真实 dart:io 下载，恢复无 override。
    HttpOverrides.global = null;
    tempDir = await Directory.systemTemp.createTemp('mc_dl_test');
    // 原生通道不存在：默认 BinaryMessenger 抛 MissingPluginException，
    // 验证「降级纯 Dart 保底」这条主路径。
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// 本地 HTTP 服务：支持 Range（206），按 1KB 块发送。
  Future<HttpServer> startServer(Uint8List payload, List<String?> seenRanges) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      seenRanges.add(req.headers.value(HttpHeaders.rangeHeader));
      var start = 0;
      var partial = false;
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        final m = RegExp(r'bytes=(\d+)-').firstMatch(range);
        if (m != null) {
          start = int.parse(m.group(1)!);
          partial = true;
        }
      }
      req.response.statusCode =
          partial ? HttpStatus.partialContent : HttpStatus.ok;
      req.response.contentLength = payload.length - start;
      if (partial) {
        req.response.headers.set(HttpHeaders.contentRangeHeader,
            'bytes $start-${payload.length - 1}/${payload.length}');
      }
      const chunk = 1024;
      for (var i = start; i < payload.length; i += chunk) {
        final end = (i + chunk) > payload.length ? payload.length : i + chunk;
        req.response.add(payload.sublist(i, end));
        await req.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      await req.response.close();
    });
    return server;
  }

  Uint8List payload(int size, [int seed = 7]) {
    final data = Uint8List(size);
    for (var i = 0; i < size; i++) {
      data[i] = (i * seed) % 256;
    }
    return data;
  }

  test('MissingPluginException 降级保底：整段下载 + 进度 + 完成落盘', () async {
    final data = payload(8 * 1024);
    final server = await startServer(data, []);
    final savePath = '${tempDir.path}/full.mp4';
    final events = <McDownloadProgress>[];
    final terminal = Completer<McDownloadProgress>();
    final sub = McDownloadChannel.progress('task-1').listen((p) {
      events.add(p);
      if ((p.done || p.error != null) && !terminal.isCompleted) {
        terminal.complete(p);
      }
    });

    await McDownloadChannel.start(McDownloadRequest(
      id: 'task-1',
      url: 'http://127.0.0.1:${server.port}/v.mp4',
      savePath: savePath,
    ));

    final last = await terminal.future.timeout(const Duration(seconds: 10));
    await sub.cancel();

    expect(McDownloadChannel.nativeAvailable, isFalse);
    expect(await File(savePath).exists(), isTrue);
    expect(await File(savePath).readAsBytes(), data);
    expect(events.isNotEmpty, isTrue);
    expect(last.done, isTrue);
    expect(last.error, isNull);
    expect(last.totalBytes, data.length);
    expect(last.receivedBytes, data.length);
    expect(await File('$savePath.part').exists(), isFalse);
    expect(await File('$savePath.part.meta').exists(), isFalse);
    await server.close(force: true);
  });

  test('断点续传：.part + .part.meta 从已收字节处 Range 续下', () async {
    final data = payload(8 * 1024);
    final seenRanges = <String?>[];
    final server = await startServer(data, seenRanges);
    final savePath = '${tempDir.path}/resume.mp4';
    final half = data.sublist(0, 4096);
    await File('$savePath.part').writeAsBytes(half);
    await File('$savePath.part.meta').writeAsString(
        '{"url":"http://127.0.0.1:${server.port}/v.mp4","received":4096,"totalBytes":${data.length}}');

    final done = Completer<McDownloadProgress>();
    final sub = McDownloadChannel.progress('task-2').listen((p) {
      if (p.done || p.error != null) {
        if (!done.isCompleted) done.complete(p);
      }
    });

    await McDownloadChannel.start(McDownloadRequest(
      id: 'task-2',
      url: 'http://127.0.0.1:${server.port}/v.mp4',
      savePath: savePath,
    ));

    final last = await done.future.timeout(const Duration(seconds: 10));
    await sub.cancel();

    expect(seenRanges.first, 'bytes=4096-');
    expect(last.done, isTrue);
    expect(last.error, isNull);
    expect(last.receivedBytes, data.length);
    expect(await File(savePath).readAsBytes(), data);
    await server.close(force: true);
  });

  test('暂停后留存 .part，重启 start 续传完成', () async {
    final data = payload(16 * 1024);
    final server = await startServer(data, []);
    final savePath = '${tempDir.path}/pause.mp4';

    // 订阅进度，收够 2KB 后暂停。
    var receivedMid = 0;
    final sub = McDownloadChannel.progress('task-3').listen((p) {
      if (p.receivedBytes >= 2048 && receivedMid == 0) {
        receivedMid = p.receivedBytes;
        McDownloadChannel.pause('task-3');
      }
    });

    await McDownloadChannel.start(McDownloadRequest(
      id: 'task-3',
      url: 'http://127.0.0.1:${server.port}/v.mp4',
      savePath: savePath,
    ));

    // 等 run() 因暂停返回（part 稳定不再增长）。
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      if (receivedMid > 0 && await File('$savePath.part.meta').exists()) break;
    }
    expect(receivedMid, greaterThan(0));
    expect(await File(savePath).exists(), isFalse);
    expect(await File('$savePath.part').exists(), isTrue);

    // 重启（同 id 再 start）→ 续传到完成。
    final done = Completer<McDownloadProgress>();
    final sub2 = McDownloadChannel.progress('task-3').listen((p) {
      if (p.done && p.error == null && !done.isCompleted) done.complete(p);
    });
    await McDownloadChannel.start(McDownloadRequest(
      id: 'task-3',
      url: 'http://127.0.0.1:${server.port}/v.mp4',
      savePath: savePath,
    ));
    final last = await done.future.timeout(const Duration(seconds: 10));
    await sub.cancel();
    await sub2.cancel();

    expect(last.receivedBytes, data.length);
    expect(await File(savePath).readAsBytes(), data);
    await server.close(force: true);
  });

  test('取消：删除半成品并上报取消', () async {
    final data = payload(32 * 1024);
    final server = await startServer(data, []);
    final savePath = '${tempDir.path}/cancel.mp4';

    final terminal = Completer<McDownloadProgress>();
    final sub = McDownloadChannel.progress('task-4').listen((p) {
      if ((p.done || p.error != null) && !terminal.isCompleted) {
        terminal.complete(p);
      }
    });
    unawaited(McDownloadChannel.start(McDownloadRequest(
      id: 'task-4',
      url: 'http://127.0.0.1:${server.port}/v.mp4',
      savePath: savePath,
    )));
    // 收到一点进度后立刻取消。
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await McDownloadChannel.cancel('task-4');

    final last = await terminal.future.timeout(const Duration(seconds: 5));
    await sub.cancel();
    expect(last.error, 'Download was cancelled');
    expect(await File('$savePath.part').exists(), isFalse);
    expect(await File('$savePath.part.meta').exists(), isFalse);
    await server.close(force: true);
  });

  test('McDownloadProgress.fromNative 字段口径（飞牛 received/currentLength）', () {
    final p = McDownloadProgress.fromNative('x', {
      'received': 300,
      'currentLength': 900,
    });
    expect(p.receivedBytes, 300);
    expect(p.totalBytes, 900);
    expect(p.ratio, closeTo(1.0 / 3.0, 0.001));
    final err = McDownloadProgress.fromNative('x', {
      'receivedBytes': 5,
      'totalBytes': 10,
      'error': 'boom',
    });
    expect(err.error, 'boom');
    expect(err.done, isFalse);
  });

  test('McDownloadPaths.resolve 无原生时落到环境/目录兜底', () async {
    final dir = await McDownloadPaths.resolve();
    expect(dir.path, isNotEmpty);
  });
}
