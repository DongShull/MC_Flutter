import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/subscriptions_api.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/rule_set_editor_sheet.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/session/permissions.dart';
import '../state/mc_api.dart';
import '../state/models.dart';

/// 订阅详情页「更多」管理抽屉动作。
enum SubscriptionManageAction {
  adjust,
  upgradeRun,
  toggleFollow,
  switchRule,
  smartDefaults,
  togglePause,
  remove,
}

/// 弹出「更多」管理抽屉（按权限裁剪，1:1 对齐 iOS `SubscriptionManageSheet`）。
Future<SubscriptionManageAction?> showSubscriptionManageSheet(
  BuildContext context, {
  required SubscriptionView detail,
  required McPermissions permissions,
  required bool busy,
}) {
  final isMovie = detail.media.kind == 'movie';
  final canTune = permissions.canSubscribe && detail.canManage;
  final canSwitchRule = permissions.canManageSubscriptions && !detail.isSmart;
  final canEditSmart = permissions.canManageSubscriptions && detail.isSmart;
  final paused = detail.status == 'paused';
  final completed = detail.status == 'completed';

  return showMcSheet<SubscriptionManageAction>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canTune || canSwitchRule || canEditSmart)
            McInsetGroup(
              header: detail.media.title,
              margin: EdgeInsets.zero,
              children: [
                if (canTune)
                  McInsetRow(
                    icon: McIcons.playListAdd,
                    title: '调整订阅',
                    subtitle: isMovie ? '调整目标媒体库' : '修改追踪季与目标媒体库',
                    showChevron: true,
                    onTap: busy
                        ? null
                        : () => Navigator.of(ctx)
                            .pop(SubscriptionManageAction.adjust),
                  ),
                if (canTune)
                  McInsetRow(
                    icon: McIcons.aiStarFill,
                    title: '洗一轮版',
                    subtitle: '体检现有库存并排期升级画质',
                    showChevron: true,
                    onTap: busy
                        ? null
                        : () => Navigator.of(ctx)
                            .pop(SubscriptionManageAction.upgradeRun),
                  ),
                if (canTune && !isMovie)
                  McInsetRow(
                    icon: McIcons.clockFill,
                    title: detail.followFuture ? '关闭自动续订' : '开启自动续订',
                    onTap: busy
                        ? null
                        : () => Navigator.of(ctx)
                            .pop(SubscriptionManageAction.toggleFollow),
                  ),
                if (canSwitchRule)
                  McInsetRow(
                    icon: McIcons.listSettings2,
                    title: '更换规则组',
                    showChevron: true,
                    onTap: busy
                        ? null
                        : () => Navigator.of(ctx)
                            .pop(SubscriptionManageAction.switchRule),
                  ),
                if (canEditSmart)
                  McInsetRow(
                    icon: McIcons.setting1,
                    title: '智能默认偏好与记忆',
                    showChevron: true,
                    onTap: busy
                        ? null
                        : () => Navigator.of(ctx)
                            .pop(SubscriptionManageAction.smartDefaults),
                  ),
                if (canTune)
                  McInsetRow(
                    icon: McIcons.pauseCircle,
                    title: paused ? '恢复追踪' : '暂停追踪',
                    subtitle: completed ? '已收齐，无需暂停' : null,
                    onTap: (busy || completed)
                        ? null
                        : () => Navigator.of(ctx)
                            .pop(SubscriptionManageAction.togglePause),
                  ),
              ],
            ),
          if (permissions.canSubscribe) ...[
            const SizedBox(height: 12),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  icon: McIcons.linkUnlink,
                  title: '取消订阅',
                  destructive: true,
                  onTap: busy
                      ? null
                      : () => Navigator.of(ctx)
                          .pop(SubscriptionManageAction.remove),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

/// 管理员取消订阅确认弹层（带 removal-preview、H&R 警示与删种/删库勾选）。
Future<({bool confirmed, String? cleanupJobId})?> showSubscriptionCancelSheet(
  BuildContext context,
  WidgetRef ref, {
  required int subscriptionId,
  required String title,
}) async {
  String? cleanupJobId;
  final ok = await showMcSheet<bool>(
    context: context,
    builder: (_) => AdminCancelSubscriptionSheet(
      subscriptionId: subscriptionId,
      title: title,
      onConfirm: (torrents, files) async {
        final res = await ref.read(subscriptionsApiProvider).delete(
              subscriptionId,
              deleteTorrents: torrents,
              deleteLibraryFiles: files,
            );
        cleanupJobId = res.cleanupJobId;
      },
    ),
  );
  if (ok == true) {
    return (confirmed: true, cleanupJobId: cleanupJobId);
  }
  return null;
}

/// 更换规则组弹层（1:1 对齐 iOS `RuleSetSwitchSheet`）。
Future<bool?> showRuleSetSwitchSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<RuleSetView> ruleSets,
  required int currentId,
  required Future<void> Function(int ruleSetId) onPick,
}) {
  return showMcSheet<bool>(
    context: context,
    builder: (_) => _RuleSetSwitchSheet(
      ruleSets: ruleSets,
      currentId: currentId,
      onPick: onPick,
    ),
  );
}

