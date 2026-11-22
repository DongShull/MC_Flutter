/// 播放看门狗与重试预算（P3 纯 Dart 移植）。
///
/// 来源：安卓 `apps/android-core/playback/PlaybackWatchdogs.kt`
/// （阈值逐一照搬 Apple 端 `Shared/Player/PlaybackWatchdogs.swift`，
/// 它们又照搬 web `lib/player/*`）。常量与判定语义与 Kotlin 一致，
/// 单元测试见 `test/watchdogs_test.dart`。
///
/// 注意：这些类只做“判定”，不直接碰引擎。调用方（[PlayerController]）
/// 每秒喂一次样本，按 [StallWatch.Verdict] 处置；video_player 拿不到
/// 字节级“正在接收”信号，调用方用“缓冲末端是否在推进”近似
/// （见 `PlayerController` 注释）。
library;

/// 掉帧看门狗：视频直通期间持续掉帧超阈值，就把当前档报废、走降档回路。
/// 窗口 10 秒（每秒一个样本，要 11 个样本才构成 10 秒的首尾差）、
/// 窗口内至少 100 帧、比率 ≥ 10%。
/// 调用方在后台、seek、换会话时 [reset]，只在视频直通时喂样本。
/// video_player 不暴露掉帧计数，本类先备着（等后端选型能拿到读数再接）。
class FrameDropTracker {
  final List<(int dropped, int total)> _history = [];

  /// 喂一个累计样本；返回 null = 没到判定条件，否则是窗口掉帧率
  /// （≥ [ratio] 时应降档）。
  double? sample(int dropped, int total) {
    final last = _history.isEmpty ? null : _history.last;
    // 累计计数变小 = 引擎换了流，旧窗口作废。
    if (last != null && (total < last.$2 || dropped < last.$1)) {
      _history.clear();
    }
    _history.add((dropped, total));
    if (_history.length > windowSamples + 1) _history.removeAt(0);
    if (_history.length != windowSamples + 1) return null;
    final first = _history.first;
    final totalDelta = total - first.$2;
    if (totalDelta < minFrames) return null;
    return (dropped - first.$1) / totalDelta;
  }

  void reset() => _history.clear();

  static const windowSamples = 10;
  static const minFrames = 100;
  static const ratio = 0.1;
}

/// 卡顿归因：只看「播放头不动」会把处置完全不同的几件事混为一谈——
/// - **解码卡死**：缓冲里明明还有 ≥ 3 秒却不走：先原地推两把，
///   推不动 8 秒判「解不了」，走兜底阶梯；
/// - **线路慢**：前方缓冲见底，但字节还在进来：不是失败，一直等；
/// - **连接断了**：缓冲见底且连续十几秒一个字节都没收到：原文件 15 秒、
///   服务端流 45 秒（转码器赶片时本来就一阵阵没有字节）。
/// 每秒喂一次；暂停、结束、定位中、播放头前进都不算停顿。
class StallWatch {
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

