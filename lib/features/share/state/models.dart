/// 访客分享域模型（1:1 对齐 iOS `SharedItemView` / `SharedFileView` / `SharedCollectionView` / `LocalMetaView`）。

library;

class SharePublic {
  const SharePublic({
    this.requiresPassword = false,
    this.unlocked = false,
    this.expiresAt,
    this.mediaItemId,
    this.collectionId,
  });

  final bool requiresPassword;
  final bool unlocked;
  final String? expiresAt;
  final int? mediaItemId;
  final int? collectionId;

  factory SharePublic.fromJson(Map<String, dynamic> j) => SharePublic(
        requiresPassword:
            j['requiresPassword'] == true || j['requires_password'] == true,
        unlocked: j['unlocked'] == true,
        expiresAt: _s(j, ['expiresAt', 'expires_at']),
        mediaItemId: _i(j, ['mediaItemId', 'media_item_id']),
        collectionId: _i(j, ['collectionId', 'collection_id']),
      );
}

class SharedAudioStream {
  const SharedAudioStream({
    this.codec,
    this.profile,
    this.channels,
    this.channelLayout,
    this.language,
    this.title,
    this.isDefault = false,
  });

  final String? codec;
  final String? profile;
  final int? channels;
  final String? channelLayout;
  final String? language;
  final String? title;
  final bool isDefault;

  String get displayCodec => (profile ?? codec ?? '').toUpperCase();

  String get displayChannels {
    if (channelLayout != null && channelLayout!.isNotEmpty) {
      return channelLayout!;
    }
    if (channels == null || channels! <= 0) return '';
    return switch (channels!) {
      1 => '1.0',
      2 => '2.0',
      6 => '5.1',
      8 => '7.1',
      _ => '${channels}ch',
    };
  }

  factory SharedAudioStream.fromJson(Map<String, dynamic> j) =>
      SharedAudioStream(
        codec: _s(j, ['codec']),
        profile: _s(j, ['profile']),
        channels: _i(j, ['channels']),
        channelLayout: _s(j, ['channel_layout', 'channelLayout']),
        language: _s(j, ['language']),
        title: _s(j, ['title']),
        isDefault: j['default'] == true || j['is_default'] == true,
      );
}

class SharedSubtitleStream {
  const SharedSubtitleStream({
    this.codec,
    this.language,
    this.title,
    this.forced = false,
    this.isDefault = false,
    this.external = false,
    this.fileName,
  });

  final String? codec;
  final String? language;
  final String? title;
  final bool forced;
  final bool isDefault;
  final bool external;
  final String? fileName;

  factory SharedSubtitleStream.fromJson(Map<String, dynamic> j) =>
      SharedSubtitleStream(
        codec: _s(j, ['codec']),
        language: _s(j, ['language']),
        title: _s(j, ['title']),
        forced: j['forced'] == true,
        isDefault: j['default'] == true || j['is_default'] == true,
        external: j['external'] == true,
        fileName: _s(j, ['file_name', 'fileName']),
      );
}

class SharedChapter {
  const SharedChapter({
    required this.index,
    required this.startMs,
    this.endMs,
    this.frameMs,
    this.title,
    this.synthetic = false,
    this.imageUrl,
  });

  final int index;
  final int startMs;
  final int? endMs;
  final int? frameMs;
  final String? title;
  final bool synthetic;
  final String? imageUrl;

  int get seekMs => frameMs ?? startMs;

  factory SharedChapter.fromJson(Map<String, dynamic> j) => SharedChapter(
        index: _i(j, ['index']) ?? 0,
        startMs: _i(j, ['start_ms', 'startMs']) ?? 0,
        endMs: _i(j, ['end_ms', 'endMs']),
        frameMs: _i(j, ['frame_ms', 'frameMs']),
        title: _s(j, ['title']),
        synthetic: j['synthetic'] == true,
        imageUrl: _s(j, ['image_url', 'imageUrl']),
      );
}

class SharedFile {
  const SharedFile({
    required this.id,
    this.sizeBytes = 0,
    this.container,
    this.resolution,
    this.videoCodec,
    this.hdr,
    this.bitDepth,
    this.durationSeconds,
    this.mediaSource,
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.missing = false,
    this.state = 'in_place',
    this.audioStreams = const [],
    this.subtitleStreams = const [],
    this.chapters = const [],
  });

  final int id;
  final int sizeBytes;
  final String? container;
  final String? resolution;
  final String? videoCodec;
  final String? hdr;
  final int? bitDepth;
  final int? durationSeconds;
  final String? mediaSource;
  final int seasonNumber;
  final int episodeNumber;
  final bool missing;
  final String state;
  final List<SharedAudioStream> audioStreams;
  final List<SharedSubtitleStream> subtitleStreams;
  final List<SharedChapter> chapters;

  bool get isPlayable => !missing && state == 'in_place';

