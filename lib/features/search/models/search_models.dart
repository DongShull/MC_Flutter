import 'package:flutter/widgets.dart';

import '../../../core/designsystem/mc_icons.dart';

/// 搜索垂直（对齐 iOS `SearchVertical`）：影视条目 / 站点资源 / 媒体库。
enum SearchVertical {
  media,
  torrent,
  library;

  String get label => switch (this) {
        SearchVertical.media => '影视',
        SearchVertical.torrent => '站点资源',
        SearchVertical.library => '媒体库',
      };

  String get shortLabel => switch (this) {
        SearchVertical.media => '影视',
        SearchVertical.torrent => '资源',
        SearchVertical.library => '媒体库',
      };

  /// 服务端搜索历史使用的 vertical 字段；媒体库无服务端历史。
  String? get historyVertical => switch (this) {
        SearchVertical.media => 'titles',
        SearchVertical.torrent => 'torrents',
        SearchVertical.library => null,
      };

  String get modeString => name;

  static SearchVertical fromRouteTab(String? raw, {SearchVertical fallback = SearchVertical.torrent}) =>
      switch (raw?.trim().toLowerCase()) {
        'media' || 'titles' || 'discover' => SearchVertical.media,
        'library' || 'local' => SearchVertical.library,
        'torrent' || 'torrents' || 'pt' || 'resource' => SearchVertical.torrent,
        _ => fallback,
      };
}

/// 种子一级分类（对齐 iOS `TorrentCategories`）。
abstract final class TorrentCategories {
  static const all = <MapEntry<String, String>>[
    MapEntry('movie', '电影'),
    MapEntry('tv', '剧集'),
    MapEntry('documentary', '纪录片'),
    MapEntry('anime', '动漫'),
    MapEntry('music', '音乐'),
    MapEntry('game', '游戏'),
    MapEntry('av', '成人'),
    MapEntry('other', '其他'),
  ];

  static final Set<String> knownValues = {for (final e in all) e.key};

  static String label(String value) => all
      .firstWhere((e) => e.key == value, orElse: () => MapEntry(value, value))
      .value;

  static IconData icon(String value) => switch (value) {
        'movie' => McIcons.movie,
        'tv' => McIcons.tv,
        'documentary' => McIcons.globe,
        'anime' => McIcons.aiStarFill,
        'music' => McIcons.fileMusic1,
        'game' => McIcons.gamepad,
        'av' => McIcons.eyeOff,
        _ => McIcons.archive,
      };

  static const IconData allIcon = McIcons.gridFill;
}

/// 一次资源搜索的范围（对齐 iOS `SearchScope`）：分类组合 × 站点组合。
class SearchScope {
  const SearchScope({
    this.label,
    this.categories = const [],
    this.siteIds = const [],
    this.posterMode = false,
    this.skipHistory = false,
  });

  static const all = SearchScope();

  final String? label;
  final List<String> categories;
  final List<String> siteIds;
  final bool posterMode;
  final bool skipHistory;

  bool get isAll =>
      label == null &&
      categories.isEmpty &&
      siteIds.isEmpty &&
      !posterMode &&
      !skipHistory;

  /// 从路由 `scope` 查询串还原（如 `label=电影&cats=movie&sites=a,b&poster=1&private=1`）。
  factory SearchScope.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return SearchScope.all;
    final clean = raw.startsWith('?') ? raw.substring(1) : raw;
    final params = Uri.splitQueryString(clean);
    final lbl = params['label']?.trim();
    final cats = (params['cats'] ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && TorrentCategories.knownValues.contains(e))
        .toList();
    final sites = (params['sites'] ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return SearchScope(
      label: (lbl != null && lbl.isNotEmpty) ? lbl : null,
      categories: cats,
      siteIds: sites,
      posterMode: params['poster'] == '1',
      skipHistory: params['private'] == '1',
    );
  }

  /// 构造保留多值查询参数的 SSE/REST 请求路径（支持重复 `categories` / `sites` / `also_keywords`）。
  String buildQueryString({
    required String keyword,
    List<String> alsoKeywords = const [],
    int page = 1,
  }) {
    final pairs = <String>[
      'keyword=${Uri.encodeQueryComponent(keyword)}',
      for (final a in alsoKeywords)
        if (a.trim().isNotEmpty)
          'also_keywords=${Uri.encodeQueryComponent(a.trim())}',
      for (final c in categories) 'categories=${Uri.encodeQueryComponent(c)}',
      for (final s in siteIds) 'sites=${Uri.encodeQueryComponent(s)}',
      if (label != null && label!.isNotEmpty)
        'label=${Uri.encodeQueryComponent(label!)}',
      if (skipHistory) 'no_history=true',
      if (posterMode) 'poster_mode=true',
      if (page > 1) 'page=$page',
    ];
    return pairs.join('&');
  }

  SearchScope copyWith({
    Object? label = _sentinel,
    List<String>? categories,
    List<String>? siteIds,
    bool? posterMode,
    bool? skipHistory,
  }) =>
      SearchScope(
        label: identical(label, _sentinel) ? this.label : label as String?,
        categories: categories ?? this.categories,
        siteIds: siteIds ?? this.siteIds,
        posterMode: posterMode ?? this.posterMode,
        skipHistory: skipHistory ?? this.skipHistory,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchScope) return false;
    return label == other.label &&
        _listEq(categories, other.categories) &&
        _listEq(siteIds, other.siteIds) &&
        posterMode == other.posterMode &&
        skipHistory == other.skipHistory;
  }

  @override
  int get hashCode => Object.hash(
        label,
        Object.hashAll(categories),
        Object.hashAll(siteIds),
        posterMode,
        skipHistory,
      );

  static const _sentinel = Object();
}

