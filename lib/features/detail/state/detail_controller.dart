import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/api/episodes_api.dart';
import '../../../core/api/mc_client.dart';

/// JSON 容错读取工具（服务端字段名历史上有多种拼法）。
abstract final class J {
  static String? s(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }

  static int? i(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v) ?? int.tryParse(v.split('-').first);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static double? d(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static List<String> list(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is List) {
        return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
      if (v is String && v.isNotEmpty) return [v];
    }
    return const [];
  }

  static Map<String, dynamic> map(Map<String, dynamic> m, String key) =>
      (m[key] is Map) ? (m[key] as Map).cast<String, dynamic>() : const {};

  static List<Map<String, dynamic>> listOfMap(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is List) {
        return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    return const [];
  }
}

/// 详情页条目模型（对齐原 LibraryItemDetailView，字段解析容错）。
class DetailEntry {
  const DetailEntry({
    required this.id,
    required this.libraryId,
    required this.kind,
    this.title = '',
    this.originalTitle,
    this.tagline,
    this.overview,
    this.year,
    this.runtimeMinutes,
    this.rating,
    this.officialRating,
    this.resolution,
    this.hdr = false,
    this.hdrLabel,
    this.genres = const [],
    this.posterUrl,
    this.backdropUrl,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.seriesName,
    this.seriesCollectionId,
    this.collections = const [],
    this.collectionIds = const {},
    this.seasons = const [],
    this.cast = const [],
    this.resumeEpisode,
    this.tmdbId,
    this.fileIds = const [],
  });

  final int id;
  final int libraryId;
  /// movie / tv
  final String kind;
  final String title;
  final String? originalTitle;
  final String? tagline;
  final String? overview;
  final int? year;
  final int? runtimeMinutes;
  final double? rating;
  final String? officialRating;
  final String? resolution;
  final bool hdr;
  final String? hdrLabel;
  final List<String> genres;
  final String? posterUrl;
  final String? backdropUrl;
  final List<String> audioTracks;
  final List<String> subtitleTracks;
  /// 系列名（文字链接行）
  final String? seriesName;
  final int? seriesCollectionId;
  /// 合集名列表（文字链接行）
  final List<String> collections;
  final Map<String, int> collectionIds;
  final List<SeasonInfo> seasons;
  /// 演职员（前 40 由页面截断）
  final List<CastMember> cast;
  /// 外部词条（订阅弹层 titleRef 用；null = 服务端没给，订阅入口置灰提示）
  final int? tmdbId;
  /// 电影的在库台账文件 id（下载 / 字幕生成取首个；剧集走分集的 fileIds）
  final List<int> fileIds;
  /// 服务端续播集锚点（resume_episode）
  final int? resumeEpisode;

  bool get isTv => kind == 'tv' || seasons.isNotEmpty;

