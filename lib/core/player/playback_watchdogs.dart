import 'dart:math' as math;

/// 卡顿归因判定（对齐 `PlaybackWatchdogs.swift` 的 `StallWatch`）：
/// - `ok`：正常播放或慢网正常缓冲中；
/// - `nudge`：缓冲 ≥ 3s 但播放头不动，先微推 `+100ms` 踢活解码管线（最多 2 次）；
/// - `decodeStalled`：缓冲充足却持续卡死 8 秒，判为解码失败；
/// - `dead`：缓冲见底且连续 15s（直连）/ 45s（转码）0 字节无数据，判为死链重连。
enum StallVerdict { ok, nudge, decodeStalled, dead }

class StallWatch {
  static const int decodeStallSeconds = 8;
  static const double decodeStallMinBuffer = 3.0;
  static const int serverDeadSeconds = 45;
  static const int directDeadSeconds = 15;
  static const int nudgeAtSeconds = 3;
  static const int maxNudges = 2;
  static const double nudgeStepSeconds = 0.1;

  double? _lastTime;
  int _stalledFor = 0;
  int _silentFor = 0;
  int _nudges = 0;
  int _sinceNudge = 99;
  bool _everAdvanced = false;

  void reset() {
    _lastTime = null;
    _stalledFor = 0;
    _silentFor = 0;
    _nudges = 0;
    _sinceNudge = 99;
    _everAdvanced = false;
  }

  /// 每秒调用一次。
  StallVerdict sample({
    required double timeSeconds,
    required double bufferedAheadSeconds,
    required bool paused,
    required bool ended,
    required bool seeking,
    required bool receiving,
    required int deadLimitSeconds,
  }) {
    final prev = _lastTime;
    final advanced = prev != null && timeSeconds > prev + 0.01;
    if (advanced && !seeking && (timeSeconds - prev) < 5.0) {
      _everAdvanced = true;
    }
    _lastTime = timeSeconds;
    _sinceNudge += 1;

    if (paused || ended || seeking || advanced) {
      _stalledFor = 0;
      _silentFor = 0;
      if (advanced && _sinceNudge > 3) {
        _nudges = 0;
      }
      return StallVerdict.ok;
    }

    _stalledFor += 1;
    if (bufferedAheadSeconds >= decodeStallMinBuffer) {
      _silentFor = 0;
      if (_stalledFor >= decodeStallSeconds) {
        _stalledFor = 0;
        _nudges = 0;
        return StallVerdict.decodeStalled;
      }
      if (_everAdvanced &&
          _stalledFor >= nudgeAtSeconds &&
          _nudges < maxNudges) {
        _nudges += 1;
        _sinceNudge = 0;
        _stalledFor = 0;
        return StallVerdict.nudge;
      }
      return StallVerdict.ok;
    }

    _silentFor = receiving ? 0 : _silentFor + 1;
    if (_silentFor >= deadLimitSeconds) {
      _stalledFor = 0;
      _silentFor = 0;
      _nudges = 0;
      return StallVerdict.dead;
    }
    return StallVerdict.ok;
  }

  static String describeReason(StallVerdict verdict, int deadLimitSeconds) {
    if (verdict == StallVerdict.decodeStalled) {
      return '画面解码停滞超过 $decodeStallSeconds 秒';
    }
    return deadLimitSeconds < serverDeadSeconds
        ? '直连取流中断超过 $deadLimitSeconds 秒无响应'
        : '转码流中断超过 $deadLimitSeconds 秒无数据';
  }
}

/// 断线重连指数退避：`[2, 4, 8, 15, 15, 15]` 秒。
class ReconnectBackoff {
  static const List<int> delaysSeconds = [2, 4, 8, 15, 15, 15];

  int _index = 0;

  int? nextDelaySeconds() {
    if (_index >= delaysSeconds.length) return null;
    final d = delaysSeconds[_index];
    _index += 1;
    return d;
  }

  int get attemptCount => _index;

  void reset() => _index = 0;
}

/// 同档重开额度（防止非网络错误伪装成网络失败时死循环）。
class NetworkRestartBudget {
  static const int limit = 2;

  int _consecutive = 0;
  int get consecutive => _consecutive;

  bool allowRestart() {
    if (_consecutive >= limit) return false;
    _consecutive += 1;
    return true;
  }

  void reachedPlaying() => _consecutive = 0;
  void reset() => _consecutive = 0;
}

/// 提前 EOF 拦截器（对齐 `PrematureEndGuard`）：
/// 当距离片尾仍超过 30 秒却报流结束时，视作断流并最多原位重试 3 次，
/// 避免错误标为已看或误跳下一集。
class PrematureEndGuard {
  static const int marginMs = 30000;
  static const int maxRetries = 3;

  int? _resumedAtMs;
  int _retries = 0;

  int get retryCount => _retries;

  bool shouldResume({
    required int positionMs,
    required int? durationMs,
  }) {
    if (durationMs == null || durationMs - positionMs <= marginMs) {
      return false;
    }
    if (_retries >= maxRetries) return false;
    if (_resumedAtMs != null && (positionMs - _resumedAtMs!).abs() < marginMs) {
      // 重开后在原地附近立刻再次 EOF，说明文件真实长度偏短，放行结束
      return false;
    }
    _resumedAtMs = positionMs;
    _retries += 1;
    return true;
  }

  void reset() {
    _resumedAtMs = null;
    _retries = 0;
  }
}

/// 2 秒滑动窗口加载速率计（对齐 `LoadingSpeedMeter`）。
class LoadingSpeedMeter {
  final List<(DateTime, double)> _samples = [];