/// 资源搜索预设标签（内置分类或自定义「分类 × 站点」预设，`GET /api/v1/search/presets`）。
class SearchTab {
  const SearchTab({
    required this.type,
    required this.id,
    required this.name,
    this.visible = true,
    this.categories = const [],
    this.siteIds = const [],
    this.posterMode = false,
    this.skipHistory = false,
  });

  final String type; // 'category' | 'preset'
  final String id;
  final String name;
  final bool visible;
  final List<String> categories;
  final List<String> siteIds;
  final bool posterMode;
  final bool skipHistory;

  bool get isPreset => type == 'preset';
  String get key => '$type:$id';
  String get label => isPreset ? name : TorrentCategories.label(id);
  IconData get icon =>
      isPreset ? McIcons.stack : TorrentCategories.icon(id);

  SearchScope get scope => isPreset
      ? SearchScope(
          label: name,
          categories: categories,
          siteIds: siteIds,
          posterMode: posterMode,
          skipHistory: skipHistory,
        )
      : SearchScope(label: TorrentCategories.label(id), categories: [id]);

  String? get summary {
    if (!isPreset) return null;
    final cats = categories.isEmpty
        ? '不限分类'
        : categories.map(TorrentCategories.label).join('、');
    final sites =
        siteIds.isEmpty ? '全部站点' : '${siteIds.length} 个站点';
    final flags = [
      if (posterMode) '图览',
      if (skipHistory) '无痕',
    ];
    return '$cats · $sites${flags.isEmpty ? '' : ' · ${flags.join(' · ')}'}';
  }

  static SearchTab? fromJson(Map<String, dynamic> j) {
    final type = (j['type'] ?? '').toString();
    final id = (j['id'] ?? '').toString();
    if (type.isEmpty || id.isEmpty) return null;
    final visible = j['visible'] != false;
    if (type == 'category') {
      return SearchTab(
        type: 'category',
        id: id,
        name: TorrentCategories.label(id),
        visible: visible,
        categories: [id],
      );
    }
    if (type == 'preset') {
      return SearchTab(
        type: 'preset',
        id: id,
        name: (j['name'] ?? id).toString(),
        visible: visible,
        categories: [
          for (final c in (j['categories'] as List<dynamic>? ?? const []))
            c.toString(),
        ],
        siteIds: [
          for (final s in (j['site_ids'] as List<dynamic>? ?? const []))
            s.toString(),
        ],
        posterMode: j['poster_mode'] == true,
        skipHistory: j['skip_history'] == true,
      );
    }
    return null;
  }

  static const defaults = <SearchTab>[
    SearchTab(type: 'category', id: 'movie', name: '电影', visible: true, categories: ['movie']),
    SearchTab(type: 'category', id: 'tv', name: '剧集', visible: true, categories: ['tv']),
    SearchTab(type: 'category', id: 'documentary', name: '纪录片', visible: true, categories: ['documentary']),
    SearchTab(type: 'category', id: 'anime', name: '动漫', visible: true, categories: ['anime']),
    SearchTab(type: 'category', id: 'music', name: '音乐', visible: false, categories: ['music']),
    SearchTab(type: 'category', id: 'game', name: '游戏', visible: false, categories: ['game']),
    SearchTab(type: 'category', id: 'other', name: '其他', visible: false, categories: ['other']),
  ];
}

/// 搜索入口权限（对齐 iOS `SearchAccess`）。
class SearchAccess {
  const SearchAccess({
    this.canMedia = false,
    this.canTorrent = false,
    this.canLibrary = false,
    this.ready = false,
  });

  final bool canMedia;
  final bool canTorrent;
  final bool canLibrary;
  final bool ready;

  List<SearchVertical> get available => [
        if (canMedia) SearchVertical.media,
        if (canTorrent) SearchVertical.torrent,
        if (canLibrary) SearchVertical.library,
      ];

  bool get canOpenSearch => available.isNotEmpty;
}

/// 种子结构化属性（对齐 `API.TorrentAttrs`）。
class TorrentAttrs {
  const TorrentAttrs({
    this.mediaType,
    this.contentType,
    this.titlesZh = const [],
    this.titlesEn = const [],
    this.titleCandidates = const [],
    this.year,
    this.seasons = const [],
    this.episodes = const [],
    this.episodesTotal,
    this.complete,
    this.resolution,
    this.videoCodec,
    this.hdr = const [],
    this.mediaSource,
    this.remux = false,
    this.audio = const [],
    this.subtitleLanguages = const [],
    this.subtitleCarriers = const [],
    this.audioLanguages = const [],
    this.platforms = const [],
    this.releaseGroup,
  });

  final String? mediaType;
  final String? contentType;
  final List<String> titlesZh;
  final List<String> titlesEn;
  final List<String> titleCandidates;
  final int? year;
  final List<int> seasons;
  final List<int> episodes;
  final int? episodesTotal;
  final bool? complete;
  final String? resolution;
  final String? videoCodec;
  final List<String> hdr;
  final String? mediaSource;
  final bool remux;
  final List<String> audio;
  final List<String> subtitleLanguages;
  final List<String> subtitleCarriers;
  final List<String> audioLanguages;
  final List<String> platforms;
  final String? releaseGroup;

