/// 播放页参数（原 features/player/state/player_controller.dart 内定义，
/// 下沉 core：detail 等入口可以构造本对象经 go_router extra 传入，
/// 不允许 feature 之间互相 import）。
///
/// 对应 Android PlayingSurface 的 active.target。会话协商路径只带
/// mediaItemId + fileId（由选集接口数据来）；url 仅为协商失败时的演示兜底流。
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
  });

  /// 直连兜底流（演示路径）；会话协商成功后由 streamUrl 覆盖。
  final String url;

  /// 非 null 时走服务器会话协商（POST /playback/sessions），null 为演示直连路径。
  final int? mediaItemId;

  /// 起播台账文件 id（选集接口 file_ids 首个，由接口数据来）。
  final int? fileId;

  /// 兼容保留：仅旧入口/演示路径使用；正式选集路径不再手传季/集号。
  final int? seasonNumber;
  final int? episodeNumber;

  final String? title;
  final String? subtitle;
  final Duration? startPosition;
  final Map<String, String> headers;

  /// 剧集元信息：true 时底栏出现「选集」入口（Android state.unit.isEpisode）。
  final bool isEpisode;

  /// 选集面板数据。TODO(playback-session): 正式路径走
  /// EpisodesApi.playbackItemEpisodes 的播放侧接口取季/集，当前先由入口方传入。
  final List<int> seasons;
  final List<EpisodeItem> episodes;
}

class EpisodeItem {
  const EpisodeItem({
    required this.season,
    required this.episode,
    required this.name,
    this.fileId,
    this.owned = true,
  });

  final int season;
  final int episode;
  final String name;

  /// 起播台账文件 id（播放侧选集接口 file_ids 首个）；null = 缺集置灰。
  final int? fileId;
  final bool owned;
}
