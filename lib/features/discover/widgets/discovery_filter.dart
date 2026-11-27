import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';

/// 后端本地化的 TMDB 类型项（`GET /api/v1/discover/filters?media_type=`）。
class DiscoveryGenre {
  const DiscoveryGenre({required this.id, required this.name});

  final int id;
  final String name;

  factory DiscoveryGenre.fromJson(Map<String, dynamic> j) => DiscoveryGenre(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
      );
}

/// 电影与剧集动态类型清单缓存（对齐 iOS `DiscoverGenreCatalog`）：
/// 优先请求 `GET /api/v1/discover/filters?media_type=...`（404 回退 `/api/v1/discover/genres`），
/// 拉取失败时优雅回退至内置中文清单，确保离网或老后端照常可用。
class DiscoverGenreCatalog {
  DiscoverGenreCatalog._();

  static final Map<String, List<DiscoveryGenre>> _cache = {};
  static final Map<String, Future<List<DiscoveryGenre>>> _inFlight = {};

  static List<DiscoveryGenre> cached(String mediaType) =>
      _cache[mediaType] ?? _fallback(mediaType);

  static Map<int, String> nameMap(String mediaType) => {
        for (final g in cached(mediaType)) g.id: g.name,
      };

  static Future<List<DiscoveryGenre>> load(
    McClient mc,
    String mediaType,
  ) async {
    final hit = _cache[mediaType];
    if (hit != null) return hit;
    final pending = _inFlight[mediaType];
    if (pending != null) return pending;

    final future = _fetch(mc, mediaType);
    _inFlight[mediaType] = future;
    try {
      final result = await future;
      if (result.isNotEmpty) {
        _cache[mediaType] = result;
      }
      return _cache[mediaType] ?? _fallback(mediaType);
    } finally {
      _inFlight.remove(mediaType);
    }
  }

  static Future<List<DiscoveryGenre>> _fetch(
    McClient mc,
    String mediaType,
  ) async {
    Future<List<DiscoveryGenre>> parse(dynamic raw) async {
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['genres'] as List<dynamic>? ?? const []) : const []);
      return [
        for (final el in list)
          if (el is Map) DiscoveryGenre.fromJson(Map<String, dynamic>.from(el)),
      ].where((g) => g.id > 0 && g.name.isNotEmpty).toList();
    }

    try {
      final raw = await mc.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/discover/filters',
        query: {'media_type': mediaType},
      );
      final parsed = await parse(raw);
      if (parsed.isNotEmpty) return parsed;
    } on ApiException catch (e) {
      if (e.httpStatus == 404) {
        try {
          final raw = await mc.unwrap<dynamic>(
            Channel.general,
            'GET',
            '/api/v1/discover/genres',
            query: {'media_type': mediaType},
          );
          final parsed = await parse(raw);
          if (parsed.isNotEmpty) return parsed;
        } catch (_) {}
      }
    } catch (_) {}
    return const [];
  }

  static List<DiscoveryGenre> _fallback(String mediaType) =>
      mediaType == 'tv' ? _fallbackTvGenres : _fallbackMovieGenres;

  static const _fallbackMovieGenres = <DiscoveryGenre>[
    DiscoveryGenre(id: 28, name: '动作'),
    DiscoveryGenre(id: 12, name: '冒险'),
    DiscoveryGenre(id: 16, name: '动画'),
    DiscoveryGenre(id: 35, name: '喜剧'),
    DiscoveryGenre(id: 80, name: '犯罪'),
    DiscoveryGenre(id: 99, name: '纪录'),
    DiscoveryGenre(id: 18, name: '剧情'),
    DiscoveryGenre(id: 10751, name: '家庭'),
    DiscoveryGenre(id: 14, name: '奇幻'),
    DiscoveryGenre(id: 36, name: '历史'),
    DiscoveryGenre(id: 27, name: '恐怖'),
    DiscoveryGenre(id: 10402, name: '音乐'),
    DiscoveryGenre(id: 9648, name: '悬疑'),
    DiscoveryGenre(id: 10749, name: '爱情'),
    DiscoveryGenre(id: 878, name: '科幻'),
    DiscoveryGenre(id: 53, name: '惊悚'),
    DiscoveryGenre(id: 10752, name: '战争'),
    DiscoveryGenre(id: 37, name: '西部'),
  ];

  static const _fallbackTvGenres = <DiscoveryGenre>[
    DiscoveryGenre(id: 10759, name: '动作冒险'),
    DiscoveryGenre(id: 16, name: '动画'),
    DiscoveryGenre(id: 35, name: '喜剧'),
    DiscoveryGenre(id: 80, name: '犯罪'),
    DiscoveryGenre(id: 99, name: '纪录'),
    DiscoveryGenre(id: 18, name: '剧情'),
    DiscoveryGenre(id: 10751, name: '家庭'),
    DiscoveryGenre(id: 10762, name: '儿童'),
    DiscoveryGenre(id: 9648, name: '悬疑'),
    DiscoveryGenre(id: 10763, name: '新闻'),
    DiscoveryGenre(id: 10764, name: '真人秀'),
    DiscoveryGenre(id: 10765, name: '科幻奇幻'),
    DiscoveryGenre(id: 10766, name: '肥皂剧'),
    DiscoveryGenre(id: 10767, name: '脱口秀'),
    DiscoveryGenre(id: 10768, name: '战争政治'),
    DiscoveryGenre(id: 37, name: '西部'),
  ];
}

