import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_ambient.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/navigation/external_media_link.dart';
import '../../../core/session/permissions.dart';
import '../routes.dart' as feat_discover;
import '../state/discover_controller.dart';
import '../widgets/discover_lightbox.dart';

/// 发现侧演职员切片（带 TMDB personId 支持点击下钻）。
class DiscoverCastMember {
  const DiscoverCastMember({
    this.personId,
    required this.name,
    this.subtitle,
    this.avatarUrl,
  });

  final int? personId;
  final String name;
  final String? subtitle;
  final String? avatarUrl;
}

/// 预告片/花絮模型（`API.MediaVideo`）。
class DiscoverVideo {
  const DiscoverVideo({
    required this.key,
    required this.name,
    required this.kind,
    required this.thumbnailUrl,
    required this.embedUrl,
    required this.watchUrl,
  });

  final String key;
  final String name;
  final String kind;
  final String thumbnailUrl;
  final String embedUrl;
  final String watchUrl;

  static DiscoverVideo? fromJson(Map<String, dynamic> j) {
    final key = (j['key'] ?? '').toString();
    final watch = (j['watch_url'] ?? j['url'] ?? '').toString();
    if (key.isEmpty && watch.isEmpty) return null;
    return DiscoverVideo(
      key: key.isNotEmpty ? key : watch,
      name: (j['name'] ?? j['title'] ?? '预告片').toString(),
      kind: (j['kind'] ?? j['type'] ?? '预告片').toString(),
      thumbnailUrl: (j['thumbnail_url'] ?? j['thumbnail'] ?? '').toString(),
      embedUrl: (j['embed_url'] ?? '').toString(),
      watchUrl: watch.isNotEmpty
          ? watch
          : (key.isNotEmpty ? 'https://www.youtube.com/watch?v=$key' : ''),
    );
  }
}

/// 剧照/海报图片项（`API.MediaImage`）。
class DiscoverPhoto {
  const DiscoverPhoto({
    required this.previewUrl,
    required this.fullUrl,
    this.width = 0,
    this.height = 0,
  });

  final String previewUrl;
  final String fullUrl;
  final int width;
  final int height;

