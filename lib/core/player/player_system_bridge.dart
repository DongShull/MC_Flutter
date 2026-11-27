import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 锁屏 / 耳机线控 / 控制中心下发的远程控制事件。
class PlayerRemoteCommand {
  const PlayerRemoteCommand({
    required this.command,
    this.positionMs,
  });

  /// `play` | `pause` | `togglePlayPause` | `nextTrack` | `previousTrack` |
  /// `skipForward` | `skipBackward` | `changePosition`
  final String command;
  final int? positionMs;
}

/// 播放器系统能力桥接（`MethodChannel('mc/player/system')`）：
/// - 屏幕亮度：`UIScreen.main.brightness` 读写与退出恢复；
/// - 系统音量：`MPVolumeView` 写入 + `AVAudioSession.outputVolume` KVO 硬件音量键监听；
/// - 屏幕方向：`UIWindowScene.requestGeometryUpdate` + `AppDelegate.supportedOrientationMask`；
/// - AirPlay：`AVRoutePickerView` 隔空播放路由选择；
/// - Now Playing：`MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`。
///
/// 非 iOS 平台或测试环境自动优雅降级，绝不抛出未捕获 `MissingPluginException`。
class PlayerSystemBridge {
  PlayerSystemBridge._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final PlayerSystemBridge instance = PlayerSystemBridge._();

  static const MethodChannel _channel = MethodChannel('mc/player/system');

  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();
  final StreamController<PlayerRemoteCommand> _remoteController =
      StreamController<PlayerRemoteCommand>.broadcast();

  bool _nativeBrightnessAvailable = !kIsWeb && Platform.isIOS;
  bool _nativeVolumeAvailable = !kIsWeb && Platform.isIOS;

  bool get supportsNativeBrightness => _nativeBrightnessAvailable;
  bool get supportsNativeVolume => _nativeVolumeAvailable;
  bool get supportsAirPlay => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  /// 硬件音量键 / 系统音量变化流（0.0–1.0）。
  Stream<double> get onVolumeChanged => _volumeController.stream;