/// 组合发现的六维筛选（对齐 iOS `DiscoveryFilters`）：类型多选 + 地区 + 整数年份 + 最低评分 + 最长片长 + 排序。
class DiscoveryFilter {
  const DiscoveryFilter({
    this.genreIds = const [],
    this.originCountry,
    this.year,
    this.ratingGte,
    this.runtimeLte,
    this.sort = defaultSort,
  });

  final List<int> genreIds;
  final String? originCountry;
  final int? year;
  final double? ratingGte;
  final int? runtimeLte;
  final String sort;

  static const defaultSort = 'popular';

  static const countries = <MapEntry<String, String>>[
    MapEntry('CN', '中国大陆'),
    MapEntry('US', '美国'),
    MapEntry('JP', '日本'),
    MapEntry('KR', '韩国'),
    MapEntry('GB', '英国'),
    MapEntry('FR', '法国'),
    MapEntry('HK', '中国香港'),
    MapEntry('TW', '中国台湾'),
    MapEntry('IN', '印度'),
  ];

  static const sorts = <MapEntry<String, String>>[
    MapEntry('popular', '热门优先'),
    MapEntry('rating', '高分优先'),
    MapEntry('newest', '最新上映'),
    MapEntry('most-rated', '最多人评'),
  ];

  static const ratings = <double>[6, 7, 8, 9];
  static const runtimes = <int>[60, 90, 120, 150];

  static String countryLabel(String code) => countries
      .firstWhere((e) => e.key == code, orElse: () => MapEntry(code, code))
      .value;

  static String sortLabel(String value) => sorts
      .firstWhere((e) => e.key == value, orElse: () => MapEntry(value, value))
      .value;

  static String formatRating(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  /// 已启用的维度数（与 iOS `activeCount` 口径一致：按维度计数）。
  int get activeCount =>
      (genreIds.isEmpty ? 0 : 1) +
      (originCountry == null ? 0 : 1) +
      (year == null ? 0 : 1) +
      (ratingGte == null ? 0 : 1) +
      (runtimeLte == null ? 0 : 1) +
      (sort == defaultSort ? 0 : 1);

  DiscoveryFilter copyWith({
    List<int>? genreIds,
    Object? originCountry = _sentinel,
    Object? year = _sentinel,
    Object? ratingGte = _sentinel,
    Object? runtimeLte = _sentinel,
    String? sort,
  }) =>
      DiscoveryFilter(
        genreIds: genreIds ?? this.genreIds,
        originCountry: identical(originCountry, _sentinel)
            ? this.originCountry
            : originCountry as String?,
        year: identical(year, _sentinel) ? this.year : year as int?,
        ratingGte: identical(ratingGte, _sentinel)
            ? this.ratingGte
            : ratingGte as double?,
        runtimeLte: identical(runtimeLte, _sentinel)
            ? this.runtimeLte
            : runtimeLte as int?,
        sort: sort ?? this.sort,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DiscoveryFilter) return false;
    if (genreIds.length != other.genreIds.length) return false;
    for (var i = 0; i < genreIds.length; i++) {
      if (genreIds[i] != other.genreIds[i]) return false;
    }
    return originCountry == other.originCountry &&
        year == other.year &&
        ratingGte == other.ratingGte &&
        runtimeLte == other.runtimeLte &&
        sort == other.sort;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(genreIds),
        originCountry,
        year,
        ratingGte,
        runtimeLte,
        sort,
      );

  static const _sentinel = Object();
}

const discoveryDimKeys = <String>[
  'genres',
  'country',
  'year',
  'rating',
  'runtime',
  'sort',
];

String discoveryDimTitle(String key, {String mediaType = 'movie'}) =>
    switch (key) {
      'genres' => '类型',
      'country' => '国家/地区',
      'year' => mediaType == 'movie' ? '上映年份' : '首播年份',
      'rating' => '最低评分',
      'runtime' => mediaType == 'movie' ? '最长片长' : '单集片长',
      'sort' => '排序',
      _ => key,
    };