  factory SharedFile.fromJson(Map<String, dynamic> j) => SharedFile(
        id: _i(j, ['id']) ?? 0,
        sizeBytes: _i(j, ['sizeBytes', 'size_bytes']) ?? 0,
        container: _s(j, ['container']),
        resolution: _s(j, ['resolution']),
        videoCodec: _s(j, ['videoCodec', 'video_codec']),
        hdr: _s(j, ['hdr']),
        bitDepth: _i(j, ['bit_depth', 'bitDepth']),
        durationSeconds: _i(j, ['duration_seconds', 'durationSeconds']),
        mediaSource: _s(j, ['media_source', 'mediaSource']),
        seasonNumber: _i(j, ['season_number', 'seasonNumber']) ?? 0,
        episodeNumber: _i(j, ['episode_number', 'episodeNumber']) ?? 0,
        missing: j['missing'] == true,
        state: _s(j, ['state']) ?? 'in_place',
        audioStreams: (((j['audio_streams'] ?? j['audioStreams']) as List?) ??
                const [])
            .whereType<Map>()
            .map((e) => SharedAudioStream.fromJson(e.cast<String, dynamic>()))
            .toList(),
        subtitleStreams:
            (((j['subtitle_streams'] ?? j['subtitleStreams']) as List?) ??
                    const [])
                .whereType<Map>()
                .map(
                  (e) =>
                      SharedSubtitleStream.fromJson(e.cast<String, dynamic>()),
                )
                .toList(),
        chapters: ((j['chapters'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SharedChapter.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

class SharedPerson {
  const SharedPerson({
    required this.name,
    this.role,
    this.thumbUrl,
    this.isDirector = false,
  });

  final String name;
  final String? role;
  final String? thumbUrl;
  final bool isDirector;

  String? get subtitle {
    if (isDirector) return '导演';
    if (role != null && role!.isNotEmpty) return '饰 $role';
    return null;
  }

  factory SharedPerson.fromJson(
    Map<String, dynamic> j, {
    bool isDirector = false,
  }) =>
      SharedPerson(
        name: _s(j, ['name']) ?? '',
        role: _s(j, ['role', 'character']),
        thumbUrl: _s(j, ['thumb_url', 'thumbUrl', 'avatar_url']),
        isDirector: isDirector,
      );
}

class LocalMetaView {
  const LocalMetaView({
    this.plot,
    this.rating,
    this.runtimeMinutes,
    this.genres = const [],
    this.directors = const [],
    this.directorCredits = const [],
    this.actors = const [],
  });

  final String? plot;
  final double? rating;
  final int? runtimeMinutes;
  final List<String> genres;
  final List<String> directors;
  final List<SharedPerson> directorCredits;
  final List<SharedPerson> actors;

  /// 完整演职员列表（导演在前、演员在后，只读不跳站内影人页）。
  List<SharedPerson> get cast {
    final out = <SharedPerson>[];
    if (directorCredits.isNotEmpty) {
      out.addAll(directorCredits);
    } else {
      final seen = <String>{};
      for (final d in directors) {
        if (d.isNotEmpty && seen.add(d)) {
          out.add(SharedPerson(name: d, isDirector: true));
        }
      }
    }
    out.addAll(actors);
    return out;
  }

  factory LocalMetaView.fromJson(Map<String, dynamic> j) => LocalMetaView(
        plot: _s(j, ['plot']),
        rating: (j['rating'] as num?)?.toDouble(),
        runtimeMinutes: _i(j, ['runtimeMinutes', 'runtime_minutes']),
        genres: ((j['genres'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList(),
        directors: ((j['directors'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList(),
        directorCredits:
            (((j['director_credits'] ?? j['directorCredits']) as List?) ??
                    const [])
                .whereType<Map>()
                .map(
                  (e) => SharedPerson.fromJson(
                    e.cast<String, dynamic>(),
                    isDirector: true,
                  ),
                )
                .where((p) => p.name.isNotEmpty)
                .toList(),
        actors: ((j['actors'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SharedPerson.fromJson(e.cast<String, dynamic>()))
            .where((p) => p.name.isNotEmpty)
            .toList(),
      );
}

/// 访客能看到的条目（只有可分享的信息，没有库内路径与管理字段）。
class SharedItem {
  const SharedItem({
    required this.mediaItemId,
    this.kind = 'movie',
    this.tmdbId,
    this.imdbId,
    this.doubanId,
    this.title = '',
    this.originalTitle,
    this.year,
    this.posterUrl,
    this.backdropUrl,
    this.primaryAspect = 2 / 3,
    this.localMeta,
    this.files = const [],
    this.seasons = const [],
    this.expiresAt,
  });

  final int mediaItemId;

  /// movie / tv
  final String kind;
  final int? tmdbId;
  final String? imdbId;
  final String? doubanId;
  final String title;
  final String? originalTitle;
  final int? year;
  final String? posterUrl;
  final String? backdropUrl;
  final double primaryAspect;
  final LocalMetaView? localMeta;
  final List<SharedFile> files;
  final List<int> seasons;
  final String? expiresAt;

  bool get isMovie => kind != 'tv';

  factory SharedItem.fromJson(Map<String, dynamic> j) => SharedItem(
        mediaItemId: _i(j, ['mediaItemId', 'media_item_id']) ?? 0,
        kind: _s(j, ['kind']) ?? 'movie',
        tmdbId: _i(j, ['tmdbId', 'tmdb_id']),
        imdbId: _s(j, ['imdbId', 'imdb_id']),
        doubanId: _s(j, ['doubanId', 'douban_id']),
        title: _s(j, ['title']) ?? '',
        originalTitle: _s(j, ['originalTitle', 'original_title']),
        year: _i(j, ['year']),
        posterUrl: _s(j, ['posterUrl', 'poster_url']),
        backdropUrl: _s(j, ['backdropUrl', 'backdrop_url']),
        primaryAspect:
            ((j['primaryAspect'] ?? j['primary_aspect']) as num?)?.toDouble() ??
                (2.0 / 3.0),
        localMeta: (j['localMeta'] is Map || j['local_meta'] is Map)
            ? LocalMetaView.fromJson(
                ((j['localMeta'] ?? j['local_meta']) as Map)
                    .cast<String, dynamic>(),
              )
            : null,
        files: ((j['files'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SharedFile.fromJson(e.cast<String, dynamic>()))
            .toList(),
        seasons: ((j['seasons'] as List?) ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList(),
        expiresAt: _s(j, ['expiresAt', 'expires_at']),
      );
}

class SharedCollectionItem {
  const SharedCollectionItem({
    required this.mediaItemId,
    this.title = '',
    this.year,
    this.kind = 'movie',
    this.posterUrl,
  });

  final int mediaItemId;
  final String title;
  final int? year;
  final String kind;
  final String? posterUrl;

  factory SharedCollectionItem.fromJson(Map<String, dynamic> j) =>
      SharedCollectionItem(
        mediaItemId: _i(j, ['mediaItemId', 'media_item_id']) ?? 0,
        title: _s(j, ['title']) ?? '',
        year: _i(j, ['year']),
        kind: _s(j, ['kind']) ?? 'movie',
        posterUrl: _s(j, ['posterUrl', 'poster_url']),
      );
}

class SharedCollection {
  const SharedCollection({
    this.name = '',
    this.description,
    this.itemCount,
    this.items = const [],
    this.expiresAt,
  });

  final String name;
  final String? description;
  final int? itemCount;
  final List<SharedCollectionItem> items;
  final String? expiresAt;

  int get totalCount => itemCount ?? items.length;

  factory SharedCollection.fromJson(Map<String, dynamic> j) {
    final parsedItems = ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => SharedCollectionItem.fromJson(e.cast<String, dynamic>()))
        .toList();
    return SharedCollection(
      name: _s(j, ['name']) ?? '',
      description: _s(j, ['description']),
      itemCount: _i(j, ['item_count', 'itemCount']) ?? parsedItems.length,
      items: parsedItems,
      expiresAt: _s(j, ['expiresAt', 'expires_at']),
    );
  }
}

class ShareEpisodeView {
  const ShareEpisodeView({
    required this.episodeNumber,
    this.seasonNumber = 0,
    this.name,
    this.overview,
    this.stillUrl,
    this.runtimeMinutes,
    this.owned = true,
    this.played = false,
    this.fileIds = const [],
  });

  final int episodeNumber;
  final int seasonNumber;
  final String? name;
  final String? overview;
  final String? stillUrl;
  final int? runtimeMinutes;
  final bool owned;
  final bool played;
  final List<int> fileIds;

  factory ShareEpisodeView.fromJson(Map<String, dynamic> j) => ShareEpisodeView(
        episodeNumber: _i(j, ['episodeNumber', 'episode_number']) ?? 0,
        seasonNumber: _i(j, ['seasonNumber', 'season_number']) ?? 0,
        name: _s(j, ['name']),
        overview: _s(j, ['overview']),
        stillUrl: _s(j, ['still_url', 'stillUrl']),
        runtimeMinutes: _i(j, ['runtime_minutes', 'runtimeMinutes']),
        owned: j['owned'] != false,
        played: j['played'] == true,
        fileIds: (((j['file_ids'] ?? j['fileIds']) as List?) ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList(),
      );
}

class SeasonEpisodesView {
  const SeasonEpisodesView({
    this.seasonNumber = 0,
    this.episodes = const [],
  });

  final int seasonNumber;
  final List<ShareEpisodeView> episodes;

  factory SeasonEpisodesView.fromJson(Map<String, dynamic> j) =>
      SeasonEpisodesView(
        seasonNumber: _i(j, ['season_number', 'seasonNumber']) ?? 0,
        episodes: ((j['episodes'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ShareEpisodeView.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

String? _s(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    final v = j[k];
    if (v != null && v.toString().isNotEmpty) return v.toString();
  }
  return null;
}

int? _i(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    final v = j[k];
    if (v is num) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null) return parsed;
    }
  }
  return null;
}
