import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dlna_discovery.dart';
import 'dlna_renderer.dart';

/// 投屏状态（DLNA 直连；对齐 trim_cast_plugin 面向用户的能力面）。
class CastState {
  const CastState({
    this.devices = const [],
    this.searching = false,
    this.activeDevice,
    this.casting = false,
    this.lastError,
  });

  final List<DlnaDevice> devices;
  final bool searching;

  /// 当前投屏目标（选中但未起播也算）。
  final DlnaDevice? activeDevice;

  /// 已向目标推送 SetAVTransportURI+Play。
  final bool casting;
  final String? lastError;

  CastState copyWith({
    List<DlnaDevice>? devices,
    bool? searching,
    DlnaDevice? activeDevice,
    bool clearActive = false,
    bool? casting,
    String? lastError,
    bool clearError = false,
  }) {
    return CastState(
      devices: devices ?? this.devices,
      searching: searching ?? this.searching,
      activeDevice: clearActive ? null : (activeDevice ?? this.activeDevice),
      casting: casting ?? this.casting,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

class CastController extends Notifier<CastState> {
  DlnaRenderer? _renderer;

  @override
  CastState build() => const CastState();

  Future<void> search() async {
    state = state.copyWith(searching: true, clearError: true);
    try {
      final devices = await DlnaDiscovery.search();
      state = state.copyWith(devices: devices, searching: false);
    } catch (e) {
      state = state.copyWith(
        searching: false,
        lastError: '搜索失败：$e',
      );
    }
  }

  /// 推流到设备：先选目标，再 setUriAndPlay。
  Future<void> castTo(DlnaDevice device, String url, {String? title}) async {
    state = state.copyWith(activeDevice: device, clearError: true);
    try {
      _renderer = DlnaRenderer(device);
      await _renderer!.setUriAndPlay(url, title: title);
      state = state.copyWith(casting: true);
    } catch (e) {
      state = state.copyWith(casting: false, lastError: '投屏失败：$e');
    }
  }

  Future<void> pause() async => _renderer?.pause();
  Future<void> resume() async => _renderer?.play();
  Future<void> stop() async {
    await _renderer?.stop();
    state = state.copyWith(casting: false);
  }

  void disconnect() {
    _renderer?.stop();
    _renderer = null;
    state = state.copyWith(casting: false, clearActive: true);
  }
}

final castControllerProvider =
    NotifierProvider<CastController, CastState>(CastController.new);
