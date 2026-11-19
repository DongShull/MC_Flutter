/// 订阅域模型（对齐 core/model/Subscription.kt 的字段子集，手写 fromJson）。
library;

import 'package:flutter/material.dart';

class MediaBrief {
  MediaBrief({
    this.mediaItemId = 0,
    this.kind = 'movie',
    this.tmdbId,
    this.title = '',
    this.originalTitle,
    this.year,
    this.posterUrl,
    this.backdropUrl,
    this.logoUrl,
    this.status,
  });

  final int mediaItemId;
  final String kind;
  final int? tmdbId;
  final String title;
  final String? originalTitle;
  final int? year;
  final String? posterUrl;
  final String? backdropUrl;
  final String? logoUrl;
  final String? status;

  factory MediaBrief.fromJson(Map<String, dynamic> j) => MediaBrief(
        mediaItemId: (j['media_item_id'] as num?)?.toInt() ?? 0,
        kind: j['kind'] as String? ?? 'movie',
        tmdbId: (j['tmdb_id'] as num?)?.toInt(),
        title: j['title'] as String? ?? '',
        originalTitle: j['original_title'] as String?,
        year: (j['year'] as num?)?.toInt(),
        posterUrl: j['poster_url'] as String?,
        backdropUrl: j['backdrop_url'] as String?,
        logoUrl: j['logo_url'] as String?,
        status: j['status'] as String?,
      );
}

class SeasonOverview {
  SeasonOverview({
    this.seasonNumber = 0,
    this.name,
    this.airDate,
    this.episodeCount,
    this.airedCount = 0,
    this.ownedCount = 0,
  });

  final int seasonNumber;
  final String? name;
  final String? airDate;
  final int? episodeCount;
  final int airedCount;
  final int ownedCount;

  factory SeasonOverview.fromJson(Map<String, dynamic> j) => SeasonOverview(
        seasonNumber: (j['season_number'] as num?)?.toInt() ?? 0,
        name: j['name'] as String?,
        airDate: j['air_date'] as String?,
        episodeCount: (j['episode_count'] as num?)?.toInt(),
        airedCount: (j['aired_count'] as num?)?.toInt() ?? 0,
        ownedCount: (j['owned_count'] as num?)?.toInt() ?? 0,
      );

  /// 「已播/总集数」展示口径（同设计文档 04 §5.2）。
  String get episodesLine => '已播 $airedCount / ${episodeCount ?? '?'} 集';
}

class ProgressView {
  ProgressView({
    this.total = 0,
    this.wanted = 0,
    this.grabbed = 0,
    this.downloaded = 0,
    this.imported = 0,
    this.upgrading = 0,
  });

  final int total;
  final int wanted;
  final int grabbed;
  final int downloaded;
  final int imported;
  final int upgrading;

  factory ProgressView.fromJson(Map<String, dynamic> j) => ProgressView(
        total: (j['total'] as num?)?.toInt() ?? 0,
        wanted: (j['wanted'] as num?)?.toInt() ?? 0,
        grabbed: (j['grabbed'] as num?)?.toInt() ?? 0,
        downloaded: (j['downloaded'] as num?)?.toInt() ?? 0,
        imported: (j['imported'] as num?)?.toInt() ?? 0,
        upgrading: (j['upgrading'] as num?)?.toInt() ?? 0,
      );
}

class WantedView {
  WantedView({
    this.id = 0,
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.status = 'wanted',
    this.airDate,
    this.grabbedAt,
    this.downloadedAt,
    this.importedAt,
    this.lastSearchAt,
    this.lastRejectReason,
    this.infoHash,
    this.grabTitle,
  });

  final int id;
  final int seasonNumber;
  final int episodeNumber;
  final String status;
  final String? airDate;
  final String? grabbedAt;
  final String? downloadedAt;
  final String? importedAt;
  final String? lastSearchAt;
  final String? lastRejectReason;
  final String? infoHash;
  final String? grabTitle;

