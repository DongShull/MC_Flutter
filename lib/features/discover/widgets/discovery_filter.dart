// IMPLEMENTED — 1:1 重写自 MovieClaw feature/discover/DiscoveryMenus.kt。
import 'package:flutter/material.dart';

import '../../../core/designsystem/theme.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 发现页筛选条件（TMDB discover 六维：类型/地区/年份/评分/片长/排序）。
class DiscoveryFilter {
  const DiscoveryFilter({
    this.genreIds = const [],
    this.originCountry,
    this.year,
    this.ratingGte,
    this.runtimeLte,
    this.sort,
  });

  final List<String> genreIds;
  final String? originCountry;
  final String? year;
  final String? ratingGte;
  final String? runtimeLte;
  final String? sort;

  static const defaultSort = 'popular';

  /// 启用条件数（排序停在「热门优先」不算启用，与角标口径一致）。
  int get activeCount =>
      genreIds.length +
      (originCountry != null ? 1 : 0) +
      (year != null ? 1 : 0) +
      (ratingGte != null ? 1 : 0) +
      (runtimeLte != null ? 1 : 0) +
      (sort != null && sort != defaultSort ? 1 : 0);

  DiscoveryFilter copyWith({
    List<String>? genreIds,
    Object? originCountry = _sentinel,
    Object? year = _sentinel,
    Object? ratingGte = _sentinel,
    Object? runtimeLte = _sentinel,
    Object? sort = _sentinel,
  }) =>
      DiscoveryFilter(
        genreIds: genreIds ?? this.genreIds,
        originCountry:
            identical(originCountry, _sentinel) ? this.originCountry : originCountry as String?,
        year: identical(year, _sentinel) ? this.year : year as String?,
        ratingGte: identical(ratingGte, _sentinel) ? this.ratingGte : ratingGte as String?,
        runtimeLte: identical(runtimeLte, _sentinel) ? this.runtimeLte : runtimeLte as String?,
        sort: identical(sort, _sentinel) ? this.sort : sort as String?,
      );

  static const _sentinel = Object();
}

class _Dim {
  const _Dim(this.key, this.title, this.icon, {this.multi = false, this.options = const []});
  final String key;
  final String title;
  final IconData icon;
  final bool multi;
  final List<MapEntry<String, String>> options;
}

const _movieGenres = [
  MapEntry('28', '动作'), MapEntry('12', '冒险'), MapEntry('16', '动画'),
  MapEntry('35', '喜剧'), MapEntry('80', '犯罪'), MapEntry('99', '纪录'),
  MapEntry('18', '剧情'), MapEntry('10751', '家庭'), MapEntry('14', '奇幻'),
  MapEntry('36', '历史'), MapEntry('27', '恐怖'), MapEntry('10402', '音乐'),
  MapEntry('9648', '悬疑'), MapEntry('10749', '爱情'), MapEntry('878', '科幻'),
  MapEntry('53', '惊悚'), MapEntry('10752', '战争'), MapEntry('37', '西部'),
];

const _tvGenres = [
  MapEntry('10759', '动作冒险'), MapEntry('16', '动画'), MapEntry('35', '喜剧'),
  MapEntry('80', '犯罪'), MapEntry('99', '纪录'), MapEntry('18', '剧情'),
  MapEntry('10751', '家庭'), MapEntry('10762', '儿童'), MapEntry('9648', '悬疑'),
  MapEntry('10763', '新闻'), MapEntry('10764', '真人秀'), MapEntry('10765', '科幻奇幻'),
  MapEntry('10766', '肥皂剧'), MapEntry('10767', '脱口秀'), MapEntry('10768', '战争政治'),
  MapEntry('37', '西部'),
];

const _dims = [
  _Dim('genres', '类型', McIcons.gridFill, multi: true),
  _Dim('country', '地区', McIcons.planet, options: [
    MapEntry('CN', '中国大陆'), MapEntry('HK', '中国香港'), MapEntry('TW', '中国台湾'),
    MapEntry('US', '美国'), MapEntry('GB', '英国'), MapEntry('JP', '日本'),
    MapEntry('KR', '韩国'), MapEntry('FR', '法国'), MapEntry('DE', '德国'),
  ]),
  _Dim('year', '年代', McIcons.calendar, options: [
    MapEntry('2025', '2025'), MapEntry('2024', '2024'), MapEntry('2023', '2023'),
    MapEntry('2022', '2022'), MapEntry('2021', '2021'), MapEntry('2020', '2020'),
    MapEntry('2010s', '2010 年代'), MapEntry('2000s', '2000 年代'), MapEntry('1990s', '90 年代'),
  ]),
  _Dim('rating', '评分', Icons.star, options: [
    MapEntry('9', '9 分以上'), MapEntry('8', '8 分以上'), MapEntry('7', '7 分以上'),
    MapEntry('6', '6 分以上'), MapEntry('5', '5 分以上'),
  ]),
  _Dim('runtime', '片长', Icons.schedule, options: [
    MapEntry('60', '60 分钟以内'), MapEntry('90', '90 分钟以内'),
    MapEntry('120', '120 分钟以内'), MapEntry('150', '150 分钟以内'),
  ]),
  _Dim('sort', '排序', McIcons.sort, options: [
    MapEntry('popular', '热门优先'), MapEntry('rating', '评分最高'),
    MapEntry('newest', '最新上线'), MapEntry('oldest', '最早上映'),
    MapEntry('revenue', '票房最高'),
  ]),
];

