import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/controllers.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../state/rule_set_spec.dart';
import '../widgets/activity_timeline.dart';
import '../widgets/tracking_list.dart';

/// 订阅详情页（对齐 SubscriptionDetailScreen.kt）：
/// 摘要卡（四段进度条 + 状态 + 进度一句话）→ 操作行 → 追踪明细 → 活动时间线。
class SubscriptionDetailPage extends ConsumerStatefulWidget {
  const SubscriptionDetailPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<SubscriptionDetailPage> createState() =>
      _SubscriptionDetailPageState();
}

class _SubscriptionDetailPageState
    extends ConsumerState<SubscriptionDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionDetailProvider(widget.id).notifier).load();
    });
  }

  void _toast(String msg) => McToast.info(msg);

  Future<void> _showMoreMenu(
    SubscriptionDetailController controller,
    SubscriptionView sub,
  ) async {
    final action = await showMcSheet<_DetailAction>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: sub.media.title,
          margin: EdgeInsets.zero,
          children: [
            McInsetRow(
              icon: McIcons.playListAdd,
              title: '调整订阅（换选季）',
              onTap: () => Navigator.of(ctx).pop(_DetailAction.seasons),
            ),
            McInsetRow(
              icon: McIcons.aiStarFill,
              title: '洗一轮版',
              onTap: () => Navigator.of(ctx).pop(_DetailAction.upgrade),
            ),
            McInsetRow(
              icon: McIcons.clockFill,
              title: sub.followFuture ? '关闭自动续订' : '开启自动续订',
              onTap: () => Navigator.of(ctx).pop(_DetailAction.follow),
            ),
            McInsetRow(
              icon: McIcons.listSettings2,
              title: '规则组',
              onTap: () => Navigator.of(ctx).pop(_DetailAction.ruleSet),
            ),
            McInsetRow(
              icon: McIcons.pauseCircle,
              title: sub.status == 'paused' ? '恢复追踪' : '暂停追踪',
              onTap: () => Navigator.of(ctx).pop(_DetailAction.pause),
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

  Future<void> _pickSeasons(
    SubscriptionDetailController controller,
    SubscriptionView sub,
  ) async {
    final selected = {...sub.selectedSeasons};
    final seasons = sub.seasonCollection;
    if (seasons.isEmpty) {
      _toast('没有可调整的季');
      return;
    }
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('调整订阅选季', style: McText.titleSm),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: McInsetGroup(
                    margin: EdgeInsets.zero,
                    dividerIndent: 46,
                    children: [
                      for (final s in seasons)
                        McInsetRow(
                          leading: Icon(
                            selected.contains(s.seasonNumber)
                                ? McIcons.checkCircleFill
                                : McIcons.circler,
                            size: 20,
                            color: selected.contains(s.seasonNumber)
                                ? McTokens.accentStrong
                                : McTokens.textFaint,
                          ),
                          title: s.name ?? '第 ${s.seasonNumber} 季',
                          subtitle: s.episodesLine,
                          onTap: () => setSheetState(() {
                            if (selected.contains(s.seasonNumber)) {
                              selected.remove(s.seasonNumber);
                            } else {
                              selected.add(s.seasonNumber);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: McActionPill(
                      label: '取消',
                      primary: false,
                      expanded: true,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: McActionPill(
                      label: '确定',
                      primary: true,
                      expanded: true,
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) await controller.updateSeasons(selected.toList());
    if (mounted) _consumeNotice(controller);
  }

  Future<void> _pickRuleSet(SubscriptionDetailController controller) async {
    List<RuleSetView> ruleSets;
    try {
      ruleSets = await ref.read(subscriptionsApiProvider).ruleSets();
    } catch (_) {
      _toast('规则组仅管理员可用');
      return;
    }
    if (!mounted) return;
    final picked = await showMcSheet<int>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: McInsetGroup(
          header: '选择规则组',
          margin: EdgeInsets.zero,
          children: [
            for (final r in ruleSets)
              McInsetRow(
                title: r.name,
                subtitle: specSummary(r.spec),
                onTap: () => Navigator.pop(ctx, r.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await controller.updateRuleSet(picked);
    if (mounted) _consumeNotice(controller);
  }

  Future<void> _confirmUnsubscribe(
    SubscriptionDetailController controller,
    SubscriptionView sub,
  ) async {
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('取消订阅', style: McText.titleSm),
            const SizedBox(height: 8),
            Text(
              '取消订阅《${sub.media.title}》将停止追踪剩余内容。'
              '默认只取消订阅，已经下载或入库的内容都会保留。',
              style: McText.sub.muted,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: McActionPill(
                    label: '保留',
                    primary: false,
                    expanded: true,
                    onTap: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: McActionPill(
                    label: '取消订阅',
                    primary: false,
                    tone: McGlassTone.danger,
                    expanded: true,
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    final controller =
        ref.watch(subscriptionDetailProvider(widget.id).notifier);
    final state = ref.watch(subscriptionDetailProvider(widget.id));
    final sub = state.value;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () => context.canPop()
                ? context.pop()
                : context.go('/subscriptions'),
            title: sub?.media.title ?? '订阅详情',
            titleVisible: true,
            trailing: [
              if (sub != null)
                McGlassIconButton(
                  icon: McIcons.more,
                  tooltip: '更多操作',
                  onTap: () => _showMoreMenu(controller, sub),
                ),
            ],
          ),
          Expanded(
            child: state.isLoading && sub == null
                ? const McLoadingView()
                : state.hasError
                    ? McErrorView(
                        text: '${state.error}',
                        onRetry: () => controller.load(),
                      )
                    : sub == null
                        ? const SizedBox.shrink()
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(
                              McTokens.pagePadding,
                              12,
                              McTokens.pagePadding,
                              32,
                            ),
                            children: [
                              _SummaryCard(sub: sub),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: McGlassButton(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 8,
                                      ),
                                      onTap: () async {
                                        await controller.searchNow();
                                        if (mounted) _consumeNotice(controller);
                                      },
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(McIcons.search, size: 15),
                                          SizedBox(width: 5),
                                          Text('立即搜索'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: McGlassButton(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 8,
                                      ),
                                      onTap: () => context.push(
                                        '/subscriptions/wall/${sub.id}',
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(McIcons.gridFill, size: 15),
                                          SizedBox(width: 5),
                                          Text('资源墙'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: McGlassButton(
                                      tone: McGlassTone.danger,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 8,
                                      ),
                                      onTap: () =>
                                          _confirmUnsubscribe(controller, sub),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(McIcons.linkUnlink, size: 15),
                                          SizedBox(width: 5),
                                          Text('取消订阅'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text('追踪明细', style: McText.titleSm),
                              const SizedBox(height: 6),
                              TrackingList(sub: sub),
                              const SizedBox(height: 20),
                              const Text('活动记录', style: McText.titleSm),
                              const SizedBox(height: 6),
                              ActivityTimeline(
                                activities: controller.activities,
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

enum _DetailAction { seasons, upgrade, follow, ruleSet, pause }

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
                  backgroundColor: McTokens.surfaceInset,
                  valueColor: AlwaysStoppedAnimation(c),
                ),
              ),
              const SizedBox(height: 5),
              Text('$label $v', style: McText.micro.muted),
            ],
          ),
        );

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(McTokens.pillRadius),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  subscriptionStatusLabel(sub),
                  style: McText.micro.copyWith(color: color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subscriptionProgressNote(sub),
                  style: McText.caption.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              seg(p.imported, McTokens.ok, '入库'),
              const SizedBox(width: 8),
              seg(p.downloaded, McTokens.info, '已下载'),
              const SizedBox(width: 8),
              seg(p.grabbed, McTokens.warning, '下载中'),
              const SizedBox(width: 8),
              seg(p.wanted, McTokens.textFaint, '缺'),
            ],
          ),
          if (sub.followFuture) ...[
            const SizedBox(height: 8),
            Text('自动续订已开启', style: McText.micro.faint),
          ],
        ],
      ),
    );
  }
}
