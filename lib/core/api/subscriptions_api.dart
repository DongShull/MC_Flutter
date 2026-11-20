import 'mc_client.dart';

/// 订阅域 API（对齐 Kotlin McApi.kt subscriptions 段 / core/model/Subscription.kt）：
/// POST /subscriptions/title-preview 预检 → POST /subscriptions 创建（三步弹层数据源）。
class SubscriptionsApi {
  SubscriptionsApi(this._client);

  final McClient _client;

  /// POST /api/v1/subscriptions/title-preview：按 titleRef（形如 tmdb:movie:123）预检，
  /// 返回作品简介 + 季清单 + 已有订阅 id（已订阅时非空）。
  Future<SubscribePreview> titlePreview(String titleRef) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/subscriptions/title-preview',
      body: {'titleRef': titleRef},
    );
    return SubscribePreview.fromJson(body);
  }

  /// POST /api/v1/subscriptions：创建订阅；成功返回订阅 id（data.subscription.id）。
  Future<int?> createSubscription({
    required String titleRef,
    List<int> selectedSeasons = const [],
    bool followFuture = false,
  }) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'POST',
      '/api/v1/subscriptions',
      body: {
        'titleRef': titleRef,
        'selectedSeasons': selectedSeasons,
        'followFuture': followFuture,
      },
    );
    final sub = (body['subscription'] is Map)
        ? (body['subscription'] as Map).cast<String, dynamic>()
        : body;
    final id = sub['id'] ?? sub['subscription_id'];
    return id is num ? id.toInt() : int.tryParse(id?.toString() ?? '');
  }
}

/// title-preview 响应（对齐 Kotlin PrepareView / MediaBrief / SeasonOverview 字段子集）。
class SubscribePreview {
  const SubscribePreview({
    this.status = 'not_found',
    this.title,
    this.overview,
    this.posterUrl,
    this.year,
    this.movieOwned = false,
    this.existingSubscriptionId,
    this.suggestedSeasons = const [],
    this.seasons = const [],
  });

  /// not_found / ok 等
  final String status;
  final String? title;
  final String? overview;
  final String? posterUrl;
  final int? year;
  /// 电影已在库（无需订阅）。
  final bool movieOwned;
  /// 非空 = 已有订阅，入口转「管理订阅」。
  final int? existingSubscriptionId;
  /// 服务端建议勾选的季号。
  final List<int> suggestedSeasons;
  final List<SubscribeSeason> seasons;

  bool get notFound => status == 'not_found' && title == null;

  factory SubscribePreview.fromJson(Map<String, dynamic> j) {
    final media = (j['media'] is Map) ? (j['media'] as Map).cast<String, dynamic>() : const {};
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
          return v.map((e) => e is num ? e.toInt() : int.tryParse(e.toString())).whereType<int>().toList();
        }
      }
      return const [];
    }

    return SubscribePreview(
      status: (j['status'] ?? 'not_found').toString(),
      title: s(['title', 'name']),
      overview: s(['overview', 'plot', 'summary']),
      posterUrl: s(['poster_url', 'poster']),
      year: i(['year', 'production_year']),
      movieOwned: j['movie_owned'] == true,
      existingSubscriptionId: i(['existing_subscription_id', 'existingSubscriptionId']),
      suggestedSeasons: ints(['suggested_seasons', 'suggestedSeasons']),
      seasons: ((j['seasons'] ?? const []) as List<dynamic>)
          .whereType<Map>()
          .map((e) => SubscribeSeason.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// 预检里的一季（对齐 Kotlin SeasonOverview）。
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
        number: (j['season_number'] ?? j['seasonNumber'] ?? j['number'] ?? 0) is num
            ? ((j['season_number'] ?? j['seasonNumber'] ?? j['number'] ?? 0) as num).toInt()
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
