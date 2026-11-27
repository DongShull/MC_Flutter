/// 订阅域模型与纯展示逻辑（1:1 对齐 iOS `Models.swift`、`SmartSubscription.swift` 与 `SubscriptionPresentation.swift`）。
library;

import 'package:flutter/material.dart';

import '../../../core/api/subscriptions_api.dart';
import '../../../core/designsystem/rule_set_editor_sheet.dart';

// ── 语义色（对齐 iOS `SubsColor` / Web 银玻璃） ──

abstract final class SubsColor {
  static const ok = Color(0xFF4ADE80);
  static const info = Color(0xFF7FB0FF);
  static const infoSoft = Color(0xFF6AA7FF);
  static const warn = Color(0xFFF5C451);
  static const danger = Color(0xFFFF6B6B);
  static const upgrade = Color(0xFF2DD4BF);
  static const upgradeInFlight = Color(0xFF34D399);
  static const neutral = Color(0xFF9CA3AF);
  static const reason = Color(0xFFFF8A8A);
}

// ── 基础域模型 ──

class MediaBrief {
  MediaBrief({
    this.mediaItemId = 0,
    this.kind = 'movie',
    this.tmdbId,
    this.doubanId,
    this.title = '',
    this.originalTitle,
    this.englishTitle,
    this.year,
    this.posterUrl,
    this.backdropUrl,
    this.logoUrl,
    this.status,
  });

  final int mediaItemId;
  final String kind;
  final int? tmdbId;
  final String? doubanId;
  final String title;
  final String? originalTitle;
  final String? englishTitle;
  final int? year;
  final String? posterUrl;
  final String? backdropUrl;
  final String? logoUrl;
  final String? status;

  factory MediaBrief.fromJson(Map<String, dynamic> j) => MediaBrief(
        mediaItemId: (j['media_item_id'] as num?)?.toInt() ?? 0,
        kind: j['kind'] as String? ?? 'movie',
        tmdbId: (j['tmdb_id'] as num?)?.toInt(),
        doubanId: j['douban_id']?.toString(),
        title: j['title'] as String? ?? '',
        originalTitle: j['original_title'] as String?,
        englishTitle: j['english_title'] as String?,
        year: (j['year'] as num?)?.toInt(),
        posterUrl: j['poster_url'] as String?,
        backdropUrl: j['backdrop_url'] as String?,
        logoUrl: j['logo_url'] as String?,
        status: j['status'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'media_item_id': mediaItemId,
        'kind': kind,
        if (tmdbId != null) 'tmdb_id': tmdbId,
        if (doubanId != null) 'douban_id': doubanId,
        'title': title,
        if (originalTitle != null) 'original_title': originalTitle,
        if (englishTitle != null) 'english_title': englishTitle,
        if (year != null) 'year': year,
        if (posterUrl != null) 'poster_url': posterUrl,
        if (backdropUrl != null) 'backdrop_url': backdropUrl,
        if (logoUrl != null) 'logo_url': logoUrl,
        if (status != null) 'status': status,
      };
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

  Map<String, dynamic> toJson() => {
        'season_number': seasonNumber,
        if (name != null) 'name': name,
        if (airDate != null) 'air_date': airDate,
        if (episodeCount != null) 'episode_count': episodeCount,
        'aired_count': airedCount,
        'owned_count': ownedCount,
      };

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

  Map<String, dynamic> toJson() => {
        'total': total,
        'wanted': wanted,
        'grabbed': grabbed,
        'downloaded': downloaded,
        'imported': imported,
        'upgrading': upgrading,
      };
}

class EpisodeWindowView {
  const EpisodeWindowView({
    required this.seasonNumber,
    required this.start,
    this.end,
    this.total = 0,
    this.airing,
  });

  final int seasonNumber;
  final int start;
  final int? end;
  final int total;
  final bool? airing;