  void reset() => _samples.clear();

  /// 喂入引擎估算的实时 bps；返回 2 秒平滑平均 bps。
  double? sample(double? instantBps, {DateTime? now}) {
    final t = now ?? DateTime.now();
    _samples.removeWhere((e) => t.difference(e.$1).inMilliseconds > 2200);
    if (instantBps != null && instantBps.isFinite && instantBps >= 0) {
      _samples.add((t, instantBps));
    }
    if (_samples.isEmpty) return null;
    var sum = 0.0;
    for (final s in _samples) {
      sum += s.$2;
    }
    return sum / _samples.length;
  }

  static String? formatBandwidth(double? bps) {
    if (bps == null || !bps.isFinite || bps <= 0) return null;
    final bytesPerSec = bps / 8.0;
    final mb = bytesPerSec / (1024 * 1024);
    if (mb >= 1.0) return '${mb.toStringAsFixed(1)} MB/s';
    final kb = bytesPerSec / 1024.0;
    if (kb < 1.0) return '0 KB/s';
    return '${kb.round()} KB/s';
  }

  static String? formatLoadingSpeed(double? bps) {
    if (bps == null || !bps.isFinite || bps < 0) return null;
    return formatBandwidth(bps) ?? '0 KB/s';
  }
}

/// 弱网换低画质提议数据。
class QualityOffer {
  const QualityOffer({
    required this.measuredBps,
    required this.requiredBps,
    required this.maxHeight,
  });

  final double measuredBps;
  final double requiredBps;
  final int maxHeight;

  String get tier => '${maxHeight}p';
}

class _StallWindowEntry {
  _StallWindowEntry({required this.startSec});

  final int startSec;
  int seconds = 0;
  final List<double> speeds = [];
}

/// 弱网画质降档建议器（只提示不强切，对齐 `QualitySuggestion`）：
/// - 单次缓冲等待满 8 秒，或 5 分钟内发生 ≥ 2 次非宽限期卡顿；
/// - 实测吞吐低于码率的 90% 时给出推荐档位（每个单元最多提示一次）。
class QualitySuggestion {
  static const int graceSeconds = 10;
  static const int windowSeconds = 300;
  static const int minStalls = 2;
  static const int longWaitSeconds = 8;
  static const double linkMargin = 0.9;

  int _clock = 0;
  int _graceUntil = graceSeconds;
  final List<_StallWindowEntry> _stalls = [];
  bool _stalling = false;
  int _waitSeconds = 0;
  final List<double> _waitSpeeds = [];
  bool _offered = false;

  int get waitSeconds => _waitSeconds;
  bool get offered => _offered;

  void reset() {
    _clock = 0;
    _graceUntil = graceSeconds;
    _stalls.clear();
    _stalling = false;
    _waitSeconds = 0;
    _waitSpeeds.clear();
    _offered = false;
  }

  void restartGrace() {
    _graceUntil = _clock + graceSeconds;
    _stalling = false;
    _waitSeconds = 0;
    _waitSpeeds.clear();
  }

  void tick({
    required bool stalled,
    bool seeking = false,
    double? loadingBps,
  }) {
    _clock += 1;
    _stalls.removeWhere((s) => s.startSec + s.seconds < _clock - windowSeconds);
    final validSpeed =
        (loadingBps != null && loadingBps.isFinite && loadingBps > 0)
            ? loadingBps
            : null;
    if (stalled) {
      _waitSeconds += 1;
      if (validSpeed != null) _waitSpeeds.add(validSpeed);
    } else {
      _waitSeconds = 0;
      _waitSpeeds.clear();
    }

    if (!stalled || seeking || _clock <= _graceUntil) {
      _stalling = false;
      return;
    }

    if (!_stalling) {
      _stalls.add(_StallWindowEntry(startSec: _clock));
      _stalling = true;
    }
    _stalls.last.seconds += 1;
    if (validSpeed != null) _stalls.last.speeds.add(validSpeed);
  }

  QualityOffer? offer({
    required double? streamBitrateBps,
    required int? currentHeight,
  }) {
    if (_offered || streamBitrateBps == null || streamBitrateBps <= 0) {
      return null;
    }
    double? measured;
    if (_waitSeconds >= longWaitSeconds) {
      if (_waitSpeeds.isEmpty) return null;
      measured = _waitSpeeds.reduce(math.max);
    } else if (_stalls.length >= minStalls) {
      final speeds = [for (final s in _stalls) ...s.speeds]..sort();
      if (speeds.isEmpty) return null;
      measured = speeds[speeds.length ~/ 2];
    } else {
      return null;
    }

    if (measured >= streamBitrateBps * linkMargin) return null;
    final rec = recommendedHeight(bps: measured, belowHeight: currentHeight);
    if (rec == null) return null;
    _offered = true;
    return QualityOffer(
      measuredBps: measured,
      requiredBps: streamBitrateBps,
      maxHeight: rec,
    );
  }

  static int? recommendedHeight({
    required double bps,
    required int? belowHeight,
  }) {
    const ladder = <(int, double)>[
      (1080, 6000000),
      (720, 3000000),
      (480, 1500000),
    ];
    final lower = ladder
        .where((rung) => belowHeight == null || rung.$1 < belowHeight)
        .toList();
    if (lower.isEmpty) return null;
    for (final rung in lower) {
      if (rung.$2 <= bps * 0.8) return rung.$1;
    }
    return lower.last.$1;
  }
}
