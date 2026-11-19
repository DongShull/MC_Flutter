import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/session_providers.dart';
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
    this.posterUrl,
    this.backdropUrl,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.seriesName,
    this.seriesCollectionId,
    this.collections = const [],
    this.seasons = const [],
    this.cast = const [],
    this.resumeEpisode,
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
  final String? posterUrl;
  final String? backdropUrl;
  final List<String> audioTracks;
  final List<String> subtitleTracks;
  /// 系列名（文字链接行）
  final String? seriesName;
  final int? seriesCollectionId;
  /// 合集名列表（文字链接行）
  final List<String> collections;
  final List<SeasonInfo> seasons;
  /// 演职员（前 40 由页面截断）
  final List<CastMember> cast;
  /// 服务端续播集锚点（resume_episode）
  final int? resumeEpisode;

  bool get isTv => kind == 'tv' || seasons.isNotEmpty;

  factory DetailEntry.fromJson(Map<String, dynamic> j) {
    final media = J.map(j, 'media');
    final series = J.map(j, 'series');
    final seasons = J.listOfMap(j, ['seasons']).map(SeasonInfo.fromJson).toList();
    return DetailEntry(
      id: J.i(j, ['id', 'item_id', 'media_item_id']) ?? 0,
      libraryId: J.i(j, ['library_id']) ?? 0,
      kind: J.s(j, ['kind', 'type', 'item_kind']) ?? 'movie',
      title: J.s(j, ['title', 'name']) ?? '',
      originalTitle: J.s(j, ['original_title', 'original_name']),
      tagline: J.s(j, ['tagline']),
      overview: J.s(j, ['overview', 'plot', 'summary']),
      year: J.i(j, ['year', 'production_year']),
      runtimeMinutes: J.i(j, ['runtime_minutes', 'runtime', 'duration_minutes']),
      rating: J.d(j, ['rating', 'community_rating', 'vote_average']),
      officialRating: J.s(j, ['official_rating', 'content_rating']),
      resolution: J.s(media, ['resolution', 'resolution_label']),
      hdr: media['hdr'] == true,
      posterUrl: J.s(j, ['poster_url', 'poster']),
      backdropUrl: J.s(j, ['backdrop_url', 'backdrop']),
      audioTracks: J.list(media, ['audio_tracks', 'audio']),
      subtitleTracks: J.list(media, ['subtitle_tracks', 'subtitles']),
      seriesName: J.s(series, ['name', 'series_name']) ?? J.s(j, ['series_name']),
      seriesCollectionId: J.i(series, ['id', 'collection_id']) ?? J.i(j, ['series_collection_id']),
      collections: J.list(j, ['collection_names', 'collections']),
      seasons: seasons,
      cast: J.listOfMap(j, ['cast', 'people']).map(CastMember.fromJson).toList(),
      resumeEpisode: J.i(j, ['resume_episode']),
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
        profileUrl: J.s(j, ['profile_url', 'photo_url']),
        personId: J.i(j, ['person_id', 'id']),
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

  /// 拉某一季的分集：GET /libraries/{id}/items/{id}/episodes?season_number=
  Future<void> loadSeason(int seasonNumber) async {
    state = state.copyWith(selectedSeason: seasonNumber);
    try {
      final body = await _api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/libraries/$_libraryId/items/$_itemId/episodes',
        query: {'season_number': seasonNumber},
      );
      final list = J.listOfMap(body, ['episodes']).map(EpisodeEntry.fromJson).toList();
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

  /// 刷新元数据：POST /items/{id}/metadata/refresh（长任务状态在任务域轮询）。
  Future<String?> refreshMetadata() async {
    try {
      await _api.post(Channel.general, '/api/v1/items/$_itemId/metadata/refresh');
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '刷新失败：$e';
    }
  }
}


/// 详情页控制器 family：key = libraryId:itemId。
final detailControllerProvider =
    NotifierProvider.family<DetailController, DetailState, String>(
  DetailController.new,
);
