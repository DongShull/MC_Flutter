import 'package:flutter/material.dart';

import '../../../core/api/mc_error.dart';
import '../../../core/image/image_urls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/state_views.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../state/rule_set_spec.dart';
import '../state/subscription_events.dart';
import '../state/subscription_index.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 订阅创建弹层的种子（对齐 SubscribeSheetHost.Seed：卡片上本来就有，
/// 抽屉立刻显示标题/海报，不必先转圈等 title-preview）。
class SubscribeSeed {
  const SubscribeSeed({
    required this.titleRef,
    this.title,
    this.posterUrl,
    this.year,
    this.kind,
  });

  final String titleRef;
  final String? title;
  final String? posterUrl;
  final int? year;
  final String? kind;
}

/// 订阅创建弹层（对齐 SubscribeSheetHost.kt → SubscribeScreen）：
/// 浮在页面上的底部抽屉而非路由——关闭即还原；季勾选（默认全选已播季）+
/// 自动续订开关 + 规则组选择（默认系统默认组）→ POST /subscriptions；
/// 重复订阅幂等返回已有订阅，onCreated 带回已有订阅 id。
Future<void> showSubscribeSheet(BuildContext context, SubscribeSeed seed) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF141A21),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SubscribeSheet(seed: seed),
  );
}

class _SubscribeSheet extends ConsumerStatefulWidget {
  const _SubscribeSheet({required this.seed});

  final SubscribeSeed seed;

  @override
  ConsumerState<_SubscribeSheet> createState() => _SubscribeSheetState();
}

class _SubscribeSheetState extends ConsumerState<_SubscribeSheet> {
  PrepareView? _prepare;
  bool _loading = true;
  String? _error;
  final Set<int> _selected = {};
  bool _followFuture = false;
  int? _ruleSetId;
  List<RuleSetView> _ruleSets = const [];
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare_());
  }

  Future<void> _prepare_() async {
    final api = ref.read(subscriptionsApiProvider);
    try {
      final p = await api.titlePreview(widget.seed.titleRef);
      if (!mounted) return;
      setState(() {
        _prepare = p;
        _loading = false;
        // 默认全选已播季（suggested_seasons 优先，退化为全部 aired 季）
        final seasons = p.suggestedSeasons.isNotEmpty
            ? p.suggestedSeasons
            : [
                for (final s in p.seasons)
                  if (s.airedCount > 0) s.seasonNumber,
              ];
        _selected.addAll(seasons);
      });
      // 规则组只有超管可读：失败就静默降级为「系统默认」
      try {
        final rs = await api.ruleSets();
        if (mounted) {
          setState(() {
            _ruleSets = rs;
            _ruleSetId = rs.where((r) => r.isDefault).firstOrNull?.id ??
                rs.firstOrNull?.id;
          });
        }
      } catch (e) {
        McErrorLog.log(e, context: 'subscribeSheet.ruleSets');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '预检失败：$e';
        });
      }
    }
  }

  Future<void> _create() async {
    final p = _prepare;
    if (p == null || _creating) return;
    setState(() => _creating = true);
    final api = ref.read(subscriptionsApiProvider);
    try {
      final sub = await api.create(
        titleRef: widget.seed.titleRef,
        selectedSeasons: _selected.toList()..sort(),
        followFuture: _followFuture,
        ruleSetId: _ruleSetId,
      );
      ref.read(subscriptionIndexProvider).invalidate();
      SubscriptionEvents.notifyChanged();
      if (!mounted) return;
      Navigator.of(context).pop(sub.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _error = '创建失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _prepare?.media?.title ?? widget.seed.title ?? '';
    final poster = _prepare?.media?.posterUrl ?? widget.seed.posterUrl;
    final year = _prepare?.media?.year ?? widget.seed.year;
    final existing = _prepare?.existingSubscriptionId;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 64,
                    height: 96,
                    child: poster != null
                        ? Image.network(
                            headers: mcImageHeaders(),
                            poster,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.white10))
                        : Container(color: Colors.white10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      if (year != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('$year',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5))),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(McIcons.close2),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: McLoadingView(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: McErrorView(text: _error!),
              )
            else ...[
              if (existing != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('已订阅该作品（幂等返回已有订阅）',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6))),
                ),
              // 季勾选（默认全选已播季）
              for (final s in _prepare!.seasons)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(s.seasonNumber),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    s.name ?? '第 ${s.seasonNumber} 季 · ${s.episodesLine}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: s.airDate != null
                      ? Text(s.airDate!,
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.45)))
                      : null,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(s.seasonNumber);
                    } else {
                      _selected.remove(s.seasonNumber);
                    }
                  }),
                ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _followFuture,
                title: const Text('自动续订', style: TextStyle(fontSize: 13)),
                subtitle: Text('未来新一季自动纳入追踪',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.45))),
                onChanged: (v) => setState(() => _followFuture = v),
              ),
              // 规则组（默认系统默认组；非管理员读不到列表则不显示）
              if (_ruleSets.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: _ruleSetId,
                  decoration: const InputDecoration(
                    labelText: '规则组',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final r in _ruleSets)
                      DropdownMenuItem(
                        value: r.id,
                        child: Text('${r.name}（${specSummary(r.spec)}）',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _ruleSetId = v),
                ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    (_creating || _loading || _error != null) ? null : _create,
                child: Text(existing != null
                    ? '查看已有订阅'
                    : (_creating ? '创建中…' : '创建订阅')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