  /// 锁屏控制中心 / 耳机线控命令流。
  Stream<PlayerRemoteCommand> get onRemoteCommand => _remoteController.stream;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    final args = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : const <String, dynamic>{};
    switch (call.method) {
      case 'onVolumeChanged':
        final v = (args['volume'] as num?)?.toDouble();
        if (v != null && !_volumeController.isClosed) {
          _volumeController.add(v.clamp(0.0, 1.0));
        }
      case 'onRemoteCommand':
        final rawCmd = (args['command'] ?? '').toString();
        final normalized = rawCmd == 'seek' ? 'changePosition' : rawCmd;
        if (normalized.isNotEmpty && !_remoteController.isClosed) {
          _remoteController.add(
            PlayerRemoteCommand(
              command: normalized,
              positionMs: (args['positionMs'] as num?)?.toInt(),
            ),
          );
        }
    }
    return null;
  }

  Future<double?> getBrightness() async {
    if (kIsWeb || !Platform.isIOS) return null;
    try {
      final res = await _channel.invokeMethod<dynamic>('getBrightness');
      final v = (res as num?)?.toDouble();
      if (v != null) {
        _nativeBrightnessAvailable = true;
        return v.clamp(0.0, 1.0);
      }
      return null;
    } on MissingPluginException {
      _nativeBrightnessAvailable = false;
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 设置真实屏幕亮度（0.0–1.0）；返回 true 表示已由系统原生生效。
  Future<bool> setBrightness(double value) async {
    if (kIsWeb || !Platform.isIOS) {
      _nativeBrightnessAvailable = false;
      return false;
    }
    try {
      await _channel.invokeMethod<dynamic>(
        'setBrightness',
        <String, dynamic>{'value': value.clamp(0.0, 1.0)},
      );
      _nativeBrightnessAvailable = true;
      return true;
    } on MissingPluginException {
      _nativeBrightnessAvailable = false;
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> restoreBrightness() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _channel.invokeMethod<dynamic>('restoreBrightness');
    } on MissingPluginException {
      // ignore on unsupported platforms / tests
    } on PlatformException {
      // ignore
    }
  }

  Future<double?> getVolume() async {
    if (kIsWeb || !Platform.isIOS) return null;
    try {
      final res = await _channel.invokeMethod<dynamic>('getVolume');
      final v = (res as num?)?.toDouble();
      if (v != null) {
        _nativeVolumeAvailable = true;
        return v.clamp(0.0, 1.0);
      }
      return null;
    } on MissingPluginException {
      _nativeVolumeAvailable = false;
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 调节系统音量（0.0–1.0）；返回 true 表示已由系统原生生效。
  Future<bool> setVolume(double value) async {
    if (kIsWeb || !Platform.isIOS) {
      _nativeVolumeAvailable = false;
      return false;
    }
    try {
      await _channel.invokeMethod<dynamic>(
        'setVolume',
        <String, dynamic>{'value': value.clamp(0.0, 1.0)},
      );
      _nativeVolumeAvailable = true;
      return true;
    } on MissingPluginException {
      _nativeVolumeAvailable = false;
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 设置方向掩码：`portrait` | `landscape` | `landscapeLeft` | `landscapeRight` | `all`。
  /// 退出播放器时一律传 `'all'`（绝不在 iPad / 桌面端强锁竖屏）。
  Future<void> setOrientationMask(String mask) async {
    final normalized = mask.trim().toLowerCase();
    final List<DeviceOrientation> flutterOrientations = switch (normalized) {
      'portrait' => const [DeviceOrientation.portraitUp],
      'landscape' => const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      'landscapeleft' || 'landscape_left' => const [
          DeviceOrientation.landscapeLeft,
        ],
      'landscaperight' || 'landscape_right' => const [
          DeviceOrientation.landscapeRight,
        ],
      _ => const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
          DeviceOrientation.portraitDown,
        ],
    };

    if (!kIsWeb && Platform.isIOS) {
      try {
        await _channel.invokeMethod<dynamic>(
          'setOrientationMask',
          <String, dynamic>{'mode': normalized},
        );
      } on MissingPluginException {
        // fall through to SystemChrome
      } on PlatformException {
        // fall through
      }
    }

    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      try {
        await SystemChrome.setPreferredOrientations(flutterOrientations);
      } catch (_) {}
    }
  }

  /// 弹出原生 AirPlay 隔空播放路由选择器（iOS `AVRoutePickerView`）。
  Future<bool> showAirPlayPicker() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) return false;
    try {
      await _channel.invokeMethod<dynamic>('showAirPlayPicker');
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> updateNowPlaying({
    required String title,
    String? subtitle,
    String? artworkUrl,
    Map<String, String>? artworkHeaders,
    int? positionMs,
    int? durationMs,
    bool isPlaying = true,
    double rate = 1.0,
    bool hasNext = false,
    bool hasPrevious = false,
  }) async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) return;
    try {
      await _channel.invokeMethod<dynamic>(
        'updateNowPlaying',
        <String, dynamic>{
          'title': title,
          if (subtitle != null && subtitle.isNotEmpty) 'subtitle': subtitle,
          if (artworkUrl != null && artworkUrl.isNotEmpty)
            'artworkUrl': artworkUrl,
          if (artworkHeaders != null && artworkHeaders.isNotEmpty)
            'artworkHeaders': artworkHeaders,
          if (positionMs != null) 'positionMs': positionMs,
          if (durationMs != null && durationMs > 0) 'durationMs': durationMs,
          'isPlaying': isPlaying,
          'rate': rate,
          'hasNext': hasNext,
          'hasPrevious': hasPrevious,
        },
      );
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }

  Future<void> updateNowPlayingPosition({
    required int positionMs,
    int? durationMs,
    bool isPlaying = true,
    double rate = 1.0,
  }) async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) return;
    try {
      await _channel.invokeMethod<dynamic>(
        'updateNowPlayingPosition',
        <String, dynamic>{
          'positionMs': positionMs,
          if (durationMs != null && durationMs > 0) 'durationMs': durationMs,
          'isPlaying': isPlaying,
          'rate': rate,
        },
      );
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }

  Future<void> clearNowPlaying() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) return;
    try {
      await _channel.invokeMethod<dynamic>('clearNowPlaying');
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }
}