  factory DetailEntry.fromJson(Map<String, dynamic> j) {
    final media = J.map(j, 'media');
    final localMeta = J.map(j, 'local_meta');
    final series = J.map(j, 'series');
    final rawFiles = (j['files'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final primaryFile = rawFiles.isNotEmpty ? rawFiles.first : const <String, dynamic>{};

    // seasons 可能是 List<int>（如 [1, 2]）或 List<Map>
    final parsedSeasons = <SeasonInfo>[];
    final rawSeasons = j['seasons'];
    if (rawSeasons is List) {
      for (final s in rawSeasons) {
        if (s is num) {
          parsedSeasons.add(SeasonInfo(number: s.toInt()));
        } else if (s is Map) {
          parsedSeasons.add(SeasonInfo.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }

    // collections 可能是 List<String> 或 List<{id, name}>
    final parsedCollections = <String>[];
    final parsedCollectionIds = <String, int>{};
    final rawCols = j['collections'] ?? j['collection_names'];
    if (rawCols is List) {
      for (final c in rawCols) {
        if (c is String && c.trim().isNotEmpty) {
          parsedCollections.add(c.trim());
        } else if (c is Map) {
          final m = Map<String, dynamic>.from(c);
          final name = (m['name'] ?? m['title'] ?? '').toString().trim();
          final cid = J.i(m, ['id', 'collection_id']);
          if (name.isNotEmpty) {
            parsedCollections.add(name);
            if (cid != null) parsedCollectionIds[name] = cid;
          }
        }
      }
    }

    // 合并导演与演员（支持 local_meta.director_credits + local_meta.actors + 顶层 cast/people）
    final parsedCast = <CastMember>[
      for (final d in J.listOfMap(localMeta, ['director_credits']))
        CastMember(
          name: J.s(d, ['name', 'person_name']) ?? '',
          role: '导演',
          profileUrl: J.s(d, ['thumb_url', 'profile_url', 'photo_url']),
          personId: J.i(d, ['tmdb_person_id', 'person_id', 'id']),
        ),
      ...J.listOfMap(localMeta, ['actors']).map(CastMember.fromJson),
      ...J.listOfMap(j, ['cast', 'people']).map(CastMember.fromJson),
    ].where((c) => c.name.isNotEmpty).toList();

    final hdrStr = J.s(primaryFile, ['hdr']) ?? J.s(media, ['hdr']);
    final isHdr = media['hdr'] == true ||
        primaryFile['hdr'] == true ||
        (hdrStr != null && hdrStr.isNotEmpty && hdrStr.toLowerCase() != 'sdr');
    final fileDurMins = ((primaryFile['duration_seconds'] as num?)?.toInt() ?? 0) ~/ 60;

    return DetailEntry(
      id: J.i(j, ['id', 'item_id', 'media_item_id']) ?? 0,
      libraryId: J.i(j, ['library_id']) ?? 0,
      kind: J.s(j, ['kind', 'type', 'item_kind']) ?? 'movie',
      title: J.s(j, ['title', 'name']) ?? '',
      originalTitle: J.s(j, ['original_title', 'english_title', 'original_name']),
      tagline: J.s(j, ['tagline']) ?? J.s(localMeta, ['tagline']),
      overview: J.s(j, ['overview', 'plot', 'summary']) ??
          J.s(localMeta, ['plot', 'overview', 'summary']),
      year: J.i(j, ['year', 'production_year']),
      runtimeMinutes: J.i(j, ['runtime_minutes', 'runtime', 'duration_minutes']) ??
          J.i(localMeta, ['runtime_minutes', 'runtime']) ??
          (fileDurMins > 0 ? fileDurMins : null),
      rating: J.d(j, ['rating', 'community_rating', 'vote_average']) ??
          J.d(localMeta, ['rating', 'vote_average']),
      officialRating: J.s(j, ['official_rating', 'content_rating']),
      resolution: J.s(media, ['resolution', 'resolution_label']) ??
          J.s(primaryFile, ['resolution']),
      hdr: isHdr,
      hdrLabel: (hdrStr != null && hdrStr.isNotEmpty && hdrStr != 'true')
          ? hdrStr.toUpperCase()
          : (isHdr ? 'HDR' : null),
      genres: <String>{
        ...J.list(j, ['genres']),
        ...J.list(localMeta, ['genres']),
      }.toList(),
      posterUrl: J.s(j, ['poster_url', 'poster']),
      backdropUrl: J.s(j, ['backdrop_url', 'backdrop']),
      audioTracks: J.list(media, ['audio_tracks', 'audio']),
      subtitleTracks: J.list(media, ['subtitle_tracks', 'subtitles']),
      seriesName: J.s(series, ['name', 'series_name']) ?? J.s(j, ['series_name']),
      seriesCollectionId: J.i(series, ['id', 'collection_id']) ?? J.i(j, ['series_collection_id']),
      collections: parsedCollections,
      collectionIds: parsedCollectionIds,
      seasons: parsedSeasons,
      cast: parsedCast,
      resumeEpisode: J.i(j, ['resume_episode']),
      tmdbId: J.i(j, ['tmdb_id', 'tmdb']),
      fileIds: rawFiles
          .map((e) => J.i(e, ['id', 'file_id']))
          .whereType<int>()
          .toList(),
    );
  }
}

class SeasonInfo {
  const SeasonInfo({required this.number, this.name, this.airDate, this.episodeCount});

  final int number;
  final String? name;
  /// 首播日期（yyyy-MM-dd）
  final String? airDate;
  final int? episodeCount;

  factory SeasonInfo.fromJson(Map<String, dynamic> j) => SeasonInfo(
        number: J.i(j, ['season_number', 'number', 'index_number']) ?? 0,
        name: J.s(j, ['name', 'season_name']),
        airDate: J.s(j, ['air_date', 'premiered']),
        episodeCount: J.i(j, ['episode_count', 'episodes']),
      );
}

/// 分集模型（对齐 media_episode / EpisodeView）。
class EpisodeEntry {
  const EpisodeEntry({
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    this.overview,
    this.airDate,
    this.runtimeMinutes,
    this.rating,
    this.stillUrl,
    this.played = false,
    this.resumeMs = 0,
    this.owned = false,
    this.fileIds = const [],
  });

  final int seasonNumber;
  final int episodeNumber;
  final String name;
  final String? overview;
  final String? airDate;
  final int? runtimeMinutes;
  final double? rating;
  final String? stillUrl;
  final bool played;
  final int resumeMs;

  /// 该集台账文件 id（选集接口 file_ids）；起播取首个。
  final List<int> fileIds;

  /// false = 缺集/文件缺失（前端置灰）；服务端未回该字段时默认在位。
  final bool owned;

  /// 起播用 fileId（首个台账文件），无在位文件时 null。
  int? get playFileId => fileIds.isEmpty ? null : fileIds.first;

  factory EpisodeEntry.fromJson(Map<String, dynamic> j) => EpisodeEntry(
        seasonNumber: J.i(j, ['season_number']) ?? 0,
        episodeNumber: J.i(j, ['episode_number', 'number', 'index_number']) ?? 0,
        name: J.s(j, ['name', 'title']) ?? '',
        overview: J.s(j, ['overview', 'plot']),
        airDate: J.s(j, ['air_date', 'premiered']),
        runtimeMinutes: J.i(j, ['runtime_minutes', 'runtime']),
        rating: J.d(j, ['rating', 'community_rating']),
        stillUrl: J.s(j, ['still_url', 'still', 'thumb_url']),
        played: j['played'] == true,
        resumeMs: J.i(j, ['resume_ms', 'position_ms']) ?? 0,
        owned: j['owned'] as bool? ?? true,
        fileIds: (j['file_ids'] as List?)
                ?.map((e) => e is num ? e.toInt() : int.tryParse(e.toString()))
                .whereType<int>()
                .toList() ??
            const [],
      );
}

/// 演职员（cast 前 40，人物卡点击进人物页）。
class CastMember {
  const CastMember({required this.name, this.role, this.profileUrl, this.personId});

  final String name;
  final String? role;
  final String? profileUrl;
  final int? personId;

  factory CastMember.fromJson(Map<String, dynamic> j) => CastMember(
        name: J.s(j, ['name', 'person_name']) ?? '',
        role: J.s(j, ['role', 'character']),
        profileUrl: J.s(j, ['thumb_url', 'profile_url', 'photo_url']),
        personId: J.i(j, ['tmdb_person_id', 'person_id', 'id']),
      );
}

/// 相似推荐 / 系列一行（对齐原 Related：有系列一行时相似推荐排除同系列）。
class RelatedItems {
  const RelatedItems({this.similar = const [], this.seriesParts = const [], this.seriesName});

  final List<DetailEntry> similar;
  /// 系列合集成员（按上映顺序）
  final List<DetailEntry> seriesParts;
  final String? seriesName;

  bool get isEmpty => similar.isEmpty && seriesParts.isEmpty;
}

/// 在播档期横幅（对齐 AirSchedule.kt 的字段子集）。
class AirScheduleBanner {
  const AirScheduleBanner({this.dayOfWeek, this.timeText, this.nextEpisodeText, this.nextAirDate});

  /// 星期几（一 ~ 日）
  final String? dayOfWeek;
  final String? timeText;
  final String? nextEpisodeText;
  final String? nextAirDate;

  factory AirScheduleBanner.fromJson(Map<String, dynamic> j) => AirScheduleBanner(
        dayOfWeek: J.s(j, ['day_of_week', 'air_day', 'weekday']),
        timeText: J.s(j, ['time', 'air_time']),
        nextEpisodeText: J.s(j, ['next_episode', 'next_episode_text']),
        nextAirDate: J.s(j, ['next_air_date']),
      );

  String get text {
    final parts = <String>[
      if (dayOfWeek != null && dayOfWeek!.isNotEmpty) '每周$dayOfWeek',
      if (timeText != null && timeText!.isNotEmpty) timeText!,
      if (nextEpisodeText != null && nextEpisodeText!.isNotEmpty) nextEpisodeText!,
      if (nextAirDate != null && nextAirDate!.isNotEmpty) '下次播出 $nextAirDate!',
    ];
    return parts.join(' · ');
  }
}

/// 标记状态：收藏 / 已看（对齐 PlaybackMarks）。
class PlaybackMarks {
  const PlaybackMarks({this.isFavorite = false, this.played = false});

  final bool isFavorite;
  final bool played;
}

/// 续播点（GET /playback/resume）。
class ResumeInfo {
  const ResumeInfo({required this.positionMs, required this.durationMs, this.season, this.episode});

  final int positionMs;
  final int durationMs;
  final int? season;
  final int? episode;
}

/// 详情页整体状态。
class DetailState {
  const DetailState({
    this.loading = false,
    this.error,
    this.entry,
    this.episodes = const {},
    this.related = const RelatedItems(),
    this.marks = const PlaybackMarks(),
    this.resume,
    this.airSchedule,
    this.selectedSeason,
    this.overviewExpanded = false,
    this.busy = false,
  });

  final bool loading;
  final String? error;
  final DetailEntry? entry;
  /// seasonNumber -> episodes
  final Map<int, List<EpisodeEntry>> episodes;
  final RelatedItems related;
  final PlaybackMarks marks;
  final ResumeInfo? resume;
  final AirScheduleBanner? airSchedule;
  final int? selectedSeason;
  final bool overviewExpanded;
  /// 动作请求在途
  final bool busy;

  DetailState copyWith({
    bool? loading,
    Object? error = _sentinel,
    DetailEntry? entry,
    Map<int, List<EpisodeEntry>>? episodes,
    RelatedItems? related,
    PlaybackMarks? marks,
    ResumeInfo? resume,
    Object? airSchedule = _sentinel,
    Object? selectedSeason = _sentinel,
    bool? overviewExpanded,
    bool? busy,
  }) {
    return DetailState(
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      entry: entry ?? this.entry,
      episodes: episodes ?? this.episodes,
      related: related ?? this.related,
      marks: marks ?? this.marks,
      resume: resume ?? this.resume,
      airSchedule:
          identical(airSchedule, _sentinel) ? this.airSchedule : airSchedule as AirScheduleBanner?,
      selectedSeason:
          identical(selectedSeason, _sentinel) ? this.selectedSeason : selectedSeason as int?,
      overviewExpanded: overviewExpanded ?? this.overviewExpanded,
      busy: busy ?? this.busy,
    );
  }

  static const _sentinel = Object();
}

/// 时长文案（h:mm / mm 分钟），对齐原 McFormat.clock。
String mcClock(int ms) {
  final total = ms ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}';
  return '$m 分钟';
}

/// 续播按钮文案（「继续 第 x 季第 y 集 · h:mm」/「继续 mm」/「播放」）。
String playButtonLabel(DetailState s) {
  final r = s.resume;
  if (r == null || r.positionMs <= 0) return '播放';
  final season = r.season ?? 0;
  final episode = r.episode ?? 0;
  if (season > 0 && episode > 0) {
    return '继续 第 $season 季第 $episode 集 · ${mcClock(r.positionMs)}';
  }
  return '继续 ${mcClock(r.positionMs)}';
}

/// 详情页控制器（对齐 ItemDetailViewModel：GET /libraries/{id}/items/{id} +
/// 分集 / 相似推荐 / 标记 / 续播点）。
class DetailController extends FamilyNotifier<DetailState, String> {
  McClient? _client;
  int _libraryId = -1;
  int _itemId = -1;
  bool _relatedRequested = false;

  @override
  DetailState build(String arg) {
    final parts = arg.split(':');
    _libraryId = int.tryParse(parts[0]) ?? -1;
    _itemId = int.tryParse(parts[1]) ?? -1;
    _client = McClient(session: ref.read(sessionStoreProvider));
    return const DetailState(loading: true);
  }

  McClient get _api => _client!;

  /// 首次加载：详情 → 分集（TV）→ 标记 / 续播 → 相似推荐（失败静默，不阻塞首屏）。
  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final body = await _api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/libraries/$_libraryId/items/$_itemId',
      );
      final entry = DetailEntry.fromJson(body);
      AirScheduleBanner? schedule;
      if (body['air_schedule'] is Map) {
        schedule = AirScheduleBanner.fromJson((body['air_schedule'] as Map).cast<String, dynamic>());
      }
      state = state.copyWith(
        loading: false,
        entry: entry,
        airSchedule: schedule,
        selectedSeason: state.selectedSeason ?? _defaultSeason(entry),
      );
      if (entry.isTv && state.episodes.isEmpty) {
        await loadSeason(state.selectedSeason ?? 1);
      }
      await loadMarks();
      await loadResume();
      if (!_relatedRequested) {
        _relatedRequested = true;
        await loadRelated(entry);
      }
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.friendlyMessage);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败：$e');
    }
  }

