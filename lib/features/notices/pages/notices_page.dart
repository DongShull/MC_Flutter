import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/models.dart';
import '../state/notices_controller.dart';

/// 通知中心（管理员）：只有需要处理的问题才出现在这里。
/// 对齐 Kotlin NoticeCenterScreen：列表卡片 + 单条/全部忽略 + 30s 轮询。
class NoticesPage extends ConsumerWidget {
  const NoticesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noticesControllerProvider);
    final controller = ref.read(noticesControllerProvider.notifier);
    final form = McFormWatch.of(context);

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            title: '通知中心',
            titleVisible: true,
            trailing: [
              if (state is NoticesReady && state.value.isNotEmpty)
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
                              '订阅失败、上游不可达等运行时异常会出现在这里',
                              textAlign: TextAlign.center,
                              style: McText.caption.muted,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => controller.refresh(silent: true),
                      child: form == McDeviceForm.phone
                          ? ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                McTokens.pagePadding,
                                8,
                                McTokens.pagePadding,
                                32,
                              ),
                              itemCount: value.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final notice = value[index];
                                return _NoticeCard(
                                  notice: notice,
                                  onDismiss: () => controller.dismiss(notice),
                                );
                              },
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = mcGridCrossAxisCount(
                                  form,
                                  constraints,
                                  min: 2,
                                  max: 4,
                                );
                                return GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    McTokens.pagePadding,
                                    8,
                                    McTokens.pagePadding,
                                    32,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 2.8,
                                  ),
                                  itemCount: value.length,
                                  itemBuilder: (context, index) {
                                    final notice = value[index];
                                    return _NoticeCard(
                                      notice: notice,
                                      onDismiss: () =>
                                          controller.dismiss(notice),
                                    );
                                  },
                                );
                              },
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
  const _NoticeCard({required this.notice, required this.onDismiss});

  final Notice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = switch (notice.severity) {
      'error' || 'critical' => McTokens.danger,
      'warning' => McTokens.warning,
      _ => McTokens.info,
    };
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.ui.semibold,
                ),
              ),
              const SizedBox(width: 8),
              Text(notice.source, style: McText.micro.muted),
            ],
          ),
          if (notice.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notice.message, style: McText.sub.muted),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (notice.updatedAt != null)
                Text('更新于 ${notice.updatedAt!}', style: McText.caption.faint),
              const Spacer(),
              McChip(
                label: '忽略',
                compact: true,
                onTap: onDismiss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
