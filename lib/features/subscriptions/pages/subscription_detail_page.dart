import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/state_views.dart';
import '../state/controllers.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../state/rule_set_spec.dart';
import '../widgets/activity_timeline.dart';
import '../widgets/tracking_list.dart';

/// 订阅详情页（对齐 SubscriptionDetailScreen.kt / 设计文档 04 §5.3）：
/// 摘要卡（四段进度条 + 状态 + 进度一句话）→ 操作行（立即搜索 / 更多）→
/// 追踪明细（按季分组）→ 活动时间线。
class SubscriptionDetailPage extends ConsumerStatefulWidget {
  const SubscriptionDetailPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<SubscriptionDetailPage> createState() => _SubscriptionDetailPageState();
}

class _SubscriptionDetailPageState extends ConsumerState<SubscriptionDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionDetailProvider(widget.id).notifier).load();
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showMoreMenu(SubscriptionDetailController controller, SubscriptionView sub) async {
    final action = await showModalBottomSheet<_DetailAction>(
      context: context,
      backgroundColor: const Color(0xFF141A21),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('调整订阅（换选季）', style: TextStyle(fontSize: 14)),
              onTap: () => Navigator.of(context).pop(_DetailAction.seasons),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('洗一轮版', style: TextStyle(fontSize: 14)),
              onTap: () => Navigator.of(context).pop(_DetailAction.upgrade),
            ),
            ListTile(
              leading: const Icon(Icons.update),
              title: Text(
                sub.followFuture ? '关闭自动续订' : '开启自动续订',
                style: const TextStyle(fontSize: 14),
              ),
              onTap: () => Navigator.of(context).pop(_DetailAction.follow),
            ),
            ListTile(
              leading: const Icon(Icons.rule),
              title: const Text('规则组', style: TextStyle(fontSize: 14)),
              onTap: () => Navigator.of(context).pop(_DetailAction.ruleSet),
            ),
            ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: Text(
                sub.status == 'paused' ? '恢复追踪' : '暂停追踪',
                style: const TextStyle(fontSize: 14),
              ),
              onTap: () => Navigator.of(context).pop(_DetailAction.pause),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _DetailAction.seasons:
        await _pickSeasons(controller, sub);
      case _DetailAction.upgrade:
        await controller.upgradeRun();
      case _DetailAction.follow:
        await controller.setFollowFuture(!sub.followFuture);
      case _DetailAction.ruleSet:
        await _pickRuleSet(controller);
      case _DetailAction.pause:
        await controller.setTracking(sub.status != 'paused');
    }
    if (mounted) _consumeNotice(controller);
  }

  Future<void> _pickSeasons(SubscriptionDetailController controller, SubscriptionView sub) async {
    final selected = {...sub.selectedSeasons};
    final seasons = sub.seasonCollection;
    if (seasons.isEmpty) {
      _toast('没有可调整的季');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('调整订阅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in seasons)
              CheckboxListTile(
                dense: true,
                value: selected.contains(s.seasonNumber),
                title: Text(
                  s.name ?? '第 ${s.seasonNumber} 季 · ${s.episodesLine}',
                  style: const TextStyle(fontSize: 13),
                ),
                onChanged: (v) {
                  if (v == true) {
                    selected.add(s.seasonNumber);
                  } else {
                    selected.remove(s.seasonNumber);
                  }
                  (context as Element).markNeedsBuild();
                },
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok == true) await controller.updateSeasons(selected.toList());
    if (mounted) _consumeNotice(controller);
  }

  Future<void> _pickRuleSet(SubscriptionDetailController controller) async {
    // 规则组只有超管可读（GET /rule-sets 是 require_admin）：失败静默降级
    List<RuleSetView> ruleSets;
    try {
      ruleSets = await ref.read(subscriptionsApiProvider).ruleSets();
    } catch (_) {
      _toast('规则组仅管理员可用');
      return;
    }
    if (!mounted) return;
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择规则组'),
        children: [
          for (final r in ruleSets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, r.id),
              child: Text('${r.name} · ${specSummary(r.spec)}',
                  style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
    if (picked != null) await controller.updateRuleSet(picked);
    if (mounted) _consumeNotice(controller);
  }

  Future<void> _confirmUnsubscribe(SubscriptionDetailController controller, SubscriptionView sub) async {
    // 文案对齐安卓："取消订阅《title》将停止追踪剩余内容。默认只取消订阅，已经下载或入库的内容都会保留。"
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消订阅'),
        content: Text(
          '取消订阅《${sub.media.title}》将停止追踪剩余内容。'
          '默认只取消订阅，已经下载或入库的内容都会保留。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('保留')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE5615B)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('取消订阅'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final done = await controller.unsubscribe();
      if (!mounted) return;
      _consumeNotice(controller);
      if (done) context.pop();
    }
  }

  void _consumeNotice(SubscriptionDetailController controller) {
    final n = controller.notice;
    if (n != null) {
      controller.consumeNotice();
      _toast(n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(subscriptionDetailProvider(widget.id).notifier);
    final state = ref.watch(subscriptionDetailProvider(widget.id));
    final sub = state.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(sub?.media.title ?? '订阅详情'),
        actions: [
          if (sub != null)
            IconButton(
              icon: const Icon(Icons.more_horiz),
              tooltip: '更多操作',
              onPressed: () => _showMoreMenu(controller, sub),
            ),
        ],
      ),
      body: state.isLoading && sub == null
          ? const McLoadingView()
          : state.hasError
              ? McErrorView(text: '${state.error}', onRetry: () => controller.load())
              : sub == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _SummaryCard(sub: sub),
                        const SizedBox(height: 12),
                        // 操作行：立即搜索 / 订阅墙
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.search, size: 16),
                                label: const Text('立即搜索'),
                                onPressed: () async {
                                  await controller.searchNow();
                                  if (mounted) _consumeNotice(controller);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.grid_view_outlined, size: 16),
                                label: const Text('资源墙'),
                                onPressed: () =>
                                    context.push('/subscriptions/wall/${sub.id}'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.link_off, size: 16),
                                label: const Text('取消订阅'),
                                onPressed: () => _confirmUnsubscribe(controller, sub),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('追踪明细',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        TrackingList(sub: sub),
                        const SizedBox(height: 16),
                        const Text('活动记录',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ActivityTimeline(activities: controller.activities),
                      ],
                    ),
    );
  }
}

enum _DetailAction { seasons, upgrade, follow, ruleSet, pause }

/// 摘要卡：海报 + 状态徽标 + 四段进度条（imported/downloaded/grabbed/wanted）+ 进度一句话。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.sub});

  final SubscriptionView sub;

  @override
  Widget build(BuildContext context) {
    final p = sub.progress;
    final total = p.total > 0 ? p.total : 1;
    final color = subscriptionStatusColor(sub);

    Widget seg(int v, Color c, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (v / total).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(c),
                ),
              ),
              const SizedBox(height: 4),
              Text('$label $v',
                  style: TextStyle(
                      fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  subscriptionStatusLabel(sub),
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subscriptionProgressNote(sub),
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              seg(p.imported, const Color(0xFF34C77B), '入库'),
              const SizedBox(width: 8),
              seg(p.downloaded, const Color(0xFF6AA7FF), '已下载'),
              const SizedBox(width: 8),
              seg(p.grabbed, const Color(0xFFF5B84C), '下载中'),
              const SizedBox(width: 8),
              seg(p.wanted, Colors.white24, '缺'),
            ],
          ),
          if (sub.followFuture)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('自动续订已开启',
                  style: TextStyle(
                      fontSize: 10, color: Colors.white.withValues(alpha: 0.45))),
            ),
        ],
      ),
    );
  }
}
