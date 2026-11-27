import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../designsystem/mc_chrome.dart';
import '../designsystem/mc_glass.dart';
import '../designsystem/mc_icons.dart';
import '../designsystem/theme.dart';
import '../l10n/mc_l10n.dart';
import 'api_exception.dart';
import 'mc_client.dart';
import 'session_providers.dart';

/// 模型接入探测状态（对齐 iOS `LLMCapabilityProbe.State`）。
enum LlmCapabilityState {
  checking,
  configured,
  missing,
  unavailable,
}

/// 全局共享的模型能力探测（1:1 对齐 iOS `MovieClaw/DesignSystem/ActivityHandoff.swift`）。
///
/// - 请求 `GET /api/v1/llm/providers`，非空即视为已接入（`configured`）；
/// - 结果缓存 5 分钟；设置里新增/删除模型后调用 `invalidate()` 立即刷新；
/// - 探测失败按 `unavailable` 处理并 **放行入口（fail-open）**，交由后端预检兜底，
///   避免单次状态接口故障锁死所有 AI 功能。
class LlmCapabilityProbe extends ChangeNotifier {
  LlmCapabilityProbe();

  static final LlmCapabilityProbe instance = LlmCapabilityProbe();
  static const Duration cacheTtl = Duration(minutes: 5);

  LlmCapabilityState _state = LlmCapabilityState.checking;
  DateTime? _checkedAt;
  bool _inFlight = false;

  LlmCapabilityState get state => _state;

  /// 是否允许展示「交给 AI 分析」入口：已接入，或探测失败时放行。
  bool get allowsHandoff =>
      _state == LlmCapabilityState.configured ||
      _state == LlmCapabilityState.unavailable;

  /// 清除缓存（接入或删除 LLM 供应商后调用）。
  void invalidate() {
    _checkedAt = null;
  }

  /// 重置状态（切换账号或测试用）。
  void reset() {
    _checkedAt = null;
    _inFlight = false;
    if (_state != LlmCapabilityState.checking) {
      _state = LlmCapabilityState.checking;
      notifyListeners();
    }
  }

  /// 若缓存已过期则探测 `GET /api/v1/llm/providers`。
  Future<void> ensure(McClient client) async {
    final checked = _checkedAt;
    if (checked != null && DateTime.now().difference(checked) < cacheTtl) {
      return;
    }
    if (_inFlight) return;
    _inFlight = true;
    try {
      final raw = await client.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/llm/providers',
      );
      final providers = _extractProviderList(raw);
      _state = providers.isEmpty
          ? LlmCapabilityState.missing
          : LlmCapabilityState.configured;
      _checkedAt = DateTime.now();
      notifyListeners();
    } catch (_) {
      // fail-open：不写 _checkedAt，下次打开页面还会重试，同时立即放行入口。
      if (_state != LlmCapabilityState.unavailable) {
        _state = LlmCapabilityState.unavailable;
        notifyListeners();
      }
    } finally {
      _inFlight = false;
    }
  }

  static List<dynamic> _extractProviderList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      for (final key in const ['providers', 'items', 'data']) {
        final v = raw[key];
        if (v is List) return v;
      }
    }
    return const [];
  }
}

/// Riverpod 访问入口（共享全局 [LlmCapabilityProbe.instance]）。
final llmCapabilityProbeProvider = Provider<LlmCapabilityProbe>(
  (ref) => LlmCapabilityProbe.instance,
);

/// 「交给 AI 分析」后端交接协议（对齐 `APIClient.activityHandoff`）。
///
/// 1. 调用 `POST /api/v1/agent-handoff`（`kind`: `notice` / `download` / `job` 等，`ref`: 事项 ID 或 info_hash）；
/// 2. 若后端已直接返回 `session_id` 则直接采用，否则取出 `prompt` 调用 `POST /api/v1/sessions` 创建新会话并返回 `session_id`。
abstract final class AgentHandoffApi {
  static Future<String> handoff(
    McClient client, {
    required String kind,
    required String ref,
  }) async {
    final handoffRes = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/agent-handoff',
      body: {
        'kind': kind,
        'ref': ref,
      },
    );

