// 媒体库域的数据模型（照抄服务端 schemas，逐字段对齐 Kotlin core/model）。
// 手写 fromJson：字段缺失退回默认值，与 kotlinx.serialization 的宽松口径一致。

int _asInt(dynamic v, [int fallback = 0]) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? fallback);

double _asDouble(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;

bool _asBool(dynamic v, [bool fallback = false]) =>
    v is bool ? v : (v?.toString() == 'true' ? true : fallback);

String _asStr(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) from) =>
    (v as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().map(from).toList();

List<int> _intList(dynamic v) =>
    (v as List<dynamic>? ?? []).map((e) => _asInt(e)).toList();

/// 库存统计（LibraryStats）。
class LibraryStats {
  const LibraryStats({
    this.itemCount = 0,
    this.fileCount = 0,
    this.totalSizeBytes = 0,
    this.unidentifiedCount = 0,
    this.missingCount = 0,
    this.ignoredCount = 0,
  });

  final int itemCount;
  final int fileCount;
  final int totalSizeBytes;
  final int unidentifiedCount;
  final int missingCount;
  final int ignoredCount;

  factory LibraryStats.fromJson(Map<String, dynamic> j) => LibraryStats(
        itemCount: _asInt(j['item_count']),
        fileCount: _asInt(j['file_count']),
        totalSizeBytes: _asInt(j['total_size_bytes']),
        unidentifiedCount: _asInt(j['unidentified_count']),
        missingCount: _asInt(j['missing_count']),
        ignoredCount: _asInt(j['ignored_count']),
      );
}

/// 库能力开关（LibraryCapabilitiesView）；浏览页只用到 scraped。
class LibraryCapabilitiesView {
  const LibraryCapabilitiesView({this.scraped = false, this.playable = true});

  final bool scraped;
  final bool playable;

  factory LibraryCapabilitiesView.fromJson(Map<String, dynamic> j) =>
      LibraryCapabilitiesView(
        scraped: _asBool(j['scraped']),
        playable: j['playable'] == null ? true : _asBool(j['playable']),
      );
}

/// 扫描 / 整理的实时进度（ScanProgressView）。
class ScanProgress {
  const ScanProgress({this.phase, this.processed = 0, this.total = 0});

  final String? phase;
  final int processed;
  final int total;

  static ScanProgress? maybe(dynamic v) => v is Map<String, dynamic>
      ? ScanProgress(
          phase: v['phase']?.toString(),
          processed: _asInt(v['processed']),
          total: _asInt(v['total']),
        )
      : null;
}

/// 整库元数据刷新状态（MetadataRefreshView）；active 只取首条「标题 · 阶段」。
class MetadataRefresh {
  const MetadataRefresh({
    this.refreshing = false,
    this.processed = 0,
    this.total = 0,
    this.activeLine,
  });

  final bool refreshing;
  final int processed;
  final int total;
  final String? activeLine;

  static MetadataRefresh? maybe(dynamic v) {
    if (v is! Map<String, dynamic>) return null;
    final active = (v['active'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return MetadataRefresh(
      refreshing: _asBool(v['refreshing']),
      processed: _asInt(v['processed']),
      total: _asInt(v['total']),
      activeLine: active.isEmpty
          ? null
          : '${_asStr(active.first['title'])} · ${_asStr(active.first['phase'])}',
    );
  }
}

/// 一个媒体库（LibraryView）。
class LibraryView {
  const LibraryView({
    required this.id,
    this.name = '',
    this.kind = 'movie',
    this.paths = const [],
    this.excludeFromHome = false,
    this.viewerAccess = true,
    this.isDefault = false,
    this.scanning = false,
    this.organizing = false,
    this.customCover = false,
    this.scanProgress,
    this.organizeProgress,
    this.metadataRefresh,
    this.lastScanDeferred = 0,
    this.stats = const LibraryStats(),
    this.capabilities = const LibraryCapabilitiesView(),
  });

  final int id;
  final String name;
  final String kind;
  final List<String> paths;
  final bool excludeFromHome;
  final bool viewerAccess;
  final bool isDefault;
  final bool scanning;
  final bool organizing;

  /// 封面是用户上传的自定义图（空库也照样出图）。
  final bool customCover;
  final ScanProgress? scanProgress;
  final ScanProgress? organizeProgress;
  final MetadataRefresh? metadataRefresh;

  /// 最近一次扫描后等待入账的文件数（last_scan.deferred）。
  final int lastScanDeferred;
  final LibraryStats stats;
  final LibraryCapabilitiesView capabilities;

  /// 库状态指纹（首页据此判断是否需要重拉各行条目）。
  String get fingerprint => [
        id, name, kind, excludeFromHome, viewerAccess, isDefault, scanning,
        organizing, customCover, scanProgress?.processed, organizeProgress?.processed,
        metadataRefresh?.refreshing, metadataRefresh?.processed, lastScanDeferred,
        stats.itemCount, stats.fileCount, stats.totalSizeBytes,
      ].join('|');

  factory LibraryView.fromJson(Map<String, dynamic> j) => LibraryView(
        id: _asInt(j['id']),
        name: _asStr(j['name']),
        kind: j['kind']?.toString() ?? 'movie',
        paths: [
          for (final p in (j['paths'] as List<dynamic>? ??
              j['root_paths'] as List<dynamic>? ??
              const []))
            if (p is Map) _asStr(p['path']) else _asStr(p),
        ].where((s) => s.isNotEmpty).toList(),
        excludeFromHome: _asBool(j['exclude_from_home']),
        viewerAccess: j['viewer_access'] == null ? true : _asBool(j['viewer_access']),
        isDefault: _asBool(j['is_default']),
        scanning: _asBool(j['scanning']),
        organizing: _asBool(j['organizing']),
        customCover: _asBool(j['custom_cover']),
        scanProgress: ScanProgress.maybe(j['scan_progress']),
        organizeProgress: ScanProgress.maybe(j['organize_progress']),
        metadataRefresh: MetadataRefresh.maybe(j['metadata_refresh']),
        lastScanDeferred: j['last_scan'] is Map<String, dynamic>
            ? _asInt((j['last_scan'] as Map<String, dynamic>)['deferred'])
            : 0,
        stats: j['stats'] is Map<String, dynamic>
            ? LibraryStats.fromJson(j['stats'] as Map<String, dynamic>)
            : const LibraryStats(),
        capabilities: j['capabilities'] is Map<String, dynamic>
            ? LibraryCapabilitiesView.fromJson(j['capabilities'] as Map<String, dynamic>)
            : const LibraryCapabilitiesView(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'paths': paths,
        'exclude_from_home': excludeFromHome,
        'viewer_access': viewerAccess,
        'is_default': isDefault,
        'custom_cover': customCover,
        'stats': {
          'item_count': stats.itemCount,
          'file_count': stats.fileCount,
          'total_size_bytes': stats.totalSizeBytes,
          'unidentified_count': stats.unidentifiedCount,
          'missing_count': stats.missingCount,
          'ignored_count': stats.ignoredCount,
        },
        'capabilities': {
          'scraped': capabilities.scraped,
          'playable': capabilities.playable,
        },
      };
}

/// 最近一次入库批次的剧集摘要（LibraryRecentAdditionView）。
class LibraryRecentAddition {
  const LibraryRecentAddition({
    this.seasonCount = 0,
    this.episodeCount = 0,
    this.seasonNumber,
    this.firstEpisodeNumber,
    this.lastEpisodeNumber,
    this.completeSeason = false,
  });

  final int seasonCount;
  final int episodeCount;
  final int? seasonNumber;
  final int? firstEpisodeNumber;
  final int? lastEpisodeNumber;
  final bool completeSeason;

  static LibraryRecentAddition? maybe(dynamic v) => v is Map<String, dynamic>
      ? LibraryRecentAddition(
          seasonCount: _asInt(v['season_count']),
          episodeCount: _asInt(v['episode_count']),
          seasonNumber: v['season_number'] == null ? null : _asInt(v['season_number']),
          firstEpisodeNumber:
              v['first_episode_number'] == null ? null : _asInt(v['first_episode_number']),
          lastEpisodeNumber:
              v['last_episode_number'] == null ? null : _asInt(v['last_episode_number']),
          completeSeason: _asBool(v['complete_season']),
        )
      : null;
}

/// 海报墙 / 横滚行通用的一条作品（LibraryItemView）。
class LibraryItemView {
  const LibraryItemView({
    required this.mediaItemId,
    this.kind = 'movie',
    this.libraryId,
    this.title = '',
    this.year,
    this.posterUrl,
    this.backdropUrl,
    this.primaryAspect = 0.6667,
    this.rating,
    this.fileCount = 0,
    this.totalSizeBytes = 0,
    this.seasons = const [],
    this.resolutions = const [],
    this.isFavorite = false,
    this.addedAt,
    this.recentAddition,
    this.favoriteSeasonNumber,
    this.favoriteEpisodeNumber,
  });

  final int mediaItemId;
  final String kind;
  final int? libraryId;
  final String title;
  final int? year;
  final String? posterUrl;
  final String? backdropUrl;
  final double primaryAspect;
  final double? rating;
  final int fileCount;
  final int totalSizeBytes;
  String get kindLabel => switch (kind) {
        'movie' => '电影',
        'tv' => '剧集',
        'episode' => '单集',
        _ => kind,
      };

  final List<int> seasons;
  final List<String> resolutions;
  final bool isFavorite;

  /// 最近一次文件入账时间（「最近添加」依据；长按信息「N 天前入库」）。
  final String? addedAt;
  final LibraryRecentAddition? recentAddition;

  /// 收藏层级（仅收藏列表）：整剧为 null；收藏了某季/某集时有值。
  final int? favoriteSeasonNumber;
  final int? favoriteEpisodeNumber;

  factory LibraryItemView.fromJson(Map<String, dynamic> j) => LibraryItemView(
        mediaItemId: _asInt(j['media_item_id']),
        kind: j['kind']?.toString() ?? 'movie',
        libraryId: j['library_id'] == null ? null : _asInt(j['library_id']),
        title: _asStr(j['title']),
        year: j['year'] == null ? null : _asInt(j['year']),
        posterUrl: j['poster_url']?.toString(),
        backdropUrl: j['backdrop_url']?.toString(),
        primaryAspect: _asDouble(j['primary_aspect'], 0.6667),
        rating: j['rating'] == null ? null : _asDouble(j['rating']),
        fileCount: _asInt(j['file_count']),
        totalSizeBytes: _asInt(j['total_size_bytes']),
        seasons: _intList(j['seasons']),
        resolutions:
            (j['resolutions'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        isFavorite: _asBool(j['is_favorite']),
        addedAt: j['added_at']?.toString(),
        recentAddition: LibraryRecentAddition.maybe(j['recent_addition']),
        favoriteSeasonNumber: j['favorite_season_number'] == null
            ? null
            : _asInt(j['favorite_season_number']),
        favoriteEpisodeNumber: j['favorite_episode_number'] == null
            ? null
            : _asInt(j['favorite_episode_number']),
      );

  Map<String, dynamic> toJson() => {
        'media_item_id': mediaItemId,
        'kind': kind,
        if (libraryId != null) 'library_id': libraryId,
        'title': title,
        if (year != null) 'year': year,
        if (posterUrl != null) 'poster_url': posterUrl,
        if (backdropUrl != null) 'backdrop_url': backdropUrl,
        'primary_aspect': primaryAspect,
        if (rating != null) 'rating': rating,
        'file_count': fileCount,
        'total_size_bytes': totalSizeBytes,
        'seasons': seasons,
        'resolutions': resolutions,
        'is_favorite': isFavorite,
        if (addedAt != null) 'added_at': addedAt,
      };
}

/// `GET /playback/favorites` 的结果（FavoritesView）。
class FavoritesResult {
  const FavoritesResult({this.items = const [], this.total = 0});

  final List<LibraryItemView> items;
  final int total;
}

/// 「接下来继续」的一条（UpNextItemView）。
class UpNextItem {
  const UpNextItem({
    required this.mediaItemId,
    required this.libraryId,
    this.kind = 'movie',
    this.title = '',
    this.year,
    this.posterUrl,
    this.posterAspect = 0.66,
    this.backdropUrl,
    this.episodeStillUrl,
    this.episodeStillOriginalUrl,
    this.overview,
    this.genres = const [],
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.episodeTitle,
    this.unwatchedAheadCount = 0,
    this.positionMs = 0,
    this.durationMs,
    this.progressPercent,
    this.advanced = false,
    this.lastPlayedAt,
  });

  final int mediaItemId;
  final int libraryId;
  final String kind;
  final String title;
  final int? year;
  final String? posterUrl;
  final double posterAspect;
  final String? backdropUrl;
  final String? episodeStillUrl;
  final String? episodeStillOriginalUrl;
  final String? overview;
  final List<String> genres;
  final int seasonNumber;
  final int episodeNumber;
  final String? episodeTitle;
  final int unwatchedAheadCount;
  final int positionMs;
  final int? durationMs;
  final double? progressPercent;
  final bool advanced;
  final String? lastPlayedAt;

  bool get isEpisode => kind == 'tv';

  factory UpNextItem.fromJson(Map<String, dynamic> j) => UpNextItem(
        mediaItemId: _asInt(j['media_item_id']),
        libraryId: _asInt(j['library_id']),
        kind: j['kind']?.toString() ?? 'movie',
        title: _asStr(j['title']),
        year: j['year'] == null ? null : _asInt(j['year']),
        posterUrl: j['poster_url']?.toString(),
        posterAspect: _asDouble(j['poster_aspect'], 0.66),
        backdropUrl: j['backdrop_url']?.toString(),
        episodeStillUrl: j['episode_still_url']?.toString(),
        episodeStillOriginalUrl: j['episode_still_original_url']?.toString(),
        overview: j['overview']?.toString(),
        genres: (j['genres'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        seasonNumber: _asInt(j['season_number']),
        episodeNumber: _asInt(j['episode_number']),
        episodeTitle: j['episode_title']?.toString(),
        unwatchedAheadCount: _asInt(j['unwatched_ahead_count']),
        positionMs: _asInt(j['position_ms']),
        durationMs: j['duration_ms'] == null ? null : _asInt(j['duration_ms']),
        progressPercent:
            j['progress_percent'] == null ? null : _asDouble(j['progress_percent']),
        advanced: _asBool(j['advanced']),
        lastPlayedAt: j['last_played_at']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'media_item_id': mediaItemId,
        'library_id': libraryId,
        'kind': kind,
        'title': title,
        if (year != null) 'year': year,
        if (posterUrl != null) 'poster_url': posterUrl,
        'poster_aspect': posterAspect,
        if (backdropUrl != null) 'backdrop_url': backdropUrl,
        if (episodeStillUrl != null) 'episode_still_url': episodeStillUrl,
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        if (episodeTitle != null) 'episode_title': episodeTitle,
        'unwatched_ahead_count': unwatchedAheadCount,
        'position_ms': positionMs,
        if (durationMs != null) 'duration_ms': durationMs,
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      };
}

/// 合集卡片的一张封面图（CollectionCover）。
class CollectionCover {
  const CollectionCover({this.url = '', this.blur});

  final String url;
  final String? blur;

  factory CollectionCover.fromJson(Map<String, dynamic> j) => CollectionCover(
        url: _asStr(j['url']),
        blur: j['blur']?.toString(),
      );
}

/// 一个合集（CollectionView）：存好的筛选，形态由服务端推导。
class CollectionView {
  const CollectionView({
    required this.id,
    this.name = '',
    this.libraryId,
    this.sort = 'added_at',
    this.visibility = 'household',
    this.builtin,
    this.kind = 'user',
    this.editable = true,
    this.ruleDriven = false,
    this.itemCount = 0,
    this.coverItemId,
    this.covers = const [],
    this.position = 0,
  });

  final int id;
  final String name;
  final int? libraryId;
  final String sort;
  final String visibility;
  final String? builtin;
  final String kind;
  final bool editable;
  final bool ruleDriven;
  final int itemCount;
  final int? coverItemId;
  final List<CollectionCover> covers;
  final int position;

  factory CollectionView.fromJson(Map<String, dynamic> j) => CollectionView(
        id: _asInt(j['id']),
        name: _asStr(j['name']),
        libraryId: j['library_id'] == null ? null : _asInt(j['library_id']),
        sort: j['sort']?.toString() ?? 'added_at',
        visibility: j['visibility']?.toString() ?? 'household',
        builtin: j['builtin']?.toString(),
        kind: j['kind']?.toString() ?? 'user',
        editable: j['editable'] == null ? true : _asBool(j['editable']),
        ruleDriven: _asBool(j['rule_driven']),
        itemCount: _asInt(j['item_count']),
        coverItemId: j['cover_item_id'] == null ? null : _asInt(j['cover_item_id']),
        covers: _list(j['covers'], CollectionCover.fromJson),
        position: _asInt(j['position']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (libraryId != null) 'library_id': libraryId,
        'sort': sort,
        'visibility': visibility,
        if (builtin != null) 'builtin': builtin,
        'kind': kind,
        'editable': editable,
        'rule_driven': ruleDriven,
        'item_count': itemCount,
        'covers': [
          for (final c in covers) {'url': c.url, if (c.blur != null) 'blur': c.blur},
        ],
        'position': position,
      };
}

/// 筛选面板里的一个候选值（FacetValue）：count 已按「排除本维自身条件」算好。
class FacetValue {
  const FacetValue({this.value = '', this.label = '', this.count = 0});

  final String value;
  final String label;
  final int count;

  factory FacetValue.fromJson(Map<String, dynamic> j) => FacetValue(
        value: _asStr(j['value']),
        label: _asStr(j['label']),
        count: _asInt(j['count']),
      );
}

/// `GET /libraries/{id}/facets` 的结果（LibraryFacets）。
class LibraryFacets {
  const LibraryFacets({
    this.total = 0,
    this.genres = const [],
    this.countries = const [],
    this.decades = const [],
    this.watch = const [],
    this.ratings = const [],
    this.runtimes = const [],
    this.languages = const [],
    this.resolutions = const [],
    this.hdr = const [],
    this.stock = const [],
  });

  final int total;
  final List<FacetValue> genres;
  final List<FacetValue> countries;
  final List<FacetValue> decades;
  final List<FacetValue> watch;
  final List<FacetValue> ratings;
  final List<FacetValue> runtimes;
  final List<FacetValue> languages;
  final List<FacetValue> resolutions;
  final List<FacetValue> hdr;
  final List<FacetValue> stock;

  factory LibraryFacets.fromJson(Map<String, dynamic> j) => LibraryFacets(
        total: _asInt(j['total']),
        genres: _list(j['genres'], FacetValue.fromJson),
        countries: _list(j['countries'], FacetValue.fromJson),
        decades: _list(j['decades'], FacetValue.fromJson),
        watch: _list(j['watch'], FacetValue.fromJson),
        ratings: _list(j['ratings'], FacetValue.fromJson),
        runtimes: _list(j['runtimes'], FacetValue.fromJson),
        languages: _list(j['languages'], FacetValue.fromJson),
        resolutions: _list(j['resolutions'], FacetValue.fromJson),
        hdr: _list(j['hdr'], FacetValue.fromJson),
        stock: _list(j['stock'], FacetValue.fromJson),
      );
}

/// 海报墙跳转索引的一档（LibraryIndexEntry）。
class LibraryIndexEntry {
  const LibraryIndexEntry({this.initial = '', this.count = 0, this.offset = 0});

  final String initial;
  final int count;
  final int offset;

  factory LibraryIndexEntry.fromJson(Map<String, dynamic> j) => LibraryIndexEntry(
        initial: _asStr(j['initial']),
        count: _asInt(j['count']),
        offset: _asInt(j['offset']),
      );
}

/// 按类型的跨库墙概况（`GET /libraries/kinds/{kind}`）。
class LibraryKindSummaryView {
  const LibraryKindSummaryView({
    this.kind = 'movie',
    this.libraryIds = const [],
    this.itemCount = 0,
  });

  final String kind;
  final List<int> libraryIds;
  final int itemCount;

  factory LibraryKindSummaryView.fromJson(Map<String, dynamic> j) =>
      LibraryKindSummaryView(
        kind: j['kind']?.toString() ?? 'movie',
        libraryIds: _intList(j['library_ids']),
        itemCount: _asInt(j['item_count']),
      );
}

/// 首页一「行」偏好（HomeRowPref）：空即默认。
class HomeRowPref {
  const HomeRowPref({
    required this.id,
    this.sort,
    this.order,
    this.name,
    this.unwatched,
    this.hidden,
    this.libraryId,
    this.collectionId,
    this.mediaKind,
  });

  final String id;
  final String? sort;
  final String? order;
  final String? name;
  final bool? unwatched;
  final bool? hidden;
  final int? libraryId;
  final int? collectionId;
  final String? mediaKind;

  factory HomeRowPref.fromJson(Map<String, dynamic> j) => HomeRowPref(
        id: _asStr(j['id']),
        sort: j['sort']?.toString(),
        order: j['order']?.toString(),
        name: j['name']?.toString(),
        unwatched: j['unwatched'] == null ? null : _asBool(j['unwatched']),
        hidden: j['hidden'] == null ? null : _asBool(j['hidden']),
        libraryId: j['library_id'] == null ? null : _asInt(j['library_id']),
        collectionId: j['collection_id'] == null ? null : _asInt(j['collection_id']),
        mediaKind: j['media_kind']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (sort != null) 'sort': sort,
        if (order != null) 'order': order,
        if (name != null) 'name': name,
        if (unwatched != null) 'unwatched': unwatched,
        if (hidden != null) 'hidden': hidden,
        if (libraryId != null) 'library_id': libraryId,
        if (collectionId != null) 'collection_id': collectionId,
        if (mediaKind != null) 'media_kind': mediaKind,
      };
}

/// 人物搜索结果的一条命中（LibrarySearchHit）。
class LibrarySearchHit {
  const LibrarySearchHit({required this.item, this.libraryIds = const []});

  final LibraryItemView item;
  final List<int> libraryIds;

  factory LibrarySearchHit.fromJson(Map<String, dynamic> j) => LibrarySearchHit(
        item: LibraryItemView.fromJson(j['item'] as Map<String, dynamic>),
        libraryIds: _intList(j['library_ids']),
      );
}

/// `GET /search/library` 的结果（LibrarySearchView）。
class LibrarySearchView {
  const LibrarySearchView({
    this.items = const [],
    this.nextCursor,
    this.indexPending = false,
  });

  final List<LibrarySearchHit> items;
  final String? nextCursor;
  final bool indexPending;

  factory LibrarySearchView.fromJson(Map<String, dynamic> j) => LibrarySearchView(
        items: _list(j['items'], LibrarySearchHit.fromJson),
        nextCursor: j['next_cursor']?.toString(),
        indexPending: _asBool(j['index_pending']),
      );
}