  factory EpisodeWindowView.fromJson(Map<String, dynamic> j) =>
      EpisodeWindowView(
        seasonNumber: (j['season_number'] as num?)?.toInt() ?? 0,
        start: (j['start'] as num?)?.toInt() ?? 1,
        end: (j['end'] as num?)?.toInt(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        airing: j['airing'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'season_number': seasonNumber,
        'start': start,
        if (end != null) 'end': end,
        'total': total,
        if (airing != null) 'airing': airing,
      };
}

class ResourceTimingView {
  const ResourceTimingView({
    required this.siteId,
    this.torrentId = '',
    this.publishTime,
    this.firstSeenAt,
    this.submittedAt = '',
    this.publishToSeenSeconds,
    this.seenToSubmitSeconds,
    this.publishToSubmitSeconds,
    this.dryRun = false,
  });

  final String siteId;
  final String torrentId;
  final String? publishTime;
  final String? firstSeenAt;
  final String submittedAt;
  final int? publishToSeenSeconds;
  final int? seenToSubmitSeconds;
  final int? publishToSubmitSeconds;
  final bool dryRun;

  factory ResourceTimingView.fromJson(Map<String, dynamic> j) =>
      ResourceTimingView(
        siteId: (j['site_id'] ?? '').toString(),
        torrentId: (j['torrent_id'] ?? '').toString(),
        publishTime: j['publish_time'] as String?,
        firstSeenAt: j['first_seen_at'] as String?,
        submittedAt: (j['submitted_at'] ?? '').toString(),
        publishToSeenSeconds: (j['publish_to_seen_seconds'] as num?)?.toInt(),
        seenToSubmitSeconds: (j['seen_to_submit_seconds'] as num?)?.toInt(),
        publishToSubmitSeconds:
            (j['publish_to_submit_seconds'] as num?)?.toInt(),
        dryRun: j['dry_run'] == true,
      );
}

class WantedUpgradeView {
  const WantedUpgradeView({
    this.active = false,
    this.currentLabel = '',
    this.targetLabel = '',
    this.searchAttempts = 0,
    this.indeterminate = false,
  });

  final bool active;
  final String currentLabel;
  final String targetLabel;
  final int searchAttempts;
  final bool indeterminate;

  factory WantedUpgradeView.fromJson(Map<String, dynamic> j) =>
      WantedUpgradeView(
        active: j['active'] == true,
        currentLabel: (j['current_label'] ?? '').toString(),
        targetLabel: (j['target_label'] ?? '').toString(),
        searchAttempts: (j['search_attempts'] as num?)?.toInt() ?? 0,
        indeterminate: j['indeterminate'] == true,
      );
}

class WantedView {
  WantedView({
    this.id = 0,
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.status = 'wanted',
    this.airDate,
    this.priority = 0,
    this.nextSearchAt,
    this.searchAttempts = 0,
    this.grabbedAt,
    this.downloadedAt,
    this.importedAt,
    this.lastSearchAt,
    this.lastRejectReason,
    this.infoHash,
    this.grabTitle,
    this.releaseForecast,
    this.resourceTiming,
    this.upgrade,
    this.selectionState,
    this.selectionVersion,
    this.provisional = false,
  });

  final int id;
  final int seasonNumber;
  final int episodeNumber;
  final String status;
  final String? airDate;
  final int priority;
  final String? nextSearchAt;
  final int searchAttempts;
  final String? grabbedAt;
  final String? downloadedAt;
  final String? importedAt;
  final String? lastSearchAt;
  final String? lastRejectReason;
  final String? infoHash;
  final String? grabTitle;
  final Map<String, dynamic>? releaseForecast;
  final ResourceTimingView? resourceTiming;
  final WantedUpgradeView? upgrade;
  final Map<String, dynamic>? selectionState;
  final int? selectionVersion;
  final bool provisional;

  factory WantedView.fromJson(Map<String, dynamic> j) => WantedView(
        id: (j['id'] as num?)?.toInt() ?? 0,
        seasonNumber: (j['season_number'] as num?)?.toInt() ?? 0,
        episodeNumber: (j['episode_number'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'wanted',
        airDate: j['air_date'] as String?,
        priority: (j['priority'] as num?)?.toInt() ?? 0,
        nextSearchAt: j['next_search_at'] as String?,
        searchAttempts: (j['search_attempts'] as num?)?.toInt() ?? 0,
        grabbedAt: j['grabbed_at'] as String?,
        downloadedAt: j['downloaded_at'] as String?,
        importedAt: j['imported_at'] as String?,
        lastSearchAt: j['last_search_at'] as String?,
        lastRejectReason: j['last_reject_reason'] as String?,
        infoHash: j['info_hash'] as String?,
        grabTitle: j['grab_title'] as String?,
        releaseForecast: j['release_forecast'] is Map
            ? (j['release_forecast'] as Map).cast<String, dynamic>()
            : null,
        resourceTiming: j['resource_timing'] is Map
            ? ResourceTimingView.fromJson(
                (j['resource_timing'] as Map).cast<String, dynamic>(),
              )
            : null,
        upgrade: j['upgrade'] is Map
            ? WantedUpgradeView.fromJson(
                (j['upgrade'] as Map).cast<String, dynamic>(),
              )
            : null,
        selectionState: j['selection_state'] is Map
            ? (j['selection_state'] as Map).cast<String, dynamic>()
            : null,
        selectionVersion: (j['selection_version'] as num?)?.toInt(),
        provisional: j['provisional'] == true,
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
    this.episodeWindows = const [],
    this.wanted = const [],
    this.canManage = true,
    this.selectionMode = 'rules',
    this.smartPolicy,
    this.smartStatus,
    this.smartSubtitle,
    this.smartQualityNote,
    this.forecastPending = false,
    this.createdAt,
    this.updatedAt,
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
  final List<EpisodeWindowView> episodeWindows;
  final List<WantedView> wanted;
  final bool canManage;
  final String selectionMode;
  final Map<String, dynamic>? smartPolicy;
  final String? smartStatus;
  final SmartSubtitleView? smartSubtitle;
  final String? smartQualityNote;
  final bool forecastPending;
  final String? createdAt;
  final String? updatedAt;

  bool get isSmart => selectionMode == 'smart';

  SmartPreferences? get smartPreferences {
    if (smartPolicy == null) return null;
    try {
      return SmartPreferences.fromJson(smartPolicy!);
    } catch (_) {
      return null;
    }
  }

  /// 智能模式异常提示（与 iOS `SubscriptionDetailView.smartNotice` 同口径）。
  String? get smartNotice {
    if (!isSmart || smartStatus == null || smartStatus == 'active') return null;
    switch (smartStatus) {
      case 'invalid_policy':
        return '智能选择策略异常，当前无法自动选源，请检查智能默认设置。';
      case 'shadow':
        return '智能选择正处于影子模式（仅对比记录，暂不自动投递）。';
      default:
        return '智能选择已在服务端停用，当前暂不会自动选源。';
    }
  }

  factory SubscriptionView.fromJson(Map<String, dynamic> j) => SubscriptionView(
        id: (j['id'] as num?)?.toInt() ?? 0,
        media: MediaBrief.fromJson(
          (j['media'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        status: j['status'] as String? ?? '',
        selectedSeasons: (j['selected_seasons'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList(),
        followFuture: j['follow_future'] as bool? ?? false,
        ruleSetId: (j['rule_set_id'] as num?)?.toInt(),
        libraryId: (j['library_id'] as num?)?.toInt(),
        progress: ProgressView.fromJson(
          (j['progress'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        seasonCollection:
            (j['season_collection'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((e) => SeasonOverview.fromJson(e.cast<String, dynamic>()))
                .toList(),
        episodeWindows: (j['episode_windows'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => EpisodeWindowView.fromJson(e.cast<String, dynamic>()))
            .toList(),
        wanted: (j['wanted'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => WantedView.fromJson(e.cast<String, dynamic>()))
            .toList(),
        canManage: j['can_manage'] as bool? ?? true,
        selectionMode: j['selection_mode'] as String? ?? 'rules',
        smartPolicy: j['smart_policy'] is Map
            ? (j['smart_policy'] as Map).cast<String, dynamic>()
            : null,
        smartStatus: j['smart_status'] as String?,
        smartSubtitle: j['smart_subtitle'] is Map
            ? SmartSubtitleView.fromJson(
                (j['smart_subtitle'] as Map).cast<String, dynamic>(),
              )
            : null,
        smartQualityNote: j['smart_quality_note'] as String?,
        forecastPending: j['forecast_pending'] == true,
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'media': media.toJson(),
        'status': status,
        'selected_seasons': selectedSeasons,
        'follow_future': followFuture,
        if (ruleSetId != null) 'rule_set_id': ruleSetId,
        if (libraryId != null) 'library_id': libraryId,
        'progress': progress.toJson(),
        'season_collection': seasonCollection.map((s) => s.toJson()).toList(),
        'episode_windows': episodeWindows.map((w) => w.toJson()).toList(),
        'can_manage': canManage,
        'selection_mode': selectionMode,
        if (smartPolicy != null) 'smart_policy': smartPolicy,
        if (smartStatus != null) 'smart_status': smartStatus,
        if (smartQualityNote != null) 'smart_quality_note': smartQualityNote,
        'forecast_pending': forecastPending,
        if (createdAt != null) 'created_at': createdAt,
        if (updatedAt != null) 'updated_at': updatedAt,
      };
}

/// `GET /subscriptions/{id}/activities` → `SubActivityView`
class SubActivityView {
  SubActivityView({
    this.id = 0,
    this.type = '',
    this.message = '',
    this.payload = const {},
    this.createdAt,
    this.wantedItemId,
  });

  final int id;
  final String type;
  final String message;
  final Map<String, dynamic> payload;
  final String? createdAt;
  final int? wantedItemId;

  factory SubActivityView.fromJson(Map<String, dynamic> j) => SubActivityView(
        id: (j['id'] as num?)?.toInt() ?? 0,
        type: j['type'] as String? ?? '',
        message: j['message'] as String? ?? '',
        payload: j['payload'] is Map
            ? (j['payload'] as Map).cast<String, dynamic>()
            : const {},
        createdAt: j['created_at'] as String?,
        wantedItemId: (j['wanted_item_id'] as num?)?.toInt(),
      );
}

/// `GET /subscriptions/{id}/active-downloads` → 实时下载快照
class SubscriptionDownloadView {
  const SubscriptionDownloadView({
    required this.infoHash,
    this.name,
    this.progress,
    this.sizeBytes,
    this.dlspeedBytes,
    this.etaSeconds,
    this.state = 'unknown',
    this.errorMessage,
    this.downloaderName,
  });

  final String infoHash;
  final String? name;
  final double? progress;
  final int? sizeBytes;
  final int? dlspeedBytes;
  final int? etaSeconds;
  final String state;
  final String? errorMessage;
  final String? downloaderName;

  factory SubscriptionDownloadView.fromJson(Map<String, dynamic> j) =>
      SubscriptionDownloadView(
        infoHash: (j['info_hash'] ?? '').toString(),
        name: j['name'] as String?,
        progress: (j['progress'] as num?)?.toDouble(),
        sizeBytes: (j['size_bytes'] as num?)?.toInt(),
        dlspeedBytes: (j['dlspeed_bytes'] as num?)?.toInt(),
        etaSeconds: (j['eta_seconds'] as num?)?.toInt(),
        state: (j['state'] ?? 'unknown').toString(),
        errorMessage: j['error_message'] as String?,
        downloaderName: j['downloader_name'] as String?,
      );
}

/// `GET /rule-sets` → `RuleSetView`
class RuleSetView {
  RuleSetView({
    this.id = 0,
    this.name = '',
    this.isDefault = false,
    this.referenceCount = 0,
    this.spec,
    this.matchRules = const [],
  });

  final int id;
  final String name;
  final bool isDefault;
  final int referenceCount;
  final Map<String, dynamic>? spec;
  final List<Map<String, dynamic>> matchRules;

  RuleSetSpec get typedSpec => RuleSetSpec.fromJson(spec);
  String? get upgradeTarget => RuleSetSpecFormatter.upgradeTargetLabel(typedSpec);

  SubscribeRuleSetOption toOption() => SubscribeRuleSetOption(
        id: id,
        name: name,
        isDefault: isDefault,
        referenceCount: referenceCount,
        spec: spec ?? const {},
        matchRules: matchRules,
      );

  factory RuleSetView.fromJson(Map<String, dynamic> j) => RuleSetView(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        isDefault: j['is_default'] as bool? ?? false,
        referenceCount: (j['reference_count'] as num?)?.toInt() ?? 0,
        spec: j['spec'] is Map
            ? (j['spec'] as Map).cast<String, dynamic>()
            : null,
        matchRules: (j['match_rules'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
      );
}

/// `POST /subscriptions/title-preview` → `PrepareView`
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
        media: j['media'] is Map
            ? MediaBrief.fromJson((j['media'] as Map).cast<String, dynamic>())
            : null,
        seasons: (j['seasons'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => SeasonOverview.fromJson(e.cast<String, dynamic>()))
            .toList(),
        existingSubscriptionId:
            (j['existing_subscription_id'] as num?)?.toInt(),
        movieOwned: j['movie_owned'] as bool? ?? false,
        suggestedSeasons: (j['suggested_seasons'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList(),
      );
}

/// 兼容保留：单订阅墙条目（`/subscriptions/wall/:id`）。
class WallItem {
  WallItem(this.raw);

  final Map<String, dynamic> raw;

  String get title => raw['title'] as String? ?? raw['name'] as String? ?? '';
  String? get posterUrl =>
      raw['poster_url'] as String? ?? raw['poster'] as String?;
  String? get kind => raw['kind'] as String?;
  int? get seasonNumber => (raw['season_number'] as num?)?.toInt();
}

// ── 首页 / 日程 / 刚刚入库模型 ──

class ReleaseForecastView {
  ReleaseForecastView({
    this.version,
    this.targetAirDate,
    this.predictedAt,
    this.windowStart,
    this.windowEnd,
    this.confidence = '',
    this.siteIds = const [],
  });

  final int? version;
  final String? targetAirDate;
  final String? predictedAt;
  final String? windowStart;
  final String? windowEnd;
  final String confidence;
  final List<String> siteIds;

  bool get usable => confidence != 'volatile';

  factory ReleaseForecastView.fromJson(Map<String, dynamic> j) =>
      ReleaseForecastView(
        version: (j['version'] as num?)?.toInt(),
        targetAirDate: j['target_air_date'] as String?,
        predictedAt: j['predicted_at'] as String?,
        windowStart: j['window_start'] as String?,
        windowEnd: j['window_end'] as String?,
        confidence: j['confidence'] as String? ?? '',
        siteIds: (j['sites'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => e['site_id']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        if (version != null) 'version': version,
        if (targetAirDate != null) 'target_air_date': targetAirDate,
        if (predictedAt != null) 'predicted_at': predictedAt,
        if (windowStart != null) 'window_start': windowStart,
        if (windowEnd != null) 'window_end': windowEnd,
        'confidence': confidence,
        if (siteIds.isNotEmpty)
          'sites': [for (final s in siteIds) {'site_id': s}],
      };
}

class TodayArrivalView {
  TodayArrivalView({
    this.subscriptionId = 0,
    this.wantedId = 0,
    this.mediaTitle = '',
    this.mediaKind = 'movie',
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.status = 'wanted',
    this.airDate,
    this.expectedDay,
    this.daysAhead = 0,
    this.forecast,
    this.nextProbeAt,
    this.infoHash,
    this.grabbedAt,
    this.downloadedAt,
    this.estimatedReleaseToImportMinutes = 0,
    this.estimatedDownloadToImportMinutes = 0,
  });

  final int subscriptionId;
  final int wantedId;
  final String mediaTitle;
  final String mediaKind;
  final int seasonNumber;
  final int episodeNumber;
  final String status;
  final String? airDate;
  final String? expectedDay;
  final int daysAhead;
  final ReleaseForecastView? forecast;
  final String? nextProbeAt;
  final String? infoHash;
  final String? grabbedAt;
  final String? downloadedAt;
  final int estimatedReleaseToImportMinutes;
  final int estimatedDownloadToImportMinutes;

  factory TodayArrivalView.fromJson(Map<String, dynamic> j) => TodayArrivalView(
        subscriptionId: (j['subscription_id'] as num?)?.toInt() ?? 0,
        wantedId: (j['wanted_id'] as num?)?.toInt() ?? 0,
        mediaTitle: j['media_title'] as String? ?? '',
        mediaKind: j['media_kind'] as String? ?? 'movie',
        seasonNumber: (j['season_number'] as num?)?.toInt() ?? 0,
        episodeNumber: (j['episode_number'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'wanted',
        airDate: j['air_date'] as String?,
        expectedDay: j['expected_day'] as String?,
        daysAhead: (j['days_ahead'] as num?)?.toInt() ?? 0,
        forecast: j['release_forecast'] is Map
            ? ReleaseForecastView.fromJson(
                (j['release_forecast'] as Map).cast<String, dynamic>(),
              )
            : null,
        nextProbeAt: j['next_probe_at'] as String?,
        infoHash: j['info_hash'] as String?,
        grabbedAt: j['grabbed_at'] as String?,
        downloadedAt: j['downloaded_at'] as String?,
        estimatedReleaseToImportMinutes:
            (j['estimated_release_to_import_minutes'] as num?)?.toInt() ?? 0,
        estimatedDownloadToImportMinutes:
            (j['estimated_download_to_import_minutes'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'subscription_id': subscriptionId,
        'wanted_id': wantedId,
        'media_title': mediaTitle,
        'media_kind': mediaKind,
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        'status': status,
        if (airDate != null) 'air_date': airDate,
        if (expectedDay != null) 'expected_day': expectedDay,
        'days_ahead': daysAhead,
        if (forecast != null) 'release_forecast': forecast!.toJson(),
        if (nextProbeAt != null) 'next_probe_at': nextProbeAt,
        if (infoHash != null) 'info_hash': infoHash,
        if (grabbedAt != null) 'grabbed_at': grabbedAt,
        if (downloadedAt != null) 'downloaded_at': downloadedAt,
        'estimated_release_to_import_minutes': estimatedReleaseToImportMinutes,
        'estimated_download_to_import_minutes':
            estimatedDownloadToImportMinutes,
      };
}

class RecentArrivalUnit {
  RecentArrivalUnit({this.seasonNumber = 0, this.episodeNumber = 0});

  final int seasonNumber;
  final int episodeNumber;

  factory RecentArrivalUnit.fromJson(Map<String, dynamic> j) =>
      RecentArrivalUnit(
        seasonNumber: (j['season_number'] as num?)?.toInt() ?? 0,
        episodeNumber: (j['episode_number'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
      };
}

class RecentArrivalView {
  RecentArrivalView({
    this.subscriptionId = 0,
    MediaBrief? media,
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.episodeName,
    this.stillUrl,
    this.units = const [],
    this.progressPercent,
    this.importedAt,
  }) : media = media ?? MediaBrief();

  final int subscriptionId;
  final MediaBrief media;
  final int seasonNumber;
  final int episodeNumber;
  final String? episodeName;
  final String? stillUrl;
  final List<RecentArrivalUnit> units;
  final int? progressPercent;
  final String? importedAt;

  factory RecentArrivalView.fromJson(Map<String, dynamic> j) =>
      RecentArrivalView(
        subscriptionId: (j['subscription_id'] as num?)?.toInt() ?? 0,
        media: j['media'] is Map
            ? MediaBrief.fromJson((j['media'] as Map).cast<String, dynamic>())
            : null,
        seasonNumber: (j['season_number'] as num?)?.toInt() ?? 0,
        episodeNumber: (j['episode_number'] as num?)?.toInt() ?? 0,
        episodeName: j['episode_name'] as String?,
        stillUrl: j['still_url'] as String?,
        units: (j['units'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => RecentArrivalUnit.fromJson(e.cast<String, dynamic>()))
            .toList(),
        progressPercent: (j['progress_percent'] as num?)?.toInt(),
        importedAt: j['imported_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'subscription_id': subscriptionId,
        'media': media.toJson(),
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        if (episodeName != null) 'episode_name': episodeName,
        if (stillUrl != null) 'still_url': stillUrl,
        'units': units.map((u) => u.toJson()).toList(),
        if (progressPercent != null) 'progress_percent': progressPercent,
        if (importedAt != null) 'imported_at': importedAt,
      };
}

class DownloadTaskView {
  DownloadTaskView({
    this.infoHash = '',
    this.etaSeconds = 0,
    this.progress,
    this.state = '',
  });

  final String infoHash;
  final int etaSeconds;
  final double? progress;
  final String state;

  factory DownloadTaskView.fromJson(Map<String, dynamic> j) => DownloadTaskView(
        infoHash: j['info_hash'] as String? ?? '',
        etaSeconds: (j['eta_seconds'] as num?)?.toInt() ?? 0,
        progress: (j['progress'] as num?)?.toDouble(),
        state: j['state'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'info_hash': infoHash,
        'eta_seconds': etaSeconds,
        if (progress != null) 'progress': progress,
        'state': state,
      };
}

class LibraryBrief {
  LibraryBrief({
    this.id = 0,
    this.name = '',
    this.kind = 'movie',
    this.isDefault = false,
  });

  final int id;
  final String name;
  final String kind;
  final bool isDefault;

  factory LibraryBrief.fromJson(Map<String, dynamic> j) => LibraryBrief(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        kind: j['kind'] as String? ?? 'movie',
        isDefault: j['is_default'] == true,
      );
}

// ── 智能选源决策状态（1:1 对齐 iOS `SmartSelection`） ──

class SmartSelection {
  SmartSelection._(this.values);

  final Map<String, dynamic> values;

  static SmartSelection? fromWanted(WantedView wanted) {
    if (wanted.status != 'wanted') return null;
    final state = wanted.selectionState;
    if (state == null || state.isEmpty) return null;
    final reason = state['reason']?.toString() ?? '';
    const allowedNoCandidate = {
      'identity_unconfirmed',
      'manual_candidate_unavailable',
      'reconciling',
      'submitting',
    };
    if (state['candidate_key'] == null &&
        !allowedNoCandidate.contains(reason)) {
      return null;
    }
    return SmartSelection._(state);
  }

  String? str(String key) {
    final v = values[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  String get reason => str('reason') ?? '';

  bool get awaitingSubtitles =>
      reason == 'awaiting_subtitles' || reason == 'deadline_awaiting_subtitles';

  String? get followingLabel {
    final raw = str('following');
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length < 3) return raw;
    const sourceMap = {
      '1': '电视录制',
      '2': '压制',
      '3': 'WEB-DL',
      '4': '蓝光',
      '5': 'Remux',
      '6': '原盘',
    };
    final src = sourceMap[parts[2]] ?? '未知片源';
    return '${parts[0]} · ${parts[1]} · $src';
  }

  ({String label, String note}) get presentation {
    final manualExt = values['manual_extended'] == true;
    if (reason == 'user_extended' ||
        (manualExt &&
            const {'observing', 'waiting_target', 'waiting_series'}
                .contains(reason))) {
      return (label: '继续观察', note: '已按你的要求延长等待，继续观察更合适版本');
    }
    switch (reason) {
      case 'awaiting_subtitles':
        final count = (values['subtitle_blocked'] as num?)?.toInt() ?? 1;
        return (label: '等待字幕', note: '已发现 $count 个候选资源，正在等待带中文字幕版本');
      case 'deadline_awaiting_subtitles':
        return (label: '等待字幕', note: '已到等待上限，仍未出现带中文字幕版本，可先下原版');
      case 'identity_unconfirmed':
        return (label: '核实匹配', note: '发现疑似资源但未能确认与本片完全一致，已暂停自动提交');
      case 'waiting_target':
        return (label: '等目标版', note: '已发现可用候选，正在等待更接近目标画质的版本');
      case 'waiting_series':
        return (label: '等系列版', note: '已发现候选，正在等待与本剧一致的发行规格');
      case 'manual_requested':
        return (label: '提交中', note: '已收到手动选定指令，正在排队提交');
      case 'manual_candidate_unavailable':
        return (label: '重新评估', note: '先前选定的候选已不可用，正在重新选源');
      case 'reconciling':
        return (label: '核对中', note: '正在核对下载器与媒体库状态');
      case 'candidate_rejected':
        return (label: '继续搜索', note: '候选资源未通过最终校验，继续寻找');
      case 'submitting':
        return (label: '提交中', note: '已选定最佳候选，正在提交给下载器');
      case 'deadline_fallback':
        return (label: '准备提交', note: '已到等待上限，准备提交当前最佳候选');
      case 'published_window_elapsed':
        return (label: '准备提交', note: '发布观察窗口已结束，准备提交当前最佳候选');
      case 'observation_finished':
        return (label: '准备提交', note: '观察结束，准备提交当前最佳候选');
      case 'target_available':
        return (label: '准备提交', note: '目标档位已出现，准备立即提交');
      default:
        return (label: '观察中', note: '已发现可用候选，正在观察是否会出现更佳版本');
    }
  }
}

// ── 状态唯一说法与格式化（1:1 对齐 iOS `SubsFormat` & `WantedLogic`） ──

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

Color subscriptionStatusColor(SubscriptionView sub) {
  switch (sub.status) {
    case 'completed':
      return SubsColor.ok;
    case 'paused':
      return SubsColor.warn;
    default:
      return SubsColor.infoSoft;
  }
}

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

String wantedStatusNote(WantedView w) => WantedLogic.presentation(w).note;

abstract final class SubsFormat {
  static DateTime? date(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.length == 10 && raw[4] == '-' && raw[7] == '-') {
      return DateTime.tryParse('${raw}T00:00:00Z');
    }
    return DateTime.tryParse(raw);
  }

  static String pad(int v) => v.toString().padLeft(2, '0');

  static String dateTime(String? raw) {
    final d = date(raw)?.toLocal();
    if (d == null) return '—';
    return '${d.year}/${pad(d.month)}/${pad(d.day)} ${pad(d.hour)}:${pad(d.minute)}';
  }

  static String relative(String? raw, {DateTime? now}) {
    final d = date(raw);
    if (d == null) return '从未';
    final n = now ?? DateTime.now();
    final diffSec = n.difference(d).inSeconds;
    if (diffSec < 0) {
      final ahead = -diffSec;
      if (ahead < 60) return '1 分钟内';
      if (ahead < 3600) return '${(ahead / 60).round()} 分钟后';
      if (ahead < 86400) return '${(ahead / 3600).round()} 小时后';
      return '${(ahead / 86400).round()} 天后';
    }
    if (diffSec < 45) return '几秒前';
    if (diffSec < 3600) return '${(diffSec / 60).round()} 分钟前';
    if (diffSec < 86400) return '${(diffSec / 3600).round()} 小时前';
    if (diffSec < 86400 * 30) return '${(diffSec / 86400).round()} 天前';
    if (diffSec < 86400 * 365) return '${(diffSec / (86400 * 30)).round()} 个月前';
    return '${(diffSec / (86400 * 365)).round()} 年前';
  }

  static String duration(int seconds) {
    if (seconds <= 0) return '—';
    if (seconds < 60) return '$seconds 秒';
    if (seconds < 3600) return '${(seconds / 60).round()} 分钟';
    final hours = seconds / 3600;
    if (hours == hours.roundToDouble()) return '${hours.round()} 小时';
    return '${hours.toStringAsFixed(1)} 小时';
  }

  static String seasonName(int season) =>
      season == 0 ? '特别篇' : '第 $season 季';

  static String seasonList(List<int> seasons) {
    final sorted = [...seasons]..sort();
    if (sorted.isEmpty) return '未选季';
    if (sorted.length == 1) return seasonName(sorted.first);
    if (sorted.every((s) => s > 0)) {
      return '第 ${sorted.join('、')} 季';
    }
    return sorted.map(seasonName).join('、');
  }

  /// 完结季「从第 N 集起」的窗口说明。
  static List<String> fromWindowNotes(List<EpisodeWindowView> windows) {
    return windows
        .where((w) => w.end == null && w.airing == false)
        .map((w) => '${seasonName(w.seasonNumber)}从第 ${w.start} 集起追更，此前已播剧集不计入进度。')
        .toList();
  }

  static String bytes(int? value) {
    if (value == null || value < 0) return '—';
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var n = value.toDouble();
    var idx = 0;
    while (n >= 1024 && idx < units.length - 1) {
      n /= 1024;
      idx++;
    }
    final text =
        (n >= 100 || idx == 0) ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
    return '$text ${units[idx]}';
  }
}

// ── 6 站里程碑链模型与推导（1:1 对齐 iOS `WantedLogic`） ──

enum MilestoneState { done, now, todo, fail }

class Milestone {
  const Milestone({
    required this.key,
    required this.label,
    required this.state,
    this.time = '',
    required this.detail,
    this.why,
    this.sources = const [],
  });

  final String key;
  final String label;
  final MilestoneState state;
  final String time;
  final String detail;
  final String? why;
  final List<String> sources;
}

class WantedPresentation {
  const WantedPresentation({
    required this.label,
    required this.color,
    required this.note,
    this.short,
  });

  final String label;
  final Color color;
  final String note;
  final String? short;

  String get shortLabel => short ?? label;
}

abstract final class WantedLogic {
  static WantedPresentation presentation(WantedView w, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (w.status == 'imported') {
      final up = w.upgrade;
      if (up != null && up.active) {
        return WantedPresentation(
          label: '洗版中',
          color: SubsColor.upgrade,
          note: '当前 ${up.currentLabel}，正在寻找 ${up.targetLabel}',
        );
      }
      if (up != null && up.indeterminate) {
        return WantedPresentation(
          label: '已入库',
          color: SubsColor.ok,
          note: '已入库（${up.currentLabel}），无法确认档位',
        );
      }
      if (up != null) {
        return WantedPresentation(
          label: '已入库',
          color: SubsColor.ok,
          note: '已入库（${up.currentLabel} · ${SubsFormat.dateTime(w.importedAt)}）',
        );
      }
      return WantedPresentation(
        label: '已入库',
        color: SubsColor.ok,
        note: '已入库（${SubsFormat.dateTime(w.importedAt)}）',
      );
    }
    if (w.status == 'downloaded') {
      return WantedPresentation(
        label: '待入库',
        color: SubsColor.ok,
        note: '下载完成（${SubsFormat.dateTime(w.downloadedAt ?? w.grabbedAt)}），等待自动整理入库',
      );
    }
    if (w.status == 'grabbed') {
      return WantedPresentation(
        label: '已投递',
        color: SubsColor.ok,
        note: '${SubsFormat.relative(w.grabbedAt, now: current)}投递到下载器',
        short: '下载中',
      );
    }
    final smart = SmartSelection.fromWanted(w);
    if (smart != null) {
      final p = smart.presentation;
      return WantedPresentation(
        label: p.label,
        color: SubsColor.info,
        note: p.note,
      );
    }
    final due = SubsFormat.date(w.nextSearchAt);
    if (due == null) {
      return const WantedPresentation(
        label: '未定档',
        color: SubsColor.neutral,
        note: '暂无播出/上映日期，等待元数据更新',
      );
    }
    if (w.airDate != null && w.releaseForecast != null) {
      final f = ReleaseForecastView.fromJson(w.releaseForecast!);
      final winEnd = SubsFormat.date(f.windowEnd);
      if (f.version == 1 &&
          f.targetAirDate == w.airDate &&
          f.usable &&
          f.siteIds.isNotEmpty &&
          winEnd != null &&
          !winEnd.isBefore(current)) {
        final sites = f.siteIds.take(2).join('、');
        return WantedPresentation(
          label: '预测窗口',
          color: SubsColor.warn,
          note:
              '预计 ${SubsFormat.dateTime(f.windowStart)}–${SubsFormat.dateTime(f.windowEnd)} 出种（$sites）',
          short: '待出种',
        );
      }
    }
    final air = SubsFormat.date(w.airDate);
    if (air != null && air.isAfter(current)) {
      return WantedPresentation(
        label: '待播出',
        color: SubsColor.warn,
        note: '${w.airDate} 播出，预计 ${SubsFormat.dateTime(w.nextSearchAt)} 开始搜索',
      );
    }
    if (!due.isAfter(current)) {
      return WantedPresentation(
        label: '排队搜索',
        color: SubsColor.info,
        note: w.lastSearchAt != null
            ? '上次搜索 ${SubsFormat.relative(w.lastSearchAt, now: current)}，已进入本轮队列'
            : '已进入搜索队列，等待本轮检索',
        short: '排队中',
      );
    }
    if (w.lastSearchAt == null && due.difference(current).inSeconds > 3600) {
      return WantedPresentation(
        label: '已排期',
        color: SubsColor.warn,
        note: '计划于 ${SubsFormat.dateTime(w.nextSearchAt)} 开始首轮搜索',
      );
    }
    return WantedPresentation(
      label: '冷却中',
      color: SubsColor.info,
      note: '预计 ${SubsFormat.dateTime(w.nextSearchAt)} 再次搜索',
    );
  }

  static String downloadNote(SubscriptionDownloadView d) {
    if (d.state == 'missing') return '下载器中未找到该任务，巡检将自动退回重新搜索';
    final pct = d.progress != null ? '${(d.progress! * 100).floor()}%' : '';
    switch (d.state) {
      case 'completed':
        return '下载完成，等待入库';
      case 'paused':
        return pct.isEmpty ? '下载已暂停' : '已暂停 · $pct';
      case 'error':
        if (d.errorMessage != null && d.errorMessage!.isNotEmpty) {
          return pct.isEmpty
              ? '下载出错：${d.errorMessage}'
              : '下载出错（$pct）：${d.errorMessage}';
        }
        return pct.isEmpty ? '下载出错，请联系管理员检查下载器' : '下载出错（$pct），请联系管理员检查下载器';
      case 'stalled':
        return pct.isEmpty ? '下载无速度（卡住）' : '无速度 · $pct';
      default:
        final parts = <String>[if (pct.isNotEmpty) pct];
        if (d.dlspeedBytes != null && d.dlspeedBytes! > 0) {
          parts.add('${SubsFormat.bytes(d.dlspeedBytes)}/s');
        }
        if (d.etaSeconds != null && d.etaSeconds! > 0) {
          parts.add('剩余 ${SubsFormat.duration(d.etaSeconds!)}');
        }
        if (d.sizeBytes != null && parts.length <= 1) {
          parts.add(SubsFormat.bytes(d.sizeBytes));
        }
        return parts.isEmpty ? '下载中' : parts.join(' · ');
    }
  }

  static String? resourceTimingNote(
    ResourceTimingView? timing, {
    required bool previous,
  }) {
    if (timing == null) return null;
    if (timing.publishToSubmitSeconds != null &&
        timing.publishToSubmitSeconds! > 7 * 24 * 3600) {
      return null;
    }
    String delay(int sec) => sec < 60 ? '不到 1 分钟' : SubsFormat.duration(sec);
    final prefix =
        '${previous ? '上次尝试 · ' : ''}${timing.dryRun ? '[试运行] ' : ''}';
    final site = timing.siteId;
    if (timing.publishToSeenSeconds != null &&
        timing.seenToSubmitSeconds != null &&
        timing.publishToSubmitSeconds != null) {
      return '$prefix$site 出种 ${delay(timing.publishToSeenSeconds!)} 后发现，${delay(timing.seenToSubmitSeconds!)} 后投递（总计 ${delay(timing.publishToSubmitSeconds!)}）';
    }
    if (timing.publishToSubmitSeconds != null) {
      return '$prefix$site 出种 ${delay(timing.publishToSubmitSeconds!)} 后投递';
    }
    if (timing.seenToSubmitSeconds != null) {
      return '$prefix$site 发现 ${delay(timing.seenToSubmitSeconds!)} 后投递';
    }
    return null;
  }

  /// 5/6 站里程碑链：播出/上映 → 搜索 → 投递 → 下载 → 入库 → [洗版]
  static List<Milestone> milestones(
    WantedView w, {
    required bool isMovie,
    SubscriptionDownloadView? live,
    SubActivityView? failure,
    bool isSmart = false,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final chain = <Milestone>[];

    // 1. 播出 / 上映
    if (isMovie) {
      final undated = w.status == 'wanted' && w.nextSearchAt == null;
      chain.add(
        undated
            ? const Milestone(
                key: 'air',
                label: '上映',
                state: MilestoneState.now,
                detail: '暂未定档，等待上映日期更新',
              )
            : const Milestone(
                key: 'air',
                label: '上映',
                state: MilestoneState.done,
                detail: '已定档可搜',
              ),
      );
    } else if (w.airDate != null && w.airDate!.isNotEmpty) {
      final air = SubsFormat.date(w.airDate);
      final future = air != null && air.isAfter(current);
      chain.add(
        Milestone(
          key: 'air',
          label: '播出',
          state: MilestoneState.done,
          time: w.airDate!,
          detail: future ? '${w.airDate} 播出' : '已播出',
        ),
      );
    } else {
      chain.add(
        const Milestone(
          key: 'air',
          label: '播出',
          state: MilestoneState.now,
          detail: '播出日期待定',
        ),
      );
    }
    final preAir = chain.first.state == MilestoneState.now;

    // 2. 搜索
    if (w.status != 'wanted') {
      chain.add(
        Milestone(
          key: 'search',
          label: '搜索',
          state: MilestoneState.done,
          time: w.lastSearchAt != null
              ? SubsFormat.relative(w.lastSearchAt, now: current)
              : '',
          detail: w.searchAttempts > 0
              ? '搜索 ${w.searchAttempts} 轮后命中'
              : '被动发现命中',
        ),
      );
    } else if (preAir) {
      chain.add(
        const Milestone(
          key: 'search',
          label: '搜索',
          state: MilestoneState.todo,
          detail: '定档后开始自动搜索',
        ),
      );
    } else {
      final smartReason = w.selectionState?['reason']?.toString();
      chain.add(
        Milestone(
          key: 'search',
          label: '搜索',
          state: MilestoneState.now,
          time: w.searchAttempts > 0 ? '已搜 ${w.searchAttempts} 轮' : '',
          detail: presentation(w, now: current).note,
          why: smartReason == 'identity_unconfirmed'
              ? null
              : (w.lastRejectReason != null && w.lastRejectReason!.isNotEmpty
                  ? '最近过滤原因：${w.lastRejectReason}'
                  : null),
        ),
      );
    }

    // 3. 投递
    if (w.grabbedAt != null && w.grabbedAt!.isNotEmpty) {
      final timing = resourceTimingNote(w.resourceTiming, previous: false);
      final sources = [
        if (w.grabTitle != null && w.grabTitle!.isNotEmpty) w.grabTitle!,
        if (timing != null) timing,
      ];
      chain.add(
        Milestone(
          key: 'dispatch',
          label: '投递',
          state: MilestoneState.done,
          time: SubsFormat.relative(w.grabbedAt, now: current),
          detail: '已提交下载任务',
          sources: sources,
        ),
      );
    } else {
      final lastTiming = resourceTimingNote(w.resourceTiming, previous: true);
      final dispatchFailure =
          failure?.type == 'dispatch_failed' ? failure : null;
      final smartSel = SmartSelection.fromWanted(w);
      final detail = dispatchFailure != null
          ? '上次投递失败，稍后重试'
          : isSmart
              ? (smartSel != null && smartSel.reason != 'identity_unconfirmed'
                  ? '等待智能选源确定最佳候选'
                  : '等待发现合格候选')
              : '尚未命中符合规则组的资源';
      chain.add(
        Milestone(
          key: 'dispatch',
          label: '投递',
          state: MilestoneState.todo,
          detail: detail,
          why: dispatchFailure?.message,
          sources: lastTiming != null ? [lastTiming] : const [],
        ),
      );
    }

    // 4. 下载
    final dlDoneAt = w.downloadedAt ?? w.importedAt;
    if (dlDoneAt != null && dlDoneAt.isNotEmpty) {
      chain.add(
        Milestone(
          key: 'download',
          label: '下载',
          state: MilestoneState.done,
          time: SubsFormat.relative(dlDoneAt, now: current),
          detail: '文件已落盘',
        ),
      );
    } else if (w.grabbedAt != null && w.grabbedAt!.isNotEmpty) {
      chain.add(
        Milestone(
          key: 'download',
          label: '下载',
          state: MilestoneState.now,
          time: '进行中',
          detail: live != null ? downloadNote(live) : '等待下载器回报实时进度',
        ),
      );
    } else {
      chain.add(
        const Milestone(
          key: 'download',
          label: '下载',
          state: MilestoneState.todo,
          detail: '等待投递后开始下载',
        ),
      );
    }

    // 5. 入库
    if (w.importedAt != null && w.importedAt!.isNotEmpty) {
      chain.add(
        Milestone(
          key: 'import',
          label: '入库',
          state: MilestoneState.done,
          time: SubsFormat.relative(w.importedAt, now: current),
          detail: w.upgrade != null
              ? '已入库（${w.upgrade!.currentLabel}）'
              : '已整理入库',
        ),
      );
    } else if (failure?.type == 'import_failed') {
      chain.add(
        Milestone(
          key: 'import',
          label: '入库',
          state: MilestoneState.fail,
          detail: '入库整理失败',
          why: failure?.message,
        ),
      );
    } else if (w.downloadedAt != null && w.downloadedAt!.isNotEmpty) {
      chain.add(
        const Milestone(
          key: 'import',
          label: '入库',
          state: MilestoneState.now,
          detail: '下载已完成，等待自动整理入库',
        ),
      );
    } else {
      chain.add(
        const Milestone(
          key: 'import',
          label: '入库',
          state: MilestoneState.todo,
          detail: '下载完成后自动整理入库',
        ),
      );
    }

    // 6. 洗版（仅当存在 upgrade 派生状态时）
    final up = w.upgrade;
    if (up != null) {
      if (up.active) {
        chain.add(
          Milestone(
            key: 'upgrade',
            label: '洗版',
            state: MilestoneState.now,
            time: up.searchAttempts > 0 ? '已搜 ${up.searchAttempts} 轮' : '',
            detail: '当前 ${up.currentLabel} → 目标 ${up.targetLabel}',
          ),
        );
      } else if (up.indeterminate) {
        chain.add(
          Milestone(
            key: 'upgrade',
            label: '洗版',
            state: MilestoneState.now,
            detail: '当前 ${up.currentLabel}，无法确认片源档位，标注片源后可自动洗版',
          ),
        );
      } else {
        chain.add(
          Milestone(
            key: 'upgrade',
            label: '洗版',
            state: MilestoneState.done,
            detail: '当前 ${up.currentLabel}，已达目标档位',
          ),
        );
      }
    }

    return chain;
  }

  static int stuckIndex(List<Milestone> chain) {
    final idx = chain.indexWhere((m) => m.state != MilestoneState.done);
    if (idx >= 0) return idx;
    return chain.isEmpty ? 0 : chain.length - 1;
  }

  static Map<int, SubActivityView> pendingFailures(
    List<SubActivityView> activities,
  ) {
    final failures = <int, SubActivityView>{};
    final seen = <int>{};
    for (final a in activities) {
      final wid = a.wantedItemId;
      if (wid == null || !seen.add(wid)) continue;
      if (a.type == 'import_failed' || a.type == 'dispatch_failed') {
        failures[wid] = a;
      }
    }
    return failures;
  }

  static Set<int> defaultOpenSeasons(List<WantedView> wanted) {
    final open = <int>{};
    final regular = wanted.where((w) => w.seasonNumber > 0).toList();
    final pool = regular.isEmpty ? wanted : regular;
    if (pool.isNotEmpty) {
      final latest =
          pool.map((w) => w.seasonNumber).reduce((a, b) => a > b ? a : b);
      open.add(latest);
    }
    for (final w in wanted) {
      if (w.status == 'grabbed' || w.status == 'downloaded') {
        open.add(w.seasonNumber);
      }
    }
    return open;
  }

  static Color activityColor(String type) {
    switch (type) {
      case 'grabbed':
      case 'match_accepted':
      case 'completed':
      case 'downloaded':
      case 'imported':
      case 'replacement_promoted':
        return SubsColor.ok;
      case 'upgrade_grabbed':
      case 'upgraded':
        return SubsColor.upgrade;
      case 'match_rejected':
      case 'dispatch_failed':
      case 'import_failed':
        return SubsColor.danger;
      case 'paused':
      case 'download_stalled':
      case 'upgrade_verify_failed':
      case 'spec_mismatch':
        return SubsColor.warn;
      default:
        return SubsColor.info;
    }
  }
}
