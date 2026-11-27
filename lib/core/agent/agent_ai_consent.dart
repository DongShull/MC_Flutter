import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/mc_client.dart';
import '../api/session_providers.dart';
import '../designsystem/mc_chrome.dart';
import '../designsystem/mc_icons.dart';
import '../designsystem/theme.dart';

/// 首次向 AI 助手发送消息前的隐私数据去向说明与同意门禁（App Store 5.1.2(i) 合规，
/// 1:1 对齐 iOS `MovieClaw/Features/Agent/AgentAIConsent.swift`）。
abstract final class AgentAIConsent {
  static const String storageKey = 'mc.agentAIConsent.v1';

  static bool? _cachedGranted;

  /// 是否已在本机同意过第三方 AI 数据传输说明。
  static Future<bool> isGranted() async {
    if (_cachedGranted == true) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool(storageKey) ?? false;
      _cachedGranted = val;
      return val;
    } catch (_) {
      return false;
    }
  }

  /// 持久化记录用户同意。
  static Future<void> grant() async {
    _cachedGranted = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageKey, true);
    } catch (_) {}
  }

  /// 重置同意状态（测试或隐私重置用）。
  static Future<void> reset() async {
    _cachedGranted = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {}
  }

  /// 从 `GET /api/v1/llm/providers` 拉取已配置的第三方模型服务商名称列表（去重保序）。
  static Future<List<String>> fetchProviderNames(McClient client) async {
    try {
      final raw = await client.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/llm/providers',
      );
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['providers'] ?? raw['items'] ?? raw['data'])
              : null);
      if (list is! List) return const <String>[];
      final seen = <String>{};
      final out = <String>[];
      for (final item in list) {
        if (item is! Map) continue;
        final name = (item['name'] ??
                item['provider_name'] ??
                item['label'] ??
                item['provider'] ??
                '')
            .toString()
            .trim();
        if (name.isNotEmpty && seen.add(name)) {
          out.add(name);
        }
      }
      return out;
    } catch (_) {
      return const <String>[];
    }
  }
}

/// 统一发送前同意校验入口（`features/agent` 与 `features/more` 共用）：
/// - 已同意时立即返回 `true`；
/// - 未同意时动态拉取服务商清单并弹出 [AgentAIConsentSheet]；
/// - 用户取消时返回 `false`（调用方保留草稿不发送）。
Future<bool> ensureAgentAiConsent(
  BuildContext context,
  WidgetRef ref, {
  List<String>? providerNames,
}) async {
  if (await AgentAIConsent.isGranted()) return true;
  if (!context.mounted) return false;

  final names = (providerNames != null && providerNames.isNotEmpty)
      ? providerNames
      : await AgentAIConsent.fetchProviderNames(ref.read(mcClientProvider));
  if (!context.mounted) return false;

  final agreed = await showMcSheet<bool>(
    context: context,
    builder: (_) => AgentAIConsentSheet(providers: names),
  );
  if (agreed == true) {
    await AgentAIConsent.grant();
    return true;
  }
  return false;
}

/// 首次发送 AI 消息前的说明与同意弹层。
class AgentAIConsentSheet extends StatelessWidget {
  const AgentAIConsentSheet({
    super.key,
    required this.providers,
  });

  final List<String> providers;

  String get _destinationText {
    if (providers.isEmpty) {
      return '你输入的提问内容、上传的图片附件，以及回答所需的媒体库与订阅上下文信息，将由你的 MovieClaw 服务器发送至你配置的第三方大语言模型服务商进行处理。';
    }
    final joined = providers.join('、');
    return '你输入的提问内容、上传的图片附件，以及回答所需的媒体库与订阅上下文信息，将由你的 MovieClaw 服务器发送至你已配置的第三方 AI 服务商（$joined）进行处理。';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: McTokens.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    McIcons.aiStarFill,
                    size: 18,
                    color: McTokens.accentStrong,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('使用 AI 助手前的数据说明', style: McText.title),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _destinationText,
              style: McText.body.copyWith(color: McTokens.text, height: 1.5),
            ),
            const SizedBox(height: 10),
            Text(
              'MovieClaw 开发者不会收集、中转或保存你的对话与图片内容。你可以随时在「设置 → AI 模型」中查看、修改或移除已接入的第三方服务商。',
              style: McText.sub.muted.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '取消',
                    primary: false,
                    height: 44,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '同意并继续',
                    primary: true,
                    height: 44,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
