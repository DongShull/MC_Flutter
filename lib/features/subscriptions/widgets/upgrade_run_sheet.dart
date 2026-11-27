import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/subscriptions_api.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/rule_set_editor_sheet.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/session/permissions.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import 'media_source_annotation_sheet.dart';

/// 弹出两段式「洗一轮版」弹层（确认段 → 体检报告段，1:1 对齐 iOS `UpgradeRunSheet.swift`）。
/// 返回 true 表示已触发洗版，父页面应刷新详情与索引。
Future<bool?> showUpgradeRunSheet(
  BuildContext context,
  WidgetRef ref, {
  required SubscriptionView detail,
}) {
  return showMcSheet<bool>(
    context: context,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
      ),
      child: UpgradeRunSheet(detail: detail),
    ),
  );
}

class UpgradeRunSheet extends ConsumerStatefulWidget {
  const UpgradeRunSheet({super.key, required this.detail});

  final SubscriptionView detail;

  @override
  ConsumerState<UpgradeRunSheet> createState() => _UpgradeRunSheetState();
}

class _UpgradeRunSheetState extends ConsumerState<UpgradeRunSheet> {
  List<RuleSetView>? _ruleSets;
  int? _ruleSetId;
  final Set<int> _optedSeasons = {};
  bool _busy = false;
  String? _error;
  UpgradeRunView? _report;

  McPermissions get _perms => ref.read(permissionsProvider);
  bool get _isMovie => widget.detail.media.kind == 'movie';
  bool get _paused => widget.detail.status == 'paused';
  bool get _picksRule => _perms.canManageSubscriptions && !widget.detail.isSmart;

  List<RuleSetView> get _upgradeRules =>
      (_ruleSets ?? const []).where((r) => r.upgradeTarget != null).toList();

  bool get _currentHasTarget => (_ruleSets ?? const [])
      .any((r) => r.id == widget.detail.ruleSetId && r.upgradeTarget != null);

  RuleSetView? get _selectedRule {
    for (final r in _upgradeRules) {
      if (r.id == _ruleSetId) return r;
    }
    return null;
  }

  bool get _canRun {
    if (_busy) return false;
    if (widget.detail.isSmart) {
      return widget.detail.smartPreferences?.allowUpgrade == true;
    }
    return !_picksRule || _selectedRule != null;
  }

  List<SeasonOverview> get _outOfScopeOwned => _isMovie
      ? const []
      : widget.detail.seasonCollection
          .where(
            (s) =>
                s.ownedCount > 0 &&
                !widget.detail.selectedSeasons.contains(s.seasonNumber),
          )
          .toList();

  @override
  void initState() {
    super.initState();
    if (_picksRule) {
      _loadRules();
    }
  }

