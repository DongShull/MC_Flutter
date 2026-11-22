import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/platform/download_channel.dart';
import 'package:mc_flutter/features/offline/state/background_download.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// 假的保底下载器：不走真网络，按表行事——
/// 有字节就写盘并报 done；无字节（null）就报 error。
/// 这样 `resumePendingDownloads` 的调度逻辑可测，
/// 真下载路径由 `McFallbackDownloadManager` 自己的测试覆盖。
class FakeFallbackManager extends McFallbackDownloadManager {
  FakeFallbackManager(this.results);

  /// url → 要写盘的字节；null = 本次下载失败。
  final Map<String, List<int>?> results;
  final hits = <String>[];
  final _ctrls = <String, StreamController<McDownloadProgress>>{};

  @override
  Stream<McDownloadProgress> watch(String id) {
    return _ctrls
        .putIfAbsent(id, StreamController<McDownloadProgress>.broadcast)
        .stream;
  }

  @override
  Future<void> start(McDownloadRequest request) async {
    hits.add(request.url);
    final ctrl = _ctrls.putIfAbsent(
        request.id, StreamController<McDownloadProgress>.broadcast);
    final bytes = results[request.url];
    if (bytes == null) {
      ctrl.add(McDownloadProgress(
          id: request.id, receivedBytes: 0, error: '404 Not Found'));
      return;
    }
    await File(request.savePath).writeAsBytes(bytes);
    ctrl.add(McDownloadProgress(
        id: request.id,
        receivedBytes: bytes.length,
        totalBytes: bytes.length,
        done: true));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('networkTypeFor：不许蜂窝 → 仅 Wi-Fi；允许 → 任意联网', () {
    expect(OfflineBackgroundScheduler.networkTypeFor(false),
        NetworkType.unmetered);
    expect(OfflineBackgroundScheduler.networkTypeFor(true),
        NetworkType.connected);
  });

  group('resumePendingDownloads', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mc_bgdl_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<void> seedTasks(List<Map<String, String>> tasks) async {
      SharedPreferences.setMockInitialValues({
        offlineBackgroundTasksKey: jsonEncode(tasks),
      });
    }

    Future<bool> resume(FakeFallbackManager manager) =>
        resumePendingDownloads(downloader: manager);

    test('无任务表 → true，不启动任何下载', () async {
      SharedPreferences.setMockInitialValues({});
      final manager = FakeFallbackManager({});
      expect(await resume(manager), isTrue);
      expect(manager.hits, isEmpty);
    });

    test('未下完的任务续跑到落盘 → true', () async {
      final savePath = '${tempDir.path}/ok.mp4';
      await seedTasks([
        {
          'id': 't1',
          'url': 'https://example.com/ok.mp4',
          'savePath': savePath,
        },
      ]);
      final manager = FakeFallbackManager({
        'https://example.com/ok.mp4': utf8.encode('hello-offline'),
      });
      expect(await resume(manager), isTrue);
      expect(manager.hits, ['https://example.com/ok.mp4']);
      expect(await File(savePath).readAsString(), 'hello-offline');
    });

    test('已落盘的任务跳过，不启动下载', () async {
      final savePath = '${tempDir.path}/done.mp4';
      await File(savePath).writeAsString('already-here');
      await seedTasks([
        {
          'id': 't1',
          'url': 'https://example.com/ok.mp4',
          'savePath': savePath,
        },
      ]);
      final manager = FakeFallbackManager({
        'https://example.com/ok.mp4': utf8.encode('hello-offline'),
      });
      expect(await resume(manager), isTrue);
      expect(manager.hits, isEmpty);
      expect(await File(savePath).readAsString(), 'already-here');
    });

    test('下载失败 → false（系统按退避重试）', () async {
      final savePath = '${tempDir.path}/missing.mp4';
      await seedTasks([
        {
          'id': 't1',
          'url': 'https://example.com/missing.mp4',
          'savePath': savePath,
        },
      ]);
      final manager =
          FakeFallbackManager({'https://example.com/missing.mp4': null});
      expect(await resume(manager), isFalse);
      expect(await File(savePath).exists(), isFalse);
    });

    test('一个成功一个失败 → false，但成功的照常落盘', () async {
      final okPath = '${tempDir.path}/ok.mp4';
      final badPath = '${tempDir.path}/bad.mp4';
      await seedTasks([
        {
          'id': 't1',
          'url': 'https://example.com/ok.mp4',
          'savePath': okPath,
        },
        {
          'id': 't2',
          'url': 'https://example.com/missing.mp4',
          'savePath': badPath,
        },
      ]);
      final manager = FakeFallbackManager({
        'https://example.com/ok.mp4': utf8.encode('hello-offline'),
        'https://example.com/missing.mp4': null,
      });
      expect(await resume(manager), isFalse);
      expect(await File(okPath).exists(), isTrue);
      expect(await File(badPath).exists(), isFalse);
    });
  });
}
