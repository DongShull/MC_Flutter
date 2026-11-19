import 'package:flutter/foundation.dart';

/// 刷片域模型（1:1 对应 Android core/model/Reels.kt，字段 snake_case）。

class ReelEpisodeView {
  const ReelEpisodeView({
    this.season = 0,
    this.episode = 0,
    this.name,
    this.overview,
  });

  factory ReelEpisodeView.fromJson(Map<String, dynamic> json) =>
      ReelEpisodeView(
        season: (json['season'] as num?)?.toInt() ?? 0,
        episode: (json['episode'] as num?)?.toInt() ?? 0,
        name: json['name'] as String?,
        overview: json['overview'] as String?,
      );

  final int season;
  final int episode;
  final String? name;
  final String? overview;
}

class ReelPersonView {
  const ReelPersonView({this.name = '', this.tmdbPersonId, this.avatarUrl});

  factory ReelPersonView.fromJson(Map<String, dynamic> json) => ReelPersonView(
        name: json['name'] as String? ?? '',
        tmdbPersonId: (json['tmdb_person_id'] as num?)?.toInt(),
        avatarUrl: json['avatar_url'] as String?,
      );

  final String name;

  /// TMDB 影人 ID（打开人物页用）；只有姓名时为空
  final int? tmdbPersonId;
  final String? avatarUrl;
}

/// 这一条属于哪部片（展示用）
class ReelTitleView {
  const ReelTitleView({
    this.mediaItemId = 0,
    this.libraryId = 0,
    this.kind = 'movie',
    this.name = '',
    this.year,
    this.rating,
    this.runtimeMinutes,
    this.genres = const [],
    this.tagline,
    this.overview,
    this.favorite = false,
    this.played = false,
    this.progressPercent,
    this.directors = const [],
    this.posterUrl,
    this.backdropUrl,
    this.logoUrl,
    this.episode,
  });

