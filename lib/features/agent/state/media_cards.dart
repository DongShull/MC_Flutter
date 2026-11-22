// Agent 生成式 UI：媒体卡片参数解析。
// 纯逻辑移植自 web lib/agent-media-cards.ts（parseMediaCardsArgs）。
// 机制：模型调用 show_media_cards_v1 时只给编号；前端拦截该工具调用，
// 按参数里的编号自行调接口加载数据并绘制卡片。流式与历史回放走同一条路径——
// 转录里的 assistant.tool_calls 与实时 tool_call 事件都会经过这里。
// 完全认不出的名字/版本返回 null，调用方退回普通工具行，不打断渲染。

import 'dart:convert';

/// 工具名（渲染器的匹配键；后端发 _v2 时需另写解析器）。
const mediaCardsToolV1 = 'show_media_cards_v1';

bool isMediaCardsTool(String name) => name == mediaCardsToolV1;

/// 一张卡片的规格（与 web MediaCardSpec 同构）。
class MediaCardSpec {
  const MediaCardSpec._({
    required this.kind,
    required this.key,
    this.libraryId,
    this.titleRef,
    this.mediaItemId,
    this.seasonNumber,
    this.episodeNumber,
    this.subscriptionId,
  });

  factory MediaCardSpec.library(int libraryId) => MediaCardSpec._(
        kind: 'library',
        key: 'library:$libraryId',
        libraryId: libraryId,
      );

  factory MediaCardSpec.title(String titleRef) => MediaCardSpec._(
        kind: 'title',
        key: titleRef,
        titleRef: titleRef,
      );

  factory MediaCardSpec.libraryItem(
    int mediaItemId, {
    int? seasonNumber,
    int? episodeNumber,
  }) =>
      MediaCardSpec._(
        kind: 'library_item',
        key: 'item:$mediaItemId'
            '${episodeNumber != null ? ':s$seasonNumber' 'e$episodeNumber' : ''}',
        mediaItemId: mediaItemId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );

  factory MediaCardSpec.subscription(int subscriptionId) =>
      MediaCardSpec._(
        kind: 'subscription',
        key: 'subscription:$subscriptionId',
        subscriptionId: subscriptionId,
      );

  /// library / title / library_item / subscription。
  final String kind;
  final String key;
  final int? libraryId;
  final String? titleRef;
  final int? mediaItemId;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? subscriptionId;
}

/// 一组卡片：同一次调用只画一种组件。
class MediaCardGroup {
  const MediaCardGroup({
    required this.component,
    required this.cards,
    this.title,
  });

  final String component;
  final String? title;
  final List<MediaCardSpec> cards;
}

final _titleRefPattern = RegExp(r'^(tmdb:(movie|tv):\d+|douban:[^:/\s]+)$');
const _components = {'library', 'title', 'library_item', 'subscription'};

int? _positiveInt(Object? value) =>
    value is num && value % 1 == 0 && value > 0 ? value.toInt() : null;

/// 解析一次 show_media_cards_v1 调用的参数（arguments 为 JSON 字符串）。
/// 单项不合法跳过那一项；整组无可画卡片返回 null。
MediaCardGroup? parseMediaCardsArgs(String name, String? argumentsJson) {
  if (name != mediaCardsToolV1 || argumentsJson == null) return null;
  Map<String, dynamic>? args;
  try {
    final decoded = jsonDecode(argumentsJson);
    if (decoded is Map<String, dynamic>) args = decoded;
  } catch (_) {
    return null;
  }
  if (args == null) return null;
  final component = args['component'];
  if (component is! String || !_components.contains(component)) return null;
  final rawItems = args['items'];
  if (rawItems is! List) return null;
  final cards = <MediaCardSpec>[];
  final seen = <String>{};
  for (final raw in rawItems) {
    if (raw is! Map<String, dynamic>) continue;
    final spec = _parseItem(component, raw);
    if (spec != null && seen.add(spec.key)) cards.add(spec);
  }
  if (cards.isEmpty) return null;
  final title = args['title'];
  return MediaCardGroup(
    component: component,
    title: title is String && title.trim().isNotEmpty ? title.trim() : null,
    cards: cards,
  );
}

MediaCardSpec? _parseItem(
    String component, Map<String, dynamic> item) {
  switch (component) {
    case 'library':
      final id = _positiveInt(item['library_id']);
      return id == null ? null : MediaCardSpec.library(id);
    case 'subscription':
      final id = _positiveInt(item['subscription_id']);
      return id == null ? null : MediaCardSpec.subscription(id);
    case 'title':
      var titleRef = (item['title_ref'] as String?)?.trim() ?? '';
      if (titleRef.isEmpty) {
        final tmdbId = _positiveInt(item['tmdb_id']);
        final mediaType = item['media_type'];
        if (tmdbId == null ||
            (mediaType != 'movie' && mediaType != 'tv')) {
          return null;
        }
        titleRef = 'tmdb:$mediaType:$tmdbId';
      }
      if (!_titleRefPattern.hasMatch(titleRef)) return null;
      return MediaCardSpec.title(titleRef);
    default: // library_item
      final mediaItemId = _positiveInt(item['media_item_id']);
      if (mediaItemId == null) return null;
      final seasonRaw = item['season_number'];
      final season = seasonRaw is num && seasonRaw % 1 == 0 && seasonRaw >= 0
          ? seasonRaw.toInt()
          : null;
      final episode = _positiveInt(item['episode_number']);
      // 季集必须成对；只给一半按整部处理。
      if (season != null && episode != null) {
        return MediaCardSpec.libraryItem(mediaItemId,
            seasonNumber: season, episodeNumber: episode);
      }
      return MediaCardSpec.libraryItem(mediaItemId);
  }
}
