import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mc_client.dart';
import 'session_providers.dart';

/// 选集数据接口（对齐 Android McApi.kt 季/集端点，Generated Models EpisodeView）：
/// - 详情页分集列表：GET /api/v1/libraries/{libraryId}/items/{itemId}/episodes?season_number=
/// - 播放页切集：GET /api/v1/playback/items/{itemId}/episodes?season_number=
/// 分集字段含拥有状态（owned / file_ids，缺集置灰）与观看状态（played / progress），
/// 点集起播只用 mediaItemId + fileId（file_ids 首个），季/集号不再手传。
class EpisodesApi {
  EpisodesApi(this._client);

  final McClient _client;

  factory EpisodesApi.of(Ref ref) => EpisodesApi(ref.read(mcClientProvider));

  /// 详情侧：某季的分集清单（集名/简介/剧照 + 拥有状态）。
  Future<SeasonEpisodes> libraryItemEpisodes(
    int libraryId,
    int itemId,
    int seasonNumber,
  ) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/libraries/$libraryId/items/$itemId/episodes',
      query: {'season_number': seasonNumber},
    );
    return SeasonEpisodes.fromJson(body);
  }

  /// 播放侧：某季的分集清单（切集/上一集下一集数据源）。
  Future<SeasonEpisodes> playbackItemEpisodes(
    int itemId,
    int seasonNumber,
  ) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.playback,
      'GET',
      '/api/v1/playback/items/$itemId/episodes',
      query: {'season_number': seasonNumber},
    );
    return SeasonEpisodes.fromJson(body);
  }
}

/// 一季的分集清单（对齐 SeasonEpisodesView）。
class SeasonEpisodes {
  const SeasonEpisodes({
    required this.seasonNumber,
    this.episodes = const [],
    this.resumeEpisode,
  });

  final int seasonNumber;

  /// 服务端续播锚点（resume_episode）：无观看记录时的默认起播集。
  final int? resumeEpisode;

  final List<EpisodeRef> episodes;

  factory SeasonEpisodes.fromJson(Map<String, dynamic> j) => SeasonEpisodes(
        seasonNumber: _int(j, const ['season_number', 'season']) ?? 0,
        resumeEpisode: _int(j, const ['resume_episode']),
        episodes: (j['episodes'] as List?)
                ?.whereType<Map>()
                .map((e) => EpisodeRef.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  static int? _int(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static String? _string(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }
}

/// 单集（对齐 EpisodeView）：owned=false 缺集置灰；fileIds 首个即起播 fileId。
class EpisodeRef {
  const EpisodeRef({
    required this.episodeNumber,
    this.name,
    this.overview,
    this.airDate,
    this.stillUrl,
    this.owned = false,
    this.fileIds = const [],
    this.positionMs = 0,
    this.played = false,
    this.progressPercent,
  });

  final int episodeNumber;
  final String? name;
  final String? overview;

  /// 首播日期（yyyy-MM-dd）。
  final String? airDate;
  final String? stillUrl;

  /// false = 缺集或文件缺失（前端置灰）。
  final bool owned;

  /// 该集的台账文件 id；起播取首个。
  final List<int> fileIds;

  /// 当前观看者上次看到的位置（毫秒）。
  final int positionMs;
  final bool played;

  /// 观看进度 1~99；已看完由 played 表达。
  final int? progressPercent;

  /// 起播用 fileId（首个台账文件），无在位文件时 null。
  int? get playFileId => fileIds.isEmpty ? null : fileIds.first;

  factory EpisodeRef.fromJson(Map<String, dynamic> j) => EpisodeRef(
        episodeNumber:
            SeasonEpisodes._int(j, const ['episode_number', 'number', 'index_number']) ?? 0,
        name: SeasonEpisodes._string(j, const ['name', 'title']),
        overview: SeasonEpisodes._string(j, const ['overview', 'plot']),
        airDate: SeasonEpisodes._string(j, const ['air_date', 'premiered']),
        stillUrl: SeasonEpisodes._string(j, const ['still_url', 'still', 'thumb_url']),
        owned: j['owned'] == true,
        fileIds: (j['file_ids'] as List?)
                ?.map((e) => e is num ? e.toInt() : int.tryParse(e.toString()))
                .whereType<int>()
                .toList() ??
            const [],
        positionMs: SeasonEpisodes._int(j, const ['position_ms', 'resume_ms']) ?? 0,
        played: j['played'] == true,
        progressPercent: SeasonEpisodes._int(j, const ['progress_percent']),
      );
}
