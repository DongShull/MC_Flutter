import 'package:flutter/foundation.dart';

/// 刷片域模型（1:1 对齐 iOS `Generated/Models.swift` 中的 Reel*View 与多选筛选）。

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
  final int? tmdbPersonId;
  final String? avatarUrl;
}

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
            .map((e) => e.toString())
            .toList(),
        tagline: json['tagline'] as String?,
        overview: json['overview'] as String?,
        favorite: json['favorite'] as bool? ?? false,
        played: json['played'] as bool? ?? false,
        progressPercent: (json['progress_percent'] as num?)?.toInt(),
        directors: ((json['directors'] as List<dynamic>?) ?? const [])
            .whereType<Map>()
            .map((e) => ReelPersonView.fromJson(e.cast<String, dynamic>()))
            .toList(),
        posterUrl: json['poster_url'] as String?,
        backdropUrl: json['backdrop_url'] as String?,
        logoUrl: json['logo_url'] as String?,
        episode: json['episode'] is Map
            ? ReelEpisodeView.fromJson(
                (json['episode'] as Map).cast<String, dynamic>(),
              )
            : null,
      );

  final int mediaItemId;
  final int libraryId;
  final String kind;
  final String name;
  final int? year;
  final double? rating;
  final int? runtimeMinutes;
  final List<String> genres;
  final String? tagline;
  final String? overview;
  final bool favorite;
  final bool played;
  final int? progressPercent;
  final List<ReelPersonView> directors;
  final String? posterUrl;
  final String? backdropUrl;
  final String? logoUrl;
  final ReelEpisodeView? episode;
}

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
  final String method;

  int get spanMs => endMs > startMs ? endMs - startMs : (durationMs ?? 45000);
}

class ReelSubtitleView {
  const ReelSubtitleView({
    this.ordinal = 0,
    this.language,
    this.title,
    this.codec,
    this.url,
    this.format,
  });

  factory ReelSubtitleView.fromJson(Map<String, dynamic> json) =>
      ReelSubtitleView(
        ordinal: (json['ordinal'] as num?)?.toInt() ?? 0,
        language: json['language']?.toString(),
        title: json['title']?.toString(),
        codec: json['codec']?.toString(),
        url: json['url']?.toString(),
        format: json['format']?.toString(),
      );

  final int ordinal;
  final String? language;
  final String? title;
  final String? codec;
  final String? url;
  final String? format;
}

class ReelPlayView {
  const ReelPlayView({
    this.mode = 'seek',
    this.streamUrl,
    this.clipUrl,
    this.clipSizeBytes,
    this.sizeBytes,
    this.disc,
    this.audioOrdinal,
    this.subtitle,
  });

  factory ReelPlayView.fromJson(Map<String, dynamic> json) => ReelPlayView(
        mode: json['mode'] as String? ?? 'seek',
        streamUrl: json['stream_url'] as String?,
        clipUrl: json['clip_url'] as String?,
        clipSizeBytes: (json['clip_size_bytes'] as num?)?.toInt(),
        sizeBytes: (json['size_bytes'] as num?)?.toInt(),
        disc: json['disc']?.toString(),
        audioOrdinal: (json['audio_ordinal'] as num?)?.toInt(),
        subtitle: json['subtitle'] is Map
            ? ReelSubtitleView.fromJson(
                (json['subtitle'] as Map).cast<String, dynamic>(),
              )
            : null,
      );

  final String mode;
  final String? streamUrl;
  final String? clipUrl;
  final int? clipSizeBytes;
  final int? sizeBytes;
  final String? disc;
  final int? audioOrdinal;
  final ReelSubtitleView? subtitle;

  bool get isClip => mode == 'clip';
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
          (json['title'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        coverUrl: json['cover_url'] as String?,
        segment: ReelSegmentView.fromJson(
          (json['segment'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        play: ReelPlayView.fromJson(
          (json['play'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );

  final String id;
  final ReelTitleView title;
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
            .whereType<Map>()
            .map((e) => ReelItemView.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

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
          .whereType<Map>()
          .map((e) => FacetValue.fromJson(e.cast<String, dynamic>()))
          .toList();

  final int total;
  final bool filterable;
  final List<FacetValue> kinds;
  final List<FacetValue> genres;
  final List<FacetValue> countries;
  final List<FacetValue> decades;
  final List<FacetValue> ratings;
  final List<FacetValue> runtimes;
  final List<FacetValue> watch;
}

class ReelShareResult {
  const ReelShareResult({
    required this.slug,
    required this.url,
    this.password,
  });

  factory ReelShareResult.fromJson(Map<String, dynamic> json) =>
      ReelShareResult(
        slug: (json['slug'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
        password: json['password']?.toString(),
      );

  final String slug;
  final String url;
  final String? password;
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
  final Map<String, dynamic>? detail;
}

/* ---------------- 刷片多选筛选（维内逗号 OR、维间 AND） ---------------- */

@immutable
class ReelFilter {
  const ReelFilter({
    this.kind,
    this.genres = const {},
    this.countries = const {},
    this.decades = const {},
    this.ratingGte,
    this.runtimes = const {},
    this.watch,
  });

  final String? kind;
  final Set<String> genres;
  final Set<String> countries;
  final Set<String> decades;
  final double? ratingGte;
  final Set<String> runtimes;
  final String? watch;

  String? get genresQuery => _joinSet(genres);
  String? get countriesQuery => _joinSet(countries);
  String? get decadesQuery => _joinSet(decades);
  String? get runtimesQuery => _joinSet(runtimes);

  static String? _joinSet(Set<String> s) {
    if (s.isEmpty) return null;
    final list = s.toList()..sort();
    return list.join(',');
  }

  bool get isActive =>
      kind != null ||
      genres.isNotEmpty ||
      countries.isNotEmpty ||
      decades.isNotEmpty ||
      ratingGte != null ||
      runtimes.isNotEmpty ||
      watch != null;

  int get activeCount => [
        kind != null,
        genres.isNotEmpty,
        countries.isNotEmpty,
        decades.isNotEmpty,
        ratingGte != null,
        runtimes.isNotEmpty,
        watch != null,
      ].where((e) => e).length;

  ReelFilter copyWith({
    String? kind,
    bool clearKind = false,
    Set<String>? genres,
    Set<String>? countries,
    Set<String>? decades,
    double? ratingGte,
    bool clearRating = false,
    Set<String>? runtimes,
    String? watch,
    bool clearWatch = false,
  }) {
    return ReelFilter(
      kind: clearKind ? null : (kind ?? this.kind),
      genres: genres ?? this.genres,
      countries: countries ?? this.countries,
      decades: decades ?? this.decades,
      ratingGte: clearRating ? null : (ratingGte ?? this.ratingGte),
      runtimes: runtimes ?? this.runtimes,
      watch: clearWatch ? null : (watch ?? this.watch),
    );
  }

  static Set<String> toggleInSet(Set<String> current, String value) {
    final next = Set<String>.from(current);
    if (!next.remove(value)) next.add(value);
    return next;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReelFilter &&
          other.kind == kind &&
          setEquals(other.genres, genres) &&
          setEquals(other.countries, countries) &&
          setEquals(other.decades, decades) &&
          other.ratingGte == ratingGte &&
          setEquals(other.runtimes, runtimes) &&
          other.watch == watch;

  @override
  int get hashCode => Object.hash(
        kind,
        Object.hashAllUnordered(genres),
        Object.hashAllUnordered(countries),
        Object.hashAllUnordered(decades),
        ratingGte,
        Object.hashAllUnordered(runtimes),
        watch,
      );
}
