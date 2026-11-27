import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/theme.dart';
import '../state/controllers.dart';
import '../state/models.dart';
import '../state/reels_api.dart';

/// 片段流多选毛玻璃筛选面板（维内多选 OR、维间 AND，每次勾选实时刷新 `/reels/facets` 剩余计数）。
Future<ReelFilter?> showReelFilterSheet(
  BuildContext context,
  ReelsState state,
) {
  return showMcSheet<ReelFilter>(
    context: context,
    builder: (_) => _ReelFilterSheet(
      initial: state.filter,
      initialFacets: state.facets,
    ),
  );
}

class _ReelFilterSheet extends ConsumerStatefulWidget {
  const _ReelFilterSheet({required this.initial, this.initialFacets});

  final ReelFilter initial;
  final ReelFacetsView? initialFacets;

  @override
  ConsumerState<_ReelFilterSheet> createState() => _ReelFilterSheetState();
}

class _ReelFilterSheetState extends ConsumerState<_ReelFilterSheet> {
  late ReelFilter _draft = widget.initial;
  late ReelFacetsView? _facets = widget.initialFacets;
  bool _refreshing = false;
  int _requestSeq = 0;

  void _update(ReelFilter next) {
    setState(() => _draft = next);
    unawaited(_refreshFacets(next));
  }

  Future<void> _refreshFacets(ReelFilter filter) async {
    final seq = ++_requestSeq;
    setState(() => _refreshing = true);
    try {
      final latest = await ref.read(reelsApiProvider).facets(filter: filter);
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _facets = latest;
        _refreshing = false;
      });
    } catch (_) {
      if (mounted && seq == _requestSeq) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final facets = _facets;
    final filterable = _draft.kind != 'video' && (facets?.filterable ?? true);
    final total = facets?.total;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.80,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text('筛选片段', style: McText.titleSm),
                      if (total != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '共 $total 部',
                          style: McText.caption.muted.tabular,
                        ),
                      ],
                      if (_refreshing) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.6),
                        ),
                      ],
                    ],
                  ),
                ),
                McPressable(
                  onTap: () => _update(const ReelFilter()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      '重置',
                      style: McText.sub.copyWith(color: McTokens.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              children: [
                if (facets != null) ...[
                  _SingleFacetRow(
                    title: '类型',
                    values: facets.kinds,
                    selected: _draft.kind,
                    enabled: true,
                    onSelect: (v) {
                      if (v == 'video') {
                        _update(ReelFilter(kind: 'video', watch: _draft.watch));
                      } else {
                        _update(
                          _draft.copyWith(kind: v, clearKind: v == null),
                        );
                      }
                    },
                  ),
                  _SingleFacetRow(
                    title: '观看状态',
                    values: facets.watch,
                    selected: _draft.watch,
                    enabled: true,
                    onSelect: (v) => _update(
                      _draft.copyWith(watch: v, clearWatch: v == null),
                    ),
                  ),
                  if (filterable) ...[
                    _MultiFacetRow(
                      title: '题材（可多选）',
                      values: facets.genres,
                      selected: _draft.genres,
                      onToggle: (v) => _update(
                        _draft.copyWith(
                          genres: ReelFilter.toggleInSet(_draft.genres, v),
                        ),
                      ),
                    ),
                    _MultiFacetRow(
                      title: '地区（可多选）',
                      values: facets.countries,
                      selected: _draft.countries,
                      onToggle: (v) => _update(
                        _draft.copyWith(
                          countries:
                              ReelFilter.toggleInSet(_draft.countries, v),
                        ),
                      ),
                    ),
                    _MultiFacetRow(
                      title: '年代（可多选）',
                      values: facets.decades,
                      selected: _draft.decades,
                      onToggle: (v) => _update(
                        _draft.copyWith(
                          decades: ReelFilter.toggleInSet(_draft.decades, v),
                        ),
                      ),
                    ),
                    _SingleFacetRow(
                      title: '评分',
                      values: facets.ratings,
                      selected: _draft.ratingGte?.toString(),
                      enabled: true,
                      onSelect: (v) => _update(
                        _draft.copyWith(
                          ratingGte: v == null ? null : double.tryParse(v),
                          clearRating: v == null,
                        ),
                      ),
                    ),
                    _MultiFacetRow(
                      title: '片长（可多选）',
                      values: facets.runtimes,
                      selected: _draft.runtimes,
                      onToggle: (v) => _update(
                        _draft.copyWith(
                          runtimes: ReelFilter.toggleInSet(_draft.runtimes, v),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: McActionPill(
              label: total != null ? '应用筛选（$total 部）' : '应用筛选',
              primary: true,
              expanded: true,
              height: 44,
              onTap: () => Navigator.of(context).pop(_draft),
            ),
          ),
        ],
      ),
    );
  }
}

class _SingleFacetRow extends StatelessWidget {
  const _SingleFacetRow({
    required this.title,
    required this.values,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final String title;
  final List<FacetValue> values;
  final String? selected;
  final bool enabled;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: McText.caption.copyWith(
                color: McTokens.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                Opacity(
                  opacity:
                      (enabled && (v.count > 0 || selected == v.value))
                          ? 1.0
                          : 0.35,
                  child: McChip(
                    label: v.count > 0 ? '${v.label} · ${v.count}' : v.label,
                    compact: true,
                    selected: selected == v.value,
                    onTap: (enabled && (v.count > 0 || selected == v.value))
                        ? () => onSelect(selected == v.value ? null : v.value)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MultiFacetRow extends StatelessWidget {
  const _MultiFacetRow({
    required this.title,
    required this.values,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<FacetValue> values;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: McText.caption.copyWith(
                color: McTokens.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                Builder(
                  builder: (_) {
                    final isSel = selected.contains(v.value);
                    final active = isSel || v.count > 0;
                    return Opacity(
                      opacity: active ? 1.0 : 0.35,
                      child: McChip(
                        label:
                            v.count > 0 ? '${v.label} · ${v.count}' : v.label,
                        compact: true,
                        selected: isSel,
                        onTap: active ? () => onToggle(v.value) : null,
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
