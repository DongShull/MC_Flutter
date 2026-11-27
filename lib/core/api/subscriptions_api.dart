import 'api_exception.dart';
import 'mc_client.dart';

/// 通用订阅、智能订阅、规则组、洗版、片源标注与路由预检 API。
///
/// 全路径 snake_case 严格对齐后端 OpenAPI 与 iOS `Endpoints.swift` / `SmartSubscription.swift`。
/// 放在 `lib/core/api/` 下以便 `core/designsystem/`（`SubscribeSheet` / `RuleSetEditorSheet`）、
/// `features/subscriptions/` 与 `features/settings/` 复用而无跨 feature 依赖。
class SubscriptionsApi {
  SubscriptionsApi(this._client);

  final McClient _client;

  static LibraryRoutingOptions? _cachedRoutingOptions;

  // ── 预检与创建 ──

  /// `POST /api/v1/subscriptions/title-preview`
  Future<SubscribePreview> titlePreview(String titleRef) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/subscriptions/title-preview',
      body: {'title_ref': titleRef},
    );
    return SubscribePreview.fromJson(body);
  }

  /// `GET /api/v1/subscriptions/download-routing-preview`
  Future<DispatchPreviewView> downloadRoutingPreview({
    required String kind,
    int? libraryId,
    int? tmdbId,
    String? title,
    int? year,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/subscriptions/download-routing-preview',
      query: {
        'kind': kind,
        if (libraryId != null) 'library_id': libraryId,
        if (tmdbId != null) 'tmdb_id': tmdbId,
        if (title != null && title.isNotEmpty) 'title': title,
        if (year != null) 'year': year,
      },
    );
    return DispatchPreviewView.fromJson(body);
  }

  /// `GET /api/v1/rule-sets`
  Future<List<SubscribeRuleSetOption>> ruleSets() async {
    try {
      final list = await _client.unwrap<List<dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/rule-sets',
      );
      return list
          .whereType<Map>()
          .map(
            (e) => SubscribeRuleSetOption.fromJson(e.cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// `POST /api/v1/rule-sets`
  Future<SubscribeRuleSetOption> createRuleSet({
    required String name,
    Map<String, dynamic>? spec,
    List<Map<String, dynamic>>? matchRules,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/rule-sets',
      body: {
        'name': name,
        if (spec != null) 'spec': spec,
        if (matchRules != null) 'match_rules': matchRules,
      },
    );
    return SubscribeRuleSetOption.fromJson(body);
  }

  /// `PUT /api/v1/rule-sets/{id}`
  Future<SubscribeRuleSetOption> updateRuleSet(
    int ruleSetId, {
    required String name,
    Map<String, dynamic>? spec,
    List<Map<String, dynamic>>? matchRules,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'PUT',
      '/api/v1/rule-sets/$ruleSetId',
      body: {
        'name': name,
        if (spec != null) 'spec': spec,
        if (matchRules != null) 'match_rules': matchRules,
      },
    );
    return SubscribeRuleSetOption.fromJson(body);
  }

  /// `DELETE /api/v1/rule-sets/{id}`
  Future<void> deleteRuleSet(int ruleSetId) async {
    await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'DELETE',
      '/api/v1/rule-sets/$ruleSetId',
    );
  }

  /// `POST /api/v1/rule-sets/{id}/default`
  Future<SubscribeRuleSetOption> setDefaultRuleSet(int ruleSetId) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/rule-sets/$ruleSetId/default',
    );
    return SubscribeRuleSetOption.fromJson(body);
  }

  /// `GET /api/v1/libraries/routing-options`（进程内静态缓存）
  Future<LibraryRoutingOptions> routingOptions({bool force = false}) async {
    if (!force && _cachedRoutingOptions != null) {
      return _cachedRoutingOptions!;
    }
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/libraries/routing-options',
    );
    final parsed = LibraryRoutingOptions.fromJson(body);
    _cachedRoutingOptions = parsed;
    return parsed;
  }

  /// `GET /api/v1/libraries?kind=&scope=all`
  Future<List<SubscribeLibraryOption>> libraries({String? kind}) async {
    try {
      final list = await _client.unwrap<List<dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/libraries',
        query: {
          if (kind != null && kind.isNotEmpty) 'kind': kind,
          'scope': 'all',
        },
      );
      return list
          .whereType<Map>()
          .map(
            (e) => SubscribeLibraryOption.fromJson(e.cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// `POST /api/v1/subscriptions`（完整支持智能字段与豆瓣 `source_title_ref`）
  Future<int?> createSubscription({
    required String titleRef,
    String? sourceTitleRef,
    List<int> selectedSeasons = const [],
    bool followFuture = false,
    int? ruleSetId,
    int? libraryId,
    String selectionMode = 'rules',
    int? smartProfileRevision,
    String? smartLanguageAnswer,
    String? smartResolution,
    String? smartSource,
    String? smartScope,
    int? smartMemoryRevision,
    Map<String, int>? episodeFloors,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/subscriptions',
      body: {
        'title_ref': titleRef,
        if (sourceTitleRef != null && sourceTitleRef.isNotEmpty)
          'source_title_ref': sourceTitleRef,
        'selected_seasons': selectedSeasons,
        'follow_future': followFuture,
        'selection_mode': selectionMode,
        if (ruleSetId != null) 'rule_set_id': ruleSetId,
        if (libraryId != null) 'library_id': libraryId,
        if (smartProfileRevision != null)
          'smart_profile_revision': smartProfileRevision,
        if (smartLanguageAnswer != null)
          'smart_language_answer': smartLanguageAnswer,
        if (smartResolution != null) 'smart_resolution': smartResolution,
        if (smartSource != null) 'smart_source': smartSource,
        if (smartScope != null) 'smart_scope': smartScope,
        if (smartMemoryRevision != null)
          'smart_memory_revision': smartMemoryRevision,
        if (episodeFloors != null && episodeFloors.isNotEmpty)
          'episode_floors': episodeFloors,
      },
    );
    final sub = (body['subscription'] is Map)
        ? (body['subscription'] as Map).cast<String, dynamic>()
        : body;
    final id = sub['id'] ?? sub['subscription_id'];
    return id is num ? id.toInt() : int.tryParse(id?.toString() ?? '');
  }

  // ── 智能订阅设置与记忆 ──

  /// `GET /api/v1/subscriptions/smart-defaults`（旧版服务端 404 时降级读取 `/smart-profiles/{movie,tv}`）
  Future<SmartDefaultsView> getSmartDefaults() async {
    try {
      final body = await _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/subscriptions/smart-defaults',
      );
      return SmartDefaultsView.fromJson(body);
    } on ApiException catch (e) {
      if (e.httpStatus != 404) rethrow;
      final movie = await getSmartProfile('movie');
      final tv = await getSmartProfile('tv');
      final mPref = movie.preferences;
      final tPref = tv.preferences;
      final base = tPref ?? mPref ?? SmartPreferences.defaults('tv');
      return SmartDefaultsView(
        configured: mPref != null || tPref != null,
        movieRevision: movie.revision,
        tvRevision: tv.revision,
        resolution: base.resolution,
        source: base.source,
        allowUpgrade: base.allowUpgrade,
        strictResolution: base.strictResolution,
        movieWaitSeconds: mPref?.waitSeconds ?? 86400,
        tvWaitSeconds: tPref?.waitSeconds ?? 10800,
        isLegacyProfiles: true,
      );
    }
  }

  /// `PUT /api/v1/subscriptions/smart-defaults`（旧版服务端 404 时降级写 `/smart-profiles/{movie,tv}`）
  Future<SmartDefaultsView> saveSmartDefaults(
    SmartDefaultsPayload payload, {
    bool useLegacyProfiles = false,
  }) async {
    if (!useLegacyProfiles) {
      try {
        final body = await _client.unwrap<Map<String, dynamic>>(
          Channel.general,
          'PUT',
          '/api/v1/subscriptions/smart-defaults',
          body: payload.toJson(),
        );
        return SmartDefaultsView.fromJson(body);
      } on ApiException catch (e) {
        if (e.httpStatus != 404) rethrow;
      }
    }
    final mSaved = await saveSmartProfile(
      'movie',
      revision: payload.movieRevision,
      preferences: SmartPreferences(
        resolution: payload.resolution,
        source: payload.source,
        waitSeconds: payload.movieWaitSeconds,
        allowUpgrade: payload.allowUpgrade,
        strictResolution: payload.strictResolution,
      ),
    );
    final tSaved = await saveSmartProfile(
      'tv',
      revision: payload.tvRevision,
      preferences: SmartPreferences(
        resolution: payload.resolution,
        source: payload.source,
        waitSeconds: payload.tvWaitSeconds,
        allowUpgrade: payload.allowUpgrade,
        strictResolution: payload.strictResolution,
      ),
    );
    return SmartDefaultsView(
      configured: true,
      movieRevision: mSaved.revision,
      tvRevision: tSaved.revision,
      resolution: payload.resolution,
      source: payload.source,
      allowUpgrade: payload.allowUpgrade,
      strictResolution: payload.strictResolution,
      movieWaitSeconds: payload.movieWaitSeconds,
      tvWaitSeconds: payload.tvWaitSeconds,
      isLegacyProfiles: true,
    );
  }

  /// 旧版接口：`GET /api/v1/subscriptions/smart-profiles/{kind}`
  Future<SmartProfile> getSmartProfile(String kind) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/subscriptions/smart-profiles/$kind',
    );
    return SmartProfile.fromJson(body);
  }

  /// 旧版接口：`PUT /api/v1/subscriptions/smart-profiles/{kind}`
  Future<SmartProfile> saveSmartProfile(
    String kind, {
    required int revision,
    required SmartPreferences preferences,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'PUT',
      '/api/v1/subscriptions/smart-profiles/$kind',
      body: {
        'revision': revision,
        'preferences': preferences.toJson(),
      },
    );
    return SmartProfile.fromJson(body);
  }

  /// `GET /api/v1/subscriptions/smart-memory`
  Future<SmartMemoryView?> getSmartMemory() async {
    try {
      final body = await _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/subscriptions/smart-memory',
      );
      return SmartMemoryView.fromJson(body);
    } on ApiException catch (e) {
      if (e.httpStatus == 404) return null;
      rethrow;
    }
  }

  /// `PATCH /api/v1/subscriptions/smart-memory`
  Future<SmartMemoryView> updateSmartMemory(SmartMemoryPatch patch) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'PATCH',
      '/api/v1/subscriptions/smart-memory',
      body: patch.toJson(),
    );
    return SmartMemoryView.fromJson(body);
  }

  /// `POST /api/v1/subscriptions/{subscription_id}/wanted/{wanted_id}/smart-wait`
  Future<void> changeSmartWait({
    required int subscriptionId,
    required int wantedId,
    required SmartWaitPayload payload,
  }) async {
    await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/subscriptions/$subscriptionId/wanted/$wantedId/smart-wait',
      body: payload.toJson(),
    );
  }

  // ── 取消订阅 / 成员退订 / 减季清理 ──

  /// `GET /api/v1/subscriptions/{id}/removal-preview`（重复 `seasons` 参数拼接）
  Future<SubscriptionRemovalPreviewView> removalPreview(
    int subscriptionId, {
    List<int>? seasons,
  }) async {
    var path = '/api/v1/subscriptions/$subscriptionId/removal-preview';
    if (seasons != null && seasons.isNotEmpty) {
      final qs = seasons.map((s) => 'seasons=$s').join('&');
      path = '$path?$qs';
    }
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      path,
    );
    return SubscriptionRemovalPreviewView.fromJson(body);
  }

  /// 管理员永久删除：`DELETE /api/v1/subscriptions/{id}`
  Future<SubscriptionDeleteView> deleteSubscription(
    int subscriptionId, {
    bool deleteTorrents = false,
    bool deleteLibraryFiles = false,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'DELETE',
      '/api/v1/subscriptions/$subscriptionId',
      query: {
        'delete_torrents': deleteTorrents,
        'delete_library_files': deleteLibraryFiles,
      },
    );
    return SubscriptionDeleteView.fromJson(body);
  }

  /// 成员取消关注：`DELETE /api/v1/subscriptions/{id}/following`（兼容旧版 `POST .../unsubscribe`）
  Future<void> unsubscribeFollowing(int subscriptionId) async {
    try {
      await _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'DELETE',
        '/api/v1/subscriptions/$subscriptionId/following',
      );
    } on ApiException catch (e) {
      if (e.httpStatus != 404 && e.httpStatus != 405) rethrow;
      await _client.unwrap<Map<String, dynamic>>(
        Channel.general,
        'POST',
        '/api/v1/subscriptions/$subscriptionId/unsubscribe',
      );
    }
  }

  /// 减季清理：`POST /api/v1/subscriptions/{id}/season-cleanup`
  Future<SubscriptionDeleteView> cleanupSeasons(
    int subscriptionId, {
    required List<int> seasons,
    bool deleteTorrents = false,
    bool deleteLibraryFiles = false,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/subscriptions/$subscriptionId/season-cleanup',
      body: {
        'seasons': seasons,
        'delete_torrents': deleteTorrents,
        'delete_library_files': deleteLibraryFiles,
      },
    );
    return SubscriptionDeleteView.fromJson(body);
  }

  // ── 洗版与片源标注 ──

  /// `POST /api/v1/subscriptions/{id}/upgrade-runs`
  Future<UpgradeRunView> upgradeRun(
    int subscriptionId, {
    int? ruleSetId,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/subscriptions/$subscriptionId/upgrade-runs',
      body: {if (ruleSetId != null) 'rule_set_id': ruleSetId},
    );
    return UpgradeRunView.fromJson(body);
  }

  /// `GET /api/v1/libraries/media-source-annotations/candidates`
  Future<List<MediaSourceAnnotationCandidateView>>
      mediaSourceAnnotationCandidates({
    required int mediaItemId,
    required int seasonNumber,
  }) async {
    final list = await _client.unwrap<List<dynamic>>(
      Channel.general,
      'GET',
      '/api/v1/libraries/media-source-annotations/candidates',
      query: {
        'media_item_id': mediaItemId,
        'season_number': seasonNumber,
      },
    );
    return list
        .whereType<Map>()
        .map(
          (e) => MediaSourceAnnotationCandidateView.fromJson(
            e.cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  /// `POST /api/v1/libraries/media-source-annotations`
  Future<int> annotateMediaSource({
    required int mediaItemId,
    required int seasonNumber,
    required String mediaSource,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/libraries/media-source-annotations',
      body: {
        'media_item_id': mediaItemId,
        'season_number': seasonNumber,
        'media_source': mediaSource,
      },
    );
    return (body['files'] as num?)?.toInt() ?? 0;
  }
}

// ── 规则组 / 媒体库 / 路由选项 ──

class SubscribeRuleSetOption {
  const SubscribeRuleSetOption({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.referenceCount = 0,
    this.spec = const {},
    this.matchRules = const [],
  });

  final int id;
  final String name;
  final bool isDefault;
  final int referenceCount;
  final Map<String, dynamic> spec;
  final List<Map<String, dynamic>> matchRules;

  /// 洗版目标标签（null = 本组未配置洗版目标）
  String? get upgradeTarget => _upgradeTargetFromRawSpec(spec);

  factory SubscribeRuleSetOption.fromJson(Map<String, dynamic> j) =>
      SubscribeRuleSetOption(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        isDefault: j['is_default'] == true,
        referenceCount: (j['reference_count'] as num?)?.toInt() ?? 0,
        spec: j['spec'] is Map
            ? (j['spec'] as Map).cast<String, dynamic>()
            : const {},
        matchRules: (j['match_rules'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
      );
}

String? _upgradeTargetFromRawSpec(Map<String, dynamic> spec) {
  final source = spec['upgrade_source']?.toString();
  if (source == null || source.isEmpty) return null;
  final resolutions = (spec['resolutions'] as List<dynamic>? ?? const [])
      .map((e) => e.toString())
      .where((e) => e.isNotEmpty)
      .toList();
  final cutoff = spec['cutoff_resolution']?.toString();
  final res = (cutoff != null && cutoff.isNotEmpty)
      ? cutoff
      : (resolutions.isNotEmpty ? resolutions.first : '1080p');
  const sourceLabels = {
    'web-dl': 'WEB-DL',
    'blu-ray': '蓝光',
    'remux': 'Remux',
  };
  final parts = <String>['$res ${sourceLabels[source] ?? source}'];
  final ladder = (spec['upgrade_ladder'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
      const ['resolution', 'source'];
  if (ladder.contains('hdr')) {
    final hdr = (spec['hdr_levels'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    if (hdr.isNotEmpty) parts.add(hdr.first);
  }
  if (ladder.contains('video_codec')) {
    final codecs = (spec['video_codecs'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    if (codecs.isNotEmpty) parts.add(codecs.first);
  }
  if (ladder.contains('platform')) {
    final plats = (spec['platforms'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    if (plats.isNotEmpty) parts.add(plats.first);
  }
  return parts.join(' · ');
}

class SubscribeLibraryOption {
  const SubscribeLibraryOption({
    required this.id,
    required this.name,
    required this.kind,
    this.isDefault = false,
  });

  final int id;
  final String name;
  final String kind;
  final bool isDefault;

  factory SubscribeLibraryOption.fromJson(Map<String, dynamic> j) =>
      SubscribeLibraryOption(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        kind: (j['kind'] ?? 'movie').toString(),
        isDefault: j['is_default'] == true,
      );
}

class RoutingGenreOption {
  const RoutingGenreOption({required this.id, required this.label});

  final int id;
  final String label;

  factory RoutingGenreOption.fromJson(Map<String, dynamic> j) =>
      RoutingGenreOption(
        id: (j['id'] as num?)?.toInt() ?? 0,
        label: (j['label'] ?? j['name'] ?? '').toString(),
      );
}

class RoutingRegionPreset {
  const RoutingRegionPreset({
    required this.key,
    required this.label,
    required this.countries,
  });

  final String key;
  final String label;
  final List<String> countries;

  factory RoutingRegionPreset.fromJson(Map<String, dynamic> j) =>
      RoutingRegionPreset(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        countries: (j['countries'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList(),
      );
}

class LibraryRoutingOptions {
  const LibraryRoutingOptions({
    this.movieGenres = const [],
    this.tvGenres = const [],
    this.regionPresets = const [],
    this.countryNames = const {},
  });

  final List<RoutingGenreOption> movieGenres;
  final List<RoutingGenreOption> tvGenres;
  final List<RoutingRegionPreset> regionPresets;
  final Map<String, String> countryNames;

  List<RoutingGenreOption> genresFor(String? kind) {
    if (kind == 'movie') return movieGenres;
    if (kind != null && kind.isNotEmpty) return tvGenres;
    final seen = <int>{};
    return [
      for (final g in [...movieGenres, ...tvGenres])
        if (seen.add(g.id)) g,
    ];
  }

  List<String> regionLabels(List<String> regions) {
    final parts = <String>[];
    final rest = [...regions];
    for (final preset in regionPresets) {
      if (preset.countries.isNotEmpty &&
          preset.countries.every(rest.contains)) {
        parts.add(preset.label);
        rest.removeWhere(preset.countries.contains);
      }
    }
    for (final code in rest) {
      parts.add(countryNames[code] ?? code);
    }
    return parts;
  }

  List<({String code, String name})> get sortedCountries {
    final ordered = <String>[];
    for (final preset in regionPresets) {
      for (final code in preset.countries) {
        if (countryNames.containsKey(code) && !ordered.contains(code)) {
          ordered.add(code);
        }
      }
    }
    final rest = countryNames.keys
        .where((k) => !ordered.contains(k))
        .toList()
      ..sort((a, b) => (countryNames[a] ?? a).compareTo(countryNames[b] ?? b));
    return [
      for (final c in [...ordered, ...rest])
        (code: c, name: countryNames[c] ?? c),
    ];
  }

  factory LibraryRoutingOptions.fromJson(Map<String, dynamic> j) =>
      LibraryRoutingOptions(
        movieGenres: (j['movie_genres'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => RoutingGenreOption.fromJson(e.cast<String, dynamic>()))
            .toList(),
        tvGenres: (j['tv_genres'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => RoutingGenreOption.fromJson(e.cast<String, dynamic>()))
            .toList(),
        regionPresets: (j['region_presets'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (e) => RoutingRegionPreset.fromJson(e.cast<String, dynamic>()),
            )
            .toList(),
        countryNames: (j['country_names'] is Map)
            ? (j['country_names'] as Map).map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              )
            : const {},
      );
}

// ── 预检与路由模型 ──

class ResolveCandidateView {
  const ResolveCandidateView({
    required this.tmdbId,
    required this.titleRef,
    required this.title,
    this.originalTitle = '',
    this.year,
    this.posterUrl,
  });

  final int tmdbId;
  final String titleRef;
  final String title;
  final String originalTitle;
  final int? year;
  final String? posterUrl;

  factory ResolveCandidateView.fromJson(Map<String, dynamic> j) =>
      ResolveCandidateView(
        tmdbId: (j['tmdb_id'] as num?)?.toInt() ?? 0,
        titleRef: (j['title_ref'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        originalTitle: (j['original_title'] ?? '').toString(),
        year: (j['year'] as num?)?.toInt(),
        posterUrl: j['poster_url'] as String?,
      );
}

class DispatchPreviewView {
  const DispatchPreviewView({
    this.mode = '',
    this.path,
    this.entryDir,
    this.stagingPath,
    this.libraryId,
    this.libraryName,
    this.downloaderName,
    this.routeMatched,
    this.routeReason,
    this.ruleSetId,
    this.ruleSetName,
    this.ruleSetMatched,
    this.ruleSetReason,
    this.ok = true,
    this.warning,
  });

  final String mode;
  final String? path;
  final String? entryDir;
  final String? stagingPath;
  final int? libraryId;
  final String? libraryName;
  final String? downloaderName;
  final bool? routeMatched;
  final String? routeReason;
  final int? ruleSetId;
  final String? ruleSetName;
  final bool? ruleSetMatched;
  final String? ruleSetReason;
  final bool ok;
  final String? warning;

  /// 按与 iOS `DispatchPreviewNote` 相同口径渲染投递落点文案。
  String formattedPathNote({bool adjusting = false}) {
    if (mode == 'watch') {
      final p = path ?? '';
      if (!adjusting && stagingPath != null && stagingPath!.isNotEmpty) {
        return '下载到监听目录 $p，完成后暂存整理到 $stagingPath';
      }
      return '下载到监听目录 $p，完成后自动整理入库';
    }
    var dir = entryDir ?? path ?? '';
    if (!adjusting) {
      while (dir.endsWith('/')) {
        dir = dir.substring(0, dir.length - 1);
      }
    }
    return dir.isEmpty ? '按所选媒体库目录入库' : '直接下载到 $dir';
  }

  factory DispatchPreviewView.fromJson(Map<String, dynamic> j) =>
      DispatchPreviewView(
        mode: (j['mode'] ?? '').toString(),
        path: j['path'] as String?,
        entryDir: j['entry_dir'] as String?,
        stagingPath: j['staging_path'] as String?,
        libraryId: (j['library_id'] as num?)?.toInt(),
        libraryName: j['library_name'] as String?,
        downloaderName: j['downloader_name'] as String?,
        routeMatched: j['route_matched'] as bool?,
        routeReason: j['route_reason'] as String?,
        ruleSetId: (j['rule_set_id'] as num?)?.toInt(),
        ruleSetName: j['rule_set_name'] as String?,
        ruleSetMatched: j['rule_set_matched'] as bool?,
        ruleSetReason: j['rule_set_reason'] as String?,
        ok: j['ok'] != false,
        warning: j['warning'] as String?,
      );
}

class SubscribePreview {
  const SubscribePreview({
    this.status = 'not_found',
    this.tmdbId,
    this.title,
    this.originalTitle,
    this.englishTitle,
    this.kind,
    this.overview,
    this.posterUrl,
    this.year,
    this.mediaStatus,
    this.movieOwned = false,
    this.existingSubscriptionId,
    this.suggestedSeasons = const [],
    this.seasons = const [],
    this.candidates = const [],
    this.smart,
  });

  final String status;
  final int? tmdbId;
  final String? title;
  final String? originalTitle;
  final String? englishTitle;
  final String? kind;
  final String? overview;
  final String? posterUrl;
  final int? year;
  final String? mediaStatus;
  final bool movieOwned;
  final int? existingSubscriptionId;
  final List<int> suggestedSeasons;
  final List<SubscribeSeason> seasons;
  final List<ResolveCandidateView> candidates;
  final SmartPlanView? smart;

  bool get notFound => status == 'not_found' && title == null;
  bool get isAmbiguous => status == 'ambiguous';
  bool get isReady => status == 'ready';

  SubscribePreview copyWith({SmartPlanView? smart}) => SubscribePreview(
        status: status,
        tmdbId: tmdbId,
        title: title,
        originalTitle: originalTitle,
        englishTitle: englishTitle,
        kind: kind,
        overview: overview,
        posterUrl: posterUrl,
        year: year,
        mediaStatus: mediaStatus,
        movieOwned: movieOwned,
        existingSubscriptionId: existingSubscriptionId,
        suggestedSeasons: suggestedSeasons,
        seasons: seasons,
        candidates: candidates,
        smart: smart ?? this.smart,
      );

  factory SubscribePreview.fromJson(Map<String, dynamic> j) {
    final media = (j['media'] is Map)
        ? (j['media'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    String? s(List<String> keys) {
      for (final k in keys) {
        final v = j[k] ?? media[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return null;
    }

    int? i(List<String> keys) {
      for (final k in keys) {
        final v = j[k] ?? media[k];
        if (v is num) return v.toInt();
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    List<int> ints(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v is List) {
          return v
              .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()))
              .whereType<int>()
              .toList();
        }
      }
      return const [];
    }

    return SubscribePreview(
      status: (j['status'] ?? 'not_found').toString(),
      tmdbId: (media['tmdb_id'] as num?)?.toInt() ?? i(['tmdb_id']),
      title: s(['title', 'name']),
      originalTitle: media['original_title'] as String?,
      englishTitle: media['english_title'] as String?,
      kind: s(['kind', 'media_type']),
      overview: s(['overview', 'plot', 'summary']),
      posterUrl: s(['poster_url', 'poster']),
      year: i(['year', 'production_year']),
      mediaStatus: media['status'] as String?,
      movieOwned: j['movie_owned'] == true,
      existingSubscriptionId:
          i(['existing_subscription_id', 'existingSubscriptionId']),
      suggestedSeasons: ints(['suggested_seasons', 'suggestedSeasons']),
      seasons: ((j['seasons'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map((e) => SubscribeSeason.fromJson(e.cast<String, dynamic>()))
          .toList(),
      candidates: ((j['candidates'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map((e) => ResolveCandidateView.fromJson(e.cast<String, dynamic>()))
          .toList(),
      smart: j['smart'] is Map
          ? SmartPlanView.fromJson((j['smart'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}

class SubscribeSeason {
  const SubscribeSeason({
    required this.number,
    this.name,
    this.airDate,
    this.episodeCount,
    this.airedCount = 0,
    this.ownedCount,
  });

  final int number;
  final String? name;
  final String? airDate;
  final int? episodeCount;
  final int airedCount;
  final int? ownedCount;

  factory SubscribeSeason.fromJson(Map<String, dynamic> j) => SubscribeSeason(
        number:
            (j['season_number'] ?? j['seasonNumber'] ?? j['number'] ?? 0) is num
                ? ((j['season_number'] ??
                        j['seasonNumber'] ??
                        j['number'] ??
                        0) as num)
                    .toInt()
                : 0,
        name: (j['name'] ?? j['season_name'])?.toString(),
        airDate: j['air_date'] as String?,
        episodeCount: (j['episode_count'] ?? j['episodeCount']) is num
            ? ((j['episode_count'] ?? j['episodeCount']) as num).toInt()
            : null,
        airedCount: (j['aired_count'] ?? j['airedCount'] ?? 0) is num
            ? ((j['aired_count'] ?? j['airedCount'] ?? 0) as num).toInt()
            : 0,
        ownedCount: (j['owned_count'] ?? j['ownedCount']) is num
            ? ((j['owned_count'] ?? j['ownedCount']) as num).toInt()
            : null,
      );
}

// ── 智能订阅模型（1:1 对齐 iOS `SmartSubscription.swift` & `Models.swift`） ──

class SmartQuestionView {
  const SmartQuestionView({
    required this.language,
    required this.prompt,
    required this.subtitlesLabel,
    required this.understoodLabel,
  });

  final String language;
  final String prompt;
  final String subtitlesLabel;
  final String understoodLabel;

  factory SmartQuestionView.fromJson(Map<String, dynamic> j) =>
      SmartQuestionView(
        language: (j['language'] ?? '').toString(),
        prompt: (j['prompt'] ?? '').toString(),
        subtitlesLabel: (j['subtitles_label'] ?? '').toString(),
        understoodLabel: (j['understood_label'] ?? '').toString(),
      );
}

class SmartScopeOptionView {
  const SmartScopeOptionView({required this.value, required this.label});

  final String value;
  final String label;

  factory SmartScopeOptionView.fromJson(Map<String, dynamic> j) =>
      SmartScopeOptionView(
        value: (j['value'] ?? 'only').toString(),
        label: (j['label'] ?? '').toString(),
      );
}

class SmartSubtitleView {
  const SmartSubtitleView({
    required this.language,
    required this.languageLabel,
    required this.line,
    required this.understood,
  });

  final String language;
  final String languageLabel;
  final String line;
  final bool understood;

  factory SmartSubtitleView.fromJson(Map<String, dynamic> j) =>
      SmartSubtitleView(
        language: (j['language'] ?? '').toString(),
        languageLabel: (j['language_label'] ?? '').toString(),
        line: (j['line'] ?? '').toString(),
        understood: j['understood'] == true,
      );
}

class SmartPlanView {
  const SmartPlanView({
    required this.configured,
    this.profileRevision = 0,
    this.memoryRevision = 0,
    this.resolution,
    this.source,
    this.qualityLabel,
    this.qualityNote,
    this.qualityShadow,
    this.waitLabel,
    this.subtitleLanguage,
    this.subtitleLanguageLabel,
    this.subtitleUnderstood,
    this.subtitleLine,
    this.question,
    this.subtitleEditQuestion,
    this.scopeOptions = const [],
    this.canEdit = false,
  });

  final bool configured;
  final int profileRevision;
  final int memoryRevision;
  final String? resolution;
  final String? source;
  final String? qualityLabel;
  final String? qualityNote;
  final String? qualityShadow;
  final String? waitLabel;
  final String? subtitleLanguage;
  final String? subtitleLanguageLabel;
  final bool? subtitleUnderstood;
  final String? subtitleLine;
  final SmartQuestionView? question;
  final SmartQuestionView? subtitleEditQuestion;
  final List<SmartScopeOptionView> scopeOptions;
  final bool canEdit;

  factory SmartPlanView.fromJson(Map<String, dynamic> j) => SmartPlanView(
        configured: j['configured'] == true,
        profileRevision: (j['profile_revision'] as num?)?.toInt() ?? 0,
        memoryRevision: (j['memory_revision'] as num?)?.toInt() ?? 0,
        resolution: j['resolution'] as String?,
        source: j['source'] as String?,
        qualityLabel: j['quality_label'] as String?,
        qualityNote: j['quality_note'] as String?,
        qualityShadow: j['quality_shadow'] as String?,
        waitLabel: j['wait_label'] as String?,
        subtitleLanguage: j['subtitle_language'] as String?,
        subtitleLanguageLabel: j['subtitle_language_label'] as String?,
        subtitleUnderstood: j['subtitle_understood'] as bool?,
        subtitleLine: j['subtitle_line'] as String?,
        question: j['question'] is Map
            ? SmartQuestionView.fromJson(
                (j['question'] as Map).cast<String, dynamic>(),
              )
            : null,
        subtitleEditQuestion: j['subtitle_edit_question'] is Map
            ? SmartQuestionView.fromJson(
                (j['subtitle_edit_question'] as Map).cast<String, dynamic>(),
              )
            : null,
        scopeOptions: (j['scope_options'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (e) => SmartScopeOptionView.fromJson(e.cast<String, dynamic>()),
            )
            .toList(),
        canEdit: j['can_edit'] == true,
      );
}

class SmartChoice {
  const SmartChoice({
    this.language,
    this.resolution,
    this.source,
    this.scope = 'only',
  });

  final String? language;
  final String? resolution;
  final String? source;
  final String scope;

  SmartChoice copyWith({
    String? language,
    String? resolution,
    String? source,
    String? scope,
  }) =>
      SmartChoice(
        language: language ?? this.language,
        resolution: resolution ?? this.resolution,
        source: source ?? this.source,
        scope: scope ?? this.scope,
      );

  bool qualityChanged(SmartPlanView plan) =>
      (resolution ?? plan.resolution) != plan.resolution ||
      (source ?? plan.source) != plan.source;

  /// 与 iOS `SmartChoice.payload(for:)` 同口径：
  /// 题目出现时即使未改也回传默认 `"subtitles"`；成员不能写记忆，全返回 null。
  ({
    String? language,
    String? resolution,
    String? source,
    String? scope,
    int? memoryRevision,
  }) payloadFor(SmartPlanView plan) {
    if (!plan.canEdit) {
      return (
        language: null,
        resolution: null,
        source: null,
        scope: null,
        memoryRevision: null,
      );
    }
    final lang = language ?? (plan.question != null ? 'subtitles' : null);
    final res =
        (resolution != null && resolution != plan.resolution) ? resolution : null;
    final src = (source != null && source != plan.source) ? source : null;
    return (
      language: lang,
      resolution: res,
      source: src,
      scope: (res != null || src != null) ? scope : null,
      memoryRevision: plan.memoryRevision,
    );
  }
}

class SmartPreferences {
  const SmartPreferences({
    this.resolution = '2160p',
    this.source = 'web-dl',
    this.waitSeconds = 10800,
    this.allowUpgrade = true,
    this.strictResolution = false,
  });

  final String resolution;
  final String source;
  final int waitSeconds;
  final bool allowUpgrade;
  final bool strictResolution;

  static SmartPreferences defaults(String kind) =>
      SmartPreferences(waitSeconds: kind == 'movie' ? 86400 : 10800);

  String get resolutionLabel => resolution == '2160p' ? '4K' : resolution;

  String get targetLabel =>
      SmartLabels.quality(resolution: resolution, source: source);

  String get waitLabel => SmartLabels.wait(waitSeconds);

  factory SmartPreferences.fromJson(Map<String, dynamic> j) => SmartPreferences(
        resolution: (j['resolution'] ?? '2160p').toString(),
        source: (j['source'] ?? 'web-dl').toString(),
        waitSeconds: (j['wait_seconds'] as num?)?.toInt() ?? 10800,
        allowUpgrade: j['allow_upgrade'] != false,
        strictResolution: j['strict_resolution'] == true,
      );

  Map<String, dynamic> toJson() => {
        'resolution': resolution,
        'source': source,
        'wait_seconds': waitSeconds,
        'allow_upgrade': allowUpgrade,
        'strict_resolution': strictResolution,
      };
}

class SmartProfile {
  const SmartProfile({
    required this.kind,
    required this.revision,
    this.preferences,
  });

  final String kind;
  final int revision;
  final SmartPreferences? preferences;

  factory SmartProfile.fromJson(Map<String, dynamic> j) => SmartProfile(
        kind: (j['kind'] ?? 'tv').toString(),
        revision: (j['revision'] as num?)?.toInt() ?? 0,
        preferences: j['preferences'] is Map
            ? SmartPreferences.fromJson(
                (j['preferences'] as Map).cast<String, dynamic>(),
              )
            : null,
      );
}

class SmartDefaultsView {
  const SmartDefaultsView({
    required this.configured,
    required this.movieRevision,
    required this.tvRevision,
    required this.resolution,
    required this.source,
    required this.allowUpgrade,
    required this.strictResolution,
    required this.movieWaitSeconds,
    required this.tvWaitSeconds,
    this.isLegacyProfiles = false,
  });

  final bool configured;
  final int movieRevision;
  final int tvRevision;
  final String resolution;
  final String source;
  final bool allowUpgrade;
  final bool strictResolution;
  final int movieWaitSeconds;
  final int tvWaitSeconds;
  final bool isLegacyProfiles;

  factory SmartDefaultsView.fromJson(Map<String, dynamic> j) =>
      SmartDefaultsView(
        configured: j['configured'] == true,
        movieRevision: (j['movie_revision'] as num?)?.toInt() ?? 0,
        tvRevision: (j['tv_revision'] as num?)?.toInt() ?? 0,
        resolution: (j['resolution'] ?? '2160p').toString(),
        source: (j['source'] ?? 'web-dl').toString(),
        allowUpgrade: j['allow_upgrade'] != false,
        strictResolution: j['strict_resolution'] == true,
        movieWaitSeconds: (j['movie_wait_seconds'] as num?)?.toInt() ?? 86400,
        tvWaitSeconds: (j['tv_wait_seconds'] as num?)?.toInt() ?? 10800,
      );
}

class SmartDefaultsPayload {
  const SmartDefaultsPayload({
    required this.movieRevision,
    required this.tvRevision,
    required this.resolution,
    required this.source,
    required this.allowUpgrade,
    required this.strictResolution,
    required this.movieWaitSeconds,
    required this.tvWaitSeconds,
  });

  final int movieRevision;
  final int tvRevision;
  final String resolution;
  final String source;
  final bool allowUpgrade;
  final bool strictResolution;
  final int movieWaitSeconds;
  final int tvWaitSeconds;

  SmartDefaultsPayload copyWith({
    String? resolution,
    String? source,
    bool? allowUpgrade,
    bool? strictResolution,
    int? movieWaitSeconds,
    int? tvWaitSeconds,
  }) =>
      SmartDefaultsPayload(
        movieRevision: movieRevision,
        tvRevision: tvRevision,
        resolution: resolution ?? this.resolution,
        source: source ?? this.source,
        allowUpgrade: allowUpgrade ?? this.allowUpgrade,
        strictResolution: strictResolution ?? this.strictResolution,
        movieWaitSeconds: movieWaitSeconds ?? this.movieWaitSeconds,
        tvWaitSeconds: tvWaitSeconds ?? this.tvWaitSeconds,
      );

  Map<String, dynamic> toJson() => {
        'movie_revision': movieRevision,
        'tv_revision': tvRevision,
        'resolution': resolution,
        'source': source,
        'allow_upgrade': allowUpgrade,
        'strict_resolution': strictResolution,
        'movie_wait_seconds': movieWaitSeconds,
        'tv_wait_seconds': tvWaitSeconds,
      };
}

class SmartLanguageView {
  const SmartLanguageView({
    required this.key,
    required this.label,
    this.sourceTitle,
    this.removable = true,
  });

  final String key;
  final String label;
  final String? sourceTitle;
  final bool removable;

  factory SmartLanguageView.fromJson(Map<String, dynamic> j) =>
      SmartLanguageView(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        sourceTitle: j['source_title'] as String?,
        removable: j['removable'] != false,
      );
}

class SmartLanguageOptionView {
  const SmartLanguageOptionView({required this.key, required this.label});

  final String key;
  final String label;

  factory SmartLanguageOptionView.fromJson(Map<String, dynamic> j) =>
      SmartLanguageOptionView(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
      );
}

class SmartHabitView {
  const SmartHabitView({
    required this.key,
    required this.label,
    required this.qualityLabel,
    this.sourceTitle,
  });

  final String key;
  final String label;
  final String qualityLabel;
  final String? sourceTitle;

  factory SmartHabitView.fromJson(Map<String, dynamic> j) => SmartHabitView(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        qualityLabel: (j['quality_label'] ?? '').toString(),
        sourceTitle: j['source_title'] as String?,
      );
}

class SmartMemoryView {
  const SmartMemoryView({
    required this.revision,
    this.languages = const [],
    this.addableLanguages = const [],
    this.habits = const [],
  });

  final int revision;
  final List<SmartLanguageView> languages;
  final List<SmartLanguageOptionView> addableLanguages;
  final List<SmartHabitView> habits;

  factory SmartMemoryView.fromJson(Map<String, dynamic> j) => SmartMemoryView(
        revision: (j['revision'] as num?)?.toInt() ?? 0,
        languages: (j['languages'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => SmartLanguageView.fromJson(e.cast<String, dynamic>()))
            .toList(),
        addableLanguages: (j['addable_languages'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (e) =>
                  SmartLanguageOptionView.fromJson(e.cast<String, dynamic>()),
            )
            .toList(),
        habits: (j['habits'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => SmartHabitView.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

class SmartMemoryPatch {
  const SmartMemoryPatch({
    required this.revision,
    this.language,
    this.understood,
    this.removeHabit,
  });

  final int revision;
  final String? language;
  final bool? understood;
  final String? removeHabit;

  Map<String, dynamic> toJson() => {
        'revision': revision,
        if (language != null) 'language': language,
        if (understood != null) 'understood': understood,
        if (removeHabit != null) 'remove_habit': removeHabit,
      };
}

class SmartWaitPayload {
  const SmartWaitPayload({
    required this.version,
    this.extendSeconds,
    this.candidateKey,
  });

  final int version;
  final int? extendSeconds;
  final String? candidateKey;

  Map<String, dynamic> toJson() => {
        'version': version,
        if (extendSeconds != null) 'extend_seconds': extendSeconds,
        if (candidateKey != null) 'candidate_key': candidateKey,
      };
}

abstract final class SmartLabels {
  static String quality({String? resolution, String? source}) {
    final r = resolution == '2160p' ? '4K' : (resolution ?? '');
    const map = {
      'web-dl': 'WEB-DL',
      'blu-ray': '蓝光',
      'remux': 'Remux',
    };
    final s = map[source ?? ''] ?? (source ?? '');
    return '$r $s'.trim();
  }

  static String wait(int seconds) {
    if (seconds == 0) return '尽快下载';
    if (seconds % 86400 == 0) return '最多等 ${seconds ~/ 86400} 天';
    return '最多等 ${seconds ~/ 3600} 小时';
  }
}

// ── 移除预览 / 删除结果 / 洗版报告 / 片源标注 ──

class RetainedTorrentView {
  const RetainedTorrentView({required this.title, this.seasons = const []});

  final String title;
  final List<int> seasons;

  factory RetainedTorrentView.fromJson(Map<String, dynamic> j) =>
      RetainedTorrentView(
        title: (j['title'] ?? '').toString(),
        seasons: (j['seasons'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList(),
      );
}

class SubscriptionRemovalPreviewView {
  const SubscriptionRemovalPreviewView({
    this.torrentCount = 0,
    this.torrentTitles = const [],
    this.hitAndRunCount = 0,
    this.libraryFileCount = 0,
    this.libraryBytes = 0,
    this.recycleRetentionDays = 7,
    this.retainedCrossSeason = const [],
  });

  final int torrentCount;
  final List<String> torrentTitles;
  final int hitAndRunCount;
  final int libraryFileCount;
  final int libraryBytes;
  final int recycleRetentionDays;
  final List<RetainedTorrentView> retainedCrossSeason;

  factory SubscriptionRemovalPreviewView.fromJson(Map<String, dynamic> j) =>
      SubscriptionRemovalPreviewView(
        torrentCount: (j['torrent_count'] as num?)?.toInt() ?? 0,
        torrentTitles: (j['torrent_titles'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        hitAndRunCount: (j['hit_and_run_count'] as num?)?.toInt() ?? 0,
        libraryFileCount: (j['library_file_count'] as num?)?.toInt() ?? 0,
        libraryBytes: (j['library_bytes'] as num?)?.toInt() ?? 0,
        recycleRetentionDays:
            (j['recycle_retention_days'] as num?)?.toInt() ?? 7,
        retainedCrossSeason:
            (j['retained_cross_season'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map(
                  (e) =>
                      RetainedTorrentView.fromJson(e.cast<String, dynamic>()),
                )
                .toList(),
      );
}

class SubscriptionDeleteView {
  const SubscriptionDeleteView({this.cleanupJobId});

  final String? cleanupJobId;

  factory SubscriptionDeleteView.fromJson(Map<String, dynamic> j) =>
      SubscriptionDeleteView(cleanupJobId: j['cleanup_job_id'] as String?);
}

class UpgradeRunUnitView {
  const UpgradeRunUnitView({
    required this.seasonNumber,
    required this.episodeNumber,
    required this.state,
    this.currentLabel,
    required this.targetLabel,
  });

  final int seasonNumber;
  final int episodeNumber;
  final String state;
  final String? currentLabel;
  final String targetLabel;

  factory UpgradeRunUnitView.fromJson(Map<String, dynamic> j) =>
      UpgradeRunUnitView(
        seasonNumber: (j['season_number'] as num?)?.toInt() ?? 0,
        episodeNumber: (j['episode_number'] as num?)?.toInt() ?? 0,
        state: (j['state'] ?? 'missing').toString(),
        currentLabel: j['current_label'] as String?,
        targetLabel: (j['target_label'] ?? '').toString(),
      );
}

class UpgradeRunView {
  const UpgradeRunView({
    required this.targetLabel,
    required this.ruleSetId,
    required this.summary,
    this.counts = const {},
    this.units = const [],
  });

  final String targetLabel;
  final int ruleSetId;
  final String summary;
  final Map<String, int> counts;
  final List<UpgradeRunUnitView> units;

  factory UpgradeRunView.fromJson(Map<String, dynamic> j) => UpgradeRunView(
        targetLabel: (j['target_label'] ?? '').toString(),
        ruleSetId: (j['rule_set_id'] as num?)?.toInt() ?? 0,
        summary: (j['summary'] ?? '').toString(),
        counts: (j['counts'] is Map)
            ? (j['counts'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
              )
            : const {},
        units: (j['units'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => UpgradeRunUnitView.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

class MediaSourceAnnotationCandidateView {
  const MediaSourceAnnotationCandidateView({
    required this.fileId,
    required this.fileName,
    required this.episodeNumber,
    required this.sizeBytes,
    this.mediaSource,
    this.mediaSourceManual = false,
  });

  final int fileId;
  final String fileName;
  final int episodeNumber;
  final int sizeBytes;
  final String? mediaSource;
  final bool mediaSourceManual;

  factory MediaSourceAnnotationCandidateView.fromJson(Map<String, dynamic> j) =>
      MediaSourceAnnotationCandidateView(
        fileId: (j['file_id'] as num?)?.toInt() ?? 0,
        fileName: (j['file_name'] ?? '').toString(),
        episodeNumber: (j['episode_number'] as num?)?.toInt() ?? 0,
        sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
        mediaSource: j['media_source'] as String?,
        mediaSourceManual: j['media_source_manual'] == true,
      );
}
