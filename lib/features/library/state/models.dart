// 媒体库域的数据模型（逐字段对齐 upstream iOS `Models.swift` & 服务端 schemas）。
// 手写 fromJson：字段缺失退回默认值，宽松兼容新旧服务端。

int _asInt(dynamic v, [int fallback = 0]) => v is int
    ? v
    : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? fallback);

double _asDouble(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;

bool _asBool(dynamic v, [bool fallback = false]) =>
    v is bool ? v : (v?.toString() == 'true' ? true : fallback);

String _asStr(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) from) =>
    (v as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((m) => from(Map<String, dynamic>.from(m)))
        .toList();

List<int> _intList(dynamic v) =>
    (v as List<dynamic>? ?? []).map((e) => _asInt(e)).toList();

List<String> _strList(dynamic v) =>
    (v as List<dynamic>? ?? []).map((e) => e.toString()).toList();

List<Map<String, dynamic>> _mapList(dynamic v) =>
    (v as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

/// 库存统计（LibraryStats）。
class LibraryStats {
  const LibraryStats({
    this.itemCount = 0,
    this.fileCount = 0,
    this.totalSizeBytes = 0,
    this.unidentifiedCount = 0,
    this.missingCount = 0,
    this.ignoredCount = 0,
    this.reviewCount = 0,
  });

  final int itemCount;
  final int fileCount;
  final int totalSizeBytes;
  final int unidentifiedCount;
  final int missingCount;
  final int ignoredCount;
  final int reviewCount;

  factory LibraryStats.fromJson(Map<String, dynamic> j) => LibraryStats(
        itemCount: _asInt(j['item_count']),
        fileCount: _asInt(j['file_count']),
        totalSizeBytes: _asInt(j['total_size_bytes']),
        unidentifiedCount: _asInt(j['unidentified_count']),
        missingCount: _asInt(j['missing_count']),
        ignoredCount: _asInt(j['ignored_count']),
        reviewCount: _asInt(j['review_count']),
      );

  Map<String, dynamic> toJson() => {
        'item_count': itemCount,
        'file_count': fileCount,
        'total_size_bytes': totalSizeBytes,
        'unidentified_count': unidentifiedCount,
        'missing_count': missingCount,
        'ignored_count': ignoredCount,
        'review_count': reviewCount,
      };
}

/// 库能力开关（LibraryCapabilitiesView）。
class LibraryCapabilitiesView {
  const LibraryCapabilitiesView({
    this.scraped = false,
    this.episodic = false,
    this.naming = false,
    this.subscribable = false,
    this.writeNfo = false,
    this.defaultAspect = 0.6667,
    this.jellyfinCollection = '',
    this.playable = true,
  });

  final bool scraped;
  final bool episodic;
  final bool naming;
  final bool subscribable;
  final bool writeNfo;
  final double defaultAspect;
  final String jellyfinCollection;
  final bool playable;

  factory LibraryCapabilitiesView.fromJson(Map<String, dynamic> j) =>
      LibraryCapabilitiesView(
        scraped: _asBool(j['scraped']),
        episodic: _asBool(j['episodic']),
        naming: _asBool(j['naming']),
        subscribable: _asBool(j['subscribable']),
        writeNfo: _asBool(j['write_nfo']),
        defaultAspect: _asDouble(j['default_aspect'], 0.6667),
        jellyfinCollection: _asStr(j['jellyfin_collection']),
        playable: j['playable'] == null ? true : _asBool(j['playable']),
      );

  Map<String, dynamic> toJson() => {
        'scraped': scraped,
        'episodic': episodic,
        'naming': naming,
        'subscribable': subscribable,
        'write_nfo': writeNfo,
        'default_aspect': defaultAspect,
        'jellyfin_collection': jellyfinCollection,
        'playable': playable,
      };
}

/// 扫描 / 整理的实时进度（ScanProgressView）。
class ScanProgress {
  const ScanProgress({this.phase, this.processed = 0, this.total = 0});

  final String? phase;
  final int processed;
  final int total;

  static ScanProgress? maybe(dynamic v) => v is Map
      ? ScanProgress(
          phase: v['phase']?.toString(),
          processed: _asInt(v['processed']),
          total: _asInt(v['total']),
        )
      : null;
}

/// 最近一次扫描结论（LastScanView）。
class LastScanView {
  const LastScanView({
    this.finishedAt = '',
    this.scanned = 0,
    this.identified = 0,
    this.unidentified = 0,
    this.markedMissing = 0,
    this.clearedMissing = 0,
    this.deferred = 0,
    this.retried = 0,
    this.cancelled = false,
    this.errors = const [],
  });

  final String finishedAt;
  final int scanned;
  final int identified;
  final int unidentified;
  final int markedMissing;
  final int clearedMissing;
  final int deferred;
  final int retried;
  final bool cancelled;
  final List<String> errors;

  static LastScanView? maybe(dynamic v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    return LastScanView(
      finishedAt: _asStr(j['finished_at']),
      scanned: _asInt(j['scanned']),
      identified: _asInt(j['identified']),
      unidentified: _asInt(j['unidentified']),
      markedMissing: _asInt(j['marked_missing']),
      clearedMissing: _asInt(j['cleared_missing']),
      deferred: _asInt(j['deferred']),
      retried: _asInt(j['retried']),
      cancelled: _asBool(j['cancelled']),
      errors: _strList(j['errors']),
    );
  }
}

/// 最近一次文件整理结论（LastOrganizeView）。
class LastOrganizeView {
  const LastOrganizeView({
    this.finishedAt = '',
    this.renamed = 0,
    this.sidecarsRenamed = 0,
    this.entryAssetsMoved = 0,
    this.alreadyOk = 0,
    this.skipped = 0,
    this.removedDirs = 0,
    this.errors = const [],
  });

  final String finishedAt;
  final int renamed;
  final int sidecarsRenamed;
  final int entryAssetsMoved;
  final int alreadyOk;
  final int skipped;
  final int removedDirs;
  final List<String> errors;

  static LastOrganizeView? maybe(dynamic v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    return LastOrganizeView(
      finishedAt: _asStr(j['finished_at']),
      renamed: _asInt(j['renamed']),
      sidecarsRenamed: _asInt(j['sidecars_renamed']),
      entryAssetsMoved: _asInt(j['entry_assets_moved']),
      alreadyOk: _asInt(j['already_ok']),
      skipped: _asInt(j['skipped']),
      removedDirs: _asInt(j['removed_dirs']),
      errors: _strList(j['errors']),
    );
  }
}

/// 元数据刷新正在处理的单条作品（RefreshActiveView）。
class RefreshActiveItem {
  const RefreshActiveItem({
    this.mediaItemId = 0,
    this.title = '',
    this.phase = '',
  });

  final int mediaItemId;
  final String title;
  final String phase;

  factory RefreshActiveItem.fromJson(Map<String, dynamic> j) =>
      RefreshActiveItem(
        mediaItemId: _asInt(j['media_item_id']),
        title: _asStr(j['title']),
        phase: _asStr(j['phase']),
      );
}

/// 整库元数据刷新状态（MetadataRefreshView）。
class MetadataRefresh {
  const MetadataRefresh({
    this.refreshing = false,
    this.processed = 0,
    this.total = 0,
    this.failed = 0,
    this.stopping = false,
    this.active = const [],
    this.activeLine,
  });

  final bool refreshing;
  final int processed;
  final int total;
  final int failed;
  final bool stopping;
  final List<RefreshActiveItem> active;
  final String? activeLine;

  static MetadataRefresh? maybe(dynamic v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    final items = _list(j['active'], RefreshActiveItem.fromJson);
    return MetadataRefresh(
      refreshing: _asBool(j['refreshing']),
      processed: _asInt(j['processed']),
      total: _asInt(j['total']),
      failed: _asInt(j['failed']),
      stopping: _asBool(j['stopping']),
      active: items,
      activeLine: items.isEmpty
          ? null
          : '${items.first.title} · ${items.first.phase}',
    );
  }
}

/// 章节生成后台作业状态（ChapterJobView）。
class ChapterJobView {
  const ChapterJobView({
    this.jobId = '',
    this.status = '',
    this.processed = 0,
    this.total = 0,
    this.failed = 0,
    this.percent,
    this.stopping = false,
  });

  final String jobId;
  final String status;
  final int processed;
  final int total;
  final int failed;
  final double? percent;
  final bool stopping;

  static ChapterJobView? maybe(dynamic v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    return ChapterJobView(
      jobId: _asStr(j['job_id']),
      status: _asStr(j['status']),
      processed: _asInt(j['processed']),
      total: _asInt(j['total']),
      failed: _asInt(j['failed']),
      percent: j['percent'] == null ? null : _asDouble(j['percent']),
      stopping: _asBool(j['stopping']),
    );
  }
}

/// 一个媒体库（LibraryView）。
class LibraryView {
  const LibraryView({
    required this.id,
    this.name = '',
    this.kind = 'movie',
    this.source = 'tmdb',
    this.paths = const [],
    this.primaryRoot,
    this.generateThumbnails = true,
    this.extractChapterImages = false,
    this.detectMediaSegments = true,
    this.excludeFromHome = false,
    this.autoSeriesCollections = true,
    this.accessMode = 'everyone',
    this.adminVisible = true,
    this.memberIds = const [],
    this.viewerAccess = true,
    this.isDefault = false,
    this.matchRules = const [],
    this.autoClearMissing = false,
    this.realtimeWatch = true,
    this.keepLocal,
    this.networkMount = false,
    this.scanning = false,
    this.organizing = false,
    this.customCover = false,
    this.scrapeOverrides = const {},
    this.scanProgress,
    this.lastScan,
    this.organizeProgress,
    this.lastOrganize,
    this.metadataRefresh,
    this.chapterJob,
    this.lastScanDeferred = 0,
    this.lastScanAt,
    this.missingCount = 0,
    this.unidentifiedCount = 0,
    this.reviewCount = 0,
    this.pendingIngestCount = 0,
    this.activeJobsCount = 0,
    this.stats = const LibraryStats(),
    this.capabilities = const LibraryCapabilitiesView(),
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String kind;
  final String source;
  final List<String> paths;
  final String? primaryRoot;
  final bool generateThumbnails;
  final bool extractChapterImages;
  final bool detectMediaSegments;
  final bool excludeFromHome;
  final bool autoSeriesCollections;
  final String accessMode;
  final bool adminVisible;
  final List<int> memberIds;
  final bool viewerAccess;
  final bool isDefault;
  final List<Map<String, dynamic>> matchRules;
  final bool autoClearMissing;
  final bool realtimeWatch;
  final bool? keepLocal;
  final bool networkMount;
  final bool scanning;
  final bool organizing;
  final bool customCover;
  final Map<String, dynamic> scrapeOverrides;
  final ScanProgress? scanProgress;
  final LastScanView? lastScan;
  final ScanProgress? organizeProgress;
  final LastOrganizeView? lastOrganize;
  final MetadataRefresh? metadataRefresh;
  final ChapterJobView? chapterJob;
  final int lastScanDeferred;
  final String? lastScanAt;
  final int missingCount;
  final int unidentifiedCount;
  final int reviewCount;
  final int pendingIngestCount;
  final int activeJobsCount;
  final LibraryStats stats;
  final LibraryCapabilitiesView capabilities;
  final String? createdAt;
  final String? updatedAt;

  /// 兼容旧名：收藏范围规则。
  List<Map<String, dynamic>> get matchScope => matchRules;

  /// 兼容旧名：可见范围。
  String get accessScope => accessMode;

  /// 库状态指纹（首页据此判断是否需要重拉各行条目）。
  String get fingerprint => [
        id,
        name,
        kind,
        excludeFromHome,
        viewerAccess,
        isDefault,
        scanning,
        organizing,
        customCover,
        scanProgress?.processed,
        organizeProgress?.processed,
        metadataRefresh?.refreshing,
        metadataRefresh?.processed,
        lastScanDeferred,
        stats.itemCount,
        stats.fileCount,
        stats.totalSizeBytes,
      ].join('|');

  factory LibraryView.fromJson(Map<String, dynamic> j) {
    final lastScanObj = LastScanView.maybe(j['last_scan']);
    final statsObj = j['stats'] is Map
        ? LibraryStats.fromJson(Map<String, dynamic>.from(j['stats'] as Map))
        : const LibraryStats();
    final rawPaths = [
      for (final p in (j['root_paths'] as List<dynamic>? ??
          j['paths'] as List<dynamic>? ??
          const []))
        if (p is Map) _asStr(p['path']) else _asStr(p),
    ].where((s) => s.isNotEmpty).toList();
    final rawAccessScope = j['access_scope'];
    String accessMode = j['access_mode']?.toString() ?? 'everyone';
    bool adminVisible =
        j['admin_visible'] == null ? true : _asBool(j['admin_visible']);
    List<int> memberIds = _intList(j['member_ids']);
    if (rawAccessScope is Map) {
      final sm = Map<String, dynamic>.from(rawAccessScope);
      if (sm['mode'] != null) accessMode = sm['mode'].toString();
      if (sm['admin_visible'] != null) {
        adminVisible = _asBool(sm['admin_visible']);
      }
      if (sm['member_ids'] is List) memberIds = _intList(sm['member_ids']);
    }
    final matchRules = _mapList(j['match_rules'] ?? j['match_scope']);
    final deferred = lastScanObj?.deferred ??
        _asInt(j['pending_ingest_count']);
    return LibraryView(
      id: _asInt(j['id']),
      name: _asStr(j['name']),
      kind: j['kind']?.toString() ?? 'movie',
      source: j['source']?.toString() ?? 'tmdb',
      paths: rawPaths,
      primaryRoot: j['primary_root']?.toString() ??
          (rawPaths.isNotEmpty ? rawPaths.first : null),
      generateThumbnails: j['generate_thumbnails'] == null
          ? true
          : _asBool(j['generate_thumbnails']),
      extractChapterImages: _asBool(j['extract_chapter_images']),
      detectMediaSegments: j['detect_media_segments'] == null
          ? true
          : _asBool(j['detect_media_segments']),
      excludeFromHome: _asBool(j['exclude_from_home']),
      autoSeriesCollections: j['auto_series_collections'] == null
          ? true
          : _asBool(j['auto_series_collections']),
      accessMode: accessMode,
      adminVisible: adminVisible,
      memberIds: memberIds,
      viewerAccess:
          j['viewer_access'] == null ? true : _asBool(j['viewer_access']),
      isDefault: _asBool(j['is_default']),
      matchRules: matchRules,
      autoClearMissing: _asBool(j['auto_clear_missing']),
      realtimeWatch:
          j['realtime_watch'] == null ? true : _asBool(j['realtime_watch']),
      keepLocal: j['keep_local'] == null ? null : _asBool(j['keep_local']),
      networkMount: _asBool(j['network_mount']),
      scanning: _asBool(j['scanning']),
      organizing: _asBool(j['organizing']),
      customCover: _asBool(j['custom_cover']),
      scrapeOverrides: _asMap(j['scrape_overrides']),
      scanProgress: ScanProgress.maybe(j['scan_progress']),
      lastScan: lastScanObj,
      organizeProgress: ScanProgress.maybe(j['organize_progress']),
      lastOrganize: LastOrganizeView.maybe(j['last_organize']),
      metadataRefresh: MetadataRefresh.maybe(j['metadata_refresh']),
      chapterJob: ChapterJobView.maybe(j['chapter_job']),
      lastScanDeferred: deferred,
      lastScanAt: j['last_scan_at']?.toString() ??
          (lastScanObj != null && lastScanObj.finishedAt.isNotEmpty
              ? lastScanObj.finishedAt
              : null),
      missingCount: j['missing_count'] != null
          ? _asInt(j['missing_count'])
          : statsObj.missingCount,
      unidentifiedCount: j['unidentified_count'] != null
          ? _asInt(j['unidentified_count'])
          : statsObj.unidentifiedCount,
      reviewCount: j['review_count'] != null
          ? _asInt(j['review_count'])
          : statsObj.reviewCount,
      pendingIngestCount: j['pending_ingest_count'] != null
          ? _asInt(j['pending_ingest_count'])
          : deferred,
      activeJobsCount: _asInt(j['active_jobs_count']),
      stats: statsObj,
      capabilities: j['capabilities'] is Map
          ? LibraryCapabilitiesView.fromJson(
              Map<String, dynamic>.from(j['capabilities'] as Map),
            )
          : const LibraryCapabilitiesView(),
      createdAt: j['created_at']?.toString(),
      updatedAt: j['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'source': source,
        'paths': paths,
        'root_paths': paths,
        'generate_thumbnails': generateThumbnails,
        'extract_chapter_images': extractChapterImages,
        'detect_media_segments': detectMediaSegments,
        'exclude_from_home': excludeFromHome,
        'auto_series_collections': autoSeriesCollections,
        'access_mode': accessMode,
        'admin_visible': adminVisible,
        'member_ids': memberIds,
        'viewer_access': viewerAccess,
        'is_default': isDefault,
        'match_rules': matchRules,
        'auto_clear_missing': autoClearMissing,
        'realtime_watch': realtimeWatch,
        'network_mount': networkMount,
        'custom_cover': customCover,
        'scrape_overrides': scrapeOverrides,
        if (lastScanAt != null) 'last_scan_at': lastScanAt,
        'missing_count': missingCount,
        'unidentified_count': unidentifiedCount,
        'review_count': reviewCount,
        'pending_ingest_count': pendingIngestCount,
        'active_jobs_count': activeJobsCount,
        'stats': stats.toJson(),
        'capabilities': capabilities.toJson(),
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

  static LibraryRecentAddition? maybe(dynamic v) => v is Map
      ? LibraryRecentAddition(
          seasonCount: _asInt(v['season_count']),
          episodeCount: _asInt(v['episode_count']),
          seasonNumber: v['season_number'] == null
              ? null
              : _asInt(v['season_number']),
          firstEpisodeNumber: v['first_episode_number'] == null
              ? null
              : _asInt(v['first_episode_number']),
          lastEpisodeNumber: v['last_episode_number'] == null
              ? null
              : _asInt(v['last_episode_number']),
          completeSeason: _asBool(v['complete_season']),
        )
      : null;
}

/// 剧集库存概况（LibraryInventorySummaryView）。
class LibraryInventorySummaryView {
  const LibraryInventorySummaryView({
    this.seasonCount = 0,
    this.episodeCount = 0,
    this.seasonNumber,
    this.totalEpisodeCount,
    this.allSeasonsOwned = false,
    this.allEpisodesOwned = false,
  });

  final int seasonCount;
  final int episodeCount;
  final int? seasonNumber;
  final int? totalEpisodeCount;
  final bool allSeasonsOwned;
  final bool allEpisodesOwned;

  static LibraryInventorySummaryView? maybe(dynamic v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    return LibraryInventorySummaryView(
      seasonCount: _asInt(j['season_count']),
      episodeCount: _asInt(j['episode_count']),
      seasonNumber:
          j['season_number'] == null ? null : _asInt(j['season_number']),
      totalEpisodeCount: j['total_episode_count'] == null
          ? null
          : _asInt(j['total_episode_count']),
      allSeasonsOwned: _asBool(j['all_seasons_owned']),
      allEpisodesOwned: _asBool(j['all_episodes_owned']),
    );
  }

  Map<String, dynamic> toJson() => {
        'season_count': seasonCount,
        'episode_count': episodeCount,
        if (seasonNumber != null) 'season_number': seasonNumber,
        if (totalEpisodeCount != null) 'total_episode_count': totalEpisodeCount,
        'all_seasons_owned': allSeasonsOwned,
        'all_episodes_owned': allEpisodesOwned,
      };
}

/// 海报墙 / 横滚行通用的一条作品（LibraryItemView）。
class LibraryItemView {
  const LibraryItemView({
    required this.mediaItemId,
    this.kind = 'movie',
    this.libraryId,
    this.source = 'tmdb',
    this.tmdbId,
    this.title = '',
    this.year,
    this.posterUrl,
    this.backdropUrl,
    this.primaryAspect = 0.6667,
    this.releaseDate,
    this.rating,
    this.posterBlur,
    this.primaryFileId,
    this.fileCount = 0,
    this.totalSizeBytes = 0,
    this.seasons = const [],
    this.episodeCount = 0,
    this.resolutions = const [],
    this.missingCount = 0,
    this.airStatus,
    this.missingEpisodeCount = 0,
    this.isFavorite = false,
    this.addedAt,
    this.recentAddition,
    this.inventorySummary,
    this.probePendingCount = 0,
    this.hasAtmos,
    this.hasChineseSubtitle,
    this.hdr,
    this.favoriteSeasonNumber,
    this.favoriteEpisodeNumber,
  });

  final int mediaItemId;
  final String kind;
  final int? libraryId;
  final String source;
  final int? tmdbId;
  final String title;
  final int? year;
  final String? posterUrl;
  final String? backdropUrl;
  final double primaryAspect;
  final String? releaseDate;
  final double? rating;
  final String? posterBlur;
  final int? primaryFileId;
  final int fileCount;
  final int totalSizeBytes;
  final List<int> seasons;
  final int episodeCount;
  final List<String> resolutions;
  final int missingCount;
  final String? airStatus;
  final int missingEpisodeCount;
  final bool isFavorite;
  final String? addedAt;
  final LibraryRecentAddition? recentAddition;
  final LibraryInventorySummaryView? inventorySummary;
  final int probePendingCount;
  final bool? hasAtmos;
  final bool? hasChineseSubtitle;
  final String? hdr;
  final int? favoriteSeasonNumber;
  final int? favoriteEpisodeNumber;

  bool get isDead => fileCount > 0 && missingCount >= fileCount;

  String get kindLabel => switch (kind) {
        'movie' => '电影',
        'tv' => '剧集',
        'episode' => '单集',
        'video' => '其他视频',
        'photo' => '照片',
        _ => kind,
      };

  LibraryItemView copyWith({
    bool? isFavorite,
    int? missingCount,
  }) =>
      LibraryItemView(
        mediaItemId: mediaItemId,
        kind: kind,
        libraryId: libraryId,
        source: source,
        tmdbId: tmdbId,
        title: title,
        year: year,
        posterUrl: posterUrl,
        backdropUrl: backdropUrl,
        primaryAspect: primaryAspect,
        releaseDate: releaseDate,
        rating: rating,
        posterBlur: posterBlur,
        primaryFileId: primaryFileId,
        fileCount: fileCount,
        totalSizeBytes: totalSizeBytes,
        seasons: seasons,
        episodeCount: episodeCount,
        resolutions: resolutions,
        missingCount: missingCount ?? this.missingCount,
        airStatus: airStatus,
        missingEpisodeCount: missingEpisodeCount,
        isFavorite: isFavorite ?? this.isFavorite,
        addedAt: addedAt,
        recentAddition: recentAddition,
        inventorySummary: inventorySummary,
        probePendingCount: probePendingCount,
        hasAtmos: hasAtmos,
        hasChineseSubtitle: hasChineseSubtitle,
        hdr: hdr,
        favoriteSeasonNumber: favoriteSeasonNumber,
        favoriteEpisodeNumber: favoriteEpisodeNumber,
      );

  factory LibraryItemView.fromJson(Map<String, dynamic> j) => LibraryItemView(
        mediaItemId: _asInt(j['media_item_id']),
        kind: j['kind']?.toString() ?? 'movie',
        libraryId: j['library_id'] == null ? null : _asInt(j['library_id']),
        source: j['source']?.toString() ?? 'tmdb',
        tmdbId: j['tmdb_id'] == null ? null : _asInt(j['tmdb_id']),
        title: _asStr(j['title']),
        year: j['year'] == null ? null : _asInt(j['year']),
        posterUrl: j['poster_url']?.toString(),
        backdropUrl: j['backdrop_url']?.toString(),
        primaryAspect: _asDouble(j['primary_aspect'], 0.6667),
        releaseDate: j['release_date']?.toString(),
        rating: j['rating'] == null ? null : _asDouble(j['rating']),
        posterBlur: j['poster_blur']?.toString(),
        primaryFileId:
            j['primary_file_id'] == null ? null : _asInt(j['primary_file_id']),
        fileCount: _asInt(j['file_count']),
        totalSizeBytes: _asInt(j['total_size_bytes']),
        seasons: _intList(j['seasons']),
        episodeCount: _asInt(j['episode_count']),
        resolutions: _strList(j['resolutions']),
        missingCount: _asInt(j['missing_count']),
        airStatus: j['air_status']?.toString(),
        missingEpisodeCount: _asInt(j['missing_episode_count']),
        isFavorite: _asBool(j['is_favorite']),
        addedAt: j['added_at']?.toString(),
        recentAddition: LibraryRecentAddition.maybe(j['recent_addition']),
        inventorySummary:
            LibraryInventorySummaryView.maybe(j['inventory_summary']),
        probePendingCount: _asInt(j['probe_pending_count']),
        hasAtmos:
            j['has_atmos'] == null ? null : _asBool(j['has_atmos']),
        hasChineseSubtitle: j['has_chinese_subtitle'] == null
            ? null
            : _asBool(j['has_chinese_subtitle']),
        hdr: j['hdr'] is bool
            ? (j['hdr'] == true ? 'HDR' : null)
            : j['hdr']?.toString(),
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
        'source': source,
        if (tmdbId != null) 'tmdb_id': tmdbId,
        'title': title,
        if (year != null) 'year': year,
        if (posterUrl != null) 'poster_url': posterUrl,
        if (backdropUrl != null) 'backdrop_url': backdropUrl,
        'primary_aspect': primaryAspect,
        if (releaseDate != null) 'release_date': releaseDate,
        if (rating != null) 'rating': rating,
        if (posterBlur != null) 'poster_blur': posterBlur,
        if (primaryFileId != null) 'primary_file_id': primaryFileId,
        'file_count': fileCount,
        'total_size_bytes': totalSizeBytes,
        'seasons': seasons,
        'episode_count': episodeCount,
        'resolutions': resolutions,
        'missing_count': missingCount,
        if (airStatus != null) 'air_status': airStatus,
        'missing_episode_count': missingEpisodeCount,
        'is_favorite': isFavorite,
        if (addedAt != null) 'added_at': addedAt,
        if (inventorySummary != null)
          'inventory_summary': inventorySummary!.toJson(),
        'probe_pending_count': probePendingCount,
        if (hasAtmos != null) 'has_atmos': hasAtmos,
        if (hasChineseSubtitle != null)
          'has_chinese_subtitle': hasChineseSubtitle,
        if (hdr != null) 'hdr': hdr,
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
        genres: _strList(j['genres']),
        seasonNumber: _asInt(j['season_number']),
        episodeNumber: _asInt(j['episode_number']),
        episodeTitle: j['episode_title']?.toString(),
        unwatchedAheadCount: _asInt(j['unwatched_ahead_count']),
        positionMs: _asInt(j['position_ms']),
        durationMs:
            j['duration_ms'] == null ? null : _asInt(j['duration_ms']),
        progressPercent: j['progress_percent'] == null
            ? null
            : _asDouble(j['progress_percent']),
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

/// 一个合集（CollectionView）。
class CollectionView {
  const CollectionView({
    required this.id,
    this.name = '',
    this.libraryId,
    this.rules = const [],
    this.sort = 'added_at',
    this.visibility = 'household',
    this.builtin,
    this.kind = 'user',
    this.editable = true,
    this.manageable = true,
    this.ruleDriven = false,
    this.itemCount = 0,
    this.coverItemId,
    this.covers = const [],
    this.hidden = false,
    this.showOnHome = false,
    this.customCover = false,
    this.position = 0,
  });

  final int id;
  final String name;
  final int? libraryId;
  final List<Map<String, dynamic>> rules;
  final String sort;
  final String visibility;
  final String? builtin;
  final String kind;
  final bool editable;
  final bool manageable;
  final bool ruleDriven;
  final int itemCount;
  final int? coverItemId;
  final List<CollectionCover> covers;
  final bool hidden;
  final bool showOnHome;
  final bool customCover;
  final int position;

  factory CollectionView.fromJson(Map<String, dynamic> j) => CollectionView(
        id: _asInt(j['id']),
        name: _asStr(j['name']),
        libraryId: j['library_id'] == null ? null : _asInt(j['library_id']),
        rules: _mapList(j['rules']),
        sort: j['sort']?.toString() ?? 'added_at',
        visibility: j['visibility']?.toString() ?? 'household',
        builtin: j['builtin']?.toString(),
        kind: j['kind']?.toString() ?? 'user',
        editable: j['editable'] == null ? true : _asBool(j['editable']),
        manageable: j['manageable'] == null
            ? (j['editable'] == null ? true : _asBool(j['editable']))
            : _asBool(j['manageable']),
        ruleDriven: _asBool(j['rule_driven']),
        itemCount: _asInt(j['item_count']),
        coverItemId:
            j['cover_item_id'] == null ? null : _asInt(j['cover_item_id']),
        covers: _list(j['covers'], CollectionCover.fromJson),
        hidden: _asBool(j['hidden']),
        showOnHome: _asBool(j['show_on_home']),
        customCover: _asBool(j['custom_cover']),
        position: _asInt(j['position']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (libraryId != null) 'library_id': libraryId,
        'rules': rules,
        'sort': sort,
        'visibility': visibility,
        if (builtin != null) 'builtin': builtin,
        'kind': kind,
        'editable': editable,
        'manageable': manageable,
        'rule_driven': ruleDriven,
        'item_count': itemCount,
        'covers': [
          for (final c in covers)
            {'url': c.url, if (c.blur != null) 'blur': c.blur},
        ],
        'hidden': hidden,
        'show_on_home': showOnHome,
        'custom_cover': customCover,
        'position': position,
      };
}

/// 系列合集的「已有 N / 共 M」与缺片名单（CollectionSeriesView）。
class CollectionSeriesView {
  const CollectionSeriesView({
    this.seriesName,
    this.ownedCount = 0,
    this.total = 0,
    this.imageUrl,
    this.parts = const [],
    this.available = false,
  });

  final String? seriesName;
  final int ownedCount;
  final int total;
  final String? imageUrl;
  final List<SeriesPartView> parts;
  final bool available;

  factory CollectionSeriesView.fromJson(Map<String, dynamic> j) =>
      CollectionSeriesView(
        seriesName: j['series_name']?.toString(),
        ownedCount: _asInt(j['owned_count']),
        total: _asInt(j['total']),
        imageUrl: j['image_url']?.toString(),
        parts: _list(j['parts'], SeriesPartView.fromJson),
        available: _asBool(j['available']),
      );
}

class SeriesPartView {
  const SeriesPartView({
    required this.tmdbId,
    this.title = '',
    this.releaseDate,
    this.posterUrl,
    this.mediaItemId,
    this.subscribed = false,
  });

  final int tmdbId;
  final String title;
  final String? releaseDate;
  final String? posterUrl;
  final int? mediaItemId;
  final bool subscribed;

  int? get year => releaseDate != null && releaseDate!.length >= 4
      ? int.tryParse(releaseDate!.substring(0, 4))
      : null;

  factory SeriesPartView.fromJson(Map<String, dynamic> j) => SeriesPartView(
        tmdbId: _asInt(j['tmdb_id']),
        title: _asStr(j['title']),
        releaseDate: j['release_date']?.toString(),
        posterUrl: j['poster_url']?.toString(),
        mediaItemId:
            j['media_item_id'] == null ? null : _asInt(j['media_item_id']),
        subscribed: _asBool(j['subscribed']),
      );
}

/// 筛选面板里的一个候选值（FacetValue）。
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

/// `GET /libraries/{id}/relax` 的放宽建议。
class RelaxSuggestionView {
  const RelaxSuggestionView({
    this.dim = '',
    this.dimLabel = '',
    this.value = '',
    this.label = '',
    this.count = 0,
  });

  final String dim;
  final String dimLabel;
  final String value;
  final String label;
  final int count;

  factory RelaxSuggestionView.fromJson(Map<String, dynamic> j) =>
      RelaxSuggestionView(
        dim: _asStr(j['dim']),
        dimLabel: _asStr(j['dim_label']),
        value: _asStr(j['value']),
        label: _asStr(j['label']),
        count: _asInt(j['count']),
      );
}

class LibraryRelaxView {
  const LibraryRelaxView({this.total = 0, this.suggestions = const []});

  final int total;
  final List<RelaxSuggestionView> suggestions;

  factory LibraryRelaxView.fromJson(Map<String, dynamic> j) => LibraryRelaxView(
        total: _asInt(j['total']),
        suggestions: _list(j['suggestions'], RelaxSuggestionView.fromJson),
      );
}

/// 图廊的一张图（LibraryGalleryImageView）。
class LibraryGalleryImageView {
  const LibraryGalleryImageView({
    this.kind = '',
    this.url = '',
    this.aspect = 1.5,
    this.label = '',
    this.season,
    this.episode,
    this.tSeconds,
  });

  final String kind;
  final String url;
  final double aspect;
  final String label;
  final int? season;
  final int? episode;
  final double? tSeconds;

  factory LibraryGalleryImageView.fromJson(Map<String, dynamic> j) =>
      LibraryGalleryImageView(
        kind: _asStr(j['kind']),
        url: _asStr(j['url']),
        aspect: _asDouble(j['aspect'], 1.5),
        label: _asStr(j['label']),
        season: j['season'] == null ? null : _asInt(j['season']),
        episode: j['episode'] == null ? null : _asInt(j['episode']),
        tSeconds: j['t_seconds'] == null ? null : _asDouble(j['t_seconds']),
      );
}

/// 图廊的一部作品分组（LibraryGalleryGroupView）。
class LibraryGalleryGroupView {
  const LibraryGalleryGroupView({
    required this.mediaItemId,
    required this.libraryId,
    this.kind = 'movie',
    this.title = '',
    this.year,
    this.isFavorite = false,
    this.images = const [],
  });

  final int mediaItemId;
  final int libraryId;
  final String kind;
  final String title;
  final int? year;
  final bool isFavorite;
  final List<LibraryGalleryImageView> images;

  LibraryGalleryGroupView copyWith({bool? isFavorite}) =>
      LibraryGalleryGroupView(
        mediaItemId: mediaItemId,
        libraryId: libraryId,
        kind: kind,
        title: title,
        year: year,
        isFavorite: isFavorite ?? this.isFavorite,
        images: images,
      );

  factory LibraryGalleryGroupView.fromJson(Map<String, dynamic> j) =>
      LibraryGalleryGroupView(
        mediaItemId: _asInt(j['media_item_id']),
        libraryId: _asInt(j['library_id']),
        kind: j['kind']?.toString() ?? 'movie',
        title: _asStr(j['title']),
        year: j['year'] == null ? null : _asInt(j['year']),
        isFavorite: _asBool(j['is_favorite']),
        images: _list(j['images'], LibraryGalleryImageView.fromJson),
      );
}

/// 海报墙跳转索引的一档（LibraryIndexEntry）。
class LibraryIndexEntry {
  const LibraryIndexEntry({this.initial = '', this.count = 0, this.offset = 0});

  final String initial;
  final int count;
  final int offset;

  factory LibraryIndexEntry.fromJson(Map<String, dynamic> j) =>
      LibraryIndexEntry(
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

/// 首页「按类型找电影 / 剧集」的单个类型卡片（LibraryKindGenreView）。
class LibraryKindGenreView {
  const LibraryKindGenreView({
    this.value = '',
    this.label = '',
    this.count = 0,
    this.coverItemId,
    this.coverTitle,
    this.coverUrl,
  });

  final String value;
  final String label;
  final int count;
  final int? coverItemId;
  final String? coverTitle;
  final String? coverUrl;

  factory LibraryKindGenreView.fromJson(Map<String, dynamic> j) =>
      LibraryKindGenreView(
        value: _asStr(j['value'] ?? j['id']),
        label: _asStr(j['label'] ?? j['name']),
        count: _asInt(j['count']),
        coverItemId:
            j['cover_item_id'] == null ? null : _asInt(j['cover_item_id']),
        coverTitle: j['cover_title']?.toString(),
        coverUrl: j['cover_url']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'value': value,
        'label': label,
        'count': count,
        if (coverItemId != null) 'cover_item_id': coverItemId,
        if (coverTitle != null) 'cover_title': coverTitle,
        if (coverUrl != null) 'cover_url': coverUrl,
      };
}

/// 首页一「行」偏好（HomeRowPref）：空即默认。
class HomeRowPref {
  const HomeRowPref({
    required this.id,
    this.sort,
    this.order,
    this.name,
    this.unwatched,
    this.unfinished,
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
  final bool? unfinished;
  final bool? hidden;
  final int? libraryId;
  final int? collectionId;
  final String? mediaKind;

  HomeRowPref copyWith({
    String? id,
    String? sort,
    String? order,
    String? name,
    bool? unwatched,
    bool? unfinished,
    bool? hidden,
    bool clearHidden = false,
    int? libraryId,
    int? collectionId,
    String? mediaKind,
  }) =>
      HomeRowPref(
        id: id ?? this.id,
        sort: sort ?? this.sort,
        order: order ?? this.order,
        name: name ?? this.name,
        unwatched: unwatched ?? this.unwatched,
        unfinished: unfinished ?? this.unfinished,
        hidden: clearHidden ? null : (hidden ?? this.hidden),
        libraryId: libraryId ?? this.libraryId,
        collectionId: collectionId ?? this.collectionId,
        mediaKind: mediaKind ?? this.mediaKind,
      );

  factory HomeRowPref.fromJson(Map<String, dynamic> j) => HomeRowPref(
        id: _asStr(j['id']),
        sort: j['sort']?.toString(),
        order: j['order']?.toString(),
        name: j['name']?.toString(),
        unwatched: j['unwatched'] == null ? null : _asBool(j['unwatched']),
        unfinished: j['unfinished'] == null ? null : _asBool(j['unfinished']),
        hidden: j['hidden'] == null ? null : _asBool(j['hidden']),
        libraryId: j['library_id'] == null ? null : _asInt(j['library_id']),
        collectionId:
            j['collection_id'] == null ? null : _asInt(j['collection_id']),
        mediaKind: j['media_kind']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (sort != null) 'sort': sort,
        if (order != null) 'order': order,
        if (name != null) 'name': name,
        if (unwatched != null) 'unwatched': unwatched,
        if (unfinished != null) 'unfinished': unfinished,
        if (hidden != null) 'hidden': hidden,
        if (libraryId != null) 'library_id': libraryId,
        if (collectionId != null) 'collection_id': collectionId,
        if (mediaKind != null) 'media_kind': mediaKind,
      };
}

/// 库内影人详情（`GET /people/{tmdbPersonId}`）。
class PersonCreditView {
  const PersonCreditView({
    required this.mediaItemId,
    this.kind = 'movie',
    this.tmdbId = 0,
    this.title = '',
    this.year,
    this.posterUrl,
    this.libraryId,
    this.department = 'cast',
    this.character,
  });

  final int mediaItemId;
  final String kind;
  final int tmdbId;
  final String title;
  final int? year;
  final String? posterUrl;
  final int? libraryId;
  final String department;
  final String? character;

  factory PersonCreditView.fromJson(Map<String, dynamic> j) => PersonCreditView(
        mediaItemId: _asInt(j['media_item_id']),
        kind: j['kind']?.toString() ?? 'movie',
        tmdbId: _asInt(j['tmdb_id']),
        title: _asStr(j['title']),
        year: j['year'] == null ? null : _asInt(j['year']),
        posterUrl: j['poster_url']?.toString(),
        libraryId: j['library_id'] == null ? null : _asInt(j['library_id']),
        department: j['department']?.toString() ?? 'cast',
        character: j['character']?.toString(),
      );
}

class PersonView {
  const PersonView({
    required this.tmdbPersonId,
    this.name = '',
    this.originalName,
    this.avatarUrl,
    this.credits = const [],
  });

  final int tmdbPersonId;
  final String name;
  final String? originalName;
  final String? avatarUrl;
  final List<PersonCreditView> credits;

  String? get profileUrl => avatarUrl;

  List<PersonCreditView> get directed => credits
      .where((c) => c.department == 'directing' || c.department == 'director')
      .toList();

  List<PersonCreditView> get acted => credits
      .where((c) => c.department != 'directing' && c.department != 'director')
      .toList();

  factory PersonView.fromJson(Map<String, dynamic> j) => PersonView(
        tmdbPersonId: _asInt(j['tmdb_person_id']),
        name: _asStr(j['name']),
        originalName: j['original_name']?.toString(),
        avatarUrl: (j['avatar_url'] ?? j['profile_url'])?.toString(),
        credits: _list(j['credits'], PersonCreditView.fromJson),
      );
}

/// 人物搜索结果的一条命中（LibrarySearchHit）。
class LibrarySearchHit {
  const LibrarySearchHit({required this.item, this.libraryIds = const []});

  final LibraryItemView item;
  final List<int> libraryIds;

  factory LibrarySearchHit.fromJson(Map<String, dynamic> j) => LibrarySearchHit(
        item: LibraryItemView.fromJson(
          Map<String, dynamic>.from(j['item'] as Map),
        ),
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

  factory LibrarySearchView.fromJson(Map<String, dynamic> j) =>
      LibrarySearchView(
        items: _list(j['items'], LibrarySearchHit.fromJson),
        nextCursor: j['next_cursor']?.toString(),
        indexPending: _asBool(j['index_pending']),
      );
}

/// 整理文件名预览（OrganizePreviewView）。
class OrganizeSidecarView {
  const OrganizeSidecarView({this.sourceRel = '', this.targetRel = ''});

  final String sourceRel;
  final String targetRel;

  factory OrganizeSidecarView.fromJson(Map<String, dynamic> j) =>
      OrganizeSidecarView(
        sourceRel: _asStr(j['source_rel'] ?? j['source_path']),
        targetRel: _asStr(j['target_rel'] ?? j['target_path']),
      );
}

class OrganizeRenameView {
  const OrganizeRenameView({
    required this.fileId,
    required this.mediaItemId,
    this.title = '',
    this.year,
    this.sourcePath = '',
    this.targetPath = '',
    this.sourceRel = '',
    this.targetRel = '',
    this.sizeBytes = 0,
    this.sidecars = const [],
  });

  final int fileId;
  final int mediaItemId;
  final String title;
  final int? year;
  final String sourcePath;
  final String targetPath;
  final String sourceRel;
  final String targetRel;
  final int sizeBytes;
  final List<OrganizeSidecarView> sidecars;

  factory OrganizeRenameView.fromJson(Map<String, dynamic> j) =>
      OrganizeRenameView(
        fileId: _asInt(j['file_id']),
        mediaItemId: _asInt(j['media_item_id']),
        title: _asStr(j['title']),
        year: j['year'] == null ? null : _asInt(j['year']),
        sourcePath: _asStr(j['source_path']),
        targetPath: _asStr(j['target_path']),
        sourceRel: _asStr(j['source_rel'] ?? j['source_path']),
        targetRel: _asStr(j['target_rel'] ?? j['target_path']),
        sizeBytes: _asInt(j['size_bytes']),
        sidecars: _list(j['sidecars'], OrganizeSidecarView.fromJson),
      );
}

class OrganizeSkipView {
  const OrganizeSkipView({this.filePath = '', this.reason = ''});

  final String filePath;
  final String reason;

  factory OrganizeSkipView.fromJson(Map<String, dynamic> j) => OrganizeSkipView(
        filePath: _asStr(j['file_path']),
        reason: _asStr(j['reason']),
      );
}

class OrganizePreviewView {
  const OrganizePreviewView({
    this.total = 0,
    this.alreadyOk = 0,
    this.renames = const [],
    this.skips = const [],
    this.entryAssets = const [],
  });

  final int total;
  final int alreadyOk;
  final List<OrganizeRenameView> renames;
  final List<OrganizeSkipView> skips;
  final List<OrganizeSidecarView> entryAssets;

  factory OrganizePreviewView.fromJson(Map<String, dynamic> j) =>
      OrganizePreviewView(
        total: _asInt(j['total']),
        alreadyOk: _asInt(j['already_ok']),
        renames: _list(j['renames'], OrganizeRenameView.fromJson),
        skips: _list(j['skips'], OrganizeSkipView.fromJson),
        entryAssets: _list(j['entry_assets'], OrganizeSidecarView.fromJson),
      );
}

/// 重复文件管理模型（DuplicateFilesData）。
class DuplicateScanStateView {
  const DuplicateScanStateView({
    this.status,
    this.jobId,
    this.message,
    this.percent,
    this.scannedAt,
    this.upgradingUnits = 0,
    this.keepOldItems = 0,
  });

  final String? status;
  final String? jobId;
  final String? message;
  final double? percent;
  final String? scannedAt;
  final int upgradingUnits;
  final int keepOldItems;

  bool get isScanning =>
      status == 'queued' || status == 'running' || status == 'pending';

  factory DuplicateScanStateView.fromJson(Map<String, dynamic> j) =>
      DuplicateScanStateView(
        status: j['status']?.toString(),
        jobId: j['job_id']?.toString(),
        message: j['message']?.toString(),
        percent: j['percent'] == null ? null : _asDouble(j['percent']),
        scannedAt: j['scanned_at']?.toString(),
        upgradingUnits: _asInt(j['upgrading_units']),
        keepOldItems: _asInt(j['keep_old_items']),
      );
}

class DuplicateGroupView {
  const DuplicateGroupView({
    this.key = '',
    this.label = '',
    this.hint = '',
    this.units = 0,
    this.files = 0,
    this.bytes = 0,
  });

  final String key;
  final String label;
  final String hint;
  final int units;
  final int files;
  final int bytes;

  factory DuplicateGroupView.fromJson(Map<String, dynamic> j) =>
      DuplicateGroupView(
        key: _asStr(j['key']),
        label: _asStr(j['label']),
        hint: _asStr(j['hint']),
        units: _asInt(j['units']),
        files: _asInt(j['files']),
        bytes: _asInt(j['bytes']),
      );
}

class DuplicateFileView {
  const DuplicateFileView({
    required this.id,
    this.fileName = '',
    this.filePath = '',
    this.qualityKey,
    this.originKey,
    this.qualityLabel = '',
    this.sizeBytes = 0,
    this.bitRate,
    this.resolution,
    this.mediaSource,
    this.hdr,
    this.videoCodec,
    this.audioLabel,
    this.originLabel = '',
    this.versionKey = '',
    this.suggested = false,
    this.suggestReason,
    this.keptAt,
  });

  final int id;
  final String fileName;
  final String filePath;
  final String? qualityKey;
  final String? originKey;
  final String qualityLabel;
  final int sizeBytes;
  final int? bitRate;
  final String? resolution;
  final String? mediaSource;
  final String? hdr;
  final String? videoCodec;
  final String? audioLabel;
  final String originLabel;
  final String versionKey;
  final bool suggested;
  final String? suggestReason;
  final String? keptAt;

  factory DuplicateFileView.fromJson(Map<String, dynamic> j) {
    final origin = _asMap(j['origin']);
    return DuplicateFileView(
      id: _asInt(j['id']),
      fileName: _asStr(j['file_name']),
      filePath: _asStr(j['file_path']),
      qualityKey: j['quality_key']?.toString(),
      originKey: j['origin_key']?.toString(),
      qualityLabel: _asStr(j['quality_label']),
      sizeBytes: _asInt(j['size_bytes']),
      bitRate: j['bit_rate'] == null ? null : _asInt(j['bit_rate']),
      resolution: j['resolution']?.toString(),
      mediaSource: j['media_source']?.toString(),
      hdr: j['hdr']?.toString(),
      videoCodec: j['video_codec']?.toString(),
      audioLabel: j['audio_label']?.toString(),
      originLabel: _asStr(origin['label'] ?? j['origin_label']),
      versionKey: _asStr(j['version_key']),
      suggested: _asBool(j['suggested']),
      suggestReason: j['suggest_reason']?.toString(),
      keptAt: j['kept_at']?.toString(),
    );
  }
}

class DuplicateVersionView {
  const DuplicateVersionView({
    this.key = '',
    this.qualityKey,
    this.originKey,
    this.qualityLabel = '',
    this.originLabel = '',
    this.episodes = const [],
    this.bytes = 0,
    this.suggested = false,
  });

  final String key;
  final String? qualityKey;
  final String? originKey;
  final String qualityLabel;
  final String originLabel;
  final List<int> episodes;
  final int bytes;
  final bool suggested;

  factory DuplicateVersionView.fromJson(Map<String, dynamic> j) =>
      DuplicateVersionView(
        key: _asStr(j['key']),
        qualityKey: j['quality_key']?.toString(),
        originKey: j['origin_key']?.toString(),
        qualityLabel: _asStr(j['quality_label']),
        originLabel: _asStr(j['origin_label']),
        episodes: _intList(j['episodes']),
        bytes: _asInt(j['bytes']),
        suggested: _asBool(j['suggested']),
      );
}

class DuplicateUnitView {
  const DuplicateUnitView({
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.bucket = '',
    this.files = const [],
  });

  final int seasonNumber;
  final int episodeNumber;
  final String bucket;
  final List<DuplicateFileView> files;

  factory DuplicateUnitView.fromJson(Map<String, dynamic> j) =>
      DuplicateUnitView(
        seasonNumber: _asInt(j['season_number']),
        episodeNumber: _asInt(j['episode_number']),
        bucket: _asStr(j['bucket']),
        files: _list(j['files'], DuplicateFileView.fromJson),
      );
}

class DuplicateSeasonView {
  const DuplicateSeasonView({
    this.seasonNumber = 0,
    this.bucket = '',
    this.uniform = false,
    this.versions = const [],
    this.units = const [],
  });

  final int seasonNumber;
  final String bucket;
  final bool uniform;
  final List<DuplicateVersionView> versions;
  final List<DuplicateUnitView> units;

  factory DuplicateSeasonView.fromJson(Map<String, dynamic> j) =>
      DuplicateSeasonView(
        seasonNumber: _asInt(j['season_number']),
        bucket: _asStr(j['bucket']),
        uniform: _asBool(j['uniform']),
        versions: _list(j['versions'], DuplicateVersionView.fromJson),
        units: _list(j['units'], DuplicateUnitView.fromJson),
      );
}

class DuplicateItemView {
  const DuplicateItemView({
    this.libraryId = 0,
    this.libraryName = '',
    this.mediaItemId = 0,
    this.title = '',
    this.kind = 'movie',
    this.year,
    this.posterUrl,
    this.seasons = const [],
  });

  final int libraryId;
  final String libraryName;
  final int mediaItemId;
  final String title;
  final String kind;
  final int? year;
  final String? posterUrl;
  final List<DuplicateSeasonView> seasons;

  factory DuplicateItemView.fromJson(Map<String, dynamic> j) {
    final lib = _asMap(j['library']);
    final item = _asMap(j['media_item']);
    return DuplicateItemView(
      libraryId: _asInt(lib['id'] ?? lib['library_id']),
      libraryName: _asStr(lib['name']),
      mediaItemId: _asInt(item['id'] ?? item['media_item_id']),
      title: _asStr(item['title']),
      kind: item['kind']?.toString() ?? 'movie',
      year: item['year'] == null ? null : _asInt(item['year']),
      posterUrl: item['poster_url']?.toString(),
      seasons: _list(j['seasons'], DuplicateSeasonView.fromJson),
    );
  }
}

class DuplicateFilesData {
  const DuplicateFilesData({
    this.scan = const DuplicateScanStateView(),
    this.tiers = const [],
    this.reviewGroups = const [],
    this.totalUnits = 0,
    this.totalFiles = 0,
    this.totalBytes = 0,
    this.totalItems = 0,
    this.items = const [],
  });

  final DuplicateScanStateView scan;
  final List<DuplicateGroupView> tiers;
  final List<DuplicateGroupView> reviewGroups;
  final int totalUnits;
  final int totalFiles;
  final int totalBytes;
  final int totalItems;
  final List<DuplicateItemView> items;

  factory DuplicateFilesData.fromJson(Map<String, dynamic> j) =>
      DuplicateFilesData(
        scan: DuplicateScanStateView.fromJson(_asMap(j['scan'])),
        tiers: _list(j['tiers'], DuplicateGroupView.fromJson),
        reviewGroups: _list(j['review_groups'], DuplicateGroupView.fromJson),
        totalUnits: _asInt(j['total_units']),
        totalFiles: _asInt(j['total_files']),
        totalBytes: _asInt(j['total_bytes']),
        totalItems: _asInt(j['total_items']),
        items: _list(j['items'], DuplicateItemView.fromJson),
      );
}

/// 待处理抽屉模型（缺失 / 待识别 / 身份复核 / 已忽略）。
class MissingFileView {
  const MissingFileView({
    this.id = 0,
    this.filePath = '',
    this.seasonNumber = 0,
    this.episodeNumber = 0,
  });

  final int id;
  final String filePath;
  final int seasonNumber;
  final int episodeNumber;

  factory MissingFileView.fromJson(Map<String, dynamic> j) => MissingFileView(
        id: _asInt(j['id'] ?? j['file_id']),
        filePath: _asStr(j['file_path'] ?? j['path']),
        seasonNumber: _asInt(j['season_number']),
        episodeNumber: _asInt(j['episode_number']),
      );
}

class MissingItemView {
  const MissingItemView({
    required this.mediaItemId,
    this.kind = 'movie',
    this.tmdbId,
    this.title = '',
    this.year,
    this.posterUrl,
    this.subscriptionId,
    this.files = const [],
  });

  final int mediaItemId;
  final String kind;
  final int? tmdbId;
  final String title;
  final int? year;
  final String? posterUrl;
  final int? subscriptionId;
  final List<MissingFileView> files;

  factory MissingItemView.fromJson(Map<String, dynamic> j) => MissingItemView(
        mediaItemId: _asInt(j['media_item_id']),
        kind: j['kind']?.toString() ?? 'movie',
        tmdbId: j['tmdb_id'] == null ? null : _asInt(j['tmdb_id']),
        title: _asStr(j['title']),
        year: j['year'] == null ? null : _asInt(j['year']),
        posterUrl: j['poster_url']?.toString(),
        subscriptionId: j['subscription_id'] == null
            ? null
            : _asInt(j['subscription_id']),
        files: _list(j['files'], MissingFileView.fromJson),
      );
}

class UnidentifiedCandidateView {
  const UnidentifiedCandidateView({
    this.tmdbId = 0,
    this.title = '',
    this.year,
    this.posterUrl,
    this.score,
    this.episodeCount,
  });

  final int tmdbId;
  final String title;
  final int? year;
  final String? posterUrl;
  final double? score;
  final int? episodeCount;

  factory UnidentifiedCandidateView.fromJson(Map<String, dynamic> j) =>
      UnidentifiedCandidateView(
        tmdbId: _asInt(j['tmdb_id']),
        title: _asStr(j['title']),
        year: j['year'] == null ? null : _asInt(j['year']),
        posterUrl: j['poster_url']?.toString(),
        score: j['score'] == null ? null : _asDouble(j['score']),
        episodeCount:
            j['episode_count'] == null ? null : _asInt(j['episode_count']),
      );
}

class UnidentifiedFileView {
  const UnidentifiedFileView({
    required this.id,
    this.filePath = '',
    this.sizeBytes = 0,
  });

  final int id;
  final String filePath;
  final int sizeBytes;

  factory UnidentifiedFileView.fromJson(Map<String, dynamic> j) =>
      UnidentifiedFileView(
        id: _asInt(j['id'] ?? j['file_id']),
        filePath: _asStr(j['file_path'] ?? j['path']),
        sizeBytes: _asInt(j['size_bytes']),
      );
}

class UnidentifiedGroupView {
  const UnidentifiedGroupView({
    this.key = '',
    this.label = '',
    this.libraryId = 0,
    this.libraryName = '',
    this.fileCount = 0,
    this.totalSizeBytes = 0,
    this.reason,
    this.code,
    this.candidates = const [],
    this.files = const [],
  });

  final String key;
  final String label;
  final int libraryId;
  final String libraryName;
  final int fileCount;
  final int totalSizeBytes;
  final String? reason;
  final String? code;
  final List<UnidentifiedCandidateView> candidates;
  final List<UnidentifiedFileView> files;

  factory UnidentifiedGroupView.fromJson(Map<String, dynamic> j) {
    final files = _list(j['files'], UnidentifiedFileView.fromJson);
    final singleId = _asInt(j['id'] ?? j['file_id']);
    final resolvedFiles = files.isNotEmpty
        ? files
        : (singleId > 0
            ? [
                UnidentifiedFileView(
                  id: singleId,
                  filePath: _asStr(j['file_path'] ?? j['path'] ?? j['label']),
                  sizeBytes: _asInt(j['size_bytes'] ?? j['total_size_bytes']),
                ),
              ]
            : const <UnidentifiedFileView>[]);
    return UnidentifiedGroupView(
      key: _asStr(j['key'] ?? j['label'] ?? singleId),
      label: _asStr(j['label'] ?? j['file_path'] ?? j['filename']),
      libraryId: _asInt(j['library_id']),
      libraryName: _asStr(j['library_name']),
      fileCount: _asInt(j['file_count'], resolvedFiles.length),
      totalSizeBytes: _asInt(j['total_size_bytes'] ?? j['size_bytes']),
      reason: j['reason']?.toString(),
      code: j['code']?.toString(),
      candidates: _list(j['candidates'], UnidentifiedCandidateView.fromJson),
      files: resolvedFiles,
    );
  }
}

class ReviewItemView {
  const ReviewItemView({
    this.mediaItemId = 0,
    this.tmdbId,
    this.title = '',
    this.year,
    this.posterUrl,
  });

  final int mediaItemId;
  final int? tmdbId;
  final String title;
  final int? year;
  final String? posterUrl;

  factory ReviewItemView.fromJson(Map<String, dynamic> j) => ReviewItemView(
        mediaItemId: _asInt(j['media_item_id']),
        tmdbId: j['tmdb_id'] == null ? null : _asInt(j['tmdb_id']),
        title: _asStr(j['title']),
        year: j['year'] == null ? null : _asInt(j['year']),
        posterUrl: j['poster_url']?.toString(),
      );
}

class ReviewGroupView {
  const ReviewGroupView({
    this.key = '',
    this.label = '',
    this.libraryId = 0,
    this.libraryName = '',
    this.fileCount = 0,
    this.totalSizeBytes = 0,
    this.fileIds = const [],
    this.current = const ReviewItemView(),
    this.suggestion = const ReviewItemView(),
  });

  final String key;
  final String label;
  final int libraryId;
  final String libraryName;
  final int fileCount;
  final int totalSizeBytes;
  final List<int> fileIds;
  final ReviewItemView current;
  final ReviewItemView suggestion;

  factory ReviewGroupView.fromJson(Map<String, dynamic> j) => ReviewGroupView(
        key: _asStr(j['key']),
        label: _asStr(j['label']),
        libraryId: _asInt(j['library_id']),
        libraryName: _asStr(j['library_name']),
        fileCount: _asInt(j['file_count']),
        totalSizeBytes: _asInt(j['total_size_bytes']),
        fileIds: _intList(j['file_ids']),
        current: ReviewItemView.fromJson(_asMap(j['current'])),
        suggestion: ReviewItemView.fromJson(_asMap(j['suggestion'])),
      );
}

/// 回收站强类型模型（TrashedFilesData）。
class TrashedLibraryCountView {
  const TrashedLibraryCountView({
    this.libraryId = 0,
    this.name = '',
    this.count = 0,
  });

  final int libraryId;
  final String name;
  final int count;

  factory TrashedLibraryCountView.fromJson(Map<String, dynamic> j) =>
      TrashedLibraryCountView(
        libraryId: _asInt(j['library_id'] ?? j['id']),
        name: _asStr(j['name']),
        count: _asInt(j['count']),
      );
}

class TrashedReasonCountView {
  const TrashedReasonCountView({this.reason = '', this.count = 0});

  final String reason;
  final int count;

  factory TrashedReasonCountView.fromJson(Map<String, dynamic> j) =>
      TrashedReasonCountView(
        reason: _asStr(j['reason']),
        count: _asInt(j['count']),
      );
}

class TrashedFileView {
  const TrashedFileView({
    required this.id,
    this.fileName = '',
    this.filePath = '',
    this.keptInPlace = false,
    this.sizeBytes = 0,
    this.resolution,
    this.mediaSource,
    this.hdr,
    this.videoCodec,
    this.audioLabel,
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.episodeTitle,
    this.trashedAt,
    this.purgeAfter,
    this.reason,
    this.note,
  });

  final int id;
  final String fileName;
  final String filePath;
  final bool keptInPlace;
  final int sizeBytes;
  final String? resolution;
  final String? mediaSource;
  final String? hdr;
  final String? videoCodec;
  final String? audioLabel;
  final int seasonNumber;
  final int episodeNumber;
  final String? episodeTitle;
  final String? trashedAt;
  final String? purgeAfter;
  final String? reason;
  final String? note;

  factory TrashedFileView.fromJson(Map<String, dynamic> j) => TrashedFileView(
        id: _asInt(j['id'] ?? j['file_id']),
        fileName: _asStr(j['file_name'] ?? j['filename']),
        filePath: _asStr(j['file_path'] ?? j['path']),
        keptInPlace: _asBool(j['kept_in_place']),
        sizeBytes: _asInt(j['size_bytes']),
        resolution: j['resolution']?.toString(),
        mediaSource: j['media_source']?.toString(),
        hdr: j['hdr']?.toString(),
        videoCodec: j['video_codec']?.toString(),
        audioLabel: j['audio_label']?.toString(),
        seasonNumber: _asInt(j['season_number']),
        episodeNumber: _asInt(j['episode_number']),
        episodeTitle: j['episode_title']?.toString(),
        trashedAt: j['trashed_at']?.toString(),
        purgeAfter: j['purge_after']?.toString(),
        reason: j['reason']?.toString(),
        note: j['note']?.toString(),
      );
}

class TrashedItemView {
  const TrashedItemView({
    this.key = '',
    this.libraryId = 0,
    this.libraryName = '',
    this.mediaItemId,
    this.title = '',
    this.year,
    this.kind = 'movie',
    this.fileCount = 0,
    this.totalBytes = 0,
    this.earliestPurgeAfter,
    this.latestPurgeAfter,
    this.triggerLabel,
    this.note,
    this.files = const [],
  });

  final String key;
  final int libraryId;
  final String libraryName;
  final int? mediaItemId;
  final String title;
  final int? year;
  final String kind;
  final int fileCount;
  final int totalBytes;
  final String? earliestPurgeAfter;
  final String? latestPurgeAfter;
  final String? triggerLabel;
  final String? note;
  final List<TrashedFileView> files;

  factory TrashedItemView.fromJson(Map<String, dynamic> j) {
    final lib = _asMap(j['library']);
    final item = _asMap(j['media_item']);
    final files = _list(j['files'], TrashedFileView.fromJson);
    final first = files.isNotEmpty ? files.first : null;
    final rawTitle = _asStr(item['title']);
    return TrashedItemView(
      key: _asStr(j['key'] ?? '${lib['id']}_${item['id']}_${first?.id ?? 0}'),
      libraryId: _asInt(lib['id'] ?? lib['library_id']),
      libraryName: _asStr(lib['name']),
      mediaItemId: item['id'] == null ? null : _asInt(item['id']),
      title: rawTitle.isNotEmpty
          ? rawTitle
          : (first?.fileName.isNotEmpty == true
              ? first!.fileName
              : (first?.filePath.split('/').last ?? '未知文件')),
      year: item['year'] == null ? null : _asInt(item['year']),
      kind: item['kind']?.toString() ?? 'movie',
      fileCount: _asInt(j['file_count'], files.length),
      totalBytes: _asInt(
        j['total_bytes'],
        files.fold<int>(0, (s, f) => s + f.sizeBytes),
      ),
      earliestPurgeAfter: j['earliest_purge_after']?.toString(),
      latestPurgeAfter: j['latest_purge_after']?.toString(),
      triggerLabel: j['trigger_label']?.toString(),
      note: j['note']?.toString(),
      files: files,
    );
  }
}

class TrashedFilesData {
  const TrashedFilesData({
    this.totalFiles = 0,
    this.totalItems = 0,
    this.totalBytes = 0,
    this.dueWithin24h = 0,
    this.keptInPlace = 0,
    this.byLibrary = const [],
    this.byReason = const [],
    this.items = const [],
  });

  final int totalFiles;
  final int totalItems;
  final int totalBytes;
  final int dueWithin24h;
  final int keptInPlace;
  final List<TrashedLibraryCountView> byLibrary;
  final List<TrashedReasonCountView> byReason;
  final List<TrashedItemView> items;

  factory TrashedFilesData.fromJson(Map<String, dynamic> j) => TrashedFilesData(
        totalFiles: _asInt(j['total_files']),
        totalItems: _asInt(j['total_items']),
        totalBytes: _asInt(j['total_bytes']),
        dueWithin24h: _asInt(j['due_within_24h']),
        keptInPlace: _asInt(j['kept_in_place']),
        byLibrary: _list(j['by_library'], TrashedLibraryCountView.fromJson),
        byReason: _list(j['by_reason'], TrashedReasonCountView.fromJson),
        items: _list(j['items'], TrashedItemView.fromJson),
      );
}

class TrashedBatchResultView {
  const TrashedBatchResultView({
    this.done = 0,
    this.failed = const [],
    this.remaining = 0,
  });

  final int done;
  final List<Map<String, dynamic>> failed;
  final int remaining;

  factory TrashedBatchResultView.fromJson(Map<String, dynamic> j) =>
      TrashedBatchResultView(
        done: _asInt(j['done']),
        failed: _mapList(j['failed']),
        remaining: _asInt(j['remaining']),
      );
}

/// 分享视图（ShareView）。
class LibraryShareView {
  const LibraryShareView({
    required this.id,
    this.slug = '',
    this.url = '',
    this.mediaItemId,
    this.collectionId,
    this.libraryId,
    this.title = '',
    this.kind,
    this.year,
    this.posterUrl,
    this.itemCount,
    this.password,
    this.hasPassword = false,
    this.expiresAt = '',
    this.createdAt = '',
    this.viewCount = 0,
    this.lastAccessedAt,
  });

  final int id;
  final String slug;
  final String url;
  final int? mediaItemId;
  final int? collectionId;
  final int? libraryId;
  final String title;
  final String? kind;
  final int? year;
  final String? posterUrl;
  final int? itemCount;
  final String? password;
  final bool hasPassword;
  final String expiresAt;
  final String createdAt;
  final int viewCount;
  final String? lastAccessedAt;

  factory LibraryShareView.fromJson(Map<String, dynamic> j) {
    final pw = j['password']?.toString();
    return LibraryShareView(
      id: _asInt(j['id']),
      slug: _asStr(j['slug']),
      url: _asStr(j['url']),
      mediaItemId:
          j['media_item_id'] == null ? null : _asInt(j['media_item_id']),
      collectionId:
          j['collection_id'] == null ? null : _asInt(j['collection_id']),
      libraryId: j['library_id'] == null ? null : _asInt(j['library_id']),
      title: _asStr(j['title'] ?? j['item_title'] ?? j['slug']),
      kind: j['kind']?.toString(),
      year: j['year'] == null ? null : _asInt(j['year']),
      posterUrl: j['poster_url']?.toString(),
      itemCount: j['item_count'] == null ? null : _asInt(j['item_count']),
      password: pw != null && pw.isNotEmpty ? pw : null,
      hasPassword: _asBool(j['has_password']) || (pw != null && pw.isNotEmpty),
      expiresAt: _asStr(j['expires_at']),
      createdAt: _asStr(j['created_at']),
      viewCount: _asInt(j['view_count']),
      lastAccessedAt: j['last_accessed_at']?.toString(),
    );
  }
}

/// 媒体库路由可选项（`GET /libraries/routing-options`）。
class RoutingGenreOption {
  const RoutingGenreOption({required this.id, required this.label});

  final int id;
  final String label;

  factory RoutingGenreOption.fromJson(Map<String, dynamic> j) =>
      RoutingGenreOption(id: _asInt(j['id']), label: _asStr(j['label']));
}

class RoutingRegionPreset {
  const RoutingRegionPreset({
    required this.key,
    required this.label,
    this.countries = const [],
  });

  final String key;
  final String label;
  final List<String> countries;

  factory RoutingRegionPreset.fromJson(Map<String, dynamic> j) =>
      RoutingRegionPreset(
        key: _asStr(j['key']),
        label: _asStr(j['label']),
        countries: _strList(j['countries']),
      );
}

class RoutingOptionsView {
  const RoutingOptionsView({
    this.movieGenres = const [],
    this.tvGenres = const [],
    this.regionPresets = const [],
    this.countryNames = const {},
  });

  final List<RoutingGenreOption> movieGenres;
  final List<RoutingGenreOption> tvGenres;
  final List<RoutingRegionPreset> regionPresets;
  final Map<String, String> countryNames;

  List<RoutingGenreOption> genresFor(String kind) =>
      kind == 'movie' ? movieGenres : tvGenres;

  String countryName(String code) => countryNames[code] ?? code;

  List<String> regionLabels(List<String> regions) {
    final parts = <String>[];
    final rest = [...regions];
    for (final preset in regionPresets) {
      if (preset.countries.isNotEmpty &&
          preset.countries.every(rest.contains)) {
        parts.add(preset.label);
        rest.removeWhere(preset.countries.contains);
      }
    }
    for (final c in rest) {
      parts.add(countryName(c));
    }
    return parts;
  }

  factory RoutingOptionsView.fromJson(Map<String, dynamic> j) {
    final rawCountries = _asMap(j['country_names']);
    return RoutingOptionsView(
      movieGenres: _list(j['movie_genres'], RoutingGenreOption.fromJson),
      tvGenres: _list(j['tv_genres'], RoutingGenreOption.fromJson),
      regionPresets: _list(j['region_presets'], RoutingRegionPreset.fromJson),
      countryNames: {
        for (final e in rawCountries.entries) e.key: e.value.toString(),
      },
    );
  }
}

/// 家庭成员精简视图（`GET /members`）。
class MemberOptionView {
  const MemberOptionView({
    required this.id,
    this.username = '',
    this.nickname = '',
    this.role = 'member',
    this.status = 'active',
  });

  final int id;
  final String username;
  final String nickname;
  final String role;
  final String status;

  String get displayName => nickname.trim().isEmpty ? username : nickname;

  factory MemberOptionView.fromJson(Map<String, dynamic> j) => MemberOptionView(
        id: _asInt(j['id']),
        username: _asStr(j['username']),
        nickname: _asStr(j['nickname']),
        role: j['role']?.toString() ?? 'member',
        status: j['status']?.toString() ?? 'active',
      );
}
