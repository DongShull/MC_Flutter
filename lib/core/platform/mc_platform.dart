import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// 平台目标探测（1:1 对齐飞牛 trim_base_plugin.HarmonyUtilApi 的设计）：
/// 飞牛在 Dart 侧运行时问原生「是不是鸿蒙 / 鸿蒙版本号」，同一份 Dart 业务代码
/// 不分叉，只有插件与产物分 ohos 分支。我们抄这个接口面。
enum McPlatformTarget { android, ios, harmony, other }

abstract final class McPlatform {
  static const _channel = MethodChannel('mc/base/platform');

  static McPlatformTarget? _cached;

  /// 当前平台目标。鸿蒙判定走原生通道（HarmonyOS 设备上 Android 体系的
  /// Platform.isAndroid 仍为 true，必须问原生），拿不到时降级为 android。
  static Future<McPlatformTarget> target() async {
    if (_cached != null) return _cached!;
    final tp = defaultTargetPlatform;
    if (tp == TargetPlatform.iOS) return _cached = McPlatformTarget.ios;
    if (tp != TargetPlatform.android) return _cached = McPlatformTarget.other;
    try {
      final isHarmony = await _channel.invokeMethod<bool>('isHarmonyOS');
      _cached = (isHarmony == true)
          ? McPlatformTarget.harmony
          : McPlatformTarget.android;
    } on MissingPluginException {
      // 原生侧尚未实现 mc/base/platform（鸿蒙壳未接入）：按 Android 走。
      _cached = McPlatformTarget.android;
    } catch (_) {
      _cached = McPlatformTarget.android;
    }
    return _cached!;
  }

  /// 鸿蒙版本号（HarmonyUtilApi.harmonyOSVersion 口径；非鸿蒙返回 null）。
  static Future<String?> harmonyOSVersion() async {
    if (await target() != McPlatformTarget.harmony) return null;
    try {
      return await _channel.invokeMethod<String>('harmonyOSVersion');
    } catch (_) {
      return null;
    }
  }

  /// 全局事件总线（trim_base_plugin.GlobalEventBus 对齐位）：
  /// 原生 → Dart 的广播（前后台切换/存储变更等），当前仅保留通道约定。
  static const eventBusSender = EventChannel('mc/base/global_events');
}