  factory TorrentAttrs.fromJson(Map<String, dynamic> j) {
    List<String> strList(String k) => [
          for (final e in (j[k] as List<dynamic>? ?? const []))
            if (e != null && e.toString().isNotEmpty) e.toString(),
        ];
    List<int> intList(String k) => [
          for (final e in (j[k] as List<dynamic>? ?? const []))
            if (e is num) e.toInt() else if (int.tryParse('$e') case final v?) v,
        ];
    String? optStr(String k) {
      final v = j[k]?.toString().trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    return TorrentAttrs(
      mediaType: optStr('media_type'),
      contentType: optStr('content_type'),
      titlesZh: strList('titles_zh'),
      titlesEn: strList('titles_en'),
      titleCandidates: strList('title_candidates'),
      year: (j['year'] as num?)?.toInt(),
      seasons: intList('seasons'),
      episodes: intList('episodes'),
      episodesTotal: (j['episodes_total'] as num?)?.toInt(),
      complete: j['complete'] is bool ? j['complete'] as bool : null,
      resolution: optStr('resolution'),
      videoCodec: optStr('video_codec'),
      hdr: strList('hdr'),
      mediaSource: optStr('media_source'),
      remux: j['remux'] == true,
      audio: strList('audio'),
      subtitleLanguages: strList('subtitle_languages'),
      subtitleCarriers: strList('subtitle_carriers'),
      audioLanguages: strList('audio_languages'),
      platforms: strList('platforms'),
      releaseGroup: optStr('release_group'),
    );
  }

  Map<String, dynamic> toJson() => {
        if (mediaType != null) 'media_type': mediaType,
        if (contentType != null) 'content_type': contentType,
        'titles_zh': titlesZh,
        'titles_en': titlesEn,
        'title_candidates': titleCandidates,
        if (year != null) 'year': year,
        'seasons': seasons,
        'episodes': episodes,
        if (episodesTotal != null) 'episodes_total': episodesTotal,
        if (complete != null) 'complete': complete,
        if (resolution != null) 'resolution': resolution,
        if (videoCodec != null) 'video_codec': videoCodec,
        'hdr': hdr,
        if (mediaSource != null) 'media_source': mediaSource,
        'remux': remux,
        'audio': audio,
        'subtitle_languages': subtitleLanguages,
        'subtitle_carriers': subtitleCarriers,
        'audio_languages': audioLanguages,
        'platforms': platforms,
        if (releaseGroup != null) 'release_group': releaseGroup,
      };
}

/// PT 种子搜索单条命中（1:1 对齐 `API.TorrentHit`）。
class TorrentHit {
  const TorrentHit({
    required this.torrentId,
    required this.title,
    this.subtitle = '',
    this.category,
    this.siteCategoryId,
    this.siteCategoryName,
    this.size,
    this.sizeBytes = 0,
    this.seeders = 0,
    this.leechers = 0,
    this.snatched = 0,
    this.uploadTime,
    this.uploader = '',
    this.posterUrl,
    this.imageUrls = const [],
    this.free = false,
    this.freeDeadline,
    this.downloadVolumeFactor = 1.0,
    this.uploadVolumeFactor = 1.0,
    this.hitAndRun,
    this.detailUrl,
    this.downloadUrl,
    required this.siteId,
    required this.siteName,
    this.attrs,
    this.rawAttrs,
  });

  final String torrentId;
  final String title;
  final String subtitle;
  final String? category;
  final String? siteCategoryId;
  final String? siteCategoryName;
  final String? size;
  final int sizeBytes;
  final int seeders;
  final int leechers;
  final int snatched;
  final String? uploadTime;
  final String uploader;
  final String? posterUrl;
  final List<String> imageUrls;
  final bool free;
  final String? freeDeadline;
  final double downloadVolumeFactor;
  final double uploadVolumeFactor;
  final bool? hitAndRun;
  final String? detailUrl;
  final String? downloadUrl;
  final String siteId;
  final String siteName;
  final TorrentAttrs? attrs;
  final Map<String, dynamic>? rawAttrs;

  String get rowKey => '$siteId:$torrentId';

  bool get hasActions =>
      (detailUrl != null && detailUrl!.isNotEmpty) ||
      (downloadUrl != null && downloadUrl!.isNotEmpty);

  /// 种子图集：海报 + 截图去重。
  List<String> get slides {
    final seen = <String>{};
    final out = <String>[];
    if (posterUrl != null && posterUrl!.isNotEmpty && seen.add(posterUrl!)) {
      out.add(posterUrl!);
    }
    for (final u in imageUrls) {
      if (u.isNotEmpty && seen.add(u)) out.add(u);
    }
    return out;
  }

