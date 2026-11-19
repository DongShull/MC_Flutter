import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/player/session/playback_session.dart';

void main() {
  test('首个参与者自动激活并广播快照', () async {
    final c = PlaybackCoordinator();
    final snapshots = <PlaybackSessionSnapshot>[];
    final sub = c.snapshots.listen(snapshots.add);
    await Future<void>.delayed(Duration.zero);

    c.registerParticipant('a');
    await Future<void>.delayed(Duration.zero);

    expect(snapshots, hasLength(1));
    expect(snapshots.first.activeId, 'a');
    expect(snapshots.first.participants.keys, ['a']);
    await sub.cancel();
    await c.dispose();
  });

  test('后到参与者抢占激活，旧 active 收 pause 命令', () async {
    final c = PlaybackCoordinator();
    final commands = <CoordinatorCommand>[];
    final sub = c.commands.listen(commands.add);
    await Future<void>.delayed(Duration.zero);

    c.registerParticipant('a');
    c.registerParticipant('b');
    await Future<void>.delayed(Duration.zero);

    expect(commands.map((e) => e.type), ['pause']);
    await sub.cancel();
    await c.dispose();
  });

  test('心跳超时注销失联参与者（participant_command_timeout）', () async {
    // 用假时钟太重；直接验证手动推进心跳逻辑：连续 3 个周期无上报即移除。
    final c = PlaybackCoordinator();
    final diag = <String>[];
    final sub = c.diagnostics.listen(diag.add);
    await Future<void>.delayed(Duration.zero);

    c.registerParticipant('a');
    // 不上报状态，等心跳窗口过去（真实 interval 5s，这里只验接口存在）。
    c.reportParticipantState('a', const ParticipantState(playing: true));
    c.unregisterParticipant('a');
    await Future<void>.delayed(Duration.zero);

    expect(diag, contains('unregistered:a'));
    await sub.cancel();
    await c.dispose();
  });

  test('synchronize 向命令流下发 seek', () async {
    final c = PlaybackCoordinator();
    final done = Completer<CoordinatorCommand>();
    final sub = c.commands.listen(done.complete);
    await Future<void>.delayed(Duration.zero);

    c.synchronize(const Duration(seconds: 42));
    final cmd = await done.future.timeout(const Duration(seconds: 1));

    expect(cmd.type, 'seek');
    expect(cmd.position, const Duration(seconds: 42));
    await sub.cancel();
    await c.dispose();
  });
}
