import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/player/watchdogs.dart';

void main() {
  test('ReconnectBackoff：2/4/8/15/15/15 秒退避，约 1 分钟后耗尽', () {
    final backoff = ReconnectBackoff();
    expect(ReconnectBackoff.delaysS, [2, 4, 8, 15, 15, 15]);
    expect(backoff.nextDelayMs(), 2000);
    expect(backoff.nextDelayMs(), 4000);
    expect(backoff.nextDelayMs(), 8000);
    expect(backoff.nextDelayMs(), 15000);
    expect(backoff.nextDelayMs(), 15000);
    expect(backoff.nextDelayMs(), 15000);
    expect(backoff.nextDelayMs(), isNull);
    backoff.reset();
    expect(backoff.nextDelayMs(), 2000);
  });

  test('StallWatch：播放头前进 / 暂停 / seek 中都不算停顿', () {
    final watch = StallWatch();
    // 前进
    expect(
        watch.sample(
            time: 0, bufferedAhead: 10, paused: false, ended: false,
            seeking: false, receiving: true, deadLimit: 15),
        StallVerdict.ok);
    expect(
        watch.sample(
            time: 1, bufferedAhead: 10, paused: false, ended: false,
            seeking: false, receiving: true, deadLimit: 15),
        StallVerdict.ok);
    // 暂停清空计数
    expect(
        watch.sample(
            time: 1, bufferedAhead: 10, paused: true, ended: false,
            seeking: false, receiving: false, deadLimit: 15),
        StallVerdict.ok);
    // seek 中不算
    expect(
        watch.sample(
            time: 30, bufferedAhead: 10, paused: false, ended: false,
            seeking: true, receiving: false, deadLimit: 15),
        StallVerdict.ok);
  });

  test('StallWatch：有缓冲却不动，先推两把，8 秒判解码卡死', () {
    final watch = StallWatch();
    // 先播起来（小步前进），否则起播预滚阶段不推。
    watch.sample(
        time: 0, bufferedAhead: 10, paused: false, ended: false,
        seeking: false, receiving: true, deadLimit: 15);
    watch.sample(
        time: 1, bufferedAhead: 10, paused: false, ended: false,
        seeking: false, receiving: true, deadLimit: 15);
    final verdicts = <StallVerdict>[];
    for (var t = 2; t < 22; t++) {
      verdicts.add(watch.sample(
          time: 1, bufferedAhead: 10, paused: false, ended: false,
          seeking: false, receiving: true, deadLimit: 15));
    }
    // 先推两把（第 3、6 个停顿样本），8 秒时判解码卡死；
    // 判卡死后计数清零，下一轮又会重新推，所以只统计第一次卡死之前的推。
    final firstStalled = verdicts.indexOf(StallVerdict.decodeStalled);
    expect(firstStalled, isNonNegative);
    expect(
        verdicts.sublist(0, firstStalled)
            .where((v) => v == StallVerdict.nudge).length,
        2);
    // 第一个卡死样本出现在第 14 个停顿样本（3+3+8 的计数叠加）。
    expect(firstStalled, 13);
  });

  test('StallWatch：缓冲见底但字节在进来 = 线路慢，不算失败', () {
    final watch = StallWatch();
    watch.sample(
        time: 0, bufferedAhead: 0, paused: false, ended: false,
        seeking: false, receiving: true, deadLimit: 15);
    for (var i = 0; i < 30; i++) {
      expect(
          watch.sample(
              time: 0, bufferedAhead: 0, paused: false, ended: false,
              seeking: false, receiving: true, deadLimit: 15),
          StallVerdict.ok);
    }
  });

  test('StallWatch：缓冲见底且连续 15 秒没字节 = 断线', () {
    final watch = StallWatch();
    watch.sample(
        time: 0, bufferedAhead: 0, paused: false, ended: false,
        seeking: false, receiving: false, deadLimit: 15);
    StallVerdict last = StallVerdict.ok;
    for (var i = 0; i < 14; i++) {
      last = watch.sample(
          time: 0, bufferedAhead: 0, paused: false, ended: false,
          seeking: false, receiving: false, deadLimit: 15);
    }
    expect(last, StallVerdict.dead);
  });

  test('StallWatch.reason：解码卡死 / 直出断线 / 服务端流断线三档文案', () {
    expect(
        StallWatch.reason(StallVerdict.decodeStalled, 15),
        contains('8 秒'));
    expect(
        StallWatch.reason(StallVerdict.dead, StallWatch.directDeadSeconds),
        contains('15 秒'));
    expect(
        StallWatch.reason(StallVerdict.dead, StallWatch.serverDeadSeconds),
        contains('45 秒'));
  });

  test('NetworkRestartBudget：连续重开 2 次，第 3 次拒绝；出画后清零', () {
    final budget = NetworkRestartBudget();
    expect(budget.allowRestart(), isTrue);
    expect(budget.allowRestart(), isTrue);
    expect(budget.allowRestart(), isFalse);
    budget.reachedPlaying();
    expect(budget.allowRestart(), isTrue);
  });

  test('PrematureEndGuard：离片尾远报播完 = 断流重开；原地再报 = 真结尾', () {
    final guard = PrematureEndGuard();
    expect(guard.shouldResume(60000, 600000), isTrue);
    // 同一位置附近又报播完：不再重开。
    expect(guard.shouldResume(61000, 600000), isFalse);
    // 离片尾 30 秒内：真结尾。
    expect(guard.shouldResume(580000, 600000), isFalse);
    // 片长未知：不重开。
    expect(guard.shouldResume(60000, null), isFalse);
    guard.reset();
    expect(guard.shouldResume(60000, 600000), isTrue);
  });

  test('NativeRetryBudget：同一集 3 分钟内只重开一次', () {
    final budget = NativeRetryBudget();
    expect(budget.allowRetry(1000000), isTrue);
    expect(budget.allowRetry(1000000 + 60000), isFalse);
    expect(budget.allowRetry(1000000 + 180000), isTrue);
  });

  test('FrameDropTracker：11 个样本构成 10 秒窗口，掉帧率 ≥10% 才报', () {
    final tracker = FrameDropTracker();
    // 前 10 个样本：没到判定条件。
    for (var i = 0; i < 10; i++) {
      expect(tracker.sample(i * 10, i * 100), isNull);
    }
    // 第 11 个样本：窗口掉帧 (100-0)/(1000-0) = 10%。
    expect(tracker.sample(100, 1000), closeTo(0.1, 0.0001));
    // 计数变小 = 引擎换了流，窗口作废。
    expect(tracker.sample(0, 0), isNull);
    tracker.reset();
    expect(tracker.sample(0, 0), isNull);
  });
}