  int? _defaultSeason(DetailEntry entry) {
    if (entry.seasons.isEmpty) return null;
    for (final s in entry.seasons) {
      if (s.number > 0) return s.number;
    }
    return entry.seasons.first.number;
  }

  /// 拉某一季的分集（选集数据接口化：core/api/episodes_api.dart 封装端点，
  /// EpisodeRef 携带 owned / file_ids / played，点集起播由 fileId 驱动）。
  Future<void> loadSeason(int seasonNumber) async {
    state = state.copyWith(selectedSeason: seasonNumber);
    try {
      final season = await EpisodesApi.of(ref).libraryItemEpisodes(
        _libraryId, _itemId, seasonNumber,
      );
      final list = season.episodes
          .map((e) => EpisodeEntry(
                seasonNumber: seasonNumber,
                episodeNumber: e.episodeNumber,
                name: e.name ?? '第 ${e.episodeNumber} 集',
                overview: e.overview,
                airDate: e.airDate,
                stillUrl: e.stillUrl,
                played: e.played,
                resumeMs: e.positionMs,
                owned: e.owned,
                fileIds: e.fileIds,
              ))
          .toList();
      state = state.copyWith(episodes: {...state.episodes, seasonNumber: list});
    } catch (_) {
      // 分集拉取失败不阻塞详情页
    }
  }

