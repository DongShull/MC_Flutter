import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';

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

  static bool b(Map<String, dynamic> m, List<String> keys, {bool fallback = false}) {
    for (final k in keys) {
      final v = m[k];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        if (v.toLowerCase() == 'true' || v == '1') return true;
        if (v.toLowerCase() == 'false' || v == '0') return false;
      }
    }
    return fallback;
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

  static List<int> intList(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is List) {
        return v
            .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()))
            .whereType<int>()
            .toList();
      }
    }
    return const [];
  }

  static Map<String, dynamic> map(Map<String, dynamic> m, String key) =>
      (m[key] is Map) ? (m[key] as Map).cast<String, dynamic>() : const {};

  static List<Map<String, dynamic>> listOfMap(
    Map<String, dynamic> m,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = m[k];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }
    return const [];
  }
}

/// 章节（对齐 iOS `API.ChapterView`）。
class DetailChapter {
  const DetailChapter({
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

  /// 起播秒数：优先用图上那一帧真实时间 `frameMs`，无图退回 `startMs`。
  double get playSeconds => (frameMs ?? startMs) / 1000.0;

  int get effectiveMs => frameMs ?? startMs;

  factory DetailChapter.fromJson(Map<String, dynamic> j, [int fallbackIdx = 0]) =>
      DetailChapter(
        index: J.i(j, ['index']) ?? fallbackIdx,
        startMs: J.i(j, ['start_ms']) ?? 0,
        endMs: J.i(j, ['end_ms']),
        frameMs: J.i(j, ['frame_ms']),
        title: J.s(j, ['title', 'name']),
        synthetic: J.b(j, ['synthetic']),
        imageUrl: J.s(j, ['image_url', 'thumb_url']),
      );
}

/// 音轨流（对齐 iOS `API.AudioStreamView`）。
class DetailAudioStream {
  const DetailAudioStream({
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

  factory DetailAudioStream.fromJson(Map<String, dynamic> j) =>
      DetailAudioStream(
        codec: J.s(j, ['codec']),
        profile: J.s(j, ['profile']),
        channels: J.i(j, ['channels']),
        channelLayout: J.s(j, ['channel_layout']),
        language: J.s(j, ['language']),
        title: J.s(j, ['title']),
        isDefault: J.b(j, ['default', 'is_default']),
      );
}

/// 字幕流（对齐 iOS `API.SubtitleStreamView`）。
class DetailSubtitleStream {
  const DetailSubtitleStream({
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

  factory DetailSubtitleStream.fromJson(Map<String, dynamic> j) =>
      DetailSubtitleStream(
        codec: J.s(j, ['codec', 'format']),
        language: J.s(j, ['language']),
        title: J.s(j, ['title']),
        forced: J.b(j, ['forced']),
        isDefault: J.b(j, ['default', 'is_default']),
        external: J.b(j, ['external']),
        fileName: J.s(j, ['file_name', 'filename']),
      );
}

/// 服务端默认起播轨道决策（对齐 iOS `API.TrackDefaultsView`）。
class TrackDefaults {
  const TrackDefaults({
    this.audioTrack,
    this.audioReason,
    this.audioNote = '',
    this.subtitleTrack,
    this.subtitleReason,
    this.subtitleNote = '',
  });

  final String? audioTrack;
  final String? audioReason;
  final String audioNote;
  final String? subtitleTrack;
  final String? subtitleReason;
  final String subtitleNote;

  factory TrackDefaults.fromJson(Map<String, dynamic> j) => TrackDefaults(
        audioTrack: J.s(j, ['audio_track']),
        audioReason: J.s(j, ['audio_reason']),
        audioNote: J.s(j, ['audio_note']) ?? '',
        subtitleTrack: J.s(j, ['subtitle_track']),
        subtitleReason: J.s(j, ['subtitle_reason']),
        subtitleNote: J.s(j, ['subtitle_note']) ?? '',
      );
}

/// 文件入库来源快照（对齐 iOS `API.FileOriginView`）。
class DetailFileOrigin {
  const DetailFileOrigin({required this.label, this.detail});

  final String label;
  final String? detail;

  factory DetailFileOrigin.fromJson(Map<String, dynamic> j) => DetailFileOrigin(
        label: J.s(j, ['label', 'kind']) ?? '媒体库扫描',
        detail: J.s(j, ['detail']),
      );
}

/// 物理媒体文件台账（1:1 对齐 iOS `API.LibraryFileView`）。
class DetailFileInfo {
  const DetailFileInfo({
    required this.id,
    required this.filePath,
    required this.fileName,
    this.sizeBytes = 0,
    this.container,
    this.resolution,
    this.videoCodec,
    this.hdr,
    this.bitDepth,
    this.durationSeconds,
    this.bitRate,
    this.frameRate,
    this.colorSpace,
    this.mediaSource,
    this.mediaSourceManual = false,
    this.releaseGroup,
    this.source = 'scanned',
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.missing = false,
    this.state = 'in_place',
    this.purgeAfter,
    this.trashNote,
    this.origin = const DetailFileOrigin(label: '存量扫描'),
    this.keptAt,
    this.audioStreams,
    this.subtitleStreams = const [],
    this.playbackDefaults,
    this.chapters,
    this.addedAt = '',
    this.versionLabel,
  });

  final int id;
  final String filePath;
  final String fileName;
  final int sizeBytes;
  final String? container;
  final String? resolution;
  final String? videoCodec;
  final String? hdr;
  final int? bitDepth;
  final int? durationSeconds;
  final int? bitRate;
  final double? frameRate;
  final String? colorSpace;
  final String? mediaSource;
  final bool mediaSourceManual;
  final String? releaseGroup;
  final String source;
  final int seasonNumber;
  final int episodeNumber;
  final bool missing;
  /// `in_place` | `missing` | `trashed`
  final String state;
  final String? purgeAfter;
  final String? trashNote;
  final DetailFileOrigin origin;
  final String? keptAt;
  /// null 表示尚未探测
  final List<DetailAudioStream>? audioStreams;
  final List<DetailSubtitleStream> subtitleStreams;
  final TrackDefaults? playbackDefaults;
  final List<DetailChapter>? chapters;
  final String addedAt;
  final String? versionLabel;

  bool get isInPlace => state == 'in_place' && !missing;
  bool get isTrashed => state == 'trashed';

  String get displayVersionLabel {
    if (versionLabel != null && versionLabel!.isNotEmpty) return versionLabel!;
    if (resolution != null && resolution!.isNotEmpty) {
      return '${mcFormatResolution(resolution!)} — $fileName';
    }
    return fileName;
  }

  /// 规格行（物理文件区与 `OfflineLocalFileRow` 原画行共用）。
  List<({String label, String value})> specRows() {
    final picture = [
      if (resolution != null && resolution!.isNotEmpty)
        mcFormatResolution(resolution!),
      if (hdr != null && hdr!.isNotEmpty) hdr!,
    ].join(' · ');

    const codecs = {
      'hevc': 'HEVC',
      'h264': 'H.264',
      'h265': 'HEVC',
      'av1': 'AV1',
      'vc1': 'VC-1',
      'mpeg2video': 'MPEG-2',
      'vp9': 'VP9',
    };
    final codec = videoCodec == null || videoCodec!.isEmpty
        ? null
        : (codecs[videoCodec!.toLowerCase()] ?? videoCodec!.toUpperCase());

    String? fpsText;
    if (frameRate != null && frameRate! > 0) {
      final rounded = (frameRate! * 1000).round() / 1000;
      final str = rounded.toString();
      fpsText = '${str.endsWith('.0') ? str.substring(0, str.length - 2) : str} fps';
    }

    String releaseSourceText;
    if (mediaSource == null || mediaSource!.isEmpty) {
      releaseSourceText = '未识别';
    } else {
      final base = switch (mediaSource!) {
        'user-lowest' => '人工标为最低',
        'Disc' => '原盘',
        final s => s,
      };
      releaseSourceText =
          base + (mediaSourceManual && mediaSource != 'user-lowest' ? '（人工标注）' : '');
    }

    return [
      (label: '片源', value: releaseSourceText),
      (label: '画面规格', value: picture.isEmpty ? '无法探测' : picture),
      (label: '视频编码', value: codec ?? '未探测'),
      (label: '色深', value: bitDepth != null ? '$bitDepth-bit' : '未探测'),
      (label: '帧率', value: fpsText ?? '未探测'),
      (label: '色彩空间', value: colorSpace ?? '未探测'),
      (
        label: '视频码率',
        value: bitRate != null
            ? '${(bitRate! / 1000000).toStringAsFixed(1)} Mbps'
            : '未探测',
      ),
    ];
  }

  factory DetailFileInfo.fromJson(Map<String, dynamic> j) {
    final rawPath = J.s(j, ['file_path', 'rel_path', 'path']) ?? '';
    final rawName = J.s(j, ['file_name', 'filename']) ??
        (rawPath.isNotEmpty ? rawPath.split(RegExp(r'[/\\]')).last : '');

    final rawAudio = j['audio_streams'] ?? j['audio_tracks'];
    List<DetailAudioStream>? audioStreams;
    if (rawAudio is List) {
      audioStreams = rawAudio
          .whereType<Map>()
          .map((e) => DetailAudioStream.fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    final rawSubs = j['subtitle_streams'] ?? j['subtitles'];
    final subtitleStreams = rawSubs is List
        ? rawSubs
            .whereType<Map>()
            .map((e) => DetailSubtitleStream.fromJson(e.cast<String, dynamic>()))
            .toList()
        : const <DetailSubtitleStream>[];

    final rawChapters = j['chapters'];
    List<DetailChapter>? chapters;
    if (rawChapters is List) {
      chapters = [
        for (var i = 0; i < rawChapters.length; i++)
          if (rawChapters[i] is Map)
            DetailChapter.fromJson(
              (rawChapters[i] as Map).cast<String, dynamic>(),
              i,
            ),
      ];
    }

    final rawDefaults = j['playback_defaults'];
    final playbackDefaults = rawDefaults is Map
        ? TrackDefaults.fromJson(rawDefaults.cast<String, dynamic>())
        : null;

    final rawOrigin = j['origin'];
    final origin = rawOrigin is Map
        ? DetailFileOrigin.fromJson(rawOrigin.cast<String, dynamic>())
        : DetailFileOrigin(
            label: J.s(j, ['source']) == 'imported' ? '入库管线' : '存量扫描',
          );

    final rawState = J.s(j, ['state', 'status']) ??
        (J.b(j, ['trashed'])
            ? 'trashed'
            : (J.b(j, ['missing']) ? 'missing' : 'in_place'));

    return DetailFileInfo(
      id: J.i(j, ['id', 'file_id']) ?? 0,
      filePath: rawPath,
      fileName: rawName,
      sizeBytes: J.i(j, ['size_bytes', 'size']) ?? 0,
      container: J.s(j, ['container']),
      resolution: J.s(j, ['resolution']),
      videoCodec: J.s(j, ['video_codec']),
      hdr: J.s(j, ['hdr']),
      bitDepth: J.i(j, ['bit_depth']),
      durationSeconds: J.i(j, ['duration_seconds']),
      bitRate: J.i(j, ['bit_rate']),
      frameRate: J.d(j, ['frame_rate']),
      colorSpace: J.s(j, ['color_space']),
      mediaSource: J.s(j, ['media_source']),
      mediaSourceManual: J.b(j, ['media_source_manual']),
      releaseGroup: J.s(j, ['release_group']),
      source: J.s(j, ['source']) ?? 'scanned',
      seasonNumber: J.i(j, ['season_number']) ?? 0,
      episodeNumber: J.i(j, ['episode_number']) ?? 0,
      missing: J.b(j, ['missing']),
      state: rawState,
      purgeAfter: J.s(j, ['purge_after', 'trash_expires_at']),
      trashNote: J.s(j, ['trash_note']),
      origin: origin,
      keptAt: J.s(j, ['kept_at']),
      audioStreams: audioStreams,
      subtitleStreams: subtitleStreams,
      playbackDefaults: playbackDefaults,
      chapters: chapters,
      addedAt: J.s(j, ['added_at']) ?? '',
      versionLabel: J.s(j, ['version_label']),
    );
  }
}

/// 分辨率文案（同 Web/iOS `formatVideoResolution`）。
String mcFormatResolution(String raw) {
  final normalized = raw.trim().toLowerCase();
  final key = RegExp(r'^\d+$').hasMatch(normalized) ? '${normalized}p' : normalized;
  const labels = {
    '4320p': '8K',
    '2160p': '4K',
    '1440p': '2K',
    '1080p': '1080p',
    '720p': '720p',
    '4k': '4K',
    '2k': '2K',
  };
  return labels[key] ?? raw;
}

/// 所在库元信息（用于判断章节图开关、转移来源匹配、是否刮削库）。
class DetailLibraryMeta {
  const DetailLibraryMeta({
    required this.id,
    required this.name,
    required this.kind,
    this.source = 'local',
    this.extractChapterImages = false,
    this.scraped = true,
    this.primaryRoot,
    this.isDefault = false,
  });

  final int id;
  final String name;
  final String kind;
  final String source;
  final bool extractChapterImages;
  final bool scraped;
  final String? primaryRoot;
  final bool isDefault;

  factory DetailLibraryMeta.fromJson(Map<String, dynamic> j) {
    final caps = J.map(j, 'capabilities');
    return DetailLibraryMeta(
      id: J.i(j, ['id', 'library_id']) ?? 0,
      name: J.s(j, ['name']) ?? '',
      kind: J.s(j, ['kind']) ?? 'movie',
      source: J.s(j, ['source']) ?? 'local',
      extractChapterImages: J.b(j, ['extract_chapter_images']),
      scraped: caps.isNotEmpty
          ? J.b(caps, ['scraped'], fallback: true)
          : (J.s(j, ['kind']) != 'video' && J.s(j, ['kind']) != 'photo'),
      primaryRoot: J.s(j, ['primary_root', 'root_dir']),
      isDefault: J.b(j, ['is_default']),
    );
  }
}

/// 详情页条目模型（1:1 对齐 iOS `API.LibraryItemDetailView`）。
class DetailEntry {
  const DetailEntry({
    required this.id,
    required this.libraryId,
    required this.kind,
    this.source = 'tmdb',
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
    this.logoUrl,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.seriesName,
    this.seriesCollectionId,
    this.collections = const [],
    this.collectionIds = const {},
    this.seasons = const [],
    this.cast = const [],
    this.resumeSeason,
    this.resumeEpisode,
    this.resumePositionMs,
    this.tmdbId,
    this.imdbId,
    this.doubanId,
    this.fileIds = const [],
    this.files = const [],
    this.entryDirs = const [],
    this.fileCount = 0,
    this.totalSizeBytes = 0,
    this.scraping = false,
    this.scrapingPhase,
    this.chaptersPending = false,
    this.topLevelChapters = const [],
    this.duplicateCount,
  });

  final int id;
  final int libraryId;
  /// movie / tv / video / photo
  final String kind;
  /// tmdb / local
  final String source;
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
  final String? logoUrl;
  final List<String> audioTracks;
  final List<String> subtitleTracks;
  final String? seriesName;
  final int? seriesCollectionId;
  final List<String> collections;
  final Map<String, int> collectionIds;
  final List<SeasonInfo> seasons;
  final List<CastMember> cast;
  final int? tmdbId;
  final String? imdbId;
  final String? doubanId;
  final List<int> fileIds;
  final List<DetailFileInfo> files;
  final List<String> entryDirs;
  final int fileCount;
  final int totalSizeBytes;
  final bool scraping;
  final String? scrapingPhase;
  final bool chaptersPending;
  final List<DetailChapter> topLevelChapters;
  final int? resumeSeason;
  final int? resumeEpisode;
  final int? resumePositionMs;
  final int? duplicateCount;

  bool get isTv => kind == 'tv' || seasons.isNotEmpty;
  bool get isMovie => kind != 'tv' && !isTv;
  bool get isScraped => source == 'tmdb';

  /// 计算同单元多文件重复数（对齐 iOS `LibraryItemDetailView.fileSection`）。
  int get duplicateUnitsCount {
    if (duplicateCount != null && duplicateCount! > 0) return duplicateCount!;
    final inPlace = files.where((f) => f.state == 'in_place').toList();
    final grouped = <String, int>{};
    for (final f in inPlace) {
      final k = '${f.seasonNumber}:${f.episodeNumber}';
      grouped[k] = (grouped[k] ?? 0) + 1;
    }
    return grouped.values.where((c) => c > 1).length;
  }

  bool get hasDuplicates => duplicateUnitsCount > 0;

  factory DetailEntry.fromJson(Map<String, dynamic> j) {
    final media = J.map(j, 'media');
    final localMeta = J.map(j, 'local_meta');
    final series = J.map(j, 'series');
    final rawFiles = (j['files'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final parsedFiles = rawFiles.map(DetailFileInfo.fromJson).toList();
    final primaryFile = rawFiles.isNotEmpty ? rawFiles.first : const <String, dynamic>{};

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

    // 合并导演与演员（保留 isActor，支持 CastLink.resolve 对本地 NFO 演员跳转）
    final directorCredits = J.listOfMap(localMeta, ['director_credits']);
    final directorStrings = J.list(localMeta, ['directors']);
    final parsedCast = <CastMember>[
      if (directorCredits.isNotEmpty)
        for (final d in directorCredits)
          CastMember(
            name: J.s(d, ['name', 'person_name']) ?? '',
            role: '导演',
            profileUrl: J.s(d, ['thumb_url', 'profile_url', 'photo_url']),
            personId: J.i(d, ['tmdb_person_id', 'person_id', 'id']),
            isActor: false,
          )
      else
        for (final name in directorStrings.toSet())
          CastMember(name: name, role: '导演', isActor: false),
      ...J.listOfMap(localMeta, ['actors'])
          .map((m) => CastMember.fromJson(m, isActor: true)),
      ...J.listOfMap(j, ['cast', 'people'])
          .map((m) => CastMember.fromJson(m, isActor: true)),
    ].where((c) => c.name.isNotEmpty).toList();

    final topChapters = <DetailChapter>[];
    final rawTopCh = j['chapters'];
    if (rawTopCh is List) {
      for (var i = 0; i < rawTopCh.length; i++) {
        if (rawTopCh[i] is Map) {
          topChapters.add(
            DetailChapter.fromJson(
              (rawTopCh[i] as Map).cast<String, dynamic>(),
              i,
            ),
          );
        }
      }
    }

    final hdrStr = J.s(primaryFile, ['hdr']) ?? J.s(media, ['hdr']);
    final isHdr = media['hdr'] == true ||
        primaryFile['hdr'] == true ||
        (hdrStr != null && hdrStr.isNotEmpty && hdrStr.toLowerCase() != 'sdr');
    final fileDurMins =
        ((primaryFile['duration_seconds'] as num?)?.toInt() ?? 0) ~/ 60;

    return DetailEntry(
      id: J.i(j, ['id', 'item_id', 'media_item_id']) ?? 0,
      libraryId: J.i(j, ['library_id']) ?? 0,
      kind: J.s(j, ['kind', 'type', 'item_kind']) ?? 'movie',
      source: J.s(j, ['source']) ?? 'tmdb',
      title: J.s(j, ['title', 'name']) ?? '',
      originalTitle: J.s(j, ['original_title', 'english_title', 'original_name']),
      tagline: J.s(j, ['tagline']) ?? J.s(localMeta, ['tagline']),
      overview: J.s(j, ['overview', 'plot', 'summary']) ??
          J.s(localMeta, ['plot', 'overview', 'summary']),
      year: J.i(j, ['year', 'production_year']),
      runtimeMinutes:
          J.i(j, ['runtime_minutes', 'runtime', 'duration_minutes']) ??
              J.i(localMeta, ['runtime_minutes', 'runtime']) ??
              (fileDurMins > 0 ? fileDurMins : null),
      rating: J.d(j, ['rating', 'community_rating', 'vote_average']) ??
          J.d(localMeta, ['rating', 'vote_average']),
      officialRating: J.s(j, ['official_rating', 'content_rating']),
      resolution: J.s(media, ['resolution', 'resolution_label']) ??
          J.s(primaryFile, ['resolution']),
      hdr: isHdr,
      hdrLabel: (hdrStr != null && hdrStr.isNotEmpty && hdrStr != 'true')
          ? hdrStr
          : (isHdr ? 'HDR' : null),
      genres: <String>{
        ...J.list(j, ['genres']),
        ...J.list(localMeta, ['genres']),
      }.toList(),
      posterUrl: J.s(j, ['poster_url', 'poster']),
      backdropUrl: J.s(j, ['backdrop_url', 'backdrop']),
      logoUrl: J.s(j, ['logo_url', 'clearlogo_url', 'logo']),
      audioTracks: J.list(media, ['audio_tracks', 'audio']),
      subtitleTracks: J.list(media, ['subtitle_tracks', 'subtitles']),
      seriesName:
          J.s(series, ['name', 'series_name']) ?? J.s(j, ['series_name']),
      seriesCollectionId: J.i(series, ['id', 'collection_id']) ??
          J.i(j, ['series_collection_id']),
      collections: parsedCollections,
      collectionIds: parsedCollectionIds,
      seasons: parsedSeasons,
      cast: parsedCast,
      resumeSeason: J.i(j, ['resume_season', 'resume_season_number']),
      resumeEpisode: J.i(j, ['resume_episode', 'resume_episode_number']),
      resumePositionMs: J.i(j, ['resume_position_ms']),
      tmdbId: J.i(j, ['tmdb_id', 'tmdb']),
      imdbId: J.s(j, ['imdb_id', 'imdb']),
      doubanId: J.s(j, ['douban_id', 'douban']),
      fileIds: parsedFiles.map((e) => e.id).where((id) => id > 0).toList(),
      files: parsedFiles,
      entryDirs: J.list(j, ['entry_dirs']),
      fileCount: J.i(j, ['file_count']) ?? parsedFiles.length,
      totalSizeBytes: J.i(j, ['total_size_bytes']) ??
          parsedFiles.fold<int>(0, (sum, f) => sum + f.sizeBytes),
      scraping: J.b(j, ['scraping']),
      scrapingPhase: J.s(j, ['scraping_phase']),
      chaptersPending: J.b(j, ['chapters_pending']),
      topLevelChapters: topChapters,
      duplicateCount: J.i(j, ['duplicate_count']),
    );
  }
}

class SeasonInfo {
  const SeasonInfo({
    required this.number,
    this.name,
    this.airDate,
    this.episodeCount,
  });

  final int number;
  final String? name;
  final String? airDate;
  final int? episodeCount;

  factory SeasonInfo.fromJson(Map<String, dynamic> j) => SeasonInfo(
        number: J.i(j, ['season_number', 'number', 'index_number']) ?? 0,
        name: J.s(j, ['name', 'season_name']),
        airDate: J.s(j, ['air_date', 'premiered']),
        episodeCount: J.i(j, ['episode_count', 'episodes']),
      );
}

/// 分集模型（对齐 `API.EpisodeView`）。
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
    this.progressPercent,
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
  final int? progressPercent;
  final List<int> fileIds;
  final bool owned;

  int? get playFileId => fileIds.isEmpty ? null : fileIds.first;

  factory EpisodeEntry.fromJson(Map<String, dynamic> j, {int? seasonOverride}) =>
      EpisodeEntry(
        seasonNumber: seasonOverride ?? J.i(j, ['season_number']) ?? 0,
        episodeNumber:
            J.i(j, ['episode_number', 'number', 'index_number']) ?? 0,
        name: J.s(j, ['name', 'title']) ?? '',
        overview: J.s(j, ['overview', 'plot']),
        airDate: J.s(j, ['air_date', 'premiered']),
        runtimeMinutes: J.i(j, ['runtime_minutes', 'runtime']),
        rating: J.d(j, ['rating', 'community_rating']),
        stillUrl: J.s(j, ['still_url', 'still', 'thumb_url']),
        played: J.b(j, ['played']),
        resumeMs: J.i(j, ['position_ms', 'resume_ms']) ?? 0,
        progressPercent: J.i(j, ['progress_percent']),
        owned: j.containsKey('owned') ? J.b(j, ['owned']) : true,
        fileIds: J.intList(j, ['file_ids']),
      );
}

/// 演职员（支持 `CastLink.resolve` 区分演员与导演）。
class CastMember {
  const CastMember({
    required this.name,
    this.role,
    this.profileUrl,
    this.personId,
    this.isActor = true,
  });

  final String name;
  final String? role;
  final String? profileUrl;
  final int? personId;
  final bool isActor;

  factory CastMember.fromJson(Map<String, dynamic> j, {bool isActor = true}) =>
      CastMember(
        name: J.s(j, ['name', 'person_name']) ?? '',
        role: J.s(j, ['role', 'character']),
        profileUrl: J.s(j, ['thumb_url', 'profile_url', 'photo_url']),
        personId: J.i(j, ['tmdb_person_id', 'person_id', 'id']),
        isActor: isActor,
      );
}

/// 系列中的一部（支持未入库缺片 `mediaItemId == null`，对齐 `API.SeriesPartView`）。
class SeriesPartEntry {
  const SeriesPartEntry({
    required this.tmdbId,
    required this.title,
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

  bool get isOwned => mediaItemId != null && mediaItemId! > 0;

  int? get year {
    final rd = releaseDate;
    if (rd == null || rd.length < 4) return null;
    return int.tryParse(rd.substring(0, 4));
  }

  factory SeriesPartEntry.fromJson(Map<String, dynamic> j) => SeriesPartEntry(
        tmdbId: J.i(j, ['tmdb_id']) ?? 0,
        title: J.s(j, ['title', 'name']) ?? '',
        releaseDate: J.s(j, ['release_date']),
        posterUrl: J.s(j, ['poster_url', 'poster']),
        mediaItemId: J.i(j, ['media_item_id', 'id']),
        subscribed: J.b(j, ['subscribed']),
      );
}

/// 作品系列视图（对齐 `API.CollectionSeriesView`）。
class CollectionSeriesInfo {
  const CollectionSeriesInfo({
    this.seriesName,
    this.available = true,
    this.ownedCount = 0,
    this.total = 0,
    this.parts = const [],
  });

  final String? seriesName;
  final bool available;
  final int ownedCount;
  final int total;
  final List<SeriesPartEntry> parts;

  factory CollectionSeriesInfo.fromJson(Map<String, dynamic> j) {
    final parts = J
        .listOfMap(j, ['parts', 'items'])
        .map(SeriesPartEntry.fromJson)
        .toList();
    return CollectionSeriesInfo(
      seriesName: J.s(j, ['series_name', 'name']),
      available: j.containsKey('available') ? J.b(j, ['available']) : parts.isNotEmpty,
      ownedCount: J.i(j, ['owned_count']) ?? parts.where((p) => p.isOwned).length,
      total: J.i(j, ['total']) ?? parts.length,
      parts: parts,
    );
  }
}

/// 相似推荐 / 作品系列（含未入库缺片 `MissingPartCell`）。
class RelatedItems {
  const RelatedItems({
    this.similar = const [],
    this.seriesParts = const [],
    this.seriesName,
    this.series,
  });

  final List<DetailEntry> similar;
  final List<DetailEntry> seriesParts;
  final String? seriesName;
  final CollectionSeriesInfo? series;

  bool get isEmpty =>
      similar.isEmpty &&
      seriesParts.isEmpty &&
      (series == null || series!.parts.length <= 1);
}

/// 单集预计入库预告（对齐 `API.EpisodeArrivalView`）。
class EpisodeArrival {
  const EpisodeArrival({
    required this.episodeNumber,
    required this.stage,
    this.expectedAt,
  });

  final int episodeNumber;
  /// `waiting` | `downloading` | `organizing`
  final String stage;
  final String? expectedAt;

  factory EpisodeArrival.fromJson(Map<String, dynamic> j) => EpisodeArrival(
        episodeNumber: J.i(j, ['episode_number']) ?? 0,
        stage: J.s(j, ['stage']) ?? 'waiting',
        expectedAt: J.s(j, ['expected_at']),
      );
}

/// 季播出日历（1:1 对齐 iOS `API.SeasonAirScheduleView`）。
class SeasonAirSchedule {
  const SeasonAirSchedule({
    required this.today,
    this.region,
    this.weekdays = const [],
    this.lastAirDate,
    this.subscriptionId,
    this.missingEpisodes = const [],
    this.arrivals = const [],
  });

  /// yyyy-MM-dd（服务端站点日历的今天）
  final String today;
  final String? region;
  /// 0=周一 .. 6=周日
  final List<int> weekdays;
  final String? lastAirDate;
  final int? subscriptionId;
  final List<int> missingEpisodes;
  final List<EpisodeArrival> arrivals;

  factory SeasonAirSchedule.fromJson(Map<String, dynamic> j) => SeasonAirSchedule(
        today: J.s(j, ['today']) ?? _todayIso(),
        region: J.s(j, ['region']),
        weekdays: J.intList(j, ['weekdays']),
        lastAirDate: J.s(j, ['last_air_date']),
        subscriptionId: J.i(j, ['subscription_id']),
        missingEpisodes: J.intList(j, ['missing_episodes']),
        arrivals: J
            .listOfMap(j, ['arrivals'])
            .map(EpisodeArrival.fromJson)
            .toList(),
      );

  static String _todayIso() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

/// 兼容旧版顶层 `air_schedule` 横幅。
class AirScheduleBanner {
  const AirScheduleBanner({
    this.dayOfWeek,
    this.timeText,
    this.nextEpisodeText,
    this.nextAirDate,
  });

  final String? dayOfWeek;
  final String? timeText;
  final String? nextEpisodeText;
  final String? nextAirDate;

  factory AirScheduleBanner.fromJson(Map<String, dynamic> j) =>
      AirScheduleBanner(
        dayOfWeek: J.s(j, ['day_of_week', 'air_day', 'weekday']),
        timeText: J.s(j, ['time', 'air_time']),
        nextEpisodeText: J.s(j, ['next_episode', 'next_episode_text']),
        nextAirDate: J.s(j, ['next_air_date']),
      );

  String get text {
    final parts = <String>[
      if (dayOfWeek != null && dayOfWeek!.isNotEmpty) '每周$dayOfWeek',
      if (timeText != null && timeText!.isNotEmpty) timeText!,
      if (nextEpisodeText != null && nextEpisodeText!.isNotEmpty)
        nextEpisodeText!,
      if (nextAirDate != null && nextAirDate!.isNotEmpty) '下次播出 $nextAirDate',
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

/// 续播点与观看次数（GET /playback/resume）。
class ResumeInfo {
  const ResumeInfo({
    required this.positionMs,
    required this.durationMs,
    this.season,
    this.episode,
    this.played = false,
    this.playCount = 0,
  });

  final int positionMs;
  final int durationMs;
  final int? season;
  final int? episode;
  final bool played;
  final int playCount;
}

/// 详情页整体状态。
class DetailState {
  const DetailState({
    this.loading = false,
    this.episodesLoading = false,
    this.error,
    this.entry,
    this.libraryMeta,
    this.episodes = const {},
    this.seasonResumeEpisodes = const {},
    this.airSchedules = const {},
    this.related = const RelatedItems(),
    this.marks = const PlaybackMarks(),
    this.resume,
    this.airSchedule,
    this.selectedSeason,
    this.selectedEpisodeNumber,
    this.selectedFileId,
    this.overviewExpanded = false,
    this.busy = false,
  });

  final bool loading;
  final bool episodesLoading;
  final String? error;
  final DetailEntry? entry;
  final DetailLibraryMeta? libraryMeta;
  final Map<int, List<EpisodeEntry>> episodes;
  final Map<int, int> seasonResumeEpisodes;
  final Map<int, SeasonAirSchedule> airSchedules;
  final RelatedItems related;
  final PlaybackMarks marks;
  final ResumeInfo? resume;
  final AirScheduleBanner? airSchedule;
  final int? selectedSeason;
  final int? selectedEpisodeNumber;
  final int? selectedFileId;
  final bool overviewExpanded;
  final bool busy;

  /// 当前季分集列表
  List<EpisodeEntry> get currentSeasonEpisodes =>
      selectedSeason == null ? const [] : (episodes[selectedSeason] ?? const []);

  /// 当前选中的那一集（剧集用）
  EpisodeEntry? get selectedEpisode {
    final list = currentSeasonEpisodes;
    if (list.isEmpty) return null;
    if (selectedEpisodeNumber != null) {
      for (final e in list) {
        if (e.episodeNumber == selectedEpisodeNumber) return e;
      }
    }
    return list.first;
  }

  /// 当前选中单元对应的物理文件集合（电影 = 全条目 files；剧集 = 当前选中集 files）。
  List<DetailFileInfo> get currentUnitFiles {
    final e = entry;
    if (e == null) return const [];
    if (!e.isTv) return e.files;
    final ep = selectedEpisode;
    if (ep == null) return const [];
    final byId = {for (final f in e.files) f.id: f};
    final matched = [
      for (final id in ep.fileIds)
        if (byId.containsKey(id)) byId[id]!,
    ];
    if (matched.isNotEmpty) return matched;
    return e.files
        .where(
          (f) =>
              f.seasonNumber == ep.seasonNumber &&
              f.episodeNumber == ep.episodeNumber,
        )
        .toList();
  }

  /// 当前选中单元在位文件列表。
  List<DetailFileInfo> get availableUnitFiles =>
      currentUnitFiles.where((f) => f.state == 'in_place').toList();

  /// 当前激活的物理文件（用于轨道显示、章节条与下载首选）。
  DetailFileInfo? get activeTrackFile {
    final avail = availableUnitFiles;
    if (avail.isEmpty) return null;
    if (selectedFileId != null) {
      for (final f in avail) {
        if (f.id == selectedFileId) return f;
      }
    }
    return avail.first;
  }

  /// 当前激活文件的章节列表（若文件无章节则回退顶层 chapters）。
  List<DetailChapter> get activeChapters {
    final fileCh = activeTrackFile?.chapters;
    if (fileCh != null && fileCh.isNotEmpty) return fileCh;
    return entry?.topLevelChapters ?? const [];
  }

  /// 当前季的播出日历（若存在）。
  SeasonAirSchedule? get currentAirSchedule =>
      selectedSeason == null ? null : airSchedules[selectedSeason];

  /// 当前季服务端续播锚点集号（若服务端未给，则按客户端规则推断）。
  int? get currentAnchorEpisode {
    final s = selectedSeason;
    if (s == null) return null;
    final list = episodes[s] ?? const <EpisodeEntry>[];
    if (list.isEmpty) return null;
    final fromServer = seasonResumeEpisodes[s];
    if (fromServer != null && list.any((e) => e.episodeNumber == fromServer)) {
      return fromServer;
    }
    // 退回客户端规则：正在看的一集 → 最后一集已看的下一集 → 首集
    for (final e in list) {
      if (e.resumeMs > 0 && !e.played && e.owned) return e.episodeNumber;
    }
    int lastPlayedIdx = -1;
    for (var i = 0; i < list.length; i++) {
      if (list[i].played) lastPlayedIdx = i;
    }
    if (lastPlayedIdx >= 0) {
      for (var i = lastPlayedIdx + 1; i < list.length; i++) {
        if (list[i].owned) return list[i].episodeNumber;
      }
    }
    return list.first.episodeNumber;
  }

  DetailState copyWith({
    bool? loading,
    bool? episodesLoading,
    Object? error = _sentinel,
    DetailEntry? entry,
    Object? libraryMeta = _sentinel,
    Map<int, List<EpisodeEntry>>? episodes,
    Map<int, int>? seasonResumeEpisodes,
    Map<int, SeasonAirSchedule>? airSchedules,
    RelatedItems? related,
    PlaybackMarks? marks,
    Object? resume = _sentinel,
    Object? airSchedule = _sentinel,
    Object? selectedSeason = _sentinel,
    Object? selectedEpisodeNumber = _sentinel,
    Object? selectedFileId = _sentinel,
    bool? overviewExpanded,
    bool? busy,
  }) {
    return DetailState(
      loading: loading ?? this.loading,
      episodesLoading: episodesLoading ?? this.episodesLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      entry: entry ?? this.entry,
      libraryMeta: identical(libraryMeta, _sentinel)
          ? this.libraryMeta
          : libraryMeta as DetailLibraryMeta?,
      episodes: episodes ?? this.episodes,
      seasonResumeEpisodes: seasonResumeEpisodes ?? this.seasonResumeEpisodes,
      airSchedules: airSchedules ?? this.airSchedules,
      related: related ?? this.related,
      marks: marks ?? this.marks,
      resume: identical(resume, _sentinel) ? this.resume : resume as ResumeInfo?,
      airSchedule: identical(airSchedule, _sentinel)
          ? this.airSchedule
          : airSchedule as AirScheduleBanner?,
      selectedSeason: identical(selectedSeason, _sentinel)
          ? this.selectedSeason
          : selectedSeason as int?,
      selectedEpisodeNumber: identical(selectedEpisodeNumber, _sentinel)
          ? this.selectedEpisodeNumber
          : selectedEpisodeNumber as int?,
      selectedFileId: identical(selectedFileId, _sentinel)
          ? this.selectedFileId
          : selectedFileId as int?,
      overviewExpanded: overviewExpanded ?? this.overviewExpanded,
      busy: busy ?? this.busy,
    );
  }

  static const _sentinel = Object();
}

/// 时长文案（h:mm:ss / mm:ss，对齐 iOS `Formatters.clock`）。
String mcClock(int ms) {
  final total = (ms ~/ 1000).clamp(0, 1 << 30);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  if (h > 0) return '$h:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}

/// 播放键三态文案（对齐 iOS `playButtonState`）：
/// - 有续播点：「继续 第 X 季第 Y 集 · mm:ss」/「继续 mm:ss」
/// - 已看完无续播点：playCount > 1 时「重看 · 第 N 次」，否则「重看」
/// - 未看：剧集「播放 第 X 季第 Y 集」/ 电影「播放」
String playButtonLabel(DetailState s) {
  final entry = s.entry;
  final r = s.resume;
  final pos = r?.positionMs ?? 0;
  final finished = (r?.played ?? false) || s.marks.played;
  final playCount = r?.playCount ?? 0;

  String? unit;
  if (entry != null && entry.isTv) {
    final season = s.selectedEpisode?.seasonNumber ?? r?.season ?? s.selectedSeason;
    final ep = s.selectedEpisode?.episodeNumber ?? r?.episode;
    if (season != null && ep != null && ep > 0) {
      unit = season == 0 ? '特别篇第 $ep 集' : '第 $season 季第 $ep 集';
    }
  }

  if (pos > 0) {
    final clock = mcClock(pos);
    return unit != null ? '继续 $unit · $clock' : '继续 $clock';
  }
  if (finished) {
    final verb = playCount > 1 ? '重看 · 第 ${playCount + 1} 次' : '重看';
    return unit != null ? '$verb $unit' : verb;
  }
  return unit != null ? '播放 $unit' : '播放';
}

/// 详情页控制器（1:1 对齐 iOS `LibraryItemDetailView` 全部数据与动作）。
class DetailController extends FamilyNotifier<DetailState, String> {
  McClient? _client;
  int _libraryId = -1;
  int _itemId = -1;
  bool _relatedRequested = false;
  Timer? _pollTimer;
  int _chapterPolls = 0;

  int get libraryId => _libraryId;
  int get itemId => _itemId;
  McClient get api => _client!;
  DetailState get current => state;

  @override
  DetailState build(String arg) {
    final parts = arg.split(':');
    _libraryId = int.tryParse(parts[0]) ?? -1;
    _itemId = int.tryParse(parts[1]) ?? -1;
    _client = McClient(session: ref.read(sessionStoreProvider));
    ref.onDispose(() {
      _pollTimer?.cancel();
      _pollTimer = null;
    });
    return const DetailState(loading: true);
  }

  /// 首次加载 / 下拉刷新：详情 + 库元信息 → 续播/季/分集 → 标记 → 相似推荐与系列。
  Future<void> load({
    int? initialSeason,
    int? initialEpisode,
    bool silent = false,
  }) async {
    if (!silent) {
      state = state.copyWith(loading: state.entry == null, error: null);
    }
    try {
      final results = await Future.wait<dynamic>([
        api.unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/libraries/$_libraryId/items/$_itemId',
        ),
        _fetchLibraryMetaSilently(),
      ]);
      final body = results[0] as Map<String, dynamic>;
      final libMeta = results[1] as DetailLibraryMeta? ?? state.libraryMeta;
      final entry = DetailEntry.fromJson(body);

      AirScheduleBanner? banner;
      if (body['air_schedule'] is Map) {
        banner = AirScheduleBanner.fromJson(
          (body['air_schedule'] as Map).cast<String, dynamic>(),
        );
      }

      if (!entry.chaptersPending) {
        _chapterPolls = 0;
      }

      final nextSeason =
          state.selectedSeason ?? _defaultSeason(entry, initialSeason);

      state = state.copyWith(
        loading: false,
        entry: entry,
        libraryMeta: libMeta,
        airSchedule: banner,
        selectedSeason: nextSeason,
      );

      _schedulePollingIfNeeded(entry);

      if (entry.isTv && nextSeason != null) {
        await loadSeason(
          nextSeason,
          initialEpisode:
              state.selectedEpisodeNumber == null ? initialEpisode : null,
        );
      } else {
        await loadResume(season: 0, episode: 0);
      }
      await loadMarks();

      if (!_relatedRequested) {
        _relatedRequested = true;
        unawaited(loadRelated(entry));
      }
    } on ApiException catch (e) {
      if (!silent) {
        state = state.copyWith(loading: false, error: e.friendlyMessage);
      }
    } catch (e) {
      if (!silent) {
        state = state.copyWith(loading: false, error: '加载失败：$e');
      }
    }
  }

  Future<DetailLibraryMeta?> _fetchLibraryMetaSilently() async {
    try {
      final body = await api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/libraries/$_libraryId',
      );
      return DetailLibraryMeta.fromJson(body);
    } catch (_) {
      return null;
    }
  }

  void _schedulePollingIfNeeded(DetailEntry entry) {
    _pollTimer?.cancel();
    _pollTimer = null;
    final needScrapePoll = entry.scraping;
    final needChapterPoll =
        entry.chaptersPending && !entry.scraping && _chapterPolls < 20;
    if (!needScrapePoll && !needChapterPoll) return;

    final interval =
        needScrapePoll ? const Duration(seconds: 2) : const Duration(seconds: 3);
    _pollTimer = Timer(interval, () async {
      if (!needScrapePoll) _chapterPolls++;
      await _pollDetailOnly();
    });
  }

  Future<void> _pollDetailOnly() async {
    try {
      final body = await api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/libraries/$_libraryId/items/$_itemId',
      );
      final next = DetailEntry.fromJson(body);
      if (!next.chaptersPending) _chapterPolls = 0;
      state = state.copyWith(entry: next);
      _schedulePollingIfNeeded(next);
    } catch (_) {
      // 轮询瞬断不报错，下次由用户刷新或章节重试触发
    }
  }

  /// 默认选季策略（对齐 iOS）：
  /// 1. 路由显式传入的 initialSeason；
  /// 2. 服务端返回的 resumeSeason；
  /// 3. 第一个有在位文件的正片季；
  /// 4. 第一个有在位文件的季；
  /// 5. 第一个正片季 / 首季。
  int? _defaultSeason(DetailEntry entry, int? initialSeason) {
    if (entry.seasons.isEmpty) return null;
    final ownedSeasons = entry.files.map((f) => f.seasonNumber).toSet();
    final seasonNums = entry.seasons.map((s) => s.number).toList();
    if (initialSeason != null && seasonNums.contains(initialSeason)) {
      return initialSeason;
    }
    if (entry.resumeSeason != null && seasonNums.contains(entry.resumeSeason)) {
      return entry.resumeSeason;
    }
    for (final s in seasonNums) {
      if (s > 0 && ownedSeasons.contains(s)) return s;
    }
    for (final s in seasonNums) {
      if (ownedSeasons.contains(s)) return s;
    }
    for (final s in seasonNums) {
      if (s > 0) return s;
    }
    return seasonNums.first;
  }

  /// 切换当前物理文件版本（同步影响轨道与章节条）。
  void selectTrackFile(int fileId) {
    state = state.copyWith(selectedFileId: fileId);
  }

  /// 选中某集（更新轨道/章节/文件区与续播点）。
  Future<void> selectEpisode(int seasonNumber, int episodeNumber) async {
    final prevEp = state.selectedEpisodeNumber;
    final prevSeason = state.selectedSeason;
    state = state.copyWith(
      selectedSeason: seasonNumber,
      selectedEpisodeNumber: episodeNumber,
      selectedFileId:
          (prevSeason != seasonNumber || prevEp != episodeNumber)
              ? null
              : state.selectedFileId,
    );
    await loadResume(season: seasonNumber, episode: episodeNumber);
  }

  /// 拉某一季的分集与播出日历（直连 `/episodes` 以完整解析 `air_schedule` 与 `resume_episode`）。
  Future<void> loadSeason(int seasonNumber, {int? initialEpisode}) async {
    final seasonChanged = state.selectedSeason != seasonNumber;
    state = state.copyWith(
      selectedSeason: seasonNumber,
      episodesLoading: !state.episodes.containsKey(seasonNumber),
      selectedFileId: seasonChanged ? null : state.selectedFileId,
    );
    try {
      final body = await api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/libraries/$_libraryId/items/$_itemId/episodes',
        query: {'season_number': seasonNumber},
      );
      final list = J
          .listOfMap(body, ['episodes'])
          .map((e) => EpisodeEntry.fromJson(e, seasonOverride: seasonNumber))
          .toList();
      final resumeEp = J.i(body, ['resume_episode']);
      final nextResumes = Map<int, int>.from(state.seasonResumeEpisodes);
      if (resumeEp != null) {
        nextResumes[seasonNumber] = resumeEp;
      }

      final nextSchedules =
          Map<int, SeasonAirSchedule>.from(state.airSchedules);
      if (body['air_schedule'] is Map) {
        nextSchedules[seasonNumber] = SeasonAirSchedule.fromJson(
          (body['air_schedule'] as Map).cast<String, dynamic>(),
        );
      } else {
        nextSchedules.remove(seasonNumber);
      }

      int? pickedEp = state.selectedEpisodeNumber;
      if (seasonChanged ||
          pickedEp == null ||
          !list.any((e) => e.episodeNumber == pickedEp)) {
        if (initialEpisode != null &&
            list.any((e) => e.episodeNumber == initialEpisode && e.owned)) {
          pickedEp = initialEpisode;
        } else if (resumeEp != null &&
            list.any((e) => e.episodeNumber == resumeEp)) {
          pickedEp = resumeEp;
        } else if (list.isNotEmpty) {
          pickedEp = list.first.episodeNumber;
        }
      }

      state = state.copyWith(
        episodesLoading: false,
        episodes: {...state.episodes, seasonNumber: list},
        seasonResumeEpisodes: nextResumes,
        airSchedules: nextSchedules,
        selectedEpisodeNumber: pickedEp,
      );

      if (pickedEp != null) {
        await loadResume(season: seasonNumber, episode: pickedEp);
      }
    } catch (_) {
      state = state.copyWith(episodesLoading: false);
    }
  }

  /// 相似推荐与作品系列（对齐 iOS `ItemRelated.load`：有系列时排除同系列，系列不足 2 部再补拉）。
  Future<void> loadRelated(DetailEntry entry) async {
    final seriesId = !entry.isTv ? entry.seriesCollectionId : null;
    final excludeSeries = seriesId != null;

    var similar = <DetailEntry>[];
    CollectionSeriesInfo? seriesInfo;
    final seriesPartsEntries = <DetailEntry>[];

    await Future.wait([
      () async {
        try {
          final raw = await api.unwrap<dynamic>(
            Channel.general,
            'GET',
            '/api/v1/libraries/$_libraryId/items/$_itemId/similar',
            query: excludeSeries ? const {'exclude_series': 'true'} : null,
          );
          final maps = raw is List
              ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
              : (raw is Map
                  ? J.listOfMap(raw.cast<String, dynamic>(), ['items', 'results', 'data'])
                  : const <Map<String, dynamic>>[]);
          similar = maps.map(DetailEntry.fromJson).toList();
        } catch (_) {}
      }(),
      if (seriesId != null)
        () async {
          try {
            final body = await api.unwrap<Map<String, dynamic>>(
              Channel.general,
              'GET',
              '/api/v1/collections/$seriesId/series',
            );
            final parsed = CollectionSeriesInfo.fromJson(body);
            if (parsed.available && parsed.parts.length > 1) {
              seriesInfo = parsed;
            }
            seriesPartsEntries.addAll(
              J.listOfMap(body, ['parts', 'items']).map(DetailEntry.fromJson),
            );
          } catch (_) {}
        }(),
    ]);

    if (seriesId != null && seriesInfo == null) {
      try {
        final raw = await api.unwrap<dynamic>(
          Channel.general,
          'GET',
          '/api/v1/libraries/$_libraryId/items/$_itemId/similar',
        );
        final maps = raw is List
            ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
            : (raw is Map
                ? J.listOfMap(raw.cast<String, dynamic>(), ['items', 'results', 'data'])
                : const <Map<String, dynamic>>[]);
        similar = maps.map(DetailEntry.fromJson).toList();
      } catch (_) {}
    }

    state = state.copyWith(
      related: RelatedItems(
        similar: similar,
        seriesParts: seriesPartsEntries,
        seriesName: seriesInfo?.seriesName ?? entry.seriesName,
        series: seriesInfo,
      ),
    );
  }

  /// GET /playback/marks：收藏 / 已看初始态。
  Future<void> loadMarks() async {
    try {
      final body = await api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/playback/marks',
        query: {'media_item_id': _itemId},
      );
      state = state.copyWith(
        marks: PlaybackMarks(
          isFavorite: J.b(body, ['favorite', 'is_favorite']),
          played: J.b(body, ['played']),
        ),
      );
    } catch (_) {}
  }

  Future<void> _setMarks({bool? favorite, bool? played}) async {
    final prev = state.marks;
    final isTv = state.entry?.isTv ?? false;
    final season = isTv ? (state.selectedSeason ?? 0) : 0;
    final ep = isTv ? (state.selectedEpisodeNumber ?? 0) : 0;
    state = state.copyWith(
      busy: true,
      marks: PlaybackMarks(
        isFavorite: favorite ?? prev.isFavorite,
        played: played ?? prev.played,
      ),
    );
    try {
      await api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/playback/marks',
        body: {
          'media_item_id': _itemId,
          if (played != null && isTv && ep > 0) ...{
            'season_number': season,
            'episode_number': ep,
          },
          if (favorite != null) 'favorite': favorite,
          if (played != null) 'played': played,
        },
      );
      if (played != null) {
        await loadResume(season: season, episode: ep);
        if (isTv && state.selectedSeason != null) {
          await loadSeason(state.selectedSeason!);
        }
      }
    } catch (_) {
      state = state.copyWith(marks: prev);
    }
    state = state.copyWith(busy: false);
  }

  Future<void> toggleFavorite() => _setMarks(favorite: !state.marks.isFavorite);

  Future<void> togglePlayed() {
    final currentPlayed = (state.resume?.played ?? false) || state.marks.played;
    return _setMarks(played: !currentPlayed);
  }

  /// GET /playback/resume：续播点与观看次数。
  Future<void> loadResume({int season = 0, int episode = 0}) async {
    try {
      final body = await api.unwrap<Map<String, dynamic>>(
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
      final dur = J.i(body, ['duration_ms']) ?? 0;
      final played = J.b(body, ['played']);
      final playCount = J.i(body, ['play_count']) ?? 0;
      state = state.copyWith(
        resume: ResumeInfo(
          positionMs: pos,
          durationMs: dur,
          season: J.i(body, ['season_number']) ?? (season > 0 ? season : null),
          episode:
              J.i(body, ['episode_number']) ?? (episode > 0 ? episode : null),
          played: played,
          playCount: playCount,
        ),
        marks: PlaybackMarks(
          isFavorite: state.marks.isFavorite,
          played: played,
        ),
      );
    } catch (_) {}
  }

  void toggleOverview() =>
      state = state.copyWith(overviewExpanded: !state.overviewExpanded);

  /// 刷新元数据 / 重读本地 NFO：POST /libraries/{libraryId}/items/{id}/metadata/refresh。
  /// （核对上游 `Endpoints.swift` 与 `LibraryItemDetailView.swift`：刮削刷新与本地 NFO 重读共用同一端点）
  Future<String?> refreshMetadata() async {
    try {
      await api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/libraries/$_libraryId/items/$_itemId/metadata/refresh',
      );
      await load(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '刷新失败：$e';
    }
  }

  /// 重读本地 NFO（对齐 `LibraryItemDetailView.swift` 的 `metadata/refresh` 通道）。
  Future<String?> reloadNfo() => refreshMetadata();

  /// 重新生成章节缩略图：POST /libraries/{libraryId}/items/{id}/chapter-images。
  Future<String?> regenerateChapters() async {
    try {
      await api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/libraries/$_libraryId/items/$_itemId/chapter-images',
      );
      _chapterPolls = 0;
      await load(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '生成章节失败：$e';
    }
  }

  /// 删除一条外挂字幕：DELETE /libraries/files/{fileId}/subtitles?filename=。
  Future<String?> deleteExternalSubtitle(int fileId, String filename) async {
    try {
      await api.unwrap<dynamic>(
        Channel.general,
        'DELETE',
        '/api/v1/libraries/files/$fileId/subtitles',
        query: {'filename': filename},
      );
      await load(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '删除字幕失败：$e';
    }
  }

  /// 字幕内容预览：GET /libraries/files/{fileId}/subtitles/preview?track=。
  Future<Map<String, dynamic>> fetchSubtitlePreview(
    int fileId,
    String trackRef,
  ) {
    return api.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/libraries/files/$fileId/subtitles/preview',
      query: {'track': trackRef},
    );
  }

  /// 一键音频对齐校准：POST /libraries/files/{fileId}/subtitles/timing-calibration。
  Future<Map<String, dynamic>> calibrateSubtitle(
    int fileId,
    String filename,
  ) async {
    final res = await api.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/libraries/files/$fileId/subtitles/timing-calibration',
      body: {'filename': filename},
    );
    if (res['ok'] == true) {
      await load(silent: true);
    }
    return res;
  }

  /// 补搜缺集：POST /subscriptions/{subscriptionId}/missing-resource-searches。
  Future<({int resetCount, String? error})> searchMissingEpisode(
    int subscriptionId, {
    int? season,
    int? episode,
  }) async {
    try {
      final res = await api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/subscriptions/$subscriptionId/missing-resource-searches',
      );
      final count = J.i(res, ['reset_count', 'count']) ?? 0;
      if (state.selectedSeason != null) {
        unawaited(loadSeason(state.selectedSeason!));
      }
      return (resetCount: count, error: null);
    } on ApiException catch (e) {
      return (resetCount: 0, error: e.friendlyMessage);
    } catch (e) {
      return (resetCount: 0, error: '搜索缺集失败：$e');
    }
  }

  /// 恢复待回收文件：POST /libraries/{libraryId}/items/{itemId}/files/{fileId}/restore。
  Future<String?> restoreFile(int fileId) async {
    try {
      await api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/libraries/$_libraryId/items/$_itemId/files/$fileId/restore',
      );
      await load(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '恢复失败：$e';
    }
  }

  /// 立即清理待回收文件：POST /libraries/{libraryId}/items/{itemId}/files/{fileId}/purge。
  Future<String?> purgeFile(int fileId) async {
    try {
      await api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/libraries/$_libraryId/items/$_itemId/files/$fileId/purge',
      );
      await load(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '彻底清理失败：$e';
    }
  }

  /// 删除前预检（整条目或单文件）：GET /libraries/{libraryId}/items/{itemId}/delete-preview。
  Future<Map<String, dynamic>?> fetchDeletePreview({int? fileId}) async {
    try {
      return await api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/libraries/$_libraryId/items/$_itemId/delete-preview',
        query: fileId != null ? {'file_id': fileId} : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// 删除整条目：DELETE /libraries/{libraryId}/items/{itemId}。
  Future<({Map<String, dynamic>? result, String? error})> deleteItem({
    String? options,
  }) async {
    try {
      final res = await api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'DELETE',
        '/api/v1/libraries/$_libraryId/items/$_itemId',
        query: (options != null && options.isNotEmpty)
            ? {'options': options}
            : null,
      );
      return (result: res, error: null);
    } on ApiException catch (e) {
      return (result: null, error: e.friendlyMessage);
    } catch (e) {
      return (result: null, error: '删除失败：$e');
    }
  }

  /// 删除单个物理文件：DELETE /libraries/{libraryId}/items/{itemId}/files/{fileId}。
  Future<({Map<String, dynamic>? result, String? error})> deleteFile(
    int fileId, {
    String? options,
  }) async {
    try {
      final res = await api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'DELETE',
        '/api/v1/libraries/$_libraryId/items/$_itemId/files/$fileId',
        query: (options != null && options.isNotEmpty)
            ? {'options': options}
            : null,
      );
      return (result: res, error: null);
    } on ApiException catch (e) {
      return (result: null, error: e.friendlyMessage);
    } catch (e) {
      return (result: null, error: '删除文件失败：$e');
    }
  }

  /// 获取后台任务详情（删除 follow-up 轮询 & AI 字幕任务轮询共用）。
  Future<Map<String, dynamic>?> fetchJob(String jobId) async {
    try {
      return await api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/jobs/$jobId',
      );
    } catch (_) {
      return null;
    }
  }

  /// 取消后台任务：POST /jobs/{jobId}/cancel。
  Future<Map<String, dynamic>?> cancelJob(String jobId) async {
    final res = await api.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/jobs/$jobId/cancel',
    );
    if (res['job'] is Map) {
      return (res['job'] as Map).cast<String, dynamic>();
    }
    return res;
  }

  /// 查询某文件最近一次 AI 字幕生成任务。
  Future<Map<String, dynamic>?> fetchLatestSubtitleJob(int fileId) async {
    try {
      final res = await api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/jobs',
        query: {
          'job_type': 'subtitle.generate',
          'resource_type': 'library_file',
          'resource_id': fileId.toString(),
          'limit': 5,
        },
      );
      final items = J.listOfMap(res, ['items', 'jobs', 'data']);
      if (items.isEmpty) return null;
      items.sort((a, b) {
        final ta = DateTime.tryParse((a['updated_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb = DateTime.tryParse((b['updated_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      return items.first;
    } catch (_) {
      return null;
    }
  }

  /// 跨库转移：读取同类型、同来源、非当前库的候选目标库。
  Future<List<DetailLibraryMeta>> listTransferCandidateLibraries() async {
    final srcLib = state.libraryMeta ?? await _fetchLibraryMetaSilently();
    final kind = srcLib?.kind ?? state.entry?.kind;
    final source = srcLib?.source ?? state.entry?.source;
    final raw = await api.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/libraries',
      query: {
        if (kind != null && kind.isNotEmpty) 'kind': kind,
        'scope': 'all',
      },
    );
    return raw
        .whereType<Map>()
        .map((e) => DetailLibraryMeta.fromJson(e.cast<String, dynamic>()))
        .where((l) => l.id != _libraryId && (source == null || l.source == source))
        .toList();
  }

  /// 跨库转移只读预检：GET /libraries/{libraryId}/items/{itemId}/transfer-preview。
  Future<Map<String, dynamic>> transferPreview(int targetLibraryId) {
    return api.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/libraries/$_libraryId/items/$_itemId/transfer-preview',
      query: {'target_library_id': targetLibraryId},
    );
  }

  /// 发起跨库转移：POST /libraries/{libraryId}/items/{itemId}/transfers。
  Future<Map<String, dynamic>> startTransfer(int targetLibraryId) {
    return api.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/libraries/$_libraryId/items/$_itemId/transfers',
      body: {'target_library_id': targetLibraryId},
    );
  }

  /// 查询转移实时状态：GET /libraries/{libraryId}/item-transfer-status。
  Future<Map<String, dynamic>> transferStatus() {
    return api.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/libraries/$_libraryId/item-transfer-status',
    );
  }

  /// 单集切换已看 / 未看标记。
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
            progressPercent: targetPlayed ? 100 : null,
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
      await api.unwrap<dynamic>(
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
      if (state.selectedSeason == ep.seasonNumber &&
          state.selectedEpisodeNumber == ep.episodeNumber) {
        await loadResume(
          season: ep.seasonNumber,
          episode: ep.episodeNumber,
        );
      }
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

  /// 详情条目的在位文件 id（当前选中的文件优先）。
  int? get leadFileId {
    final active = state.activeTrackFile;
    if (active != null) return active.id;
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

  /// AI 字幕生成预检：GET /libraries/files/{fileId}/subtitles/generation-preview。
  Future<Map<String, dynamic>> previewSubtitleGen({
    int? fileId,
    String targetLanguage = 'chs',
    String? secondaryLanguage,
    String? sourceCandidateKey,
  }) async {
    final id = fileId ?? leadFileId;
    if (id == null) {
      throw const ApiException('subtitle.no_file', '没有在位文件，无法生成字幕');
    }
    return api.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/libraries/files/$id/subtitles/generation-preview',
      query: {
        'target_language': targetLanguage,
        if (secondaryLanguage != null && secondaryLanguage.isNotEmpty)
          'secondary_language': secondaryLanguage,
        if (sourceCandidateKey != null && sourceCandidateKey.isNotEmpty)
          'source_candidate_key': sourceCandidateKey,
      },
    );
  }

  /// 发起 AI 字幕生成后台任务（返回 Job 对象以便留在弹层实时跟踪 5 阶段进度）。
  Future<Map<String, dynamic>> startSubtitleGenJob({
    required int fileId,
    required String targetLanguage,
    String? secondaryLanguage,
    String? sourceCandidateKey,
    bool convertPgs = false,
    String? pgsOcrLanguage,
  }) {
    return api.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/libraries/files/$fileId/subtitles/generations',
      body: {
        'target_language': targetLanguage,
        if (secondaryLanguage != null && secondaryLanguage.isNotEmpty)
          'secondary_language': secondaryLanguage,
        if (sourceCandidateKey != null && sourceCandidateKey.isNotEmpty)
          'source_candidate_key': sourceCandidateKey,
        'convert_pgs': convertPgs,
        if (convertPgs && pgsOcrLanguage != null && pgsOcrLanguage.isNotEmpty)
          'pgs_ocr_language': pgsOcrLanguage,
      },
    );
  }

  /// 交给智能体处理（POST /api/v1/sessions 创建带完整文件与参数上下文的新会话）。
  Future<String> startAgentSession(String content) async {
    final res = await api.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/sessions',
      body: {'content': content},
    );
    final sid =
        (res['session_id'] ?? res['sessionId'] ?? res['id'])?.toString() ?? '';
    if (sid.isEmpty) {
      throw const ApiException('agent.session_missing', '未返回会话编号');
    }
    return sid;
  }

  /// 查找是否已有此作品的订阅（用于「洗版升级」直跳订阅详情）。
  Future<int?> findExistingSubscriptionId() async {
    final entry = state.entry;
    final tmdb = entry?.tmdbId;
    if (entry == null || tmdb == null || tmdb <= 0) return null;
    try {
      final kind = entry.isTv ? 'tv' : 'movie';
      final raw = await api.unwrap<dynamic>(
        Channel.general,
        'GET',
        '/api/v1/subscriptions',
        query: {'kind': kind},
      );
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['items'] ?? raw['data'] ?? const []) as List : const []);
      for (final item in list.whereType<Map>()) {
        final m = item.cast<String, dynamic>();
        final media = J.map(m, 'media');
        final itemTmdb = J.i(media, ['tmdb_id']) ?? J.i(m, ['tmdb_id']);
        if (itemTmdb == tmdb) {
          return J.i(m, ['id', 'subscription_id']);
        }
      }
    } catch (_) {}
    return null;
  }

  /// 读取当前条目的活跃分享状态。
  Future<Map<String, dynamic>?> getShareInfo() async {
    try {
      return await api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/libraries/$_libraryId/items/$_itemId/share',
      );
    } catch (_) {
      return null;
    }
  }

  /// 创建/更新可配置分享链接。
  Future<String?> createShareLink({
    int expiresInDays = 7,
    String? password,
    StringBuffer? err,
  }) async {
    try {
      final body = await api.unwrap<Map<String, dynamic>>(
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
      final base = api.baseUrl;
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
      await api.unwrap<dynamic>(
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

  /// 读取候选海报/剧照/Logo。
  Future<Map<String, dynamic>> fetchArtworkCandidates() {
    return api.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/libraries/$_libraryId/items/$_itemId/artwork/candidates',
    );
  }

  /// 更换海报/剧照/Logo；`filePath == null` 表示解锁并恢复自动选图。
  Future<String?> selectArtwork({
    required String kind,
    String? filePath,
  }) async {
    try {
      await api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/libraries/$_libraryId/items/$_itemId/artwork/select',
        body: {'kind': kind, 'file_path': filePath},
      );
      await load(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '更换图片失败：$e';
    }
  }

  /// 恢复自动选图（解锁人工锁定）。
  Future<String?> unlockArtwork(String kind) =>
      selectArtwork(kind: kind, filePath: null);

  /// 修正识别结果第一阶段只读预览：POST .../reidentification-preview。
  Future<Map<String, dynamic>> reidentifyPreview() {
    return api.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/libraries/$_libraryId/items/$_itemId/reidentification-preview',
    );
  }

  /// 搜索手动重新识别的候选词条（支持跨 movie↔tv 切换）。
  Future<List<Map<String, dynamic>>> searchReidentifyCandidates(
    String query, {
    String? mediaType,
  }) async {
    final kind = mediaType ?? ((state.entry?.isTv ?? false) ? 'tv' : 'movie');
    final raw = await api.unwrap<dynamic>(
      Channel.general,
      'POST',
      '/api/v1/search/titles',
      body: {'query': query, 'provider': 'tmdb', 'save_history': false},
    );
    final list = raw is List
        ? raw
        : (raw is Map
            ? (raw['titles'] ?? raw['items'] ?? const []) as List<dynamic>
            : const <dynamic>[]);
    final all = list.whereType<Map>().map(Map<String, dynamic>.from).toList();
    if (kind == 'all') return all;
    final filtered = all.where((h) => h['media_type'] == kind).toList();
    return filtered.isNotEmpty ? filtered : all;
  }

  /// 拉取候选词条详情（海报/简介/季数/演职员，确认认领前核对）。
  Future<Map<String, dynamic>?> fetchDiscoverTitleDetails(String titleRef) async {
    try {
      return await api.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/discover/titles/$titleRef',
      );
    } catch (_) {
      return null;
    }
  }

  /// 将选定文件组归属到目标 TMDB 词条（支持剧集统一指定季号）。
  Future<String?> assignFilesToTitle({
    required List<int> fileIds,
    required String titleRef,
    int? seasonNumber,
  }) async {
    try {
      await api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/libraries/identification/file-title-assignments',
        body: {
          'file_ids': fileIds,
          'title_ref': titleRef,
          if (seasonNumber != null) 'season_number': seasonNumber,
        },
      );
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '应用识别失败：$e';
    }
  }

  /// 标为花絮/特典（非独立作品，不动磁盘）。
  Future<String?> markFilesAsExtras(List<int> fileIds) async {
    try {
      await api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/libraries/identification/files/mark-as-extras',
        body: {'file_ids': fileIds},
      );
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return '标记花絮失败：$e';
    }
  }

  /// 读取可编辑的用户合集列表。
  Future<List<Map<String, dynamic>>> listEditableCollections() async {
    final raw = await api.unwrap<List<dynamic>>(
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

  /// 将当前条目加入已有合集。
  Future<String?> addToCollection(int collectionId) async {
    try {
      await api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/collections/$collectionId/items',
        body: {'media_item_ids': [_itemId]},
      );
      await load(silent: true);
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
      await api.unwrap<dynamic>(
        Channel.general,
        'POST',
        '/api/v1/collections',
        body: {
          'name': name,
          'library_id': _libraryId,
          'item_ids': [_itemId],
        },
      );
      await load(silent: true);
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
