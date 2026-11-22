// P2：画质/倍速记忆（`QualityMemory` / `SpeedMemory`，移植自安卓
// `android-core/playback/PlayerPreferences.kt`）+ 网络分类 +
// `RememberedChoices.notice`。全部走内存 store，不碰 SharedPreferences。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/player/playback_memory.dart';

void main() {
  group('PlaybackNetwork.ofHost', () {
    test('私网 IP 与 localhost 判局域网', () {
      expect(PlaybackNetwork.ofHost('192.168.1.10'), PlaybackNetwork.home);
      expect(PlaybackNetwork.ofHost('10.0.0.5'), PlaybackNetwork.home);
      expect(PlaybackNetwork.ofHost('172.16.9.9'), PlaybackNetwork.home);
      expect(PlaybackNetwork.ofHost('172.31.255.1'), PlaybackNetwork.home);
      expect(PlaybackNetwork.ofHost('127.0.0.1'), PlaybackNetwork.home);
      expect(PlaybackNetwork.ofHost('localhost'), PlaybackNetwork.home);
      expect(PlaybackNetwork.ofHost('::1'), PlaybackNetwork.home);
    });

    test('公网 IP 与域名判外网；空判 unknown', () {
      expect(PlaybackNetwork.ofHost('172.32.0.1'), PlaybackNetwork.away);
      expect(PlaybackNetwork.ofHost('8.8.8.8'), PlaybackNetwork.away);
      expect(PlaybackNetwork.ofHost('example.com'), PlaybackNetwork.away);
      expect(PlaybackNetwork.ofHost(null), PlaybackNetwork.unknown);
      expect(PlaybackNetwork.ofHost(''), PlaybackNetwork.unknown);
    });

    test('ofServerUrl 从基址取 host', () {
      expect(PlaybackNetwork.ofServerUrl('http://192.168.1.2:8080'),
          PlaybackNetwork.home);
      expect(PlaybackNetwork.ofServerUrl('https://mc.example.com'),
          PlaybackNetwork.away);
      expect(PlaybackNetwork.ofServerUrl(null), PlaybackNetwork.unknown);
    });
  });

  group('QualityMemory', () {
    test('按影片 × 网络记忆；选回原画删掉记忆', () async {
      final mem = PlaybackMemories.inMemory();
      await mem.quality.remember(1080, 123, PlaybackNetwork.home);
      await mem.quality.remember(720, 123, PlaybackNetwork.away);
      expect(mem.quality.quality(123, PlaybackNetwork.home), 1080);
      expect(mem.quality.quality(123, PlaybackNetwork.away), 720);
      expect(mem.quality.quality(999, PlaybackNetwork.home), isNull);
      await mem.quality.remember(null, 123, PlaybackNetwork.home);
      expect(mem.quality.quality(123, PlaybackNetwork.home), isNull);
      expect(mem.quality.quality(123, PlaybackNetwork.away), 720);
    });

    test('非法档位视为无效', () async {
      final mem = PlaybackMemories.inMemory();
      await mem.quality.remember(999, 1, PlaybackNetwork.home);
      expect(mem.quality.quality(1, PlaybackNetwork.home), isNull);
    });

    test('超 300 条按最久没用先丢', () async {
      var now = 0;
      final mem = PlaybackMemories.inMemory(nowMs: () => ++now);
      for (var i = 0; i < 301; i++) {
        await mem.quality.remember(720, i, PlaybackNetwork.home);
      }
      expect(mem.quality.quality(0, PlaybackNetwork.home), isNull);
      expect(mem.quality.quality(300, PlaybackNetwork.home), 720);
    });

    test('损坏的存储 JSON 不抛错，当作无记忆', () {
      final store = MemoryStringStore();
      unawaited(store.write(QualityMemory.storeKey, '{not json'));
      final q = QualityMemory(store);
      expect(q.quality(1, PlaybackNetwork.home), isNull);
    });
  });

  group('SpeedMemory', () {
    test('只记非正常速度；选回常速删掉', () async {
      final mem = PlaybackMemories.inMemory();
      await mem.speed.remember(1.5, 42);
      expect(mem.speed.speed(42), 1.5);
      await mem.speed.remember(1.0, 42);
      expect(mem.speed.speed(42), isNull);
    });

    test('非法档位视为无效', () async {
      final mem = PlaybackMemories.inMemory();
      await mem.speed.remember(3.0, 7);
      expect(mem.speed.speed(7), isNull);
    });
  });

  group('RememberedChoices.notice', () {
    test('全部默认返回 null；有记忆时拼提示', () {
      expect(RememberedChoices.notice(), isNull);
      expect(
        RememberedChoices.notice(
            quality: 1080, network: PlaybackNetwork.home, speed: 1.5),
        '已沿用上次的选择：画质 1080p（局域网）、倍速 1.5×',
      );
      expect(
        RememberedChoices.notice(audio: '国语', subtitle: '简体中文'),
        '已沿用上次的选择：音轨 国语、字幕 简体中文',
      );
    });
  });
}