IconData discoveryDimIcon(String key) => switch (key) {
      'genres' => McIcons.gridFill,
      'country' => McIcons.planet,
      'year' => McIcons.calendar,
      'rating' => McIcons.star2Fill,
      'runtime' => McIcons.clock,
      'sort' => McIcons.sort,
      _ => McIcons.filterS,
    };

bool discoveryDimEnabled(String key, DiscoveryFilter f) => switch (key) {
      'genres' => f.genreIds.isNotEmpty,
      'country' => f.originCountry != null,
      'year' => f.year != null,
      'rating' => f.ratingGte != null,
      'runtime' => f.runtimeLte != null,
      'sort' => f.sort != DiscoveryFilter.defaultSort,
      _ => false,
    };

String? discoveryDimSummary(
  String key,
  DiscoveryFilter f,
  String mediaType, {
  Map<int, String>? genreNames,
}) {
  if (!discoveryDimEnabled(key, f)) return null;
  final names = genreNames ?? DiscoverGenreCatalog.nameMap(mediaType);
  return switch (key) {
    'genres' => () {
        final resolved = [
          for (final id in f.genreIds)
            if (names[id] != null) names[id]!,
        ];
        if (resolved.length == f.genreIds.length && resolved.length <= 2) {
          return resolved.join('、');
        }
        if (resolved.isNotEmpty) {
          return '${resolved.first} 等 ${f.genreIds.length} 个';
        }
        return '${f.genreIds.length} 个类型';
      }(),
    'country' => DiscoveryFilter.countryLabel(f.originCountry!),
    'year' => '${f.year} 年',
    'rating' => '${DiscoveryFilter.formatRating(f.ratingGte!)} 分以上',
    'runtime' => '${f.runtimeLte} 分钟以内',
    'sort' => DiscoveryFilter.sortLabel(f.sort),
    _ => null,
  };
}

String dimValue(
  String key,
  DiscoveryFilter f,
  String mediaType, {
  Map<int, String>? genreNames,
}) {
  final summary = discoveryDimSummary(
    key,
    f,
    mediaType,
    genreNames: genreNames,
  );
  if (summary != null) return summary;
  return key == 'sort' ? DiscoveryFilter.sortLabel(f.sort) : '不限';
}

DiscoveryFilter clearDiscoveryDim(String key, DiscoveryFilter f) =>
    switch (key) {
      'genres' => f.copyWith(genreIds: const []),
      'country' => f.copyWith(originCountry: null),
      'year' => f.copyWith(year: null),
      'rating' => f.copyWith(ratingGte: null),
      'runtime' => f.copyWith(runtimeLte: null),
      'sort' => f.copyWith(sort: DiscoveryFilter.defaultSort),
      _ => f,
    };

/// 单维度筛选选项弹层（支持动态类型、真实整数年份+更早年份展开、4 种有效排序）。
class DiscoveryFilterOptionsPanel extends StatefulWidget {
  const DiscoveryFilterOptionsPanel({
    super.key,
    required this.dimKey,
    required this.filter,
    required this.mediaType,
    required this.onApply,
    this.genres,
    this.onBack,
  });

  final String dimKey;
  final DiscoveryFilter filter;
  final String mediaType;
  final List<DiscoveryGenre>? genres;
  final ValueChanged<DiscoveryFilter> onApply;
  final VoidCallback? onBack;

  @override
  State<DiscoveryFilterOptionsPanel> createState() =>
      _DiscoveryFilterOptionsPanelState();
}