class _RuleSetSwitchSheet extends StatefulWidget {
  const _RuleSetSwitchSheet({
    required this.ruleSets,
    required this.currentId,
    required this.onPick,
  });

  final List<RuleSetView> ruleSets;
  final int currentId;
  final Future<void> Function(int ruleSetId) onPick;

  @override
  State<_RuleSetSwitchSheet> createState() => _RuleSetSwitchSheetState();
}

class _RuleSetSwitchSheetState extends State<_RuleSetSwitchSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _select(int id) async {
    if (id == widget.currentId) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onPick(id);
      if (mounted) Navigator.of(context).pop(true);
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
          _error = '更换失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('更换规则组', style: McText.title),
          const SizedBox(height: 4),
          Text('仅影响之后的资源匹配与洗版评估', style: McText.caption.muted),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: McText.caption.copyWith(color: SubsColor.danger),
            ),
          ],
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: McInsetGroup(
                margin: EdgeInsets.zero,
                children: [
                  for (final r in widget.ruleSets)
                    Builder(
                      builder: (_) {
                        final chips =
                            RuleSetSpecFormatter.summaryChips(r.typedSpec);
                        final selected = r.id == widget.currentId;
                        return McInsetRow(
                          leading: Icon(
                            selected
                                ? McIcons.checkCircleFill
                                : McIcons.circler,
                            size: 20,
                            color: selected
                                ? McTokens.accentStrong
                                : McTokens.textFaint,
                          ),
                          title: r.isDefault ? '${r.name}（默认）' : r.name,
                          subtitle: chips.isEmpty
                              ? '未限制条件'
                              : chips.join(' · '),
                          onTap: _busy ? null : () => _select(r.id),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 调整订阅弹层（加载全量季列表、支持修改或清除 `library_id`、减季后进入 `SeasonCleanupSheet`）。
Future<bool?> showSubscriptionAdjustSheet(
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
      child: SubscriptionAdjustSheet(detail: detail),
    ),
  );
}

class SubscriptionAdjustSheet extends ConsumerStatefulWidget {
  const SubscriptionAdjustSheet({super.key, required this.detail});

  final SubscriptionView detail;

  @override
  ConsumerState<SubscriptionAdjustSheet> createState() =>
      _SubscriptionAdjustSheetState();
}

class _SubscriptionAdjustSheetState
    extends ConsumerState<SubscriptionAdjustSheet> {
  List<SeasonOverview>? _seasons;
  List<LibraryBrief> _libraries = const [];
  final Set<int> _selected = {};
  int? _libraryId; // null = 按默认库路由
  DispatchPreviewView? _preview;
  bool _busy = false;
  String? _error;

  /// 第二步：减季清理确认态
  ({List<int> seasons, SubscriptionRemovalPreviewView preview})? _cleanup;

  McPermissions get _perms => ref.read(permissionsProvider);
  bool get _isMovie => widget.detail.media.kind == 'movie';

  bool get _seasonsChanged {
    if (_isMovie) return false;
    final a = _selected.toList()..sort();
    final b = [...widget.detail.selectedSeasons]..sort();
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }

  bool get _libraryChanged =>
      _perms.canManageSubscriptions && _libraryId != widget.detail.libraryId;

  List<int> get _droppedWithProgress {
    if (_isMovie) return const [];
    final progressed = widget.detail.wanted
        .where((w) => w.status != 'wanted')
        .map((w) => w.seasonNumber)
        .toSet();
    return widget.detail.selectedSeasons
        .where((s) => !_selected.contains(s) && progressed.contains(s))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.detail.selectedSeasons);
    _libraryId = widget.detail.libraryId;
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final api = ref.read(subscriptionsApiProvider);
    try {
      if (!_isMovie && widget.detail.media.tmdbId != null) {
        final p = await api.titlePreview(
          'tmdb:${widget.detail.media.kind}:${widget.detail.media.tmdbId}',
        );
        if (mounted) {
          setState(() {
            _seasons = p.status == 'ready'
                ? p.seasons
                : widget.detail.seasonCollection;
          });
        }
      } else if (!_isMovie) {
        if (mounted) {
          setState(() => _seasons = widget.detail.seasonCollection);
        }
      }
      if (_perms.canManageSubscriptions) {
        final libs = await api.libraries(kind: widget.detail.media.kind);
        if (mounted) setState(() => _libraries = libs);
        await _loadRoutingPreview();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _seasons ??= widget.detail.seasonCollection;
          _error = '读取订阅配置失败';
        });
      }
    }
  }

  Future<void> _loadRoutingPreview() async {
    if (!_perms.canManageSubscriptions) return;
    try {
      final p = await ref.read(subscriptionsApiProvider).downloadRoutingPreview(
            kind: widget.detail.media.kind,
            libraryId: _libraryId,
            tmdbId: widget.detail.media.tmdbId,
          );
      if (mounted) setState(() => _preview = p);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = ref.read(subscriptionsApiProvider);
    final dropped = _seasonsChanged
        ? widget.detail.selectedSeasons
            .where((s) => !_selected.contains(s))
            .toList()
        : const <int>[];

    final patch = <String, dynamic>{};
    if (_seasonsChanged) {
      patch['selected_seasons'] = _selected.toList()..sort();
    }
    if (_libraryChanged) {
      // 显式写入 null 表示清除指定库、恢复默认库路由
      patch['library_id'] = _libraryId;
    }

    try {
      await api.update(widget.detail.id, patch);
      McToast.success('订阅设置已保存');
      if (dropped.isNotEmpty && _perms.canManageSubscriptions) {
        try {
          final plan = await api.removalPreview(
            widget.detail.id,
            seasons: dropped,
          );
          if (plan.torrentCount > 0 || plan.libraryFileCount > 0) {
            if (mounted) {
              setState(() {
                _busy = false;
                _cleanup = (seasons: dropped, preview: plan);
              });
            }
            return;
          }
        } catch (_) {
          McToast.info('已保存选季，但读取可清理内容失败');
        }
      }
      if (mounted) Navigator.of(context).pop(true);
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
          _error = '保存失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanup = _cleanup;
    if (cleanup != null) {
      return SeasonCleanupSheet(
        subscriptionId: widget.detail.id,
        title: widget.detail.media.title,
        seasons: cleanup.seasons,
        preview: cleanup.preview,
        onFinished: () => Navigator.of(context).pop(true),
      );
    }

    final canSave = (_seasonsChanged || _libraryChanged) &&
        (_isMovie || _selected.isNotEmpty) &&
        !_busy;

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
                    const Text('调整订阅', style: McText.title),
                    const SizedBox(height: 2),
                    Text(
                      widget.detail.media.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.caption.muted,
                    ),
                  ],
                ),
              ),
              McActionPill(
                label: _busy ? '保存中…' : '保存',
                primary: true,
                busy: _busy,
                height: 36,
                onTap: canSave ? _save : null,
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
                  Text(
                    _error!,
                    style: McText.caption.copyWith(color: SubsColor.danger),
                  ),
                  const SizedBox(height: 10),
                ],
                if (!_isMovie) ...[
                  Text('选择追踪季', style: McText.caption.semibold.muted),
                  const SizedBox(height: 8),
                  if (_seasons == null)
                    const SizedBox(height: 80, child: McLoadingView())
                  else
                    McInsetGroup(
                      margin: EdgeInsets.zero,
                      children: [
                        for (final s in _seasons!)
                          McInsetRow(
                            leading: Icon(
                              _selected.contains(s.seasonNumber)
                                  ? McIcons.checkCircleFill
                                  : McIcons.circler,
                              size: 20,
                              color: _selected.contains(s.seasonNumber)
                                  ? McTokens.accentStrong
                                  : McTokens.textFaint,
                            ),
                            title: SubsFormat.seasonName(s.seasonNumber),
                            subtitle:
                                '${s.episodesLine}${s.ownedCount > 0 ? ' · 已入库 ${s.ownedCount} 集' : ''}',
                            onTap: _busy
                                ? null
                                : () => setState(() {
                                      if (!_selected.remove(s.seasonNumber)) {
                                        _selected.add(s.seasonNumber);
                                      }
                                    }),
                          ),
                      ],
                    ),
                  if (_droppedWithProgress.isNotEmpty) ...[
                    const SizedBox(height: 10),
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
                        '${SubsFormat.seasonList(_droppedWithProgress)}已有下载或入库记录。'
                        '${_perms.canManageSubscriptions ? '保存后可选择是否清理这些季的种子和媒体库文件。' : '移出范围后将保留已有内容。'}',
                        style: McText.caption.copyWith(color: SubsColor.warn),
                      ),
                    ),
                  ],
                ],
                if (_perms.canManageSubscriptions && _libraries.isNotEmpty) ...[
                  if (!_isMovie) const SizedBox(height: 16),
                  Text('入库目标媒体库', style: McText.caption.semibold.muted),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      McChip(
                        label: '按默认库路由',
                        selected: _libraryId == null,
                        compact: true,
                        onTap: _busy
                            ? null
                            : () {
                                setState(() => _libraryId = null);
                                _loadRoutingPreview();
                              },
                      ),
                      for (final lib in _libraries)
                        McChip(
                          label: lib.isDefault ? '${lib.name}（默认）' : lib.name,
                          selected: _libraryId == lib.id,
                          compact: true,
                          onTap: _busy
                              ? null
                              : () {
                                  setState(() => _libraryId = lib.id);
                                  _loadRoutingPreview();
                                },
                        ),
                    ],
                  ),
                  if (_preview != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _preview!.ok
                          ? _preview!.formattedPathNote(adjusting: true)
                          : (_preview!.warning ?? '该媒体库暂无法自动入库'),
                      style: McText.micro.copyWith(
                        color: _preview!.ok ? McTokens.textMuted : SubsColor.warn,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 减季后的清理追问弹层（1:1 对齐 iOS `SeasonCleanupContent`）。
class SeasonCleanupSheet extends ConsumerStatefulWidget {
  const SeasonCleanupSheet({
    super.key,
    required this.subscriptionId,
    required this.title,
    required this.seasons,
    required this.preview,
    required this.onFinished,
  });

  final int subscriptionId;
  final String title;
  final List<int> seasons;
  final SubscriptionRemovalPreviewView preview;
  final VoidCallback onFinished;

  @override
  ConsumerState<SeasonCleanupSheet> createState() => _SeasonCleanupSheetState();
}

class _SeasonCleanupSheetState extends ConsumerState<SeasonCleanupSheet> {
  bool _deleteTorrents = false;
  bool _deleteFiles = false;
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(subscriptionsApiProvider).cleanupSeasons(
            widget.subscriptionId,
            seasons: widget.seasons,
            deleteTorrents: _deleteTorrents,
            deleteLibraryFiles: _deleteFiles,
          );
      McToast.success('已启动后台清理任务');
      if (mounted) widget.onFinished();
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
          _error = '清理失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = SubsFormat.seasonList(widget.seasons);
    final p = widget.preview;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('已移出 $label', style: McText.title),
          const SizedBox(height: 6),
          Text(
            '《${widget.title}》的 $label 已移出订阅范围。是否一并清理相关种子或媒体库文件？',
            style: McText.sub.muted,
          ),
          const SizedBox(height: 14),
          McInsetGroup(
            margin: EdgeInsets.zero,
            children: [
              McInsetRow(
                leading: Checkbox(
                  value: _deleteTorrents,
                  onChanged: (p.torrentCount == 0 || _busy)
                      ? null
                      : (v) => setState(() => _deleteTorrents = v == true),
                ),
                title: p.torrentCount == 0
                    ? '$label 没有可清理的下载任务'
                    : '删除 $label 的 ${p.torrentCount} 个下载任务',
                subtitle:
                    p.torrentCount == 0 ? null : '从下载器删除任务及数据文件（不可恢复）',
                onTap: (p.torrentCount == 0 || _busy)
                    ? null
                    : () => setState(() => _deleteTorrents = !_deleteTorrents),
              ),
              McInsetRow(
                leading: Checkbox(
                  value: _deleteFiles,
                  onChanged: (p.libraryFileCount == 0 || _busy)
                      ? null
                      : (v) => setState(() => _deleteFiles = v == true),
                ),
                title: p.libraryFileCount == 0
                    ? '$label 没有可清理的媒体库文件'
                    : '删除 $label 的 ${p.libraryFileCount} 个媒体库文件（${SubsFormat.bytes(p.libraryBytes)}）',
                subtitle: p.libraryFileCount == 0
                    ? null
                    : '移入回收站保留 ${p.recycleRetentionDays} 天，期间可恢复',
                onTap: (p.libraryFileCount == 0 || _busy)
                    ? null
                    : () => setState(() => _deleteFiles = !_deleteFiles),
              ),
            ],
          ),
          if (_deleteTorrents && p.hitAndRunCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SubsColor.warn.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SubsColor.warn.withValues(alpha: 0.4)),
              ),
              child: Text(
                '注意：其中有 ${p.hitAndRunCount} 个任务处于 H&R 考核或状态未知，删除可能影响站点考核。',
                style: McText.caption.copyWith(color: SubsColor.warn),
              ),
            ),
          ],
          if (p.retainedCrossSeason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SubsColor.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SubsColor.info.withValues(alpha: 0.35)),
              ),
              child: Text(
                p.retainedCrossSeason.first.seasons.isEmpty
                    ? '有 ${p.retainedCrossSeason.length} 个跨季合集种子仍被其他季使用，已自动保护保留。'
                    : '有 ${p.retainedCrossSeason.length} 个跨季种子（覆盖 ${SubsFormat.seasonList(p.retainedCrossSeason.first.seasons)}）仍被其他季使用，已自动保护保留。',
                style: McText.caption.copyWith(color: SubsColor.info),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: McText.caption.copyWith(color: SubsColor.danger),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: '保留内容',
                  primary: false,
                  expanded: true,
                  onTap: _busy ? null : widget.onFinished,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: McActionPill(
                  label: _busy ? '正在清理…' : '清理 $label',
                  primary: false,
                  tone: McGlassTone.danger,
                  expanded: true,
                  busy: _busy,
                  onTap: (_busy || !(_deleteTorrents || _deleteFiles))
                      ? null
                      : _confirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 定制取消键文案的确认弹窗（与 iOS `SubsConfirmCenter` 同口径：「返回」/「先不」不和「取消订阅」混）。
Future<bool> showSubsConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmTitle,
  required String cancelTitle,
  bool destructive = false,
}) async {
  final res = await showMcSheet<bool>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: McText.titleSm),
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message, style: McText.sub.muted),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: McActionPill(
                  label: cancelTitle,
                  primary: false,
                  expanded: true,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: McActionPill(
                  label: confirmTitle,
                  primary: !destructive,
                  tone: destructive ? McGlassTone.danger : McGlassTone.primary,
                  expanded: true,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return res == true;
}