  factory ReelTitleView.fromJson(Map<String, dynamic> json) => ReelTitleView(
        mediaItemId: (json['media_item_id'] as num?)?.toInt() ?? 0,
        libraryId: (json['library_id'] as num?)?.toInt() ?? 0,
        kind: json['kind'] as String? ?? 'movie',
        name: json['name'] as String? ?? '',
        year: (json['year'] as num?)?.toInt(),
        rating: (json['rating'] as num?)?.toDouble(),
        runtimeMinutes: (json['runtime_minutes'] as num?)?.toInt(),
        genres: ((json['genres'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toList(),
        tagline: json['tagline'] as String?,
        overview: json['overview'] as String?,
        favorite: json['favorite'] as bool? ?? false,
        played: json['played'] as bool? ?? false,
        progressPercent: (json['progress_percent'] as num?)?.toInt(),
        directors: ((json['directors'] as List<dynamic>?) ?? const [])
            .map((e) => ReelPersonView.fromJson(e as Map<String, dynamic>))
            .toList(),
        posterUrl: json['poster_url'] as String?,
        backdropUrl: json['backdrop_url'] as String?,
        logoUrl: json['logo_url'] as String?,
        episode: json['episode'] == null
            ? null
            : ReelEpisodeView.fromJson(json['episode'] as Map<String, dynamic>),
      );

  final int mediaItemId;
  final int libraryId;

  /// movie / tv / video
  final String kind;
  final String name;
  final int? year;
  final double? rating;

  /// 片长；剧集是这一集的时长
  final int? runtimeMinutes;
  final List<String> genres;
  final String? tagline;
  final String? overview;

  /// 本人收藏了没有（电影 / 整剧）
  final bool favorite;

  /// 本人看过没有（电影看整部，剧集看这一集）
  final bool played;

  /// 看了一半时的进度（1~99）；没看过、已看完为空
  final int? progressPercent;

  /// 电影是导演、剧集是主创，最多两位
  final List<ReelPersonView> directors;
  final String? posterUrl;
  final String? backdropUrl;
  final String? logoUrl;
  final ReelEpisodeView? episode;
}

/// 放原片的哪一段（原片时间轴）
class ReelSegmentView {
  const ReelSegmentView({
    this.fileId = 0,
    this.startMs = 0,
    this.endMs = 0,
    this.durationMs,
    this.method = '',
  });

  factory ReelSegmentView.fromJson(Map<String, dynamic> json) =>
      ReelSegmentView(
        fileId: (json['file_id'] as num?)?.toInt() ?? 0,
        startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
        endMs: (json['end_ms'] as num?)?.toInt() ?? 0,
        durationMs: (json['duration_ms'] as num?)?.toInt(),
        method: json['method'] as String? ?? '',
      );

  final int fileId;
  final int startMs;
  final int endMs;
  final int? durationMs;

  /// bitrate 码率最高段 / chapter 章节起点 / position 固定位置
  final String method;
}

/// 怎么放这一条：seek = 从原片中间起播；clip = 放服务端预切好的片段文件
class ReelPlayView {
  const ReelPlayView({this.mode = 'seek', this.streamUrl, this.clipUrl});

  factory ReelPlayView.fromJson(Map<String, dynamic> json) => ReelPlayView(
        mode: json['mode'] as String? ?? 'seek',
        streamUrl: json['stream_url'] as String?,
        clipUrl: json['clip_url'] as String?,
      );

  final String mode;
  final String? streamUrl;
  final String? clipUrl;
}

class ReelItemView {
  const ReelItemView({
    this.id = '',
    required this.title,
    this.coverUrl,
    required this.segment,
    required this.play,
  });

  factory ReelItemView.fromJson(Map<String, dynamic> json) => ReelItemView(
        id: json['id'] as String? ?? '',
        title: ReelTitleView.fromJson(
            (json['title'] as Map<String, dynamic>?) ?? const {}),
        coverUrl: json['cover_url'] as String?,
        segment: ReelSegmentView.fromJson(
            (json['segment'] as Map<String, dynamic>?) ?? const {}),
        play: ReelPlayView.fromJson(
            (json['play'] as Map<String, dynamic>?) ?? const {}),
      );

  /// 片段标识（事件上报用）：文件 + 起点
  final String id;
  final ReelTitleView title;

  /// 封面：起点那一帧；没有时是剧照
  final String? coverUrl;
  final ReelSegmentView segment;
  final ReelPlayView play;
}

class ReelFeedView {
  const ReelFeedView({
    this.seed = 0,
    this.nextOffset = 0,
    this.hasMore = false,
    this.items = const [],
  });

  factory ReelFeedView.fromJson(Map<String, dynamic> json) => ReelFeedView(
        seed: (json['seed'] as num?)?.toInt() ?? 0,
        nextOffset: (json['next_offset'] as num?)?.toInt() ?? 0,
        hasMore: json['has_more'] as bool? ?? false,
        items: ((json['items'] as List<dynamic>?) ?? const [])
            .map((e) => ReelItemView.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// 这次刷片的随机种子，翻页时原样带回
  final int seed;
  final int nextOffset;
  final bool hasMore;
  final List<ReelItemView> items;
}

class FacetValue {
  const FacetValue({this.value = '', this.label = '', this.count = 0});

  factory FacetValue.fromJson(Map<String, dynamic> json) => FacetValue(
        value: json['value'] as String? ?? '',
        label: json['label'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );

  final String value;
  final String label;
  final int count;
}

/// 筛选菜单的候选值与计数（每维计数排除本维自身条件；为 0 的档 UI 置灰）
class ReelFacetsView {
  const ReelFacetsView({
    this.total = 0,
    this.filterable = true,
    this.kinds = const [],
    this.genres = const [],
    this.countries = const [],
    this.decades = const [],
    this.ratings = const [],
    this.runtimes = const [],
    this.watch = const [],
  });

  factory ReelFacetsView.fromJson(Map<String, dynamic> json) => ReelFacetsView(
        total: (json['total'] as num?)?.toInt() ?? 0,
        filterable: json['filterable'] as bool? ?? true,
        kinds: _facetList(json['kinds']),
        genres: _facetList(json['genres']),
        countries: _facetList(json['countries']),
        decades: _facetList(json['decades']),
        ratings: _facetList(json['ratings']),
        runtimes: _facetList(json['runtimes']),
        watch: _facetList(json['watch']),
      );

  static List<FacetValue> _facetList(dynamic raw) =>
      ((raw as List<dynamic>?) ?? const [])
          .map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
          .toList();

  final int total;

  /// False = 当前池子是「其他」，只剩观看状态可筛
  final bool filterable;
  final List<FacetValue> kinds;
  final List<FacetValue> genres;
  final List<FacetValue> countries;
  final List<FacetValue> decades;
  final List<FacetValue> ratings;
  final List<FacetValue> runtimes;

  /// 观看状态：只有「没看过」一项
  final List<FacetValue> watch;
}

/* ---------------- 事件上报 ---------------- */

class ReelEventView {
  const ReelEventView({
    required this.reelId,
    required this.kind,
    this.mode = 'seek',
    this.mediaItemId,
    this.fileId,
    this.positionMs,
    this.watchedMs,
    this.waitMs,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'reel_id': reelId,
        'kind': kind,
        'mode': mode,
        if (mediaItemId != null) 'media_item_id': mediaItemId,
        if (fileId != null) 'file_id': fileId,
        if (positionMs != null) 'position_ms': positionMs,
        if (watchedMs != null) 'watched_ms': watchedMs,
        if (waitMs != null) 'wait_ms': waitMs,
        if (detail != null) 'detail': detail,
      };

  final String reelId;

  /// impression / first_frame / leave / complete / fullscreen / detail / fail
  final String kind;
  final String mode;
  final int? mediaItemId;
  final int? fileId;
  final int? positionMs;
  final int? watchedMs;
  final int? waitMs;
  final String? detail;
}

/* ---------------- 刷片筛选（请求参数的唯一来源） ---------------- */

/// 与服务端 GET /reels 的参数一一对应（维内 OR、维间 AND）
@immutable
class ReelFilter {
  const ReelFilter({
    this.kind,
    this.genres,
    this.countries,
    this.decades,
    this.ratingGte,
    this.runtimes,
    this.watch,
  });

  /// movie / tv / video；null = 电影 + 剧集（服务端默认）
  final String? kind;
  final String? genres;
  final String? countries;
  final String? decades;
  final double? ratingGte;
  final String? runtimes;

  /// 只看没看过的（"unwatched"）；null = 不限
  final String? watch;

  bool get isActive => kind != null ||
      genres != null ||
      countries != null ||
      decades != null ||
      ratingGte != null ||
      runtimes != null ||
      watch != null;

  int get activeCount => [
        kind != null,
        genres != null,
        countries != null,
        decades != null,
        ratingGte != null,
        runtimes != null,
        watch != null,
      ].where((e) => e).length;
}
