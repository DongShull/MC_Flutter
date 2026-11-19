import 'dart:async';

import 'package:flutter/foundation.dart';

/// 播放会话协调器（docs/design/08-playback-session.md）。
/// 形状对齐飞牛 trim_playback_session_plugin 的 Pigeon 接口面：
/// registerParticipant / requestActivation / synchronize / reportUserStopped /
/// onCoordinatorCommand / onSessionSnapshotChanged（纯 Dart 版本，暂无原生层）。

/// 参与者运行状态快照（对应 reportParticipantState 上报体）。
@immutable
class ParticipantState {
  const ParticipantState({
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
  });

  final bool playing;
  final Duration position;
  final Duration? duration;
  final double speed;

  ParticipantState copyWith({
    bool? playing,
    Duration? position,
    Duration? duration,
    double? speed,
  }) {
    return ParticipantState(
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
    );
  }
}

/// 协调器命令（对应 onCoordinatorCommand 下发）。
@immutable
class CoordinatorCommand {
  const CoordinatorCommand({required this.type, this.position});

  final String type; // play | pause | seek | stop
  final Duration? position; // seek 目标
}

/// 会话快照（对应 onSessionSnapshotChanged）。
@immutable
class PlaybackSessionSnapshot {
  const PlaybackSessionSnapshot({
    required this.sessionId,
    required this.participants,
    required this.activeId,
  });

  final String sessionId;
  /// participantId → 最近一次上报的状态。
  final Map<String, ParticipantState> participants;
  /// 当前持有播放权的参与者；null = 空闲。
  final String? activeId;

  bool get isEmpty => participants.isEmpty;
}

/// 单个参与者的运行时记录（含心跳，对应 keepAliveId）。
class _Participant {
  _Participant(this.id) : lastHeartbeat = DateTime.now();

  final String id;
  ParticipantState state = const ParticipantState();
  DateTime lastHeartbeat;
  Timer? heartbeatTimer;
  int missedHeartbeats = 0;
}

/// 播放会话协调器：同一时间仅 1 个 activeParticipant。
/// 新参与者 requestActivation 成功后，旧 active 收到 pause 命令；
/// 心跳 5s 一次，连失 3 次判失联移除（participant_command_timeout 口径）。
class PlaybackCoordinator {
  PlaybackCoordinator();

  static const heartbeatInterval = Duration(seconds: 5);
  static const maxMissedHeartbeats = 3;

  final _sessionSeq = <int>{};
  final Map<String, _Participant> _participants = {};
  String? _activeId;
  String? _sessionId;
  int _sessionCounter = 0;

  final _commands = StreamController<CoordinatorCommand>.broadcast();
  final _snapshots = StreamController<PlaybackSessionSnapshot>.broadcast();
  final _diagnostics = StreamController<String>.broadcast();

  /// 协调器命令流（active 参与者订阅执行）。
  Stream<CoordinatorCommand> get commands => _commands.stream;

  /// 会话快照流（诊断/调试 UI 订阅）。
  Stream<PlaybackSessionSnapshot> get snapshots => _snapshots.stream;

  /// 诊断事件流（diagnostic_logged 口径）。
  Stream<String> get diagnostics => _diagnostics.stream;

  String get _nextSessionId {
    _sessionCounter += 1;
    final id = 'mc-session-$_sessionCounter';
    _sessionSeq.add(_sessionCounter);
    return id;
  }

  /// 注册参与者；首个参与者自动获得播放权。
  /// 返回当前会话 id（participant_register_failed 时抛 StateError）。
  String registerParticipant(String participantId) {
    if (_participants.containsKey(participantId)) {
      // participant_reregister_failed 口径：同 id 重复注册视为刷新心跳。
      _participants[participantId]!.lastHeartbeat = DateTime.now();
      return _sessionId!;
    }
    _sessionId ??= _nextSessionId;
    final p = _Participant(participantId);
    _participants[participantId] = p;
    _startHeartbeat(p);
    _diagnostics.add('registered:$participantId');
    if (_activeId == null) {
      _activeId = participantId;
    } else {
      // 激活抢占：旧 active 收到暂停命令（reportRemoteUserPaused 口径）。
      _commands.add(const CoordinatorCommand(type: 'pause'));
      _activeId = participantId;
      _diagnostics.add('activation_takeover:$participantId');
    }
    _emitSnapshot();
    return _sessionId!;
  }

  /// 注销参与者；最后一个退出时会话回到空闲。
  void unregisterParticipant(String participantId) {
    final p = _participants.remove(participantId);
    p?.heartbeatTimer?.cancel();
    if (p != null) _diagnostics.add('unregistered:$participantId');
    if (_activeId == participantId) {
      _activeId = _participants.keys.isEmpty ? null : _participants.keys.first;
    }
    if (_participants.isEmpty) _sessionId = null;
    _emitSnapshot();
  }

  /// 上报参与者状态（播放页在播放/暂停/进度变化节流后调用）。
  void reportParticipantState(String participantId, ParticipantState state) {
    final p = _participants[participantId];
    if (p == null) return;
    p.state = state;
    p.lastHeartbeat = DateTime.now();
    p.missedHeartbeats = 0;
    _emitSnapshot();
  }

  /// 显式用户停止（reportUserStopped 口径）：注销并清会话。
  void reportUserStopped(String participantId) {
    unregisterParticipant(participantId);
  }

  /// 全员时间轴对齐（synchronize 口径）：向 active 下发 seek。
  void synchronize(Duration position) {
    _commands.add(CoordinatorCommand(type: 'seek', position: position));
  }

  void _startHeartbeat(_Participant p) {
    p.heartbeatTimer?.cancel();
    p.heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      final idle = DateTime.now().difference(p.lastHeartbeat);
      if (idle > heartbeatInterval) {
        p.missedHeartbeats += 1;
      } else {
        p.missedHeartbeats = 0;
      }
      if (p.missedHeartbeats >= maxMissedHeartbeats) {
        _diagnostics.add('participant_command_timeout:${p.id}');
        unregisterParticipant(p.id);
      }
    });
  }

  void _emitSnapshot() {
    if (!_snapshots.hasListener) return;
    _snapshots.add(PlaybackSessionSnapshot(
      sessionId: _sessionId ?? '-',
      participants: {
        for (final e in _participants.entries) e.key: e.value.state,
      },
      activeId: _activeId,
    ));
  }

  /// 关闭全部流（仅测试/停机用）。
  Future<void> dispose() async {
    for (final p in _participants.values) {
      p.heartbeatTimer?.cancel();
    }
    _participants.clear();
    await _commands.close();
    await _snapshots.close();
    await _diagnostics.close();
  }
}
