/// 访客分享域模型（对齐原 core/model/Share.kt 的访客侧段）。

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
        requiresPassword: j['requiresPassword'] == true,
        unlocked: j['unlocked'] == true,
        expiresAt: _s(j, ['expiresAt', 'expires_at']),
        mediaItemId: _i(j, ['mediaItemId', 'media_item_id']),
        collectionId: _i(j, ['collectionId', 'collection_id']),
      );
}

class SharedFile {
  const SharedFile({
    required this.id,
    this.sizeBytes = 0,
    this.container,
    this.resolution,
    this.videoCodec,
  });

  final int id;
  final int sizeBytes;
  final String? container;
  final String? resolution;
  final String? videoCodec;

  factory SharedFile.fromJson(Map<String, dynamic> j) => SharedFile(
        id: _i(j, ['id']) ?? 0,
        sizeBytes: _i(j, ['sizeBytes', 'size_bytes']) ?? 0,
        container: _s(j, ['container']),
        resolution: _s(j, ['resolution']),
        videoCodec: _s(j, ['videoCodec', 'video_codec']),
      );
}

class LocalMetaView {
  const LocalMetaView({this.plot, this.runtimeMinutes});

  final String? plot;
  final int? runtimeMinutes;

  factory LocalMetaView.fromJson(Map<String, dynamic> j) => LocalMetaView(
        plot: _s(j, ['plot']),
        runtimeMinutes: _i(j, ['runtimeMinutes', 'runtime_minutes']),
      );
}

/// 访客能看到的条目（只有可分享的信息，没有库内路径）。
class SharedItem {
  const SharedItem({
    required this.mediaItemId,
    this.kind = 'movie',
    this.title = '',
    this.year,
    this.posterUrl,
    this.backdropUrl,
    this.localMeta,
    this.files = const [],
    this.seasons = const [],
    this.expiresAt,
  });

  final int mediaItemId;
  /// movie / tv
  final String kind;
  final String title;
  final int? year;
  final String? posterUrl;
  final String? backdropUrl;
  final LocalMetaView? localMeta;
  final List<SharedFile> files;
  final List<int> seasons;
  final String? expiresAt;

  factory SharedItem.fromJson(Map<String, dynamic> j) => SharedItem(
        mediaItemId: _i(j, ['mediaItemId', 'media_item_id']) ?? 0,
        kind: _s(j, ['kind']) ?? 'movie',
        title: _s(j, ['title']) ?? '',
        year: _i(j, ['year']),
        posterUrl: _s(j, ['posterUrl', 'poster_url']),
        backdropUrl: _s(j, ['backdropUrl', 'backdrop_url']),
        localMeta: (j['localMeta'] is Map || j['local_meta'] is Map)
            ? LocalMetaView.fromJson(
                ((j['localMeta'] ?? j['local_meta']) as Map).cast<String, dynamic>())
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

  factory SharedCollectionItem.fromJson(Map<String, dynamic> j) => SharedCollectionItem(
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
    this.items = const [],
    this.expiresAt,
  });

  final String name;
  final String? description;
  final List<SharedCollectionItem> items;
  final String? expiresAt;

  factory SharedCollection.fromJson(Map<String, dynamic> j) => SharedCollection(
        name: _s(j, ['name']) ?? '',
        description: _s(j, ['description']),
        items: ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SharedCollectionItem.fromJson(e.cast<String, dynamic>()))
            .toList(),
        expiresAt: _s(j, ['expiresAt', 'expires_at']),
      );
}

class ShareEpisodeView {
  const ShareEpisodeView({
    required this.episodeNumber,
    this.name,
    this.overview,
    this.owned = true,
    this.played = false,
  });

  final int episodeNumber;
  final String? name;
  final String? overview;
  final bool owned;
  final bool played;

  factory ShareEpisodeView.fromJson(Map<String, dynamic> j) => ShareEpisodeView(
        episodeNumber: _i(j, ['episodeNumber', 'episode_number']) ?? 0,
        name: _s(j, ['name']),
        overview: _s(j, ['overview']),
        owned: j['owned'] != false,
        played: j['played'] == true,
      );
}

class SeasonEpisodesView {
  const SeasonEpisodesView({this.episodes = const []});
  final List<ShareEpisodeView> episodes;

  factory SeasonEpisodesView.fromJson(Map<String, dynamic> j) => SeasonEpisodesView(
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
