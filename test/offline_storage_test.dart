import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/platform/download_channel.dart';
import 'package:mc_flutter/features/offline/state/offline_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mc/native/download');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    McDownloadChannel.resetForTest();
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    McDownloadChannel.resetForTest();
  });

  Future<OfflineController> makeController() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(offlineProvider.notifier);
    // build() 里也会 unawaited 调一次 refreshStorage；这里显式再调一次，
    // 等它落定后再断言（两次都走同一 mock，结果一致）。
    await controller.refreshStorage();
    await Future<void>.delayed(Duration.zero);
    return controller;
  }

  test('原生返回容量：storage 置位，原因清空', () async {
    messenger.setMockMethodCallHandler(channel,
        (MethodCall call) async {
      if (call.method == 'capacity') {
        return {'freeBytes': 100, 'totalBytes': 1000};
      }
      return null;
    });
    final controller = await makeController();
    expect(controller.state.storage?.availableBytes, 100);
    expect(controller.state.storage?.totalBytes, 1000);
    expect(controller.state.storageUnavailableReason, isNull);
  });

  test('原生返回 null：原因写“capacity 为 null”', () async {
    messenger.setMockMethodCallHandler(channel,
        (MethodCall call) async => null);
    final controller = await makeController();
    expect(controller.state.storage, isNull);
    expect(controller.state.storageUnavailableReason,
        '原生通道未返回容量（capacity 为 null）');
  });

  test('原生通道未实现：原因写 Dart 层没有磁盘容量 API', () async {
    // 不设 handler → MissingPluginException。
    final controller = await makeController();
    expect(controller.state.storage, isNull);
    expect(controller.state.storageUnavailableReason,
        '原生下载通道未实现：Dart 层没有磁盘容量 API');
  });

  test('原生抛错：原因写“容量读取失败”', () async {
    messenger.setMockMethodCallHandler(channel,
        (MethodCall call) async {
      throw PlatformException(code: 'boom', message: 'no disk');
    });
    final controller = await makeController();
    expect(controller.state.storage, isNull);
    expect(controller.state.storageUnavailableReason,
        startsWith('容量读取失败：'));
  });

  test('先失败后成功：原因被清掉', () async {
    messenger.setMockMethodCallHandler(channel,
        (MethodCall call) async => null);
    final controller = await makeController();
    expect(controller.state.storageUnavailableReason, isNotNull);

    McDownloadChannel.resetForTest();
    messenger.setMockMethodCallHandler(channel,
        (MethodCall call) async {
      if (call.method == 'capacity') {
        return {'freeBytes': 500, 'totalBytes': 1000};
      }
      return null;
    });
    await controller.refreshStorage();
    expect(controller.state.storage?.availableBytes, 500);
    expect(controller.state.storageUnavailableReason, isNull);
  });
}