class _DiscoveryFilterOptionsPanelState
    extends State<DiscoveryFilterOptionsPanel> {
  bool _showOlderYears = false;

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    if (widget.filter.year != null && widget.filter.year! < currentYear - 14) {
      _showOlderYears = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dim = widget.dimKey;
    final f = widget.filter;
    final title = discoveryDimTitle(dim, mediaType: widget.mediaType);
    final enabled = discoveryDimEnabled(dim, f);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              if (widget.onBack != null)
                IconButton(
                  tooltip: '返回',
                  onPressed: widget.onBack,
                  icon: const Icon(McIcons.arrowLeftS, size: 20),
                ),
              Expanded(child: Text('筛选 · $title', style: McText.titleSm)),
              if (enabled)
                TextButton(
                  onPressed: () =>
                      widget.onApply(clearDiscoveryDim(dim, f)),
                  child: Text(dim == 'sort' ? '恢复默认' : '不限'),
                ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: switch (dim) {
              'genres' => _buildGenres(f),
              'country' => _buildCountries(f),
              'year' => _buildYears(f),
              'rating' => _buildRatings(f),
              'runtime' => _buildRuntimes(f),
              _ => _buildSorts(f),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenres(DiscoveryFilter f) {
    final list = widget.genres ?? DiscoverGenreCatalog.cached(widget.mediaType);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in list)
          McChip(
            label: g.name,
            selected: f.genreIds.contains(g.id),
            onTap: () {
              final next = f.genreIds.contains(g.id)
                  ? f.genreIds.where((e) => e != g.id).toList()
                  : [...f.genreIds, g.id];
              widget.onApply(f.copyWith(genreIds: next));
            },
          ),
      ],
    );
  }

  Widget _buildCountries(DiscoveryFilter f) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        McChip(
          label: '不限',
          selected: f.originCountry == null,
          onTap: () => widget.onApply(f.copyWith(originCountry: null)),
        ),
        for (final c in DiscoveryFilter.countries)
          McChip(
            label: c.value,
            selected: f.originCountry == c.key,
            onTap: () => widget.onApply(
              f.copyWith(
                originCountry: f.originCountry == c.key ? null : c.key,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildYears(DiscoveryFilter f) {
    final nowYear = DateTime.now().year;
    final recentYears = [for (var y = nowYear; y >= nowYear - 14; y--) y];
    final olderYears = [for (var y = nowYear - 15; y >= 1950; y--) y];
    final classicYears = [for (var y = 1949; y >= 1874; y--) y];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            McChip(
              label: '不限',
              selected: f.year == null,
              onTap: () => widget.onApply(f.copyWith(year: null)),
            ),
            for (final y in recentYears)
              McChip(
                label: '$y',
                selected: f.year == y,
                onTap: () =>
                    widget.onApply(f.copyWith(year: f.year == y ? null : y)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _showOlderYears = !_showOlderYears),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _showOlderYears ? '收起更早年份' : '更早年份（1950–${nowYear - 15}）',
                  style: McText.caption.copyWith(
                    color: McTokens.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showOlderYears ? McIcons.arrowUpS : McIcons.arrowDownS,
                  size: 16,
                  color: McTokens.accent,
                ),
              ],
            ),
          ),
        ),
        if (_showOlderYears) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final y in olderYears)
                McChip(
                  label: '$y',
                  compact: true,
                  selected: f.year == y,
                  onTap: () =>
                      widget.onApply(f.copyWith(year: f.year == y ? null : y)),
                ),
              for (final y in classicYears)
                McChip(
                  label: '$y',
                  compact: true,
                  selected: f.year == y,
                  onTap: () =>
                      widget.onApply(f.copyWith(year: f.year == y ? null : y)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRatings(DiscoveryFilter f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OptionRow(
          label: '不限',
          selected: f.ratingGte == null,
          onTap: () => widget.onApply(f.copyWith(ratingGte: null)),
        ),
        for (final r in DiscoveryFilter.ratings)
          _OptionRow(
            label: '${DiscoveryFilter.formatRating(r)} 分以上',
            selected: f.ratingGte == r,
            onTap: () => widget.onApply(
              f.copyWith(ratingGte: f.ratingGte == r ? null : r),
            ),
          ),
      ],
    );
  }

  Widget _buildRuntimes(DiscoveryFilter f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OptionRow(
          label: '不限',
          selected: f.runtimeLte == null,
          onTap: () => widget.onApply(f.copyWith(runtimeLte: null)),
        ),
        for (final m in DiscoveryFilter.runtimes)
          _OptionRow(
            label: '$m 分钟以内',
            selected: f.runtimeLte == m,
            onTap: () => widget.onApply(
              f.copyWith(runtimeLte: f.runtimeLte == m ? null : m),
            ),
          ),
      ],
    );
  }

  Widget _buildSorts(DiscoveryFilter f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in DiscoveryFilter.sorts)
          _OptionRow(
            label: s.value,
            selected: f.sort == s.key,
            onTap: () => widget.onApply(f.copyWith(sort: s.key)),
          ),
      ],
    );
  }
}

/// 结果页头部的横向条件胶囊（六个维度固定顺序，激活项银白实心高亮）。
class DiscoverFilterChipsRow extends StatelessWidget {
  const DiscoverFilterChipsRow({
    super.key,
    required this.filters,
    required this.mediaType,
    required this.onOpenDim,
    this.genreNames,
  });

  final DiscoveryFilter filters;
  final String mediaType;
  final ValueChanged<String> onOpenDim;
  final Map<int, String>? genreNames;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
        itemCount: discoveryDimKeys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final key = discoveryDimKeys[i];
          final summary = discoveryDimSummary(
            key,
            filters,
            mediaType,
            genreNames: genreNames,
          );
          final on = summary != null;
          return McChip(
            label: on
                ? summary
                : discoveryDimTitle(key, mediaType: mediaType),
            selected: on,
            compact: true,
            onTap: () => onOpenDim(key),
          );
        },
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.sub.copyWith(
                    color: selected ? McTokens.text : McTokens.textMuted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                const Icon(McIcons.check, size: 16, color: McTokens.accentStrong),
            ],
          ),
        ),
      ),
    );
  }
}
