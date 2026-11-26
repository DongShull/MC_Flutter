import 'mc_client.dart';

/// 通用订阅创建与预检 API（全路径 snake_case 严格对齐后端 `/api/v1/subscriptions` 与 `/api/v1/rule-sets`）。
class SubscriptionsApi {
  SubscriptionsApi(this._client);

  final McClient _client;

  Future<SubscribePreview> titlePreview(String titleRef) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/subscriptions/title-preview',
      body: {'title_ref': titleRef},
    );
    return SubscribePreview.fromJson(body);
  }

  Future<List<SubscribeRuleSetOption>> ruleSets() async {
    try {
      final list = await _client.unwrap<List<dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/rule-sets',
      );
      return list
          .whereType<Map>()
          .map((e) => SubscribeRuleSetOption.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

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
          .map((e) => SubscribeLibraryOption.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<int?> createSubscription({
    required String titleRef,
    List<int> selectedSeasons = const [],
    bool followFuture = false,
    int? ruleSetId,
    int? libraryId,
    String selectionMode = 'rules',
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/subscriptions',
      body: {
        'title_ref': titleRef,
        'selected_seasons': selectedSeasons,
        'follow_future': followFuture,
        'selection_mode': selectionMode,
        if (ruleSetId != null) 'rule_set_id': ruleSetId,
        if (libraryId != null) 'library_id': libraryId,
      },
    );
    final sub = (body['subscription'] is Map)
        ? (body['subscription'] as Map).cast<String, dynamic>()
        : body;
    final id = sub['id'] ?? sub['subscription_id'];
    return id is num ? id.toInt() : int.tryParse(id?.toString() ?? '');
  }
}

class SubscribeRuleSetOption {
  const SubscribeRuleSetOption({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  final int id;
  final String name;
  final bool isDefault;

  factory SubscribeRuleSetOption.fromJson(Map<String, dynamic> j) =>
      SubscribeRuleSetOption(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        isDefault: j['is_default'] == true,
      );
}

class SubscribeLibraryOption {
  const SubscribeLibraryOption({
    required this.id,
    required this.name,
    required this.kind,
  });

  final int id;
  final String name;
  final String kind;

  factory SubscribeLibraryOption.fromJson(Map<String, dynamic> j) =>
      SubscribeLibraryOption(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        kind: (j['kind'] ?? 'movie').toString(),
      );
}

class SubscribePreview {
  const SubscribePreview({
    this.status = 'not_found',
    this.title,
    this.kind,
    this.overview,
    this.posterUrl,
    this.year,
    this.movieOwned = false,
    this.existingSubscriptionId,
    this.suggestedSeasons = const [],
    this.seasons = const [],
  });

  final String status;
  final String? title;
  final String? kind;
  final String? overview;
  final String? posterUrl;
  final int? year;
  final bool movieOwned;
  final int? existingSubscriptionId;
  final List<int> suggestedSeasons;
  final List<SubscribeSeason> seasons;

  bool get notFound => status == 'not_found' && title == null;

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
      title: s(['title', 'name']),
      kind: s(['kind', 'media_type']),
      overview: s(['overview', 'plot', 'summary']),
      posterUrl: s(['poster_url', 'poster']),
      year: i(['year', 'production_year']),
      movieOwned: j['movie_owned'] == true,
      existingSubscriptionId:
          i(['existing_subscription_id', 'existingSubscriptionId']),
      suggestedSeasons: ints(['suggested_seasons', 'suggestedSeasons']),
      seasons: ((j['seasons'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map((e) => SubscribeSeason.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class SubscribeSeason {
  const SubscribeSeason({
    required this.number,
    this.name,
    this.episodeCount,
    this.ownedCount,
  });

  final int number;
  final String? name;
  final int? episodeCount;
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
        episodeCount: (j['episode_count'] ?? j['episodeCount']) is num
            ? ((j['episode_count'] ?? j['episodeCount']) as num).toInt()
            : null,
        ownedCount: (j['owned_count'] ?? j['ownedCount']) is num
            ? ((j['owned_count'] ?? j['ownedCount']) as num).toInt()
            : null,
      );
}