  factory TorrentHit.fromJson(Map<String, dynamic> o) {
    String? optStr(List<String> keys) {
      for (final k in keys) {
        final v = o[k]?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    final siteId = (o['site_id'] ?? o['site'] ?? '').toString();
    final siteName = (o['site_name'] ?? o['indexer_name'] ?? siteId).toString();
    final tid = (o['torrent_id'] ?? o['id'] ?? '').toString();
    final rawAttrs = o['attrs'] is Map
        ? Map<String, dynamic>.from(o['attrs'] as Map)
        : null;

    final dlFactor = (o['download_volume_factor'] as num?)?.toDouble() ??
        (o['free'] == true || o['is_free'] == true ? 0.0 : 1.0);
    final ulFactor = (o['upload_volume_factor'] as num?)?.toDouble() ?? 1.0;

    return TorrentHit(
      torrentId: tid,
      title: (o['title'] ?? o['name'] ?? '').toString(),
      subtitle: (o['subtitle'] ?? o['description'] ?? '').toString(),
      category: optStr(['category']),
      siteCategoryId: optStr(['site_category_id']),
      siteCategoryName: optStr(['site_category_name']),
      size: o['size'] is String ? optStr(['size']) : null,
      sizeBytes: (o['size_bytes'] as num?)?.toInt() ??
          (o['size'] is num ? (o['size'] as num).toInt() : 0),
      seeders: (o['seeders'] as num?)?.toInt() ?? 0,
      leechers: (o['leechers'] as num?)?.toInt() ??
          (o['peers'] as num?)?.toInt() ??
          0,
      snatched: (o['snatched'] as num?)?.toInt() ?? 0,
      uploadTime: optStr(['upload_time', 'publish_time', 'published_at', 'pub_date']),
      uploader: (o['uploader'] ?? '').toString(),
      posterUrl: optStr(['poster_url']),
      imageUrls: [
        for (final u in (o['image_urls'] as List<dynamic>? ?? const []))
          if (u != null && u.toString().trim().isNotEmpty) u.toString().trim(),
      ],
      free: o['free'] == true || o['is_free'] == true || dlFactor == 0,
      freeDeadline: optStr(['free_deadline']),
      downloadVolumeFactor: dlFactor,
      uploadVolumeFactor: ulFactor,
      hitAndRun: o['hit_and_run'] is bool
          ? o['hit_and_run'] as bool
          : (o['hr'] is bool ? o['hr'] as bool : null),
      detailUrl: optStr(['detail_url', 'page_url', 'details_url']),
      downloadUrl: optStr(['download_url', 'enclosure']),
      siteId: siteId,
      siteName: siteName.isEmpty ? 'PT 站点' : siteName,
      attrs: rawAttrs != null ? TorrentAttrs.fromJson(rawAttrs) : null,
      rawAttrs: rawAttrs,
    );
  }
}

enum SiteProgressState { searching, ok, error }

class SiteProgress {
  const SiteProgress({
    required this.siteId,
    required this.siteName,
    required this.state,
    this.count = 0,
    this.error,
    this.elapsedMs,
    this.hasMore,
  });

  final String siteId;
  final String siteName;
  final SiteProgressState state;
  final int count;
  final String? error;
  final int? elapsedMs;
  final bool? hasMore;

  SiteProgress copyWith({
    SiteProgressState? state,
    int? count,
    Object? error = _sentinel,
    Object? elapsedMs = _sentinel,
    Object? hasMore = _sentinel,
  }) =>
      SiteProgress(
        siteId: siteId,
        siteName: siteName,
        state: state ?? this.state,
        count: count ?? this.count,
        error: identical(error, _sentinel) ? this.error : error as String?,
        elapsedMs: identical(elapsedMs, _sentinel)
            ? this.elapsedMs
            : elapsedMs as int?,
        hasMore:
            identical(hasMore, _sentinel) ? this.hasMore : hasMore as bool?,
      );

  static const _sentinel = Object();

  factory SiteProgress.fromStatusJson(Map<String, dynamic> j) {
    final err = j['error']?.toString();
    final hasErr = err != null && err.isNotEmpty;
    return SiteProgress(
      siteId: (j['site_id'] ?? '').toString(),
      siteName: (j['site_name'] ?? j['site_id'] ?? '').toString(),
      state: hasErr ? SiteProgressState.error : SiteProgressState.ok,
      count: (j['count'] as num?)?.toInt() ?? 0,
      error: hasErr ? err : null,
      elapsedMs: (j['elapsed_ms'] as num?)?.toInt(),
      hasMore: j['has_more'] is bool ? j['has_more'] as bool : null,
    );
  }
}

enum TorrentStreamPhase { idle, connecting, streaming, done, error }

/// 7 维排序键（4 常规 + 3 智能，对齐 iOS `TorrentSortKey`）。
enum TorrentSortKey {
  seeders,
  time,
  size,
  snatched,
  complete,
  quality,
  free;

  String get label => switch (this) {
        TorrentSortKey.seeders => '做种数',
        TorrentSortKey.time => '发布时间',
        TorrentSortKey.size => '体积',
        TorrentSortKey.snatched => '完成数',
        TorrentSortKey.complete => '全集优先',
        TorrentSortKey.quality => '画质优先',
        TorrentSortKey.free => '免费优先',
      };

  static const regular = <TorrentSortKey>[
    TorrentSortKey.seeders,
    TorrentSortKey.time,
    TorrentSortKey.size,
    TorrentSortKey.snatched,
  ];

  static const smart = <TorrentSortKey>[
    TorrentSortKey.complete,
    TorrentSortKey.quality,
    TorrentSortKey.free,
  ];
}

class TorrentSort {
  const TorrentSort({
    this.key = TorrentSortKey.seeders,
    this.descending = true,
  });

  final TorrentSortKey key;
  final bool descending;

  TorrentSort picking(TorrentSortKey next) => next == key
      ? TorrentSort(key: next, descending: !descending)
      : TorrentSort(key: next, descending: true);

  bool get isDefault => key == TorrentSortKey.seeders && descending;

  @override
  bool operator ==(Object other) =>
      other is TorrentSort && other.key == key && other.descending == descending;

  @override
  int get hashCode => Object.hash(key, descending);
}

/// 3 种种子结果视图模式（对齐 iOS `TorrentResultView`）：分组（默认）/ 列表 / 图览。
enum TorrentResultView {
  group,
  list,
  poster;

  String get label => switch (this) {
        TorrentResultView.group => '作品分组',
        TorrentResultView.list => '原始列表',
        TorrentResultView.poster => '海报图览',
      };

  IconData get icon => switch (this) {
        TorrentResultView.group => McIcons.stack,
        TorrentResultView.list => McIcons.list2,
        TorrentResultView.poster => McIcons.gallery1,
      };
}

/// 12 维分面筛选键（对齐 iOS `TorrentFilterDim`）。
enum TorrentFilterDim {
  resolution,
  site,
  year,
  season,
  episode,
  source,
  platform,
  codec,
  hdr,
  audio,
  subtitle,
  group;

  String get title => switch (this) {
        TorrentFilterDim.resolution => '分辨率',
        TorrentFilterDim.site => '站点',
        TorrentFilterDim.year => '年份',
        TorrentFilterDim.season => '季',
        TorrentFilterDim.episode => '集',
        TorrentFilterDim.source => '片源',
        TorrentFilterDim.platform => '流媒体',
        TorrentFilterDim.codec => '视频编码',
        TorrentFilterDim.hdr => 'HDR',
        TorrentFilterDim.audio => '音频',
        TorrentFilterDim.subtitle => '字幕',
        TorrentFilterDim.group => '压制组',
      };
}

class TorrentFilters {
  const TorrentFilters({this.selected = const {}});

  final Map<TorrentFilterDim, Set<String>> selected;

  Set<String> values(TorrentFilterDim dim) => selected[dim] ?? const {};

  bool get isActive => selected.values.any((s) => s.isNotEmpty);

  TorrentFilters toggled(TorrentFilterDim dim, String value) {
    final next = <TorrentFilterDim, Set<String>>{
      for (final e in selected.entries) e.key: Set<String>.from(e.value),
    };
    final set = next.putIfAbsent(dim, () => <String>{});
    if (!set.remove(value)) set.add(value);
    if (set.isEmpty) next.remove(dim);
    return TorrentFilters(selected: next);
  }

  TorrentFilters cleared(TorrentFilterDim dim) {
    final next = <TorrentFilterDim, Set<String>>{
      for (final e in selected.entries)
        if (e.key != dim) e.key: Set<String>.from(e.value),
    };
    return TorrentFilters(selected: next);
  }
}

class TorrentFacetValue {
  const TorrentFacetValue({required this.value, required this.count});

  final String value;
  final int count;
}

class TorrentFacets {
  const TorrentFacets({this.byDim = const {}});

  final Map<TorrentFilterDim, List<TorrentFacetValue>> byDim;

  List<TorrentFacetValue> values(TorrentFilterDim dim) => byDim[dim] ?? const [];
}

class TorrentEntity {
  const TorrentEntity({
    required this.key,
    this.nameZh,
    this.nameEn,
    this.year,
    this.mediaType,
    this.contentType,
  });

  final String key;
  final String? nameZh;
  final String? nameEn;
  final int? year;
  final String? mediaType;
  final String? contentType;
}

enum TorrentSubmitState {
  idle,
  submitting,
  done,
  exists,
  error;

  String get downloadLabel => switch (this) {
        TorrentSubmitState.idle => '下载',
        TorrentSubmitState.submitting => '提交中…',
        TorrentSubmitState.done => '已提交',
        TorrentSubmitState.exists => '已在队列',
        TorrentSubmitState.error => '重试下载',
      };

  String get grabLabel => switch (this) {
        TorrentSubmitState.idle => '投给订阅',
        TorrentSubmitState.submitting => '投递中…',
        TorrentSubmitState.done || TorrentSubmitState.exists => '已投递',
        TorrentSubmitState.error => '重试投递',
      };
}

/// 服务端搜索历史条目（`GET /api/v1/search/history`）。
class SearchHistoryItem {
  const SearchHistoryItem({
    required this.id,
    required this.keyword,
    this.alsoKeywords = const [],
    required this.vertical,
    this.labelKey,
    this.label,
    this.categories = const [],
    this.siteIds = const [],
    this.posterMode = false,
    this.searchCount = 1,
    this.lastSearchedAt = '',
    this.hasSnapshot = false,
  });

  final int id;
  final String keyword;
  final List<String> alsoKeywords;
  final String vertical; // 'titles' | 'torrents'
  final String? labelKey;
  final String? label;
  final List<String> categories;
  final List<String> siteIds;
  final bool posterMode;
  final int searchCount;
  final String lastSearchedAt;
  final bool hasSnapshot;

  SearchScope get scope => SearchScope(
        label: label,
        categories: categories,
        siteIds: siteIds,
        posterMode: posterMode,
      );

  String get scopeLabel {
    if (vertical == 'titles') return '影视';
    final base = (label != null && label!.isNotEmpty) ? '资源 · $label' : '资源';
    if (alsoKeywords.isEmpty) return base;
    return '$base（另含 ${alsoKeywords.join(' / ')}）';
  }

  factory SearchHistoryItem.fromJson(Map<String, dynamic> j) => SearchHistoryItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        keyword: (j['keyword'] ?? '').toString(),
        alsoKeywords: [
          for (final a in (j['also_keywords'] as List<dynamic>? ?? const []))
            if (a != null && a.toString().trim().isNotEmpty)
              a.toString().trim(),
        ],
        vertical: (j['vertical'] ?? 'torrents').toString(),
        labelKey: j['label_key']?.toString(),
        label: j['label']?.toString(),
        categories: [
          for (final c in (j['categories'] as List<dynamic>? ?? const []))
            c.toString(),
        ],
        siteIds: [
          for (final s in (j['site_ids'] as List<dynamic>? ?? const []))
            s.toString(),
        ],
        posterMode: j['poster_mode'] == true,
        searchCount: (j['search_count'] as num?)?.toInt() ?? 1,
        lastSearchedAt: (j['last_searched_at'] ?? '').toString(),
        hasSnapshot: j['has_snapshot'] == true,
      );
}

class HistoryGroup {
  const HistoryGroup({
    required this.key,
    required this.keyword,
    required this.items,
  });