String _genreLabel(String mediaType, String id) {
  final table = mediaType == 'tv' ? _tvGenres : _movieGenres;
  return table.firstWhere((e) => e.key == id, orElse: () => const MapEntry('', '1 个类型')).value;
}

String dimValue(String key, DiscoveryFilter f, String mediaType) => switch (key) {
      'genres' => () {
          if (f.genreIds.isEmpty) return '不限';
          if (f.genreIds.length == 1) return _genreLabel(mediaType, f.genreIds.first);
          return '${_genreLabel(mediaType, f.genreIds.first)} +${f.genreIds.length - 1}';
        }(),
      'country' => () {
          final c = f.originCountry;
          if (c == null) return '不限';
          return _dims
              .firstWhere((d) => d.key == 'country')
              .options
              .firstWhere((e) => e.key == c, orElse: () => MapEntry(c, c))
              .value;
        }(),
      'year' => f.year ?? '不限',
      'rating' => f.ratingGte != null ? '${f.ratingGte} 分以上' : '不限',
      'runtime' => f.runtimeLte != null ? '${f.runtimeLte} 分钟以内' : '不限',
      _ => () {
          final s = f.sort;
          if (s == null || s == DiscoveryFilter.defaultSort) return '热门优先';
          return _dims
              .firstWhere((d) => d.key == 'sort')
              .options
              .firstWhere((e) => e.key == s, orElse: () => MapEntry(s, s))
              .value;
        }(),
    };

String discoveryDimTitle(String key) =>
    _dims.firstWhere((d) => d.key == key, orElse: () => _Dim(key, key, McIcons.helpCircleFill)).title;

List<String> get discoveryDimKeys => [for (final d in _dims) d.key];

bool _dimEnabled(_Dim dim, DiscoveryFilter f) => switch (dim.key) {
      'genres' => f.genreIds.isNotEmpty,
      'country' => f.originCountry != null,
      'year' => f.year != null,
      'rating' => f.ratingGte != null,
      'runtime' => f.runtimeLte != null,
      _ => f.sort != null && f.sort != DiscoveryFilter.defaultSort,
    };

/// 某一维度的当前值摘要（未启用返回 null）。
String? discoveryDimSummary(String key, DiscoveryFilter f, String mediaType) {
  final dim = _dims.firstWhere((d) => d.key == key);
  if (!_dimEnabled(dim, f)) return null;
  return dimValue(key, f, mediaType);
}

DiscoveryFilter _clearDim(String key, DiscoveryFilter f) => switch (key) {
      'genres' => f.copyWith(genreIds: const []),
      'country' => f.copyWith(originCountry: null),
      'year' => f.copyWith(year: null),
      'rating' => f.copyWith(ratingGte: null),
      'runtime' => f.copyWith(runtimeLte: null),
      _ => f.copyWith(sort: null),
    };

DiscoveryFilter _toggleDim(String key, String value, DiscoveryFilter f) => switch (key) {
      'genres' => f.copyWith(
          genreIds: f.genreIds.contains(value)
              ? f.genreIds.where((e) => e != value).toList()
              : [...f.genreIds, value],
        ),
      'country' => f.copyWith(originCountry: f.originCountry == value ? null : value),
      'year' => f.copyWith(year: f.year == value ? null : value),
      'rating' => f.copyWith(ratingGte: f.ratingGte == value ? null : value),
      'runtime' => f.copyWith(runtimeLte: f.runtimeLte == value ? null : value),
      _ => f.copyWith(sort: f.sort == value ? null : value),
    };

/// 单维度的选项面板（顶部「‹ 维度名」返回行 + 「不限」/ 各选项，当前项带对勾）。
class DiscoveryFilterOptionsPanel extends StatelessWidget {
  const DiscoveryFilterOptionsPanel({
    super.key,
    required this.dimKey,
    required this.filter,
    required this.mediaType,
    required this.onApply,
    this.onBack,
  });