  static DiscoverPhoto? fromJson(Map<String, dynamic> j) {
    final preview = (j['preview_url'] ?? j['url'] ?? j['full_url'] ?? '').toString();
    final full = (j['full_url'] ?? j['preview_url'] ?? j['url'] ?? '').toString();
    if (preview.isEmpty && full.isEmpty) return null;
    return DiscoverPhoto(
      previewUrl: preview.isNotEmpty ? preview : full,
      fullUrl: full.isNotEmpty ? full : preview,
      width: (j['width'] as num?)?.toInt() ?? 0,
      height: (j['height'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 在库媒体库入口（`API.MediaLibraryLink`）。
class DiscoverLibraryLink {
  const DiscoverLibraryLink({
    required this.libraryId,
    required this.libraryName,
    required this.mediaItemId,
  });

  final int libraryId;
  final String libraryName;
  final int mediaItemId;

  static DiscoverLibraryLink? fromJson(Map<String, dynamic> j) {
    final libId = (j['library_id'] as num?)?.toInt();
    final itemId =
        (j['media_item_id'] as num?)?.toInt() ?? (j['item_id'] as num?)?.toInt();
    if (libId == null || itemId == null) return null;
    return DiscoverLibraryLink(
      libraryId: libId,
      libraryName: (j['library_name'] ?? '媒体库 #$libId').toString(),
      mediaItemId: itemId,
    );
  }
}

/// 同系列作品（`API.DiscoveredTitleCollectionView`）。
class DiscoverSeriesCollection {
  const DiscoverSeriesCollection({
    required this.id,
    required this.name,
    required this.titles,
  });

  final String id;
  final String name;
  final List<DiscTitle> titles;
}

/// 发现条目完整详情数据模型（兼容嵌套 `DiscoveredTitleDetailsView` 与老版平铺响应）。
class TitleDetailData {
  const TitleDetailData({
    required this.titleRef,
    required this.provider,
    required this.externalId,
    this.mediaType,
    required this.title,
    this.originalTitle = '',
    this.englishTitle,
    this.chineseTitle,
    this.year,
    this.rating = 0,
    this.extentLabel = '',
    this.overview = '',
    this.posterUrl,
    this.backdropUrl,
    this.backdropOriginalUrl,
    this.genres = const [],
    this.country = '',
    this.language = '',
    this.released = '',
    this.sourceUrl,
    this.people = const [],
    this.videos = const [],
    this.backdrops = const [],
    this.posters = const [],
    this.collection,
    this.recommendations = const [],
    this.libraryLinks = const [],
    this.isSeed = false,
  });

  final String titleRef;
  final String provider;
  final String externalId;
  final String? mediaType;
  final String title;
  final String originalTitle;
  final String? englishTitle;
  final String? chineseTitle;
  final int? year;
  final double rating;
  final String extentLabel;
  final String overview;
  final String? posterUrl;
  final String? backdropUrl;
  final String? backdropOriginalUrl;
  final List<String> genres;
  final String country;
  final String language;
  final String released;
  final String? sourceUrl;
  final List<DiscoverCastMember> people;
  final List<DiscoverVideo> videos;
  final List<DiscoverPhoto> backdrops;
  final List<DiscoverPhoto> posters;
  final DiscoverSeriesCollection? collection;
  final List<DiscTitle> recommendations;
  final List<DiscoverLibraryLink> libraryLinks;
  final bool isSeed;

  bool get isMovie => mediaType != 'tv';

  /// 沉浸剧照地址：优先 `backdropOriginalUrl`，其次升级 `backdropUrl`，豆瓣无剧照再兜底海报。
  String? get heroImageUrl {
    if (provider != 'douban' &&
        backdropOriginalUrl != null &&
        backdropOriginalUrl!.isNotEmpty) {
      return backdropOriginalUrl;
    }
    if (backdropUrl != null && backdropUrl!.isNotEmpty) {
      return upgradeTmdbBackdropUrl(backdropUrl);
    }
    if (posterUrl != null && posterUrl!.isNotEmpty) {
      return posterUrl;
    }
    return null;
  }

  /// 列表卡片种子构造首屏半份详情（对齐 iOS `DiscoveredTitleDetails+Seed.swift`）。
  factory TitleDetailData.fromSeed(DiscTitle seed) => TitleDetailData(
        titleRef: seed.ref,
        provider: seed.provider,
        externalId: seed.externalId,
        mediaType: seed.mediaType,
        title: seed.title,
        originalTitle: seed.originalTitle,
        year: seed.year,
        rating: seed.rating ?? 0,
        extentLabel: seed.extentLabel,
        overview: seed.overview,
        posterUrl: seed.posterUrl,
        backdropUrl: seed.backdropUrl,
        genres: seed.genres,
        isSeed: true,
      );

  /// 解析 `GET /api/v1/discover/titles/{titleRef}` 真实嵌套结构（同时兼容平铺回退）。
  factory TitleDetailData.fromJson(
    Map<String, dynamic> d, {
    required String fallbackRef,
  }) {
    final nestedTitle = d['title'] is Map
        ? Map<String, dynamic>.from(d['title'] as Map)
        : null;
    final t = nestedTitle ?? d;
    final meta = d['metadata'] is Map
        ? Map<String, dynamic>.from(d['metadata'] as Map)
        : const <String, dynamic>{};

    final ref = (t['title_ref'] ?? d['title_ref'] ?? fallbackRef).toString();
    final refParts = parseTitleRef(ref);
    final provider = (t['provider'] ?? refParts.source).toString();
    final externalId = (t['external_id'] ?? refParts.externalId).toString();
    final mediaType =
        (t['media_type'] ?? d['media_type'] ?? refParts.mediaType)?.toString();
    final isMovie = mediaType != 'tv';
    final directorLabel = isMovie ? '导演' : '主创';

    // 演职员：优先 director_credits + cast；缺 director_credits 时回退 directors 字符串数组
    final people = <DiscoverCastMember>[];
    final dirCredits = (meta['director_credits'] as List<dynamic>? ?? const [])
        .whereType<Map>();
    if (dirCredits.isNotEmpty) {
      for (final c in dirCredits) {
        final name = (c['name'] ?? '').toString();
        if (name.isEmpty) continue;
        people.add(
          DiscoverCastMember(
            personId: (c['tmdb_person_id'] as num?)?.toInt() ??
                (c['person_id'] as num?)?.toInt(),
            name: name,
            subtitle: directorLabel,
            avatarUrl: (c['avatar_url'] ?? c['profile_url'])?.toString(),
          ),
        );
      }
    } else {
      final seen = <String>{};
      for (final rawDir in (meta['directors'] as List<dynamic>? ?? const [])) {
        final name = rawDir.toString().trim();
        if (name.isNotEmpty && seen.add(name)) {
          people.add(DiscoverCastMember(name: name, subtitle: directorLabel));
        }
      }
    }

    final castList =
        (meta['cast'] as List<dynamic>? ?? d['cast'] as List<dynamic>? ?? const [])
            .whereType<Map>();
    for (final c in castList) {
      final name = (c['name'] ?? '').toString();
      if (name.isEmpty) continue;
      final role = (c['role'] ?? c['character'] ?? '').toString().trim();
      people.add(
        DiscoverCastMember(
          personId: (c['tmdb_person_id'] as num?)?.toInt() ??
              (c['person_id'] as num?)?.toInt() ??
              (c['id'] as num?)?.toInt(),
          name: name,
          subtitle: role.isNotEmpty ? '饰 $role' : null,
          avatarUrl: (c['avatar_url'] ?? c['profile_url'])?.toString(),
        ),
      );
    }

    // 预告片（兼容 videos 与 trailers）
    final rawVideos =
        (d['videos'] as List<dynamic>? ?? d['trailers'] as List<dynamic>? ?? const []);
    final videos = <DiscoverVideo>[
      for (final v in rawVideos)
        if (v is Map)
          if (DiscoverVideo.fromJson(Map<String, dynamic>.from(v))
              case final vid?)
            vid,
    ];

    // 剧照 & 海报（兼容顶层 backdrops/posters 及 images.{backdrops,posters}）
    final imagesMap = d['images'] is Map
        ? Map<String, dynamic>.from(d['images'] as Map)
        : const <String, dynamic>{};
    final rawBackdrops = (d['backdrops'] as List<dynamic>? ??
        imagesMap['backdrops'] as List<dynamic>? ??
        const []);
    final rawPosters = (d['posters'] as List<dynamic>? ??
        imagesMap['posters'] as List<dynamic>? ??
        const []);
    final backdrops = <DiscoverPhoto>[
      for (final el in rawBackdrops)
        if (el is Map)
          if (DiscoverPhoto.fromJson(Map<String, dynamic>.from(el))
              case final img?)
            img,
    ];
    final posters = <DiscoverPhoto>[
      for (final el in rawPosters)
        if (el is Map)
          if (DiscoverPhoto.fromJson(Map<String, dynamic>.from(el))
              case final img?)
            img,
    ];

    // 同系列作品
    DiscoverSeriesCollection? collection;
    if (d['collection'] is Map) {
      final colMap = Map<String, dynamic>.from(d['collection'] as Map);
      final colTitles = <DiscTitle>[
        for (final el in (colMap['titles'] as List<dynamic>? ?? const []))
          if (el is Map)
            if (DiscTitle.fromJson(Map<String, dynamic>.from(el)) case final item?)
              item,
      ];
      if (colTitles.length > 1) {
        collection = DiscoverSeriesCollection(
          id: (colMap['id'] ?? '').toString(),
          name: (colMap['name'] ?? '同系列作品').toString(),
          titles: colTitles,
        );
      }
    }

    // 相似推荐
    final recommendations = <DiscTitle>[
      for (final el in (d['recommendations'] as List<dynamic>? ?? const []))
        if (el is Map)
          if (DiscTitle.fromJson(Map<String, dynamic>.from(el)) case final item?)
            item,
    ];

    // 多媒体库在库入口（兼容 library_links 与平铺 library_status）
    final libraryLinks = <DiscoverLibraryLink>[
      for (final el in (d['library_links'] as List<dynamic>? ?? const []))
        if (el is Map)
          if (DiscoverLibraryLink.fromJson(Map<String, dynamic>.from(el))
              case final link?)
            link,
    ];
    if (libraryLinks.isEmpty && t['library_status'] is Map) {
      final ls = Map<String, dynamic>.from(t['library_status'] as Map);
      final libId = (ls['library_id'] as num?)?.toInt();
      final itemId = (ls['media_item_id'] as num?)?.toInt() ??
          (ls['item_id'] as num?)?.toInt();
      if (libId != null && itemId != null) {
        libraryLinks.add(
          DiscoverLibraryLink(
            libraryId: libId,
            libraryName: (ls['library_name'] ?? '媒体库').toString(),
            mediaItemId: itemId,
          ),
        );
      }
    }

    final posterStr = t['poster_url']?.toString();
    final backdropStr = t['backdrop_url']?.toString();
    final backdropOrig = d['backdrop_original_url']?.toString();

    return TitleDetailData(
      titleRef: ref,
      provider: provider,
      externalId: externalId,
      mediaType: mediaType,
      title: (nestedTitle != null ? nestedTitle['title'] : d['title'])
              ?.toString() ??
          '',
      originalTitle: (t['original_title'] ?? '').toString(),
      englishTitle: meta['english_title']?.toString(),
      chineseTitle: meta['chinese_title']?.toString(),
      year: (t['release_year'] as num?)?.toInt() ?? (t['year'] as num?)?.toInt(),
      rating: (t['provider_rating'] as num?)?.toDouble() ?? 0,
      extentLabel: (t['extent_label'] ?? '').toString(),
      overview: (t['overview'] ?? '').toString(),
      posterUrl: (posterStr != null && posterStr.isNotEmpty) ? posterStr : null,
      backdropUrl:
          (backdropStr != null && backdropStr.isNotEmpty) ? backdropStr : null,
      backdropOriginalUrl: (backdropOrig != null && backdropOrig.isNotEmpty)
          ? backdropOrig
          : null,
      genres: [
        for (final g in (t['genres'] as List<dynamic>? ?? const [])) g.toString(),
      ],
      country: (meta['country'] ?? '').toString(),
      language: (meta['language'] ?? '').toString(),
      released: (meta['released'] ?? '').toString(),
      sourceUrl: meta['source_url']?.toString(),
      people: people,
      videos: videos,
      backdrops: backdrops,
      posters: posters,
      collection: collection,
      recommendations: recommendations,
      libraryLinks: libraryLinks,
      isSeed: false,
    );
  }
}

/// 发现条目沉浸式详情页（1:1 对齐 iOS `MediaDetailView.swift`）。
class TitleDetailPage extends ConsumerStatefulWidget {
  const TitleDetailPage({
    super.key,
    required this.titleRef,
    this.seed,
  });

  final String titleRef;
  final DiscTitle? seed;

  @override
  ConsumerState<TitleDetailPage> createState() => _TitleDetailPageState();
}

class _TitleDetailPageState extends ConsumerState<TitleDetailPage> {
  late final McClient _mc = McClient(session: ref.read(sessionStoreProvider));

  TitleDetailData? _detail;
  bool _loading = true;
  String? _error;
  double _scrollOffset = 0;
  Color? _edgeColor;
  String? _sampledUrl;
  bool _overviewExpanded = false;
  String? _probingTrailerKey;
  String _photoTab = 'backdrops';

  @override
  void initState() {
    super.initState();
    if (widget.seed != null) {
      _detail = TitleDetailData.fromSeed(widget.seed!);
    }
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (widget.titleRef.isEmpty) {
      setState(() {
        _loading = false;
        _error = '缺少条目 ref';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/discover/titles/${Uri.encodeComponent(widget.titleRef)}',
      );
      final parsed = TitleDetailData.fromJson(raw, fallbackRef: widget.titleRef);
      if (!mounted) return;
      setState(() {
        _detail = parsed;
        _loading = false;
        _error = null;
        if (parsed.backdrops.isEmpty && parsed.posters.isNotEmpty) {
          _photoTab = 'posters';
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.friendlyMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '网络错误，请稍后重试';
      });
    }
  }

  void _ensureAmbient(String? url) {
    if (url == null || url.isEmpty || url == _sampledUrl) return;
    _sampledUrl = url;
    McAmbientColor.bottomEdge(url).then((c) {
      if (mounted && c != null && c != _edgeColor) {
        setState(() => _edgeColor = c);
      }
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home?tab=discover');
    }
  }

  Future<void> _onSubscribe(TitleDetailData detail) async {
    final outcome = await showSubscribeSheet(
      context,
      ref,
      titleRef: detail.titleRef,
    );
    if (!mounted || outcome == null) return;
    ref.read(discoverSubscriptionIndexProvider.notifier).refresh();
    if (outcome == SubscribeSheetOutcome.created) {
      McToast.success('已加入追更订阅');
    } else {
      context.push('/subscriptions');
    }
  }

  void _openSearch(TitleDetailData detail) {
    final also = <String>[];
    final seen = <String>{detail.title.trim().toLowerCase()};
    for (final candidate in [
      detail.englishTitle,
      detail.originalTitle,
      detail.chineseTitle,
    ]) {
      final trimmed = candidate?.trim() ?? '';
      if (trimmed.isNotEmpty && seen.add(trimmed.toLowerCase())) {
        also.add(trimmed);
      }
    }
    final kind = detail.mediaType;
    final scope = (kind == 'movie' || kind == 'tv')
        ? 'label=${Uri.encodeQueryComponent(kind == 'movie' ? '电影' : '剧集')}&cats=$kind'
        : null;
    final params = <String, dynamic>{
      'q': detail.title,
      'tab': 'torrent',
      if (scope != null) 'scope': scope,
      if (also.isNotEmpty) 'also': also,
    };
    final uri = Uri(path: '/search', queryParameters: params);
    context.push(uri.toString());
  }

  /// 探测本机直连 YouTube 可达性（6 秒超时，刻意不走服务端代理，对齐 iOS `DiscoverYouTubeProbe`）。
  Future<bool> _probeYouTubeReachable(String videoKey) async {
    if (videoKey.isEmpty) return false;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client
          .getUrl(Uri.parse('https://i.ytimg.com/vi/$videoKey/default.jpg'))
          .timeout(const Duration(seconds: 6));
      final res = await req.close().timeout(const Duration(seconds: 6));
      await res.drain<void>();
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _playTrailer(DiscoverVideo video) async {
    if (_probingTrailerKey != null) return;
    setState(() => _probingTrailerKey = video.key);
    final reachable = await _probeYouTubeReachable(video.key);
    if (!mounted) return;
    setState(() => _probingTrailerKey = null);
    if (reachable) {
      await ExternalMediaLink.open(video.watchUrl);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('当前设备无法直连 YouTube'),
        content: const Text(
          '预告片由 YouTube 直接播放，服务端网络代理不会作用于本机播放器。你仍可尝试在 YouTube 应用或浏览器中打开。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
          if (video.watchUrl.isNotEmpty)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ExternalMediaLink.open(video.watchUrl);
              },
              child: const Text('在 YouTube 打开'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final form = McFormWatch.of(context);
    final pad = form == McDeviceForm.phone
        ? McTokens.pagePadding
        : McTokens.pagePaddingWide;
    final detail = _detail;

    if (detail == null && _loading) {
      return Scaffold(
        backgroundColor: McTokens.bg,
        body: Stack(
          children: [
            const McFeedSkeleton(showHero: true),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: McFloatingDetailBar(onBack: _back),
            ),
          ],
        ),
      );
    }

    if (detail == null && _error != null) {
      return Scaffold(
        backgroundColor: McTokens.bg,
        body: Stack(
          children: [
            McErrorView(
              title: '影片详情加载失败',
              text: _error!,
              onRetry: _load,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: McFloatingDetailBar(onBack: _back),
            ),
          ],
        ),
      );
    }

    final d = detail!;
    final heroRaw = d.heroImageUrl;
    _ensureAmbient(heroRaw);
    final ambient = _edgeColor ?? McTokens.bg;
    final heroHeight = topPad + 360.0;
    final resolvedHero = McImageUrls.resolve(heroRaw, widthPx: 1920);
    final stretch = _scrollOffset < 0
        ? (1.0 + (-_scrollOffset) / heroHeight).clamp(1.0, 1.32)
        : 1.0;
    final parallax =
        _scrollOffset > 0 ? math.min(_scrollOffset * 0.25, 68.0) : 0.0;

    final perms = ref.watch(permissionsProvider);
    final subs = ref.watch(discoverSubscriptionIndexProvider);
    final sub = subs.find(
      source: d.provider,
      externalId: d.externalId,
      mediaType: d.mediaType,
    );
    final ownedMovie = d.isMovie && d.libraryLinks.isNotEmpty;
    final showSubscribe = perms.canSubscribe && (sub != null || !ownedMovie);
    final showSearch = perms.canSearch && !ownedMovie && d.title.isNotEmpty;

    final place = [d.country, d.language]
        .where((e) => e.trim().isNotEmpty)
        .join(' · ');

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 1.0],
                  colors: [
                    ambient,
                    ambient.withValues(alpha: 0.38),
                    McTokens.bg,
                  ],
                ),
              ),
            ),
          ),
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical && n.depth == 0) {
                setState(() => _scrollOffset = n.metrics.pixels);
              }
              return false;
            },
            child: RefreshIndicator(
              edgeOffset: topPad + 56,
              color: McTokens.accentStrong,
              backgroundColor: McTokens.surfaceSolid,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 56),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // 沉浸式剧照 Hero
                  if (resolvedHero.isNotEmpty)
                    SizedBox(
                      height: heroHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRect(
                            child: Transform.translate(
                              offset: Offset(0, parallax),
                              child: Transform.scale(
                                scale: stretch,
                                alignment: Alignment.bottomCenter,
                                child: CachedNetworkImage(
                                  imageUrl: resolvedHero,
                                  httpHeaders: mcImageHeaders(),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const ColoredBox(
                                    color: McTokens.posterPlaceholder,
                                  ),
                                  errorWidget: (_, __, ___) => const ColoredBox(
                                    color: McTokens.posterPlaceholder,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.42, 0.78, 1.0],
                                colors: [
                                  const Color(0x55000000),
                                  ambient.withValues(alpha: 0.14),
                                  ambient.withValues(alpha: 0.85),
                                  ambient,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(height: topPad + 64),

                  // 标题、评分、地区/语言/类型、上映日期、在库条、订阅/搜索操作
                  Transform.translate(
                    offset: Offset(0, resolvedHero.isNotEmpty ? -96 : 0),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (d.posterUrl != null &&
                                  d.posterUrl!.isNotEmpty) ...[
                                Container(
                                  width: 96,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      McTokens.posterRadius,
                                    ),
                                    border: Border.all(
                                      color: McTokens.lineStrong,
                                      width: 1,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x99000000),
                                        blurRadius: 20,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: McArtwork(
                                    url: d.posterUrl,
                                    widthPx: 320,
                                    fallbackText: d.title,
                                  ),
                                ),
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.title,
                                      style: McText.titleLg.copyWith(
                                        fontSize: 26,
                                        height: 1.2,
                                      ),
                                    ),
                                    if (d.originalTitle.isNotEmpty &&
                                        d.originalTitle != d.title) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        d.originalTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: McText.caption.muted,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (d.rating > 0)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                McIcons.star2Fill,
                                                size: 14,
                                                color: McTokens.warning,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                d.rating.toStringAsFixed(1),
                                                style: McText.titleSm
                                                    .copyWith(
                                                      color: Colors.white,
                                                    )
                                                    .tabular,
                                              ),
                                            ],
                                          ),
                                        if (d.year != null)
                                          Text(
                                            '${d.year}',
                                            style: McText.sub.tabular,
                                          ),
                                        if (d.extentLabel.isNotEmpty)
                                          Text(
                                            '· ${d.extentLabel}',
                                            style: McText.sub.tabular,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (place.isNotEmpty || d.genres.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (place.isNotEmpty)
                                  Text(
                                    place,
                                    style: McText.sub.copyWith(
                                      color: const Color(0xA6FFFFFF),
                                    ),
                                  ),
                                if (place.isNotEmpty && d.genres.isNotEmpty)
                                  Text(
                                    '｜',
                                    style: McText.sub.copyWith(
                                      color: const Color(0x40FFFFFF),
                                    ),
                                  ),
                                if (d.genres.isNotEmpty)
                                  Text(
                                    d.genres.join(' · '),
                                    style: McText.sub.copyWith(
                                      color: const Color(0xB8FFFFFF),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (d.released.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${d.isMovie ? '上映日期' : '首播日期'} · ${d.released}',
                              style: McText.caption.faint.tabular,
                            ),
                          ],
                          // 多媒体库在库条
                          if (d.libraryLinks.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildLibraryBar(d.libraryLinks),
                          ],
                          // 操作按钮行（遵循 iOS 规则：已入库电影隐藏未订阅的订阅与搜索）
                          if (showSubscribe || showSearch || sub != null) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (showSubscribe)
                                  if (sub != null)
                                    McActionPill(
                                      label: '已订阅 · ${sub.statusLabel}',
                                      icon: McIcons.check,
                                      primary: false,
                                      onTap: () => _onSubscribe(d),
                                    )
                                  else
                                    McActionPill(
                                      label: '订阅影片',
                                      icon: McIcons.bookmarkFill,
                                      primary: true,
                                      onTap: () => _onSubscribe(d),
                                    ),
                                if (showSearch)
                                  McActionPill(
                                    label: '搜索资源',
                                    icon: McIcons.search,
                                    primary: false,
                                    onTap: () => _openSearch(d),
                                  ),
                                if (sub != null && sub.progressNote.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: McTokens.ok,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        sub.progressNote,
                                        style: McText.caption.muted,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                          // 4 行可折叠简介
                          if (d.overview.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _CollapsibleOverview(
                              text: d.overview,
                              expanded: _overviewExpanded,
                              onToggle: () => setState(
                                () => _overviewExpanded = !_overviewExpanded,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // 下方各分区（演职员 -> 预告片 -> 剧照与海报 -> 同系列 -> 相似推荐 -> 外链）
                  Transform.translate(
                    offset: Offset(0, resolvedHero.isNotEmpty ? -72 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (d.people.isNotEmpty) _buildCastSection(d.people, pad),
                        if (d.videos.isNotEmpty)
                          _buildTrailersSection(d.videos, pad),
                        if (d.backdrops.isNotEmpty || d.posters.isNotEmpty)
                          _buildPhotoWall(d, pad),
                        if (d.collection != null)
                          _buildPosterShelf(
                            title: d.collection!.name,
                            items: d.collection!.titles,
                            pad: pad,
                          ),
                        if (d.recommendations.isNotEmpty)
                          _buildPosterShelf(
                            title: '相似推荐',
                            items: d.recommendations,
                            pad: pad,
                          ),
                        _buildExternalLinks(d, pad),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: McFloatingDetailBar(
              onBack: _back,
              title: d.title.isEmpty ? '作品详情' : d.title,
              titleVisible: _scrollOffset > 200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryBar(List<DiscoverLibraryLink> links) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x1433CC8C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x3366E6B3)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                McIcons.folder,
                size: 15,
                color: Color(0xFF99F2CC),
              ),
              const SizedBox(width: 6),
              Text(
                '已在库',
                style: McText.sub.copyWith(
                  color: const Color(0xFF99F2CC),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          for (final link in links)
            GestureDetector(
              onTap: () =>
                  context.push('/detail/${link.libraryId}/${link.mediaItemId}'),
              child: Text(
                link.libraryName,
                style: McText.sub.copyWith(
                  color: const Color(0xFFD9FFED),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCastSection(List<DiscoverCastMember> people, double pad) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McSectionHeader(
            title: '演职员',
            padding: EdgeInsets.symmetric(horizontal: pad),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              itemCount: people.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final p = people[i];
                final resolved =
                    McImageUrls.resolve(p.avatarUrl, widthPx: 240);
                final pid = p.personId;
                final initial =
                    p.name.trim().isNotEmpty ? p.name.trim().substring(0, 1) : '?';
                return McFocusRing(
                  borderRadius: 12,
                  child: McPressable(
                    onTap: pid != null && pid > 0
                        ? () => context.push('/discover/person?id=$pid')
                        : null,
                    child: SizedBox(
                      width: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 100,
                            height: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x14FFFFFF),
                                  Color(0x05FFFFFF),
                                ],
                              ),
                              border: Border.all(
                                color: McTokens.line,
                                width: 0.8,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0x4DFFFFFF),
                                    ),
                                  ),
                                ),
                                if (resolved.isNotEmpty)
                                  CachedNetworkImage(
                                    imageUrl: resolved,
                                    httpHeaders: mcImageHeaders(),
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: McText.caption.copyWith(
                              color: McTokens.text,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (p.subtitle != null && p.subtitle!.isNotEmpty)
                            Text(
                              p.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McText.micro.copyWith(
                                color: McTokens.textFaint,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailersSection(List<DiscoverVideo> videos, double pad) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McSectionHeader(
            title: '预告片与花絮',
            padding: EdgeInsets.symmetric(horizontal: pad),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final v = videos[i];
                final probing = _probingTrailerKey == v.key;
                final thumb =
                    McImageUrls.resolve(v.thumbnailUrl, widthPx: 480);
                return McPressable(
                  onTap: () => _playTrailer(v),
                  child: SizedBox(
                    width: 240,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 240,
                          height: 135,
                          decoration: BoxDecoration(
                            color: McTokens.posterPlaceholder,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: McTokens.line),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (thumb.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: thumb,
                                  httpHeaders: mcImageHeaders(),
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Center(
                                    child: Icon(
                                      McIcons.film,
                                      size: 28,
                                      color: McTokens.textFaint,
                                    ),
                                  ),
                                ),
                              Center(
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: Color(0x8C000000),
                                    shape: BoxShape.circle,
                                  ),
                                  child: probing
                                      ? const Padding(
                                          padding: EdgeInsets.all(11),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          McIcons.playFill,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x99000000),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    v.kind,
                                    style: McText.micro.copyWith(
                                      color: const Color(0xD9FFFFFF),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          v.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: McText.caption.muted,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoWall(TitleDetailData d, double pad) {
    final tabs = <({String id, String label, List<DiscoverPhoto> list})>[
      if (d.backdrops.isNotEmpty)
        (id: 'backdrops', label: '剧照', list: d.backdrops),
      if (d.posters.isNotEmpty) (id: 'posters', label: '海报', list: d.posters),
    ];
    if (tabs.isEmpty) return const SizedBox.shrink();
    final active = tabs.firstWhere(
      (t) => t.id == _photoTab,
      orElse: () => tabs.first,
    );
    final isLandscape = active.id == 'backdrops';
    final itemW = isLandscape ? 185.0 : 84.0;
    final itemH = isLandscape ? 104.0 : 126.0;

    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Row(
              children: [
                const Text('剧照与海报', style: McText.title),
                if (tabs.length > 1) ...[
                  const SizedBox(width: 12),
                  for (final t in tabs) ...[
                    McChip(
                      label: '${t.label} ${t.list.length}',
                      compact: true,
                      selected: t.id == active.id,
                      onTap: () => setState(() => _photoTab = t.id),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: itemH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              itemCount: active.list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final photo = active.list[i];
                final thumb = McImageUrls.resolve(
                  photo.previewUrl,
                  widthPx: isLandscape ? 480 : 240,
                );
                return GestureDetector(
                  onTap: () => DiscoverLightboxPage.show(
                    context,
                    urls: [for (final p in active.list) p.fullUrl],
                    thumbnails: [for (final p in active.list) p.previewUrl],
                    title: '${d.title} · ${active.label}',
                    initialIndex: i,
                    thumbAspect: isLandscape ? 16 / 9 : 2 / 3,
                  ),
                  child: Container(
                    width: itemW,
                    height: itemH,
                    decoration: BoxDecoration(
                      color: McTokens.posterPlaceholder,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: McTokens.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: thumb.isEmpty
                        ? const Icon(
                            McIcons.image3Fill,
                            color: McTokens.textFaint,
                          )
                        : CachedNetworkImage(
                            imageUrl: thumb,
                            httpHeaders: mcImageHeaders(),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                              McIcons.image3Fill,
                              color: McTokens.textFaint,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterShelf({
    required String title,
    required List<DiscTitle> items,
    required double pad,
  }) {
    final subs = ref.watch(discoverSubscriptionIndexProvider);
    final perms = ref.watch(permissionsProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McSectionHeader(
            title: title,
            padding: EdgeInsets.symmetric(horizontal: pad),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 234,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final t = items[i];
                final sub = subs.findByTitle(t);
                return McPosterCard(
                  title: t.title,
                  posterUrl: t.posterUrl,
                  width: 122,
                  subtitle: t.year?.toString(),
                  rating: (t.rating ?? 0) > 0 ? t.rating : null,
                  badge: t.owned ? '已入库' : (sub != null ? '已订阅' : null),
                  badgeDotColor:
                      t.owned ? McTokens.ok : (sub != null ? McTokens.info : null),
                  onTap: () =>
                      feat_discover.pushTitle(context, t.ref, seed: t),
                  contextActions: [
                    McPosterMenuAction(
                      icon: McIcons.film,
                      label: '查看详情',
                      onTap: () =>
                          feat_discover.pushTitle(context, t.ref, seed: t),
                    ),
                    if (perms.canSubscribe)
                      McPosterMenuAction(
                        icon: McIcons.bookmarkFill,
                        label: sub != null ? '管理订阅' : '订阅影片',
                        onTap: () async {
                          final out = await showSubscribeSheet(
                            context,
                            ref,
                            titleRef: t.ref,
                          );
                          if (out != null) {
                            ref
                                .read(
                                  discoverSubscriptionIndexProvider.notifier,
                                )
                                .refresh();
                          }
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalLinks(TitleDetailData d, double pad) {
    final tmdbUrl = d.provider == 'tmdb' && d.externalId.isNotEmpty
        ? 'https://www.themoviedb.org/${d.mediaType ?? 'movie'}/${d.externalId}'
        : null;
    final doubanUrl =
        (d.sourceUrl != null && d.sourceUrl!.isNotEmpty) ? d.sourceUrl : null;
    if (tmdbUrl == null && doubanUrl == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 28, pad, 0),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('相关链接', style: McText.sub.faint),
          if (tmdbUrl != null)
            GestureDetector(
              onTap: () => ExternalMediaLink.open(tmdbUrl),
              child: Text(
                'TMDB ↗',
                style: McText.sub.copyWith(color: McTokens.textMuted),
              ),
            ),
          if (doubanUrl != null)
            GestureDetector(
              onTap: () => ExternalMediaLink.open(doubanUrl),
              child: Text(
                '豆瓣 ↗',
                style: McText.sub.copyWith(color: McTokens.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// 4 行截断自动检测 + 展开全文 / 收起（对齐 iOS `MediaDetailView.overview`）。
class _CollapsibleOverview extends StatelessWidget {
  const _CollapsibleOverview({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final style = McText.bodyLg.copyWith(
      fontSize: 15,
      height: 1.55,
      color: const Color(0xC7FFFFFF),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 4,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: expanded ? null : 4,
              overflow:
                  expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: style,
            ),
            if (expanded || overflows) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onToggle,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expanded ? '收起' : '展开全文',
                      style: McText.sub.copyWith(
                        color: McTokens.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      expanded ? McIcons.arrowUpS : McIcons.arrowDownS,
                      size: 16,
                      color: McTokens.accent,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