  final String key;
  final String keyword;
  final List<SearchHistoryItem> items;
}

/// 影视搜索命中（`POST /api/v1/search/titles` + 快照回放）。
class MediaSearchHit {
  const MediaSearchHit({
    required this.titleRef,
    required this.provider,
    required this.title,
    this.originalTitle = '',
    required this.mediaType,
    this.year,
    this.rating,
    this.posterUrl,
    this.backdropUrl,
    this.overview = '',
    this.extentLabel = '',
    this.genres = const [],
    this.inLibrary = false,
    this.libraryId,
    this.mediaItemId,
  });

  final String titleRef;
  final String provider; // 'douban' | 'tmdb'
  final String title;
  final String originalTitle;
  final String mediaType;
  final int? year;
  final double? rating;
  final String? posterUrl;
  final String? backdropUrl;
  final String overview;
  final String extentLabel;
  final List<String> genres;
  final bool inLibrary;
  final int? libraryId;
  final int? mediaItemId;

  static MediaSearchHit? fromJson(Map<String, dynamic> o) {
    final prov = (o['provider'] ?? o['source'] ?? '').toString().toLowerCase();
    final mType = (o['media_type'] ?? o['type'] ?? o['kind'] ?? 'movie')
        .toString();
    var ref = (o['title_ref'] ?? o['ref'] ?? '').toString();
    final extId = (o['external_id'] ?? o['tmdb_id'] ?? o['id'] ?? '').toString();
    if (ref.isEmpty && extId.isNotEmpty) {
      if (prov == 'douban') {
        ref = 'douban:$extId';
      } else {
        ref = 'tmdb:${mType == 'tv' ? 'tv' : 'movie'}:$extId';
      }
    }
    if (ref.isEmpty) return null;
    final resolvedProvider =
        prov.isNotEmpty ? prov : (ref.startsWith('douban:') ? 'douban' : 'tmdb');
    final lib = o['library_status'];
    final libMap = lib is Map ? Map<String, dynamic>.from(lib) : null;
    final owned = libMap != null &&
        (((libMap['file_count'] as num? ?? 0).toInt() > 0) ||
            (libMap['library_count'] as num? ?? 0).toInt() > 0 ||
            libMap['owned'] == true ||
            libMap['in_library'] == true);
    return MediaSearchHit(
      titleRef: ref,
      provider: resolvedProvider,
      title: (o['title'] ?? o['name'] ?? '').toString(),
      originalTitle: (o['original_title'] ?? '').toString(),
      mediaType: mType,
      year: (o['release_year'] as num?)?.toInt() ?? (o['year'] as num?)?.toInt(),
      rating: (o['provider_rating'] as num?)?.toDouble() ??
          (o['rating'] as num?)?.toDouble(),
      posterUrl: o['poster_url']?.toString(),
      backdropUrl: o['backdrop_url']?.toString(),
      overview: (o['overview'] ?? '').toString(),
      extentLabel: (o['extent_label'] ?? '').toString(),
      genres: [
        for (final g in (o['genres'] as List<dynamic>? ?? const [])) g.toString(),
      ],
      inLibrary: owned,
      libraryId: (libMap?['library_id'] as num?)?.toInt(),
      mediaItemId: (libMap?['media_item_id'] as num?)?.toInt() ??
          (libMap?['item_id'] as num?)?.toInt(),
    );
  }
}

/// 媒体库搜索命中（对齐 `API.LibrarySearchHit`）。
class LibrarySearchHit {
  const LibrarySearchHit({
    required this.itemId,
    required this.itemName,
    this.kind = 'movie',
    this.posterUrl,
    this.year,
    this.primaryLibraryId,
    this.libraryIds = const [],
    this.seasons = const [],
    this.episodeCount = 0,
    this.resolutions = const [],
    this.matchType = '',
    this.matchSourceField = '',
    this.matchLabel = '',
    this.matchPersonId,
  });