  /// 相似推荐与系列一行（有系列一行时排除同系列；拉不到再补一次不排除的）。
  Future<void> loadRelated(DetailEntry entry) async {
    final seriesId = entry.seriesCollectionId;
    final excludeSeries = seriesId != null && !entry.isTv;
    var similar = <DetailEntry>[];
    try {
      final body = await _api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/libraries/$_libraryId/items/$_itemId/similar',
        query: excludeSeries ? const {'exclude_series': 'true'} : null,
      );
      similar = J.listOfMap(body, ['items', 'results', 'data']).map(DetailEntry.fromJson).toList();
    } catch (_) {}
    final seriesParts = <DetailEntry>[];
    if (seriesId != null) {
      try {
        final body = await _api.unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/collections/$seriesId/series',
        );
        seriesParts.addAll(J.listOfMap(body, ['parts', 'items']).map(DetailEntry.fromJson));
      } catch (_) {}
      // 系列没出来（只有一部 / 拉不到上游档案）：再拉一次不排除的相似推荐
      if (seriesParts.length <= 1 && excludeSeries) {
        try {
          final body = await _api.unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/libraries/$_libraryId/items/$_itemId/similar',
          );
          similar = J.listOfMap(body, ['items', 'results', 'data']).map(DetailEntry.fromJson).toList();
        } catch (_) {}
      }
    }
    state = state.copyWith(
      related: RelatedItems(
        similar: similar,
        seriesParts: seriesParts,
        seriesName: entry.seriesName,
      ),
    );
  }

  /// GET /playback/marks：收藏 / 已看初始态。
  Future<void> loadMarks() async {
    try {
      final body = await _api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/playback/marks',
        query: {'media_item_id': _itemId},
      );
      state = state.copyWith(
        marks: PlaybackMarks(
          isFavorite: body['favorite'] == true,
          played: body['played'] == true,
        ),
      );
    } catch (_) {}
  }

  /// POST /playback/marks：只传要改的那一项，失败回滚。
  Future<void> _setMarks({bool? favorite, bool? played}) async {
    final prev = state.marks;
    state = state.copyWith(
      busy: true,
      marks: PlaybackMarks(
        isFavorite: favorite ?? prev.isFavorite,
        played: played ?? prev.played,
      ),
    );
    try {
      await _api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/playback/marks',
        body: {
          'media_item_id': _itemId,
          if (favorite != null) 'favorite': favorite,
          if (played != null) 'played': played,
        },
      );
    } catch (_) {
      state = state.copyWith(marks: prev);
    }
    state = state.copyWith(busy: false);
  }

  Future<void> toggleFavorite() => _setMarks(favorite: !state.marks.isFavorite);

  Future<void> togglePlayed() => _setMarks(played: !state.marks.played);

  /// GET /playback/resume：续播点（决定「播放」还是「继续 xx」）。
  Future<void> loadResume({int season = 0, int episode = 0}) async {
    try {
      final body = await _api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/playback/resume',
        query: {
          'media_item_id': _itemId,
          'season_number': season,
          'episode_number': episode,
        },
      );
      final pos = J.i(body, ['position_ms']) ?? 0;
      if (pos > 0) {
        state = state.copyWith(
          resume: ResumeInfo(
            positionMs: pos,
            durationMs: J.i(body, ['duration_ms']) ?? 0,
            season: J.i(body, ['season_number']),
            episode: J.i(body, ['episode_number']),
          ),
        );
      }
    } catch (_) {}
  }

  void toggleOverview() => state = state.copyWith(overviewExpanded: !state.overviewExpanded);

  /// 刷新元数据：POST /libraries/{libraryId}/items/{id}/metadata/refresh。
  Future<String?> refreshMetadata() async {
    try {
      await _api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/libraries/$_libraryId/items/$_itemId/metadata/refresh',
      );
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '刷新失败：$e';
    }
  }

  /// 删除前预检：GET /libraries/{libraryId}/items/{itemId}/delete-preview。
  Future<Map<String, dynamic>?> fetchDeletePreview() async {
    try {
      return await _api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/libraries/$_libraryId/items/$_itemId/delete-preview',
      );
    } catch (_) {
      return null;
    }
  }

  /// 删除条目：DELETE /libraries/{libraryId}/items/{itemId}。null = 成功。
  Future<String?> deleteItem() async {
    try {
      await _api.unwrap<dynamic>(
        Channel.general,
        'DELETE',
        '/api/v1/libraries/$_libraryId/items/$_itemId',
      );
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '删除失败：$e';
    }
  }

  /// 单集切换已看 / 未看标记（POST /playback/marks 携带 season_number + episode_number）。
  Future<String?> toggleEpisodePlayed(EpisodeEntry ep) async {
    final targetPlayed = !ep.played;
    final prevSeason = state.episodes[ep.seasonNumber] ?? const <EpisodeEntry>[];
    final nextSeason = [
      for (final e in prevSeason)
        if (e.episodeNumber == ep.episodeNumber)
          EpisodeEntry(
            seasonNumber: e.seasonNumber,
            episodeNumber: e.episodeNumber,
            name: e.name,
            overview: e.overview,
            airDate: e.airDate,
            runtimeMinutes: e.runtimeMinutes,
            rating: e.rating,
            stillUrl: e.stillUrl,
            played: targetPlayed,
            resumeMs: targetPlayed ? 0 : e.resumeMs,
            owned: e.owned,
            fileIds: e.fileIds,
          )
        else
          e,
    ];
    state = state.copyWith(
      episodes: {...state.episodes, ep.seasonNumber: nextSeason},
    );
    try {
      await _api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/playback/marks',
        body: {
          'media_item_id': _itemId,
          'season_number': ep.seasonNumber,
          'episode_number': ep.episodeNumber,
          'played': targetPlayed,
        },
      );
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(
        episodes: {...state.episodes, ep.seasonNumber: prevSeason},
      );
      return e.friendlyMessage;
    } catch (e) {
      state = state.copyWith(
        episodes: {...state.episodes, ep.seasonNumber: prevSeason},
      );
      return '操作失败：$e';
    }
  }

  /// 详情条目的在位文件 id（电影取 files；剧集取首个可播集），无则 null。
  int? get leadFileId {
    final state = this.state;
    final entry = state.entry;
    if (entry == null) return null;
    if (!entry.isTv && entry.fileIds.isNotEmpty) return entry.fileIds.first;
    for (final list in state.episodes.values) {
      for (final e in list) {
        if (e.playFileId != null) return e.playFileId;
      }
    }
    return null;
  }

  /// AI 字幕生成预检（GET /libraries/files/{fileId}/subtitles/generation-preview）。
  Future<Map<String, dynamic>?> previewSubtitleGen({
    int? fileId,
    String targetLanguage = 'zh-CN',
    String? secondaryLanguage,
  }) async {
    final id = fileId ?? leadFileId;
    if (id == null) return null;
    try {
      return await _api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/libraries/files/$id/subtitles/generation-preview',
        query: {
          'target_language': targetLanguage,
          if (secondaryLanguage != null && secondaryLanguage.isNotEmpty)
            'secondary_language': secondaryLanguage,
        },
      );
    } catch (_) {
      return null;
    }
  }

  /// AI 字幕生成提交（POST /libraries/files/{fileId}/subtitles/generations）。
  Future<String> startSubtitleGen({
    int? fileId,
    String targetLanguage = 'zh-CN',
    String? secondaryLanguage,
    bool retranscribe = false,
  }) async {
    final id = fileId ?? leadFileId;
    if (id == null) return '没有在位文件，无法生成字幕';
    try {
      final preview = await previewSubtitleGen(
        fileId: id,
        targetLanguage: targetLanguage,
        secondaryLanguage: secondaryLanguage,
      );
      if (preview != null) {
        final blocker = preview['blocker'];
        if (blocker is Map) {
          final b = blocker.cast<String, dynamic>();
          final title = b['title']?.toString();
          final message = b['message']?.toString();
          return '无法生成字幕：${title ?? ''}${message != null && message.isNotEmpty ? ' $message' : ''}';
        }
        final pending = preview['pending'];
        if (pending is Map &&
            (pending['message']?.toString().isNotEmpty ?? false)) {
          return pending['message'].toString();
        }
      }
      await _api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/libraries/files/$id/subtitles/generations',
        body: {
          'target_language': targetLanguage,
          if (secondaryLanguage != null && secondaryLanguage.isNotEmpty)
            'secondary_language': secondaryLanguage,
          'retranscribe': retranscribe,
        },
      );
      return '已提交 AI 字幕生成任务，可在活动与任务中查看实时进度';
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '字幕生成失败：$e';
    }
  }

  /// 读取当前条目的活跃分享状态（GET /libraries/{libraryId}/items/{itemId}/share）。
  Future<Map<String, dynamic>?> getShareInfo() async {
    try {
      return await _api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/libraries/$_libraryId/items/$_itemId/share',
      );
    } catch (_) {
      return null;
    }
  }

  /// 创建/更新可配置分享链接（支持有效期天数与访问密码）。
  Future<String?> createShareLink({
    int expiresInDays = 7,
    String? password,
    StringBuffer? err,
  }) async {
    try {
      final body = await _api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/libraries/$_libraryId/items/$_itemId/share',
        body: {
          'expires_in_days': expiresInDays,
          if (password != null && password.trim().isNotEmpty)
            'password': password.trim(),
        },
      );
      var url = body['url']?.toString() ?? '';
      if (url.isEmpty) {
        final slug = body['slug']?.toString() ?? '';
        if (slug.isEmpty) return null;
        url = '/s/$slug';
      }
      final base = _api.baseUrl;
      if (url.startsWith('/') && base.isNotEmpty) url = base + url;
      return url;
    } on ApiException catch (e) {
      err?.write(e.friendlyMessage);
      return null;
    } catch (e) {
      err?.write(e.toString());
      return null;
    }
  }

  /// 吊销当前条目的分享外链。
  Future<String?> revokeShare() async {
    try {
      await _api.unwrap<dynamic>(
        Channel.general,
        'DELETE',
        '/api/v1/libraries/$_libraryId/items/$_itemId/share',
      );
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '吊销失败：$e';
    }
  }

  /// 读取候选海报/剧照/Logo（GET /libraries/{libraryId}/items/{itemId}/artwork/candidates）。
  Future<Map<String, dynamic>> fetchArtworkCandidates() async {
    final raw = await _api.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/libraries/$_libraryId/items/$_itemId/artwork/candidates',
    );
    return raw;
  }

  /// 更换海报/剧照/Logo（POST .../artwork/select）。
  Future<String?> selectArtwork({
    required String kind,
    String? filePath,
  }) async {
    try {
      await _api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/libraries/$_libraryId/items/$_itemId/artwork/select',
        body: {'kind': kind, 'file_path': filePath},
      );
      await load();
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '更换图片失败：$e';
    }
  }

  /// 搜索手动重新识别的候选词条（POST /search/titles）。
  Future<List<Map<String, dynamic>>> searchReidentifyCandidates(
    String query,
  ) async {
    final kind = (state.entry?.isTv ?? false) ? 'tv' : 'movie';
    final raw = await _api.unwrap<dynamic>(
      Channel.general,
      'POST',
      '/api/v1/search/titles',
      body: {'query': query, 'provider': 'tmdb', 'media_type': kind},
    );
    final list = raw is List
        ? raw
        : (raw is Map
            ? (raw['titles'] ?? raw['items'] ?? const []) as List<dynamic>
            : const <dynamic>[]);
    return list.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  /// 执行重新识别（POST .../reidentifications）。
  Future<String?> applyReidentify(String titleRef) async {
    try {
      await _api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/libraries/$_libraryId/items/$_itemId/reidentifications',
        body: {'title_ref': titleRef},
      );
      await load();
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '重新识别失败：$e';
    }
  }

  /// 读取可编辑的用户合集列表。
  Future<List<Map<String, dynamic>>> listEditableCollections() async {
    final raw = await _api.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/collections',
      query: {'include_empty': true},
    );
    return raw
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .where((c) => c['editable'] != false && c['rule_driven'] != true)
        .toList();
  }

  /// 将当前条目加入已有合集（POST /collections/{id}/items）。
  Future<String?> addToCollection(int collectionId) async {
    try {
      await _api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/collections/$collectionId/items',
        body: {'media_item_ids': [_itemId]},
      );
      await load();
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '加入合集失败：$e';
    }
  }

  /// 新建合集并立即收入当前条目。
  Future<String?> createCollectionWithItem(String name) async {
    try {
      await _api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/collections',
        body: {
          'name': name,
          'library_id': _libraryId,
          'item_ids': [_itemId],
        },
      );
      await load();
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '创建合集失败：$e';
    }
  }
}


/// 详情页控制器 family：key = libraryId:itemId。
final detailControllerProvider =
    NotifierProvider.family<DetailController, DetailState, String>(
  DetailController.new,
);