  /// [receiving]：这一秒有没有收到字节；[deadLimit]：缓冲见底后连续
  /// 多少秒没字节算断线。
  StallVerdict sample({
    required double time,
    required double bufferedAhead,
    required bool paused,
    required bool ended,
    required bool seeking,
    required bool receiving,
    required int deadLimit,
  }) {
    final previous = _lastTime;
    final advanced = previous != null && time > previous;
    // 「真正播起来过」只认小步前进：起播定位、用户拖动是一次大跳，不算。
    // advanced 为真时 previous 已由流分析收窄为非空，直接用。
    if (advanced && !seeking && time - previous < 5) {
      _everAdvanced = true;
    }
    _lastTime = time;
    _sinceNudge += 1;
    if (paused || ended || seeking || advanced) {
      _stalledFor = 0;
      _silentFor = 0;
      // 只有远离上次推动的真实前进才算恢复——推动自己造成的播放头变化不作数。
      if (advanced && _sinceNudge > 3) _nudges = 0;
      return StallVerdict.ok;
    }
    _stalledFor += 1;
    if (bufferedAhead >= decodeStallMinBuffer) {
      _silentFor = 0;
      if (_stalledFor >= decodeStallSeconds) {
        _stalledFor = 0;
        _nudges = 0;
        return StallVerdict.decodeStalled;
      }
      // 有数据却不动：先推一把（起播预滚阶段不推，否则会把预滚冲掉重来）。
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
    // 缓冲见底：只看字节还在不在进来。在进来就是线路慢，不算失败。
    _silentFor = receiving ? 0 : _silentFor + 1;
    if (_silentFor >= deadLimit) {
      _stalledFor = 0;
      _silentFor = 0;
      _nudges = 0;
      return StallVerdict.dead;
    }
    return StallVerdict.ok;
  }

  static const decodeStallSeconds = 8;
  static const decodeStallMinBuffer = 3.0;
  static const serverDeadSeconds = 45;
  static const directDeadSeconds = 15;
  static const nudgeAtSeconds = 3;
  static const maxNudges = 2;

  /// 引擎 seek 的推动步长（毫秒）。
  static const nudgeStepMs = 100;

  static String reason(StallVerdict verdict, int deadLimit) {
    if (verdict == StallVerdict.decodeStalled) {
      return '播放停滞超过 $decodeStallSeconds 秒，这一档的码流播放器吃不下';
    }
    if (deadLimit < serverDeadSeconds) {
      return '连续 $deadLimit 秒没有收到数据——连接可能中断了';
    }
    return '连续 $deadLimit 秒没有收到服务端的数据——转码可能中断了';
  }
}

enum StallVerdict { ok, nudge, decodeStalled, dead }

/// 取流失败的同档重开预算：「网络」归因的失败走同档原地重开
/// （新会话 = 新 token），不降档。归因可能出错（某档格式放不了
/// 却报成网络错误），连续重开 [limit] 次都没能出画，就交给调用方
/// 按「这一档放不了」降档。
class NetworkRestartBudget {
  int consecutive = 0;

  bool allowRestart() {
    if (consecutive >= limit) return false;
    consecutive += 1;
    return true;
  }

  /// 真正放起来了：之前的失败不再算「连续」。
  void reachedPlaying() => consecutive = 0;

  void reset() => consecutive = 0;

  static const limit = 2;
}

/// 引擎报「播完」时离片尾还远：是取流断了，不是真播完，
/// 不能弹「即将播放下一集」。从当前位置重开；重开后在原地附近
/// 又报播完，就认定真到了结尾（片长信息本身可能不准），
/// 不在片尾反复重开。
class PrematureEndGuard {
  int? _resumedAtMs;

  bool shouldResume(int positionMs, int? durationMs) {
    if (durationMs == null || durationMs - positionMs <= marginMs) {
      return false;
    }
    final last = _resumedAtMs;
    if (last != null && (positionMs - last).abs() < marginMs) return false;
    _resumedAtMs = positionMs;
    return true;
  }

  void reset() => _resumedAtMs = null;

  static const marginMs = 30000;
}

/// 播放中重开时服务端暂时连不上（多半在重启）：按 2、4、8、15、15、15 秒
/// 退避重试，约 1 分钟仍不行才落错误页。
class ReconnectBackoff {
  int _index = 0;

  /// 下一次重试的等待毫秒；null = 退避耗尽，交给调用方落错误页。
  int? nextDelayMs() {
    if (_index >= delaysS.length) return null;
    return delaysS[_index++] * 1000;
  }

  void reset() => _index = 0;

  static const delaysS = [2, 4, 8, 15, 15, 15];
}

/// Exo 一时出问题（中途出错、楞住、持续掉帧）时先原位重开的额度：
/// 同一集 3 分钟内只重开一次，再失败才改走服务端流。
class NativeRetryBudget {
  int? _lastRetryAtMs;

  bool allowRetry(int nowMs) {
    final last = _lastRetryAtMs;
    if (last != null && nowMs - last < windowMs) return false;
    _lastRetryAtMs = nowMs;
    return true;
  }

  void reset() => _lastRetryAtMs = null;

  static const windowMs = 180000;
}
