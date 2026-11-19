import 'package:flutter/material.dart';

import '../state/controllers.dart';
import '../state/models.dart';

/// 筛选面板（对应 Android ReelFilterSheet）：候选值与计数都来自
/// /reels/facets（每维计数排除本维自身条件——为 0 的档置灰不可点）。
/// 返回 null = 未应用（直接关闭）。
Future<ReelFilter?> showReelFilterSheet(BuildContext context, ReelsState state) {
  return showModalBottomSheet<ReelFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ReelFilterSheet(
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
    final draggable = facets?.filterable ?? true;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  '筛选',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _kind = null;
                  _genres = null;
                  _countries = null;
                  _decades = null;
                  _ratingGte = null;
                  _runtimes = null;
                  _watch = null;
                }),
                child: const Text('重置'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
              children: [
                if (facets != null) ...[
                  _FacetRow(
                    title: '类型',
                    values: facets.kinds,
                    selected: _kind,
                    enabled: draggable,
                    onSelect: (v) => setState(() => _kind = v),
                  ),
                  _FacetRow(
                    title: '观看状态',
                    values: facets.watch,
                    selected: _watch,
                    enabled: true,
                    onSelect: (v) => setState(() => _watch = v),
                  ),
                  if (draggable) ...[
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
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_filter),
              child: const Text('应用'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一维候选值：横向流式选择；count 为 0 的档置灰（每维计数排除本维自身条件）
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                FilterChip(
                  label: Text(
                    v.count > 0 ? '${v.label} ${v.count}' : v.label,
                  ),
                  selected: selected == v.value,
                  onSelected: (enabled && v.count > 0)
                      ? (on) => onSelect(on ? v.value : null)
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
