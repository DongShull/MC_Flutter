import 'package:flutter/material.dart';

import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/theme.dart';
import '../state/controllers.dart';
import '../state/models.dart';

/// 片段流毛玻璃筛选面板（使用 `showMcSheet` + `McChip` 胶囊与亮银白应用按钮）。
Future<ReelFilter?> showReelFilterSheet(
  BuildContext context,
  ReelsState state,
) {
  return showMcSheet<ReelFilter>(
    context: context,
    builder: (_) => _ReelFilterSheet(
      initial: state.filter,
      facets: state.facets,
    ),
  );
}

class _ReelFilterSheet extends StatefulWidget {
  const _ReelFilterSheet({required this.initial, this.facets});

  final ReelFilter initial;
  final ReelFacetsView? facets;

  @override
  State<_ReelFilterSheet> createState() => _ReelFilterSheetState();
}

class _ReelFilterSheetState extends State<_ReelFilterSheet> {
  late String? _kind = widget.initial.kind;
  late String? _genres = widget.initial.genres;
  late String? _countries = widget.initial.countries;
  late String? _decades = widget.initial.decades;
  late double? _ratingGte = widget.initial.ratingGte;
  late String? _runtimes = widget.initial.runtimes;
  late String? _watch = widget.initial.watch;

  ReelFilter get _filter => ReelFilter(
        kind: _kind,
        genres: _genres,
        countries: _countries,
        decades: _decades,
        ratingGte: _ratingGte,
        runtimes: _runtimes,
        watch: _watch,
      );

  @override
  Widget build(BuildContext context) {
    final facets = widget.facets;
    final filterable = facets?.filterable ?? true;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
            child: Row(
              children: [
                const Expanded(child: Text('筛选片段', style: McText.titleSm)),
                McPressable(
                  onTap: () => setState(() {
                    _kind = null;
                    _genres = null;
                    _countries = null;
                    _decades = null;
                    _ratingGte = null;
                    _runtimes = null;
                    _watch = null;
                  }),
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
                  _FacetRow(
                    title: '类型',
                    values: facets.kinds,
                    selected: _kind,
                    enabled: filterable,
                    onSelect: (v) => setState(() => _kind = v),
                  ),
                  _FacetRow(
                    title: '观看状态',
                    values: facets.watch,
                    selected: _watch,
                    enabled: true,
                    onSelect: (v) => setState(() => _watch = v),
                  ),
                  if (filterable) ...[
                    _FacetRow(
                      title: '题材',
                      values: facets.genres,
                      selected: _genres,
                      enabled: true,
                      onSelect: (v) => setState(() => _genres = v),
                    ),
                    _FacetRow(
                      title: '地区',
                      values: facets.countries,
                      selected: _countries,
                      enabled: true,
                      onSelect: (v) => setState(() => _countries = v),
                    ),
                    _FacetRow(
                      title: '年代',
                      values: facets.decades,
                      selected: _decades,
                      enabled: true,
                      onSelect: (v) => setState(() => _decades = v),
                    ),
                    _FacetRow(
                      title: '评分',
                      values: facets.ratings,
                      selected: _ratingGte?.toString(),
                      enabled: true,
                      onSelect: (v) => setState(() {
                        _ratingGte = v == null ? null : double.tryParse(v);
                      }),
                    ),
                    _FacetRow(
                      title: '片长',
                      values: facets.runtimes,
                      selected: _runtimes,
                      enabled: true,
                      onSelect: (v) => setState(() => _runtimes = v),
                    ),
                  ],
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: McActionPill(
              label: '应用筛选',
              primary: true,
              expanded: true,
              height: 44,
              onTap: () => Navigator.of(context).pop(_filter),
            ),
          ),
        ],
      ),
    );
  }
}

class _FacetRow extends StatelessWidget {
  const _FacetRow({
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
                  opacity: (enabled && v.count > 0) ? 1.0 : 0.35,
                  child: McChip(
                    label: v.count > 0 ? '${v.label} · ${v.count}' : v.label,
                    compact: true,
                    selected: selected == v.value,
                    onTap: (enabled && v.count > 0)
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