  final int itemId;
  final String itemName;
  final String kind;
  final String? posterUrl;
  final int? year;
  final int? primaryLibraryId;
  final List<int> libraryIds;
  final List<int> seasons;
  final int episodeCount;
  final List<String> resolutions;
  final String matchType;
  final String matchSourceField;
  final String matchLabel;
  final int? matchPersonId;

  int get targetLibraryId =>
      primaryLibraryId ?? (libraryIds.isNotEmpty ? libraryIds.first : 0);

  /// 命中原因（仅别名/原名/拼音/人物带出时展示，直接标题命中不冗余显示）。
  String? get matchHint {
    if (matchLabel.isEmpty) return null;
    if (matchPersonId == null &&
        matchSourceField == 'title' &&
        matchType.startsWith('text')) {
      return null;
    }
    return matchLabel;
  }

  /// 海报下方规格副行（季/集 · 分辨率）。
  String? get footnote {
    final parts = <String>[];
    if (kind == 'tv' && seasons.isNotEmpty) {
      parts.add(
        seasons.length == 1
            ? '第 ${seasons.first} 季 · $episodeCount 集'
            : '${seasons.length} 季 · $episodeCount 集',
      );
    }
    if (resolutions.isNotEmpty) parts.add(resolutions.join('/'));
    return parts.isEmpty ? null : parts.join(' · ');
  }