    final directSessionId =
        (handoffRes['session_id'] ?? handoffRes['sessionId'])?.toString() ?? '';
    if (directSessionId.isNotEmpty) {
      return directSessionId;
    }

    final prompt = (handoffRes['prompt'] ?? '').toString().trim();
    if (prompt.isEmpty) {
      throw const ApiException('agent.handoff_empty', '诊断工单为空');
    }

    final accepted = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/sessions',
      body: {'content': prompt},
    );

    final sessionId =
        (accepted['session_id'] ?? accepted['sessionId'] ?? accepted['id'])
                ?.toString() ??
            '';
    if (sessionId.isEmpty) {
      throw const ApiException('agent.session_missing', '未返回会话编号');
    }
    return sessionId;
  }
}

/// 跨页面复用的「交给 AI 分析」液态玻璃按钮（Notices / Activity / Detail 等处通用）。
///
/// 对齐 iOS `ActivityHandoffButton`：未接入模型时不渲染；点击后调用 [AgentHandoffApi.handoff]
/// 并跳转到 `/agent/session/:sessionId`。
class McAgentHandoffButton extends ConsumerStatefulWidget {
  const McAgentHandoffButton({
    super.key,
    required this.kind,
    required this.refId,
    this.onBeforeNavigate,
    this.onSessionCreated,
    this.label,
    this.compact = false,
  });

  /// 事项类型：`notice` / `download` / `job` 等。
  final String kind;

  /// 事项标识（告警 ID、种子 info_hash、任务 ID 等）。
  final String refId;

  /// 跳转会话页前的回调（如关闭当前弹层）。
  final VoidCallback? onBeforeNavigate;

  /// 自定义会话创建后的跳转逻辑；为空时默认 `context.push('/agent/session/$id')`。
  final void Function(String sessionId)? onSessionCreated;

  /// 自定义文案（默认取 `McL10n.of(context).agentHandoffAnalyze`）。
  final String? label;

  /// 紧凑模式（用于卡片底部操作栏）。
  final bool compact;

  @override
  ConsumerState<McAgentHandoffButton> createState() =>
      _McAgentHandoffButtonState();
}

class _McAgentHandoffButtonState extends ConsumerState<McAgentHandoffButton> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final client = ref.read(mcClientProvider);
      unawaited(ref.read(llmCapabilityProbeProvider).ensure(client));
    });
  }

  Future<void> _triggerHandoff() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = McL10n.of(context);
    try {
      final client = ref.read(mcClientProvider);
      final sessionId = await AgentHandoffApi.handoff(
        client,
        kind: widget.kind,
        ref: widget.refId,
      );
      if (!mounted) return;
      widget.onBeforeNavigate?.call();
      if (widget.onSessionCreated != null) {
        widget.onSessionCreated!(sessionId);
      } else {
        context.push('/agent/session/${Uri.encodeComponent(sessionId)}');
      }
    } on ApiException catch (e) {
      final msg =
          e.friendlyMessage.isNotEmpty ? e.friendlyMessage : l10n.agentHandoffFailed;
      McToast.error(msg);
    } catch (_) {
      McToast.error(l10n.agentHandoffFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final probe = ref.watch(llmCapabilityProbeProvider);
    final l10n = McL10n.of(context);
    return ListenableBuilder(
      listenable: probe,
      builder: (context, _) {
        if (!probe.allowsHandoff) return const SizedBox.shrink();
        final text = _busy
            ? l10n.agentHandoffPreparing
            : (widget.label ?? l10n.agentHandoffAnalyze);
        return Semantics(
          button: true,
          identifier: 'handoff-${widget.kind}-${widget.refId}',
          child: McGlassButton(
            onTap: _busy ? null : _triggerHandoff,
            tone: McGlassTone.secondary,
            padding: widget.compact
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: McTokens.accent,
                    ),
                  )
                else
                  Icon(
                    McIcons.aiSearch2,
                    size: widget.compact ? 14 : 16,
                    color: McTokens.accent,
                  ),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: (widget.compact ? McText.caption : McText.sub).copyWith(
                    color: McTokens.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