  Future<void> _loadRules() async {
    try {
      final rules = await ref.read(subscriptionsApiProvider).ruleSets();
      if (!mounted) return;
      int? picked;
      final cur = rules
          .where((r) => r.id == widget.detail.ruleSetId && r.upgradeTarget != null)
          .firstOrNull;
      if (cur != null) {
        picked = cur.id;
      } else {
        final candidates = rules.where((r) => r.upgradeTarget != null).toList();
        if (candidates.length == 1) picked = candidates.first.id;
      }
      setState(() {
        _ruleSets = rules;
        _ruleSetId = picked;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _ruleSets = const [];
          _error = '读取规则组失败';
        });
      }
    }
  }

  Future<void> _createRuleSet() async {
    final saved = await showRuleSetEditorSheet(context, ref);
    if (!mounted || saved == null) return;
    final view = RuleSetView(
      id: saved.id,
      name: saved.name,
      isDefault: saved.isDefault,
      referenceCount: saved.referenceCount,
      spec: saved.spec,
      matchRules: saved.matchRules,
    );
    setState(() {
      _ruleSets = [...?_ruleSets, view];
      if (view.upgradeTarget != null) {
        _ruleSetId = view.id;
      }
    });
  }

  Future<void> _run() async {
    if (!_canRun) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = ref.read(subscriptionsApiProvider);
    try {
      if (_optedSeasons.isNotEmpty) {
        final merged = {
          ...widget.detail.selectedSeasons,
          ..._optedSeasons,
        }.toList()
          ..sort();
        await api.update(widget.detail.id, {'selected_seasons': merged});
      }
      if (_paused) {
        await api.setTrackingState(widget.detail.id, paused: false);
      }
      int? switchTo;
      if (_selectedRule != null && _selectedRule!.id != widget.detail.ruleSetId) {
        switchTo = _selectedRule!.id;
      }
      final report = await api.upgradeRun(
        widget.detail.id,
        ruleSetId: switchTo,
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _report = report;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.friendlyMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '触发洗版失败：$e';
        });
      }
    }
  }

  Future<void> _annotateSeason(int season) async {
    final msg = await showMediaSourceAnnotationSheet(
      context,
      ref,
      mediaItemId: widget.detail.media.mediaItemId,
      seasonNumber: season,
      isMovie: _isMovie,
    );
    if (!mounted || msg == null) return;
    McToast.success(msg);
    try {
      final fresh =
          await ref.read(subscriptionsApiProvider).upgradeRun(widget.detail.id);
      if (mounted) setState(() => _report = fresh);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(true);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 10),
              child: Row(
                children: [
                  const Expanded(child: Text('洗版体检报告', style: McText.title)),
                  McActionPill(
                    label: '完成',
                    primary: true,
                    height: 36,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: McTokens.line),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
                child: UpgradeReportBody(
                  title: widget.detail.media.title,
                  isMovie: _isMovie,
                  report: report,
                  canAnnotate: _perms.isAdmin,
                  onAnnotate: _annotateSeason,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('洗一轮版', style: McText.title),
                    const SizedBox(height: 2),
                    Text(
                      '体检《${widget.detail.media.title}》现有库存并排入洗版搜索',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.caption.muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              McActionPill(
                label: _busy
                    ? '体检中…'
                    : (_paused ? '恢复并洗版' : '开始洗版'),
                primary: true,
                busy: _busy,
                height: 36,
                onTap: _canRun ? _run : null,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: McTokens.line),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SubsColor.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: SubsColor.danger.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: McText.caption.copyWith(color: SubsColor.danger),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_paused) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SubsColor.warn.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: SubsColor.warn.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '当前订阅已暂停追踪，开始洗版将自动恢复追踪。',
                      style: McText.caption.copyWith(color: SubsColor.warn),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildTargetSection(),
                if (_outOfScopeOwned.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('媒体库已有但不在订阅范围的季', style: McText.caption.semibold.muted),
                  const SizedBox(height: 6),
                  McInsetGroup(
                    margin: EdgeInsets.zero,
                    children: [
                      for (final s in _outOfScopeOwned)
                        McInsetRow(
                          leading: Icon(
                            _optedSeasons.contains(s.seasonNumber)
                                ? McIcons.checkCircleFill
                                : McIcons.circler,
                            size: 20,
                            color: _optedSeasons.contains(s.seasonNumber)
                                ? SubsColor.upgrade
                                : McTokens.textFaint,
                          ),
                          title: SubsFormat.seasonName(s.seasonNumber),
                          subtitle: (s.episodeCount != null &&
                                  s.ownedCount < s.episodeCount!)
                              ? '已有 ${s.ownedCount} / ${s.episodeCount} 集'
                              : '已有 ${s.ownedCount} 集',
                          onTap: _busy
                              ? null
                              : () => setState(() {
                                    if (!_optedSeasons.remove(s.seasonNumber)) {
                                      _optedSeasons.add(s.seasonNumber);
                                    }
                                  }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '勾选后将并入本订阅范围一并体检洗版（未入库的缺失集也会随之补缺）。',
                    style: McText.micro.faint,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetSection() {
    if (widget.detail.isSmart) {
      final pref = widget.detail.smartPreferences;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: McTokens.line),
        ),
        child: pref == null
            ? Text('无法读取智能订阅策略，暂不能洗版。', style: McText.caption.muted)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('智能洗版目标：${pref.targetLabel}', style: McText.ui.semibold),
                  const SizedBox(height: 4),
                  Text(
                    pref.allowUpgrade
                        ? '已开启自动洗版，将为低于目标档位的已入库内容排期搜索。'
                        : '当前智能订阅未开启允许洗版，请先在智能设置中开启。',
                    style: McText.caption.muted,
                  ),
                ],
              ),
      );
    }

    if (!_picksRule) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: McTokens.surfaceInset,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: McTokens.line),
        ),
        child: Text('将沿用本订阅当前配置的规则组执行一轮洗版。', style: McText.sub.muted),
      );
    }

    final rules = _ruleSets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('选择洗版规则组', style: McText.caption.semibold.muted),
            const Spacer(),
            GestureDetector(
              onTap: _busy ? null : _createRuleSet,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(McIcons.addS, size: 14, color: SubsColor.info),
                  const SizedBox(width: 3),
                  Text(
                    '新建规则组',
                    style: McText.micro.copyWith(color: SubsColor.info),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (rules == null)
          const SizedBox(height: 70, child: McLoadingView())
        else if (_upgradeRules.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: McTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前没有配置洗版目标的规则组，请先新建一个带洗版目标的规则组。',
                  style: McText.caption.muted,
                ),
                const SizedBox(height: 10),
                McActionPill(
                  label: '新建规则组',
                  icon: McIcons.addS,
                  primary: false,
                  height: 36,
                  onTap: _createRuleSet,
                ),
              ],
            ),
          )
        else ...[
          McInsetGroup(
            margin: EdgeInsets.zero,
            children: [
              for (final r in _upgradeRules)
                McInsetRow(
                  leading: Icon(
                    _ruleSetId == r.id
                        ? McIcons.checkCircleFill
                        : McIcons.circler,
                    size: 20,
                    color: _ruleSetId == r.id
                        ? SubsColor.upgrade
                        : McTokens.textFaint,
                  ),
                  title: r.id == widget.detail.ruleSetId
                      ? '${r.name}（当前）'
                      : r.name,
                  subtitle: '洗到 ${r.upgradeTarget ?? ''}',
                  onTap: _busy ? null : () => setState(() => _ruleSetId = r.id),
                ),
            ],
          ),
          if (!_currentHasTarget) ...[
            const SizedBox(height: 6),
            Text('当前规则组未配洗版目标，选择后将一并切换规则组并开始洗版。', style: McText.micro.faint),
          ],
        ],
      ],
    );
  }
}
