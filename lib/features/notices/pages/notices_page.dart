import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: '返回',
                  onPressed: () => context.pop(),
                ),
                const Expanded(
                  child: Text('通知中心', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                if (state is NoticesReady && state.value.isNotEmpty)
                  TextButton.icon(
                    onPressed: controller.dismissAll,
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('全部忽略', style: TextStyle(fontSize: 12)),
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
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('没有需要处理的问题',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            SizedBox(height: 6),
                            Text(
                              '订阅失败、上游不可达等运行时异常会出现在这里',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => controller.refresh(silent: true),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: value.length,
                          separatorBuilder: (context, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final notice = value[index];
                            return _NoticeCard(
                              notice: notice,
                              onDismiss: () => controller.dismiss(notice),
                            );
                          },
                        ),
                      ),
              },
            ),
          ],
        ),
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
      'error' || 'critical' => const Color(0xFFE5484D),
      'warning' => const Color(0xFFF5A623),
      _ => McColors.accent,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(notice.source, style: const TextStyle(fontSize: 11)),
            ],
          ),
          if (notice.message.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              notice.message,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ],
          Row(
            children: [
              if (notice.updatedAt != null)
                Text('更新于 ${notice.updatedAt!}', style: const TextStyle(fontSize: 11)),
              const Spacer(),
              TextButton(
                onPressed: onDismiss,
                child: const Text('忽略', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
