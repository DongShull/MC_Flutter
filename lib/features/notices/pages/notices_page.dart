import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/llm_capability_probe.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/l10n/mc_l10n.dart';
import '../../../core/navigation/external_media_link.dart';
import '../state/models.dart';
import '../state/notices_controller.dart';

/// 待处理事项中心（管理员，1:1 对齐 iOS `NoticeCenterView.swift`）：
/// - 顶栏显示可见待处理数量胶囊 + 「全部忽略」；
/// - 每条事项三段动作主次分明：忽略（退路）+ 「交给 AI 分析」（`McAgentHandoffButton`）+ 主玻璃按钮「去处理 ›」；
/// - 相对时间（`McFormatting.relative`）+ 正文支持长按选择/复制（`SelectableText`）。
class NoticesPage extends ConsumerWidget {
  const NoticesPage({super.key});

  void _gotoNotice(BuildContext context, Notice notice) {
    final webHref = notice.resolveWebHref();
    final resolved = AppWebPathResolver.resolveDetailed(webHref);
    final location = resolved?.location ?? '/settings';
    if (location.startsWith('/home')) {
      context.go(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noticesControllerProvider);
    final controller = ref.read(noticesControllerProvider.notifier);
    final form = McFormWatch.of(context);
    final visibleList = state is NoticesReady ? state.value : const <Notice>[];
    final visibleCount = visibleList.length;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: '待处理事项',
            titleVisible: true,
            trailing: [
              if (visibleCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: McTokens.glassFillActive,
                    borderRadius: BorderRadius.circular(McTokens.pillRadius),
                    border: Border.all(color: McTokens.line),
                  ),
                  child: Text(
                    '$visibleCount',
                    style: McText.caption.tabular.copyWith(
                      color: McTokens.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                McFocusRing(
                  borderRadius: McTokens.pillRadius,
                  child: McChip(
                    icon: McIcons.checkDouble,
                    label: '全部忽略',
                    compact: true,
                    onTap: controller.dismissAll,
                  ),
                ),
              ],
            ],
          ),
          Expanded(
            child: switch (state) {
              NoticesLoading() => const McLoadingView(),
              NoticesFailed(:final message) => McErrorView(
                  text: message,
                  onRetry: controller.refresh,
                ),
              NoticesReady(:final value) => value.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              McIcons.checkCircle,
                              size: 42,
                              color: McTokens.textFaint,
                            ),
                            const SizedBox(height: 12),
                            const Text('没有需要处理的问题', style: McText.titleSm),
                            const SizedBox(height: 6),
                            Text(
                              '订阅失败、下载器故障、入库阻塞等需要人工介入的运行时异常会出现在这里；修复后服务端会自动消退。',
                              textAlign: TextAlign.center,
                              style: McText.caption.muted,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => controller.refresh(silent: true),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: form == McDeviceForm.phone
                                ? double.infinity
                                : 820,
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              McTokens.pagePadding,
                              8,
                              McTokens.pagePadding,
                              32,
                            ),
                            itemCount: value.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index == value.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '仅展示需要你行动才能推进的运行时问题，修好后服务端会自动消退。',
                                    style: McText.caption.faint,
                                  ),
                                );
                              }
                              final notice = value[index];
                              return _NoticeCard(
                                notice: notice,
                                onGoto: () => _gotoNotice(context, notice),
                                onDismiss: () => controller.dismiss(notice),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
            },
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.onGoto,
    required this.onDismiss,
  });

  final Notice notice;
  final VoidCallback onGoto;
  final VoidCallback onDismiss;

  String _relativeTime(BuildContext context) {
    final raw = notice.updatedAt ?? notice.createdAt;
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return McFormatting.relative(
      dt,
      locale: Localizations.maybeLocaleOf(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (notice.severity) {
      'warning' => McTokens.warning,
      'info' => McTokens.info,
      _ => McTokens.danger,
    };
    final relTime = _relativeTime(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            notice.title,
                            style: McText.ui.semibold,
                          ),
                        ),
                        if (relTime.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Text(relTime, style: McText.caption.faint),
                        ],
                      ],
                    ),
                    if (notice.message.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SelectableText(
                        notice.message,
                        style: McText.sub.muted.copyWith(height: 1.45),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: McTokens.line),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              McPressable(
                onTap: onDismiss,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text('忽略', style: McText.sub.faint),
                ),
              ),
              McAgentHandoffButton(
                kind: 'notice',
                refId: '${notice.id}',
                compact: true,
              ),
              McGlassButton(
                onTap: onGoto,
                tone: McGlassTone.strong,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '去处理',
                      style: McText.sub.copyWith(
                        color: McTokens.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      McIcons.chevronRight,
                      size: 14,
                      color: McTokens.text,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