  factory LibrarySearchHit.fromJson(Map<String, dynamic> o) {
    final item = o['item'];
    final itemMap =
        item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final match = o['match'];
    final matchMap =
        match is Map ? Map<String, dynamic>.from(match) : <String, dynamic>{};
    return LibrarySearchHit(
      itemId: (itemMap['media_item_id'] as num? ?? itemMap['id'] as num? ?? 0)
          .toInt(),
      itemName: (itemMap['title'] ?? itemMap['name'] ?? '').toString(),
      kind: (itemMap['kind'] ?? 'movie').toString(),
      posterUrl: itemMap['poster_url']?.toString(),
      year: (itemMap['year'] as num?)?.toInt() ??
          (itemMap['release_year'] as num?)?.toInt(),
      primaryLibraryId: (itemMap['library_id'] as num?)?.toInt(),
      libraryIds: [
        for (final id in (o['library_ids'] as List<dynamic>? ?? const []))
          if (id is num) id.toInt(),
      ],
      seasons: [
        for (final s in (itemMap['seasons'] as List<dynamic>? ?? const []))
          if (s is num) s.toInt(),
      ],
      episodeCount: (itemMap['episode_count'] as num?)?.toInt() ?? 0,
      resolutions: [
        for (final r in (itemMap['resolutions'] as List<dynamic>? ?? const []))
          if (r != null && r.toString().isNotEmpty) r.toString(),
      ],
      matchType: (matchMap['type'] ?? '').toString(),
      matchSourceField: (matchMap['source_field'] ?? '').toString(),
      matchLabel: (matchMap['label'] ?? '').toString(),
      matchPersonId: (matchMap['person_id'] as num?)?.toInt(),
    );
  }
}

/// 媒体库人物命中（对齐 `API.LibrarySearchPerson`）。
class LibrarySearchPerson {
  const LibrarySearchPerson({
    required this.id,
    this.tmdbPersonId,
    required this.name,
    this.avatarUrl,
    this.itemCount = 0,
  });

  final int id;
  final int? tmdbPersonId;
  final String name;
  final String? avatarUrl;
  final int itemCount;

  factory LibrarySearchPerson.fromJson(Map<String, dynamic> o) =>
      LibrarySearchPerson(
        id: (o['id'] as num? ?? 0).toInt(),
        tmdbPersonId: (o['tmdb_person_id'] as num?)?.toInt(),
        name: (o['name'] ?? '').toString(),
        avatarUrl: o['avatar_url']?.toString() ?? o['profile_path']?.toString(),
        itemCount: (o['item_count'] as num? ?? 0).toInt(),
      );
}

/// 媒体库实时搜索联想（对齐 `API.LibrarySearchSuggestion`）。
class SearchSuggestion {
  const SearchSuggestion({
    required this.text,
    this.type = 'title',
    this.label,
    this.personId,
    this.mediaItemId,
  });

  final String text;
  final String type;
  final String? label;
  final int? personId;
  final int? mediaItemId;

  String? get informativeReason =>
      (label == null || label!.isEmpty || label == '名称匹配') ? null : label;

  factory SearchSuggestion.fromJson(Map<String, dynamic> o) => SearchSuggestion(
        text: (o['text'] ?? '').toString(),
        type: (o['type'] ?? 'title').toString(),
        label: o['label']?.toString(),
        personId: (o['person_id'] as num?)?.toInt(),
        mediaItemId: (o['media_item_id'] as num?)?.toInt(),
      );
}

// ── 下载目标与偏好模型（对齐 iOS `DownloadTargetDialog.swift`） ──

class DownloadTargetIdentity {
  const DownloadTargetIdentity({
    required this.kind,
    required this.title,
    required this.year,
  });

  final String kind;
  final String title;
  final int year;
}

class DownloadTargetRequest {
  const DownloadTargetRequest({
    required this.hitKey,
    required this.siteId,
    required this.downloadUrl,
    required this.torrentId,
    this.identity,
    this.subtitle,
    this.hint,
    required this.category,
    this.reason,
  });

  final String hitKey;
  final String siteId;
  final String downloadUrl;
  final String torrentId;
  final DownloadTargetIdentity? identity;
  final String? subtitle;
  final String? hint;
  final String category;
  final String? reason;

  DownloadTargetRequest withReason(String? nextReason) => DownloadTargetRequest(
        hitKey: hitKey,
        siteId: siteId,
        downloadUrl: downloadUrl,
        torrentId: torrentId,
        identity: identity,
        subtitle: subtitle,
        hint: hint,
        category: category,
        reason: nextReason,
      );

  static DownloadTargetRequest? fromHit(TorrentHit hit, {String keyword = ''}) {
    final url = hit.downloadUrl;
    if (url == null || url.isEmpty) return null;
    final a = hit.attrs;
    final title = (a != null && a.titlesZh.isNotEmpty)
        ? a.titlesZh.first
        : (a != null && a.titlesEn.isNotEmpty ? a.titlesEn.first : null);
    DownloadTargetIdentity? id;
    if (a != null &&
        (a.mediaType == 'movie' || a.mediaType == 'tv') &&
        title != null &&
        a.year != null) {
      id = DownloadTargetIdentity(kind: a.mediaType!, title: title, year: a.year!);
    }
    final trimmed = keyword.trim();
    return DownloadTargetRequest(
      hitKey: hit.rowKey,
      siteId: hit.siteId,
      downloadUrl: url,
      torrentId: hit.torrentId,
      identity: id,
      subtitle: hit.subtitle.isEmpty ? null : hit.subtitle,
      hint: trimmed.isEmpty ? null : trimmed,
      category: hit.category ?? 'other',
    );
  }
}

class DownloadTargetPref {
  const DownloadTargetPref({
    required this.category,
    required this.kind,
    this.savePath,
    this.downloaderId,
    this.downloaderName,
    this.updatedAt = '',
  });

  final String category;
  final String kind; // 'smart' | 'dir' | 'default'
  final String? savePath;
  final int? downloaderId;
  final String? downloaderName;
  final String updatedAt;

  factory DownloadTargetPref.fromJson(Map<String, dynamic> j) =>
      DownloadTargetPref(
        category: (j['category'] ?? 'other').toString(),
        kind: (j['kind'] ?? 'default').toString(),
        savePath: j['save_path']?.toString(),
        downloaderId: (j['downloader_id'] as num?)?.toInt(),
        downloaderName: j['downloader_name']?.toString(),
        updatedAt: (j['updated_at'] ?? '').toString(),
      );
}

class ManualDownloadCandidate {
  const ManualDownloadCandidate({
    required this.tmdbId,
    required this.kind,
    required this.title,
    this.year,
    this.episodeCount,
    this.posterUrl,
  });