  final String dimKey;
  final DiscoveryFilter filter;
  final String mediaType;
  final ValueChanged<DiscoveryFilter> onApply;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final dim = _dims.firstWhere((d) => d.key == dimKey);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onBack != null)
          _MenuRow(
            title: dim.title,
            icon: McIcons.arrowLeft,
            highlight: true,
            onTap: onBack!,
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 370),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dim.key != 'sort' && !dim.multi)
                  _OptionRow(
                    label: '不限',
                    selected: !_dimEnabled(dim, filter),
                    onTap: () => onApply(_clearDim(dim.key, filter)),
                  ),
                for (final opt in dim.options)
                  _OptionRow(
                    label: opt.value,
                    selected: switch (dim.key) {
                      'genres' => filter.genreIds.contains(opt.key),
                      'country' => filter.originCountry == opt.key,
                      'year' => filter.year == opt.key,
                      'rating' => filter.ratingGte == opt.key,
                      'runtime' => filter.runtimeLte == opt.key,
                      _ => filter.sort == opt.key,
                    },
                    onTap: () => onApply(_toggleDim(dim.key, opt.key, filter)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 发现页筛选菜单面板（主菜单：六个维度行 + 有条件时的「清空条件」）。
class DiscoveryFilterMenu extends StatefulWidget {
  const DiscoveryFilterMenu({
    super.key,
    required this.filter,
    required this.mediaType,
    required this.onApply,
  });

  final DiscoveryFilter filter;
  final String mediaType;
  final ValueChanged<DiscoveryFilter> onApply;

  @override
  State<DiscoveryFilterMenu> createState() => _DiscoveryFilterMenuState();
}

class _DiscoveryFilterMenuState extends State<DiscoveryFilterMenu> {
  String? _openDim;

  @override
  Widget build(BuildContext context) {
    final f = widget.filter;
    return Material(
      color: McColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SizedBox(
        width: 272,
        child: _openDim == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in _dims)
                    _MenuRow(
                      title: d.title,
                      icon: d.icon,
                      value: dimValue(d.key, f, widget.mediaType),
                      chevron: true,
                      onTap: () => setState(() => _openDim = d.key),
                    ),
                  if (f.activeCount > 0) ...[
                    const Divider(height: 1, color: Colors.white12),
                    _MenuRow(
                      title: '清空条件',
                      icon: McIcons.close2,
                      danger: true,
                      onTap: () => widget.onApply(const DiscoveryFilter()),
                    ),
                  ],
                ],
              )
            : DiscoveryFilterOptionsPanel(
                dimKey: _openDim!,
                filter: f,
                mediaType: widget.mediaType,
                onApply: widget.onApply,
                onBack: () => setState(() => _openDim = null),
              ),
      ),
    );
  }
}

/// 结果页头部的条件胶囊（六个维度固定顺序，已启用的高亮并写出当前值）。
class DiscoverFilterChipsRow extends StatelessWidget {
  const DiscoverFilterChipsRow({
    super.key,
    required this.filters,
    required this.mediaType,
    required this.onOpenDim,
  });

  final DiscoveryFilter filters;
  final String mediaType;
  final ValueChanged<String> onOpenDim;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final key in discoveryDimKeys)
            Builder(builder: (context) {
              final summary = discoveryDimSummary(key, filters, mediaType);
              final on = summary != null;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onOpenDim(key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: on ? 0.16 : 0.05),
                      borderRadius: BorderRadius.circular(999),
                      border: on ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
                    ),
                    child: Text(
                      on ? '${discoveryDimTitle(key)} · $summary' : discoveryDimTitle(key),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: on ? Colors.white : Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.title,
    required this.onTap,
    this.icon,
    this.value,
    this.highlight = false,
    this.danger = false,
    this.chevron = false,
  });

  final String title;
  final VoidCallback onTap;
  final IconData? icon;
  final String? value;
  final bool highlight;
  final bool danger;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: highlight ? Colors.white.withValues(alpha: 0.075) : null,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: danger ? Colors.redAccent : Colors.white54),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: highlight ? FontWeight.w600 : null,
                  color: danger
                      ? Colors.redAccent
                      : highlight
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
            if (value != null)
              Text(value!, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
            if (chevron && value != null)
              Icon(McIcons.arrowRight, size: 14, color: Colors.white.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
            ),
            if (selected) const Icon(McIcons.check, size: 14, color: McColors.accent),
          ],
        ),
      ),
    );
  }
}
