/// 播放页参数（下沉 core：detail / reels / share / offline 等入口可经 go_router extra 传入，
/// 严格遵守 feature 之间不得互相 import 的架构铁律）。
///
/// 会话协商路径优先带 mediaItemId + fileId；url 仅作为离线本地文件路径或协商失败兜底流。
class PlayerPageArgs {
  const PlayerPageArgs({
    this.url = '',
    this.mediaItemId,
    this.fileId,
    this.seasonNumber,
    this.episodeNumber,
    this.title,
    this.subtitle,
    this.startPosition,
    this.headers = const {},
    this.isEpisode = false,
    this.seasons = const [],
    this.episodes = const [],
    this.shareSlug,
    this.clipStartMs,
    this.clipEndMs,
    this.isOffline = false,
    this.offlineItemId,
    this.offlineFileId,
    this.artworkUrl,
    this.episodeSubtitle,
    this.seriesTitle,
    this.initialMaxHeight,
  });

  /// 直连兜底流或本地离线文件路径；会话协商成功后由 streamUrl 覆盖。
  final String url;

  /// 非 null 时走服务器会话协商（POST /playback/sessions），null 为演示/直连路径。
  final int? mediaItemId;

  /// 起播台账文件 id（选集接口 file_ids 首个，由接口数据来）。
  final int? fileId;

  final int? seasonNumber;
  final int? episodeNumber;

  final String? title;
  final String? subtitle;
  final Duration? startPosition;
  final Map<String, String> headers;

  /// 剧集元信息：true 时底栏出现「选集」入口。
  final bool isEpisode;

  /// 选集面板数据（播放页也会自动拉取 `/api/v1/playback/items/{id}/episodes`）。
  final List<int> seasons;
  final List<EpisodeItem> episodes;

  /// 访客分享 slug：非空时走 `/api/v1/share/{slug}/playback/*` 公开播放通道，进度仅存本机。
  final String? shareSlug;

  /// 片段模式起止文件时间（毫秒，Reels 全屏观看）：
  /// 进度条按片段时长计算、到终点暂停、不写观看历史，支持原地「看全片」无缝展开。
  final int? clipStartMs;
  final int? clipEndMs;

  /// 离线本机副本播放标记与关联元数据。
  final bool isOffline;
  final String? offlineItemId;
  final int? offlineFileId;

  /// 锁屏 Now Playing / 氛围背景 / 选集剧照使用的海报或剧照地址。
  final String? artworkUrl;

  /// 分集副标题（如 `S01E02 · 集名`）。
  final String? episodeSubtitle;

  /// 剧集主片名（当 title 为集名时供锁屏与暂停遮罩展示）。
  final String? seriesTitle;

  /// 初始画质上限（例如 Reels 片段模式传入当前网络画质档）。
  final int? initialMaxHeight;

  bool get isClip =>
      clipStartMs != null &&
      clipEndMs != null &&
      clipEndMs! > clipStartMs!;

  bool get isShare => shareSlug != null && shareSlug!.isNotEmpty;

  String get displayTitle =>
      (seriesTitle != null && seriesTitle!.trim().isNotEmpty)
          ? seriesTitle!.trim()
          : (title?.trim().isNotEmpty == true ? title!.trim() : '播放');

  String? get displaySubtitle =>
      (episodeSubtitle != null && episodeSubtitle!.trim().isNotEmpty)
          ? episodeSubtitle!.trim()
          : (subtitle?.trim().isNotEmpty == true ? subtitle!.trim() : null);

  PlayerPageArgs copyWith({
    String? url,
    int? mediaItemId,
    int? fileId,
    int? seasonNumber,
    int? episodeNumber,
    String? title,
    String? subtitle,
    Duration? startPosition,
    bool clearStartPosition = false,
    Map<String, String>? headers,
    bool? isEpisode,
    List<int>? seasons,
    List<EpisodeItem>? episodes,
    String? shareSlug,
    int? clipStartMs,
    int? clipEndMs,
    bool clearClip = false,
    bool? isOffline,
    String? offlineItemId,
    int? offlineFileId,
    String? artworkUrl,
    String? episodeSubtitle,
    String? seriesTitle,
    int? initialMaxHeight,
  }) {
    return PlayerPageArgs(
      url: url ?? this.url,
      mediaItemId: mediaItemId ?? this.mediaItemId,
      fileId: fileId ?? this.fileId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      startPosition:
          clearStartPosition ? null : (startPosition ?? this.startPosition),
      headers: headers ?? this.headers,
      isEpisode: isEpisode ?? this.isEpisode,
      seasons: seasons ?? this.seasons,
      episodes: episodes ?? this.episodes,
      shareSlug: shareSlug ?? this.shareSlug,
      clipStartMs: clearClip ? null : (clipStartMs ?? this.clipStartMs),
      clipEndMs: clearClip ? null : (clipEndMs ?? this.clipEndMs),
      isOffline: isOffline ?? this.isOffline,
      offlineItemId: offlineItemId ?? this.offlineItemId,
      offlineFileId: offlineFileId ?? this.offlineFileId,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      episodeSubtitle: episodeSubtitle ?? this.episodeSubtitle,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      initialMaxHeight: initialMaxHeight ?? this.initialMaxHeight,
    );
  }
}

class EpisodeItem {
  const EpisodeItem({
    required this.season,
    required this.episode,
    required this.name,
    this.fileId,
    this.owned = true,
    this.stillUrl,
    this.overview,
    this.played = false,
    this.progressPercent,
    this.positionMs = 0,
    this.airDate,
  });

  final int season;
  final int episode;
  final String name;

  /// 起播台账文件 id（播放侧选集接口 file_ids 首个）；null = 缺集置灰。
  final int? fileId;
  final bool owned;
  final String? stillUrl;
  final String? overview;
  final bool played;
  final int? progressPercent;
  final int positionMs;
  final String? airDate;

  String get code =>
      'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';
}