  final int tmdbId;
  final String kind;
  final String title;
  final int? year;
  final int? episodeCount;
  final String? posterUrl;

  factory ManualDownloadCandidate.fromJson(Map<String, dynamic> j) =>
      ManualDownloadCandidate(
        tmdbId: (j['tmdb_id'] as num?)?.toInt() ?? 0,
        kind: (j['kind'] ?? 'movie').toString(),
        title: (j['title'] ?? '').toString(),
        year: (j['year'] as num?)?.toInt(),
        episodeCount: (j['episode_count'] as num?)?.toInt(),
        posterUrl: j['poster_url']?.toString(),
      );
}

class ManualDownloadTarget {
  const ManualDownloadTarget({
    required this.status,
    this.tmdbId,
    this.kind,
    this.title,
    this.year,
    this.candidates = const [],
    this.libraryId,
    this.libraryName,
    this.mode,
    this.path,
    this.entryDir,
    this.stagingPath,
    this.routeReason,
    this.ok = false,
    this.warning,
  });

  final String status; // 'ready' | 'ambiguous' | 'not_found'
  final int? tmdbId;
  final String? kind;
  final String? title;
  final int? year;
  final List<ManualDownloadCandidate> candidates;
  final int? libraryId;
  final String? libraryName;
  final String? mode; // 'watch' | 'inplace'
  final String? path;
  final String? entryDir;
  final String? stagingPath;
  final String? routeReason;
  final bool ok;
  final String? warning;

  factory ManualDownloadTarget.fromJson(Map<String, dynamic> j) =>
      ManualDownloadTarget(
        status: (j['status'] ?? 'not_found').toString(),
        tmdbId: (j['tmdb_id'] as num?)?.toInt(),
        kind: j['kind']?.toString(),
        title: j['title']?.toString(),
        year: (j['year'] as num?)?.toInt(),
        candidates: [
          for (final c in (j['candidates'] as List<dynamic>? ?? const []))
            if (c is Map)
              ManualDownloadCandidate.fromJson(Map<String, dynamic>.from(c)),
        ],
        libraryId: (j['library_id'] as num?)?.toInt(),
        libraryName: j['library_name']?.toString(),
        mode: j['mode']?.toString(),
        path: j['path']?.toString(),
        entryDir: j['entry_dir']?.toString(),
        stagingPath: j['staging_path']?.toString(),
        routeReason: j['route_reason']?.toString(),
        ok: j['ok'] == true,
        warning: j['warning']?.toString(),
      );
}

class PathMappingInfo {
  const PathMappingInfo({required this.local, required this.remote});

  final String local;
  final String remote;

  factory PathMappingInfo.fromJson(Map<String, dynamic> j) => PathMappingInfo(
        local: (j['local'] ?? '').toString(),
        remote: (j['remote'] ?? '').toString(),
      );
}

class DownloaderInfo {
  const DownloaderInfo({
    required this.id,
    required this.name,
    this.savePath,
    this.pathMappings = const [],
    this.isDefault = false,
    this.usable = false,
  });

  final int id;
  final String name;
  final String? savePath;
  final List<PathMappingInfo> pathMappings;
  final bool isDefault;
  final bool usable;

  factory DownloaderInfo.fromJson(Map<String, dynamic> j) {
    final sp = j['save_path']?.toString().trim();
    return DownloaderInfo(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: (j['name'] ?? '').toString(),
      savePath: (sp != null && sp.isNotEmpty) ? sp : null,
      pathMappings: [
        for (final m in (j['path_mappings'] as List<dynamic>? ?? const []))
          if (m is Map) PathMappingInfo.fromJson(Map<String, dynamic>.from(m)),
      ],
      isDefault: j['is_default'] == true,
      usable: j['usable'] == true || j['enabled'] == true,
    );
  }
}

class DownloadSubmitResult {
  const DownloadSubmitResult({
    this.infoHash,
    this.name = '',
    this.alreadyExists = false,
    this.downloaderId = 0,
    this.downloaderName = '',
    this.savePath,
  });

  final String? infoHash;
  final String name;
  final bool alreadyExists;
  final int downloaderId;
  final String downloaderName;
  final String? savePath;

  factory DownloadSubmitResult.fromJson(Map<String, dynamic> j) {
    final sp = j['save_path']?.toString().trim();
    return DownloadSubmitResult(
      infoHash: j['info_hash']?.toString(),
      name: (j['name'] ?? '').toString(),
      alreadyExists: j['already_exists'] == true,
      downloaderId: (j['downloader_id'] as num?)?.toInt() ?? 0,
      downloaderName: (j['downloader_name'] ?? '下载器').toString(),
      savePath: (sp != null && sp.isNotEmpty) ? sp : null,
    );
  }
}

class MemberLibraryOption {
  const MemberLibraryOption({
    required this.id,
    required this.name,
    required this.kind,
    this.isDefault = false,
  });

  final int id;
  final String name;
  final String kind;
  final bool isDefault;

  String get kindLabel => switch (kind) {
        'movie' => '电影库',
        'tv' => '剧集库',
        'video' => '视频库',
        'photo' => '图片库',
        _ => kind,
      };

  factory MemberLibraryOption.fromJson(Map<String, dynamic> j) =>
      MemberLibraryOption(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        kind: (j['kind'] ?? 'movie').toString(),
        isDefault: j['is_default'] == true,
      );
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