  factory WantedView.fromJson(Map<String, dynamic> j) => WantedView(
        id: (j['id'] as num?)?.toInt() ?? 0,
        seasonNumber: (j['season_number'] as num?)?.toInt() ?? 0,
        episodeNumber: (j['episode_number'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'wanted',
        airDate: j['air_date'] as String?,
        grabbedAt: j['grabbed_at'] as String?,
        downloadedAt: j['downloaded_at'] as String?,
        importedAt: j['imported_at'] as String?,
        lastSearchAt: j['last_search_at'] as String?,
        lastRejectReason: j['last_reject_reason'] as String?,
        infoHash: j['info_hash'] as String?,
        grabTitle: j['grab_title'] as String?,
      );
}

class SubscriptionView {
  SubscriptionView({
    this.id = 0,
    MediaBrief? media,
    this.status = '',
    this.selectedSeasons = const [],
    this.followFuture = false,
    this.ruleSetId,
    this.libraryId,
    ProgressView? progress,
    this.seasonCollection = const [],
    this.wanted = const [],
    this.canManage = true,
    this.selectionMode = 'rules',
  })  : media = media ?? MediaBrief(),
        progress = progress ?? ProgressView();

  final int id;
  final MediaBrief media;
  final String status;
  final List<int> selectedSeasons;
  final bool followFuture;
  final int? ruleSetId;
  final int? libraryId;
  final ProgressView progress;
  final List<SeasonOverview> seasonCollection;
  final List<WantedView> wanted;
  final bool canManage;
  final String selectionMode;

  factory SubscriptionView.fromJson(Map<String, dynamic> j) => SubscriptionView(
        id: (j['id'] as num?)?.toInt() ?? 0,
        media: MediaBrief.fromJson((j['media'] as Map<String, dynamic>?) ?? const {}),
        status: j['status'] as String? ?? '',
        selectedSeasons: (j['selected_seasons'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList(),
        followFuture: j['follow_future'] as bool? ?? false,
        ruleSetId: (j['rule_set_id'] as num?)?.toInt(),
        libraryId: (j['library_id'] as num?)?.toInt(),
        progress: ProgressView.fromJson((j['progress'] as Map<String, dynamic>?) ?? const {}),
        seasonCollection: (j['season_collection'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SeasonOverview.fromJson)
            .toList(),
        wanted: (j['wanted'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WantedView.fromJson)
            .toList(),
        canManage: j['can_manage'] as bool? ?? true,
        selectionMode: j['selection_mode'] as String? ?? 'rules',
      );
}

/// GET /subscriptions/{id}/activities → SubActivityView
class SubActivityView {
  SubActivityView({this.id = 0, this.type = '', this.message = '', this.createdAt});

  final int id;
  final String type;
  final String message;
  final String? createdAt;

  factory SubActivityView.fromJson(Map<String, dynamic> j) => SubActivityView(
        id: (j['id'] as num?)?.toInt() ?? 0,
        type: j['type'] as String? ?? '',
        message: j['message'] as String? ?? '',
        createdAt: j['created_at'] as String?,
      );
}

/// GET /rule-sets → RuleSetView（规则组只有超管可读）
class RuleSetView {
  RuleSetView({
    this.id = 0,
    this.name = '',
    this.isDefault = false,
    this.referenceCount = 0,
    this.spec,
  });

  final int id;
  final String name;
  final bool isDefault;
  final int referenceCount;
  final Map<String, dynamic>? spec;

  factory RuleSetView.fromJson(Map<String, dynamic> j) => RuleSetView(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        isDefault: j['is_default'] as bool? ?? false,
        referenceCount: (j['reference_count'] as num?)?.toInt() ?? 0,
        spec: j['spec'] as Map<String, dynamic>?,
      );
}

/// POST /subscriptions/title-preview → PrepareView（幂等预检）
class PrepareView {
  PrepareView({
    this.status = 'not_found',
    this.media,
    this.seasons = const [],
    this.existingSubscriptionId,
    this.movieOwned = false,
    this.suggestedSeasons = const [],
  });

  final String status;
  final MediaBrief? media;
  final List<SeasonOverview> seasons;
  final int? existingSubscriptionId;
  final bool movieOwned;
  final List<int> suggestedSeasons;

  factory PrepareView.fromJson(Map<String, dynamic> j) => PrepareView(
        status: j['status'] as String? ?? 'not_found',
        media: j['media'] is Map<String, dynamic>
            ? MediaBrief.fromJson(j['media'] as Map<String, dynamic>)
            : null,
        seasons: (j['seasons'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SeasonOverview.fromJson)
            .toList(),
        existingSubscriptionId: (j['existing_subscription_id'] as num?)?.toInt(),
        movieOwned: j['movie_owned'] as bool? ?? false,
        suggestedSeasons: (j['suggested_seasons'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList(),
      );
}

/// GET /subscriptions/{id}/items → 订阅墙资源条目（服务端结构宽松，保留原 Map）。
class WallItem {
  WallItem(this.raw);

  final Map<String, dynamic> raw;

  String get title => raw['title'] as String? ?? raw['name'] as String? ?? '';
  String? get posterUrl => raw['poster_url'] as String? ?? raw['poster'] as String?;
  String? get kind => raw['kind'] as String?;
  int? get seasonNumber => (raw['season_number'] as num?)?.toInt();
}

// ── 状态唯一说法与配色（对齐 core/designsystem/SubscriptionStatus.kt） ──

/// 状态徽标文字：completed→(剧集?已收齐:已入库) / paused→已暂停 / 其余→追踪中。
String subscriptionStatusLabel(SubscriptionView sub) {
  switch (sub.status) {
    case 'completed':
      return sub.media.kind == 'tv' ? '已收齐' : '已入库';
    case 'paused':
      return '已暂停';
    default:
      return '追踪中';
  }
}

/// 状态徽标颜色：completed→绿 / paused→黄 / 其余→#6AA7FF。
Color subscriptionStatusColor(SubscriptionView sub) {
  switch (sub.status) {
    case 'completed':
      return const Color(0xFF34C77B);
    case 'paused':
      return const Color(0xFFF5B84C);
    default:
      return const Color(0xFF6AA7FF);
  }
}

/// 进度一句话（progressNote 同款口径）。
String subscriptionProgressNote(SubscriptionView sub) {
  final p = sub.progress;
  if (sub.status == 'paused') return '暂停追踪';
  final inPipeline = p.grabbed + p.downloaded;
  final isMovie = sub.media.kind == 'movie';
  if (p.wanted == 0) {
    if (isMovie) {
      if (p.imported > 0) return '已入库';
      if (inPipeline > 0) return '下载安排中';
      return '已收齐';
    }
    if (inPipeline > 0) return '$inPipeline 集下载中 · 已入库 ${p.imported}';
    if (sub.status == 'active') return '等待新集播出';
    return p.imported > 0 ? '全部 ${p.total} 集已入库' : '全部 ${p.total} 集已安排';
  }
  if (isMovie) return '正在寻找资源';
  return '还缺 ${p.wanted} 集 · 已入库 ${p.imported}';
}

/// 追踪工单的中文调度解释（对齐 SubscriptionDetailContent.downloadNote 口径）。
String wantedStatusNote(WantedView w) {
  switch (w.status) {
    case 'imported':
      return '已入库';
    case 'downloaded':
      return '已下载，等待入库';
    case 'grabbed':
      return '已在下载器中，正在下载';
    case 'failed':
      return '下载任务出错，稍后自动重试';
    case 'rejected':
      final reason = w.lastRejectReason;
      if (reason != null && reason.isNotEmpty) return '资源被过滤：$reason';
      return '候选资源未达规则要求';
    default:
      return w.airDate == null ? '正在寻找资源' : '等待资源出现';
  }
}
