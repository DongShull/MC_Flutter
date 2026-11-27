import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_exception.dart';
import 'session/playback_session_api.dart';

/// 播放 QoE 指标落盘与离线补发队列（对齐 `PlaybackReportQueue.swift`）：
/// - 持久化目录：`<ApplicationSupport>/playback-reports/`；
/// - `active.json`：每 10 秒刷新正在播放的快照（闪退/强杀后下次启动自动恢复并转入待发队列）；
/// - 7 天 TTL 自动过期清理，仅发回产生该记录的那台服务器；
/// - 服务端 2xx 或 4xx（明确拒收）后删盘；网络故障保留待下次补发。
class PlaybackReportQueue {
  PlaybackReportQueue._();

  static final PlaybackReportQueue instance = PlaybackReportQueue._();

  static const Duration _maxAge = Duration(days: 7);

  Directory? _cachedDir;
  bool _flushing = false;

  Future<Directory?> _dir() async {
    if (kIsWeb) return null;
    if (_cachedDir != null) return _cachedDir;
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}${Platform.pathSeparator}playback-reports');
      if (!await d.exists()) {
        await d.create(recursive: true);
      }
      _cachedDir = d;
      return d;
    } catch (_) {
      return null;
    }
  }

  Future<File?> _activeFile() async {
    final d = await _dir();
    if (d == null) return null;
    return File('${d.path}${Platform.pathSeparator}active.json');
  }

  /// 启动或开启新播放前调用：若上次播放异常退出（残留 `active.json`），将其转入待发队列。
  Future<void> recoverAbnormalExit() async {
    final active = await _activeFile();
    if (active == null || !await active.exists()) return;
    try {
      final raw = await active.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final payload = decoded['payload'];
        final attemptId = (payload is Map ? payload['attempt_id'] : null)
                ?.toString() ??
            'recovered-${DateTime.now().millisecondsSinceEpoch}';
        final d = await _dir();
        if (d != null) {
          final target = File(
            '${d.path}${Platform.pathSeparator}${_safeName(attemptId)}.json',
          );
          await target.writeAsString(raw, flush: true);
        }
      }
    } catch (_) {
      // 损坏文件直接清理
    } finally {
      try {
        await active.delete();
      } catch (_) {}
    }
  }

  /// 刷新 `active.json` 闪退恢复标记（播放期间每 10 秒与切后台时调用）。
  Future<void> markActive({
    required String serverOrigin,
    required Map<String, dynamic> payload,
  }) async {
    if (serverOrigin.isEmpty) return;
    final active = await _activeFile();
    if (active == null) return;
    final envelope = <String, dynamic>{
      'server': serverOrigin,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'payload': payload,
    };
    try {
      await active.writeAsString(jsonEncode(envelope), flush: true);
    } catch (_) {}
  }

  /// 正常结束一次播放：先写队列文件、删掉 `active.json`，随后尝试立刻补发。
  Future<void> submit({
    required String serverOrigin,
    required Map<String, dynamic> payload,
    required PlaybackSessionApi api,
  }) async {
    if (serverOrigin.isEmpty) return;
    final d = await _dir();
    if (d != null) {
      final attemptId = payload['attempt_id']?.toString() ??
          'a-${DateTime.now().millisecondsSinceEpoch}';
      final file = File(
        '${d.path}${Platform.pathSeparator}${_safeName(attemptId)}.json',
      );
      final envelope = <String, dynamic>{
        'server': serverOrigin,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'payload': payload,
      };
      try {
        await file.writeAsString(jsonEncode(envelope), flush: true);
      } catch (_) {}
      final active = await _activeFile();
      if (active != null && await active.exists()) {
        try {
          await active.delete();
        } catch (_) {}
      }
    }
    unawaited(flush(serverOrigin: serverOrigin, api: api));
  }

  /// 补发队列中属于当前服务器的待发 QoE 记录（自动清理超 7 天条目）。
  Future<void> flush({
    required String serverOrigin,
    required PlaybackSessionApi api,
  }) async {
    if (_flushing || serverOrigin.isEmpty) return;
    final d = await _dir();
    if (d == null || !await d.exists()) return;
    _flushing = true;
    try {
      final now = DateTime.now().toUtc();
      final entities = d.listSync().whereType<File>().toList();
      for (final file in entities) {
        final name = file.uri.pathSegments.isEmpty
            ? ''
            : file.uri.pathSegments.last;
        if (!name.endsWith('.json') || name == 'active.json') continue;

        Map<String, dynamic>? envelope;
        try {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is Map<String, dynamic>) {
            envelope = decoded;
          }
        } catch (_) {
          try {
            await file.delete();
          } catch (_) {}
          continue;
        }
        if (envelope == null) {
          try {
            await file.delete();
          } catch (_) {}
          continue;
        }

        final savedAt = DateTime.tryParse(
          (envelope['saved_at'] ?? '').toString(),
        );
        if (savedAt == null || now.difference(savedAt) > _maxAge) {
          try {
            await file.delete();
          } catch (_) {}
          continue;
        }

        if ((envelope['server'] ?? '').toString() != serverOrigin) {
          continue;
        }
        final payloadRaw = envelope['payload'];
        if (payloadRaw is! Map) {
          try {
            await file.delete();
          } catch (_) {}
          continue;
        }

        try {
          await api.submitMetrics(payloadRaw.cast<String, dynamic>());
          try {
            await file.delete();
          } catch (_) {}
        } on ApiException catch (e) {
          final status = e.httpStatus ?? 0;
          if (status >= 400 && status < 500) {
            // 服务端明确拒收，删盘避免死循环重试
            try {
              await file.delete();
            } catch (_) {}
          } else {
            // 瞬时网络/5xx，中断本轮补发留待下次
            return;
          }
        } catch (_) {
          return;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  static String _safeName(String raw) =>
      raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
