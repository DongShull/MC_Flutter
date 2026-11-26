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
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';

/// 发现侧条目详情状态（GET /discover/titles/{titleRef}）。
class TitleDetailState {
  const TitleDetailState({
    this.loading = true,
    this.error,
    this.title,
    this.overview,
    this.year,
    this.rating,
    this.posterUrl,
    this.backdropUrl,
    this.genres = const [],
    this.cast = const [],
    this.inLibrary = false,
  });

  final bool loading;
  final String? error;
  final String? title;
  final String? overview;
  final int? year;
  final double? rating;
  final String? posterUrl;
  final String? backdropUrl;
  final List<String> genres;
  final List<({String name, String role, String? profileUrl})> cast;
  final bool inLibrary;

  TitleDetailState copyWith({
    bool? loading,
    Object? error = _sentinel,
    String? title,
    String? overview,
    int? year,
    double? rating,
    String? posterUrl,
    String? backdropUrl,
    List<String>? genres,
    List<({String name, String role, String? profileUrl})>? cast,
    bool? inLibrary,
  }) =>
      TitleDetailState(
        loading: loading ?? this.loading,
        error: identical(error, _sentinel) ? this.error : error as String?,
        title: title ?? this.title,
        overview: overview ?? this.overview,
        year: year ?? this.year,
        rating: rating ?? this.rating,
        posterUrl: posterUrl ?? this.posterUrl,
        backdropUrl: backdropUrl ?? this.backdropUrl,
        genres: genres ?? this.genres,
        cast: cast ?? this.cast,
        inLibrary: inLibrary ?? this.inLibrary,
      );

  static const _sentinel = Object();
}

class TitleDetailController extends Notifier<TitleDetailState> {
  McClient? _client;
  McClient get _mc =>
      _client ??= McClient(session: ref.read(sessionStoreProvider));

  @override
  TitleDetailState build() => const TitleDetailState();

  Future<void> load(String titleRef) async {
    if (titleRef.isEmpty) {
      state = state.copyWith(loading: false, error: '缺少条目 ref');
      return;
    }
    state = const TitleDetailState();
    try {
      final d = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/discover/titles/${Uri.encodeComponent(titleRef)}',
      );
      final lib = d['library_status'];
      final castRaw = (d['cast'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (c) => (
              name: (c['name'] ?? '').toString(),
              role: (c['character'] ?? c['role'] ?? '').toString(),
              profileUrl:
                  c['profile_url']?.toString() ?? c['avatar_url']?.toString(),
            ),
          )
          .toList();
      state = state.copyWith(
        loading: false,
        title: (d['title'] ?? '').toString(),
        overview: d['overview']?.toString(),
        year: (d['release_year'] as num?)?.toInt(),
        rating: (d['provider_rating'] as num?)?.toDouble(),
        posterUrl: d['poster_url']?.toString(),
        backdropUrl:
            d['backdrop_url']?.toString() ?? d['poster_url']?.toString(),
        genres: [
          for (final g in (d['genres'] as List<dynamic>? ?? const []))
            g.toString(),
        ],
        cast: castRaw,
        inLibrary: lib is Map && ((lib['file_count'] as num? ?? 0).toInt() > 0),
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(loading: false, error: '网络错误，请稍后重试');
    }
  }
}

final titleDetailProvider =
    NotifierProvider<TitleDetailController, TitleDetailState>(
      TitleDetailController.new,
    );

/// 发现条目沉浸式详情页（全出血剧照 + 底边动态取色 + 亮银白胶囊「订阅影片」）。
class TitleDetailPage extends ConsumerStatefulWidget {
  const TitleDetailPage({super.key, required this.titleRef});

  final String titleRef;

  @override
  ConsumerState<TitleDetailPage> createState() => _TitleDetailPageState();
}

class _TitleDetailPageState extends ConsumerState<TitleDetailPage> {
  double _scrollOffset = 0;
  Color? _edgeColor;
  String? _sampledUrl;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(titleDetailProvider.notifier).load(widget.titleRef),
    );
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
      context.go('/home');
    }
  }

  Future<void> _onSubscribe() async {
    final outcome = await showSubscribeSheet(
      context,
      ref,
      titleRef: widget.titleRef,
    );
    if (!mounted || outcome == null) return;
    if (outcome == SubscribeSheetOutcome.created) {
      McToast.success('已加入追更订阅');
    } else {
      context.push('/subscriptions');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(titleDetailProvider);
    final topPad = MediaQuery.paddingOf(context).top;
    final form = McFormWatch.of(context);
    final pad = form == McDeviceForm.phone
        ? McTokens.pagePadding
        : McTokens.pagePaddingWide;

    if (s.loading) {
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

    if (s.error != null) {
      return Scaffold(
        backgroundColor: McTokens.bg,
        body: Stack(
          children: [
            McErrorView(
              text: s.error!,
              onRetry: () =>
                  ref.read(titleDetailProvider.notifier).load(widget.titleRef),
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

    _ensureAmbient(s.backdropUrl ?? s.posterUrl);
    final ambient = _edgeColor ?? McTokens.bg;
    final heroHeight = topPad + 320.0;
    final resolvedHero = McImageUrls.resolve(
      s.backdropUrl ?? s.posterUrl,
      widthPx: 1280,
    );
    final stretch = _scrollOffset < 0
        ? (1.0 + (-_scrollOffset) / heroHeight).clamp(1.0, 1.32)
        : 1.0;
    final parallax =
        _scrollOffset > 0 ? math.min(_scrollOffset * 0.25, 68.0) : 0.0;

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
            child: ListView(
              padding: const EdgeInsets.only(bottom: 48),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
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
                            child: resolvedHero.isEmpty
                                ? const ColoredBox(
                                    color: McTokens.posterPlaceholder,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: resolvedHero,
                                    httpHeaders: mcImageHeaders(),
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const ColoredBox(
                                      color: McTokens.posterPlaceholder,
                                    ),
                                    errorWidget: (_, __, ___) =>
                                        const ColoredBox(
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
                            stops: const [0.0, 0.45, 0.80, 1.0],
                            colors: [
                              const Color(0x38000000),
                              ambient.withValues(alpha: 0.16),
                              ambient.withValues(alpha: 0.85),
                              ambient,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: pad,
                        right: pad,
                        bottom: 8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 100,
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
                                url: s.posterUrl,
                                widthPx: 320,
                                fallbackText: s.title,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    s.title ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: McText.titleLg,
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      if (s.year != null)
                                        Text(
                                          s.year.toString(),
                                          style: McText.caption.muted.tabular,
                                        ),
                                      if (s.rating != null && s.rating! > 0)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              McIcons.star2Fill,
                                              size: 13,
                                              color: McTokens.warning,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              s.rating!.toStringAsFixed(1),
                                              style: McText.caption
                                                  .copyWith(
                                                    color: McTokens.text,
                                                    fontWeight: FontWeight.w600,
                                                  )
                                                  .tabular,
                                            ),
                                          ],
                                        ),
                                      if (s.inLibrary)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0x1F4ADE80),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: const Color(0x4D4ADE80),
                                            ),
                                          ),
                                          child: Text(
                                            '● 已在库',
                                            style: McText.micro.copyWith(
                                              color: McTokens.ok,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (s.genres.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final g in s.genres.take(4))
                                          McChip(label: g, compact: true),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 408),
                      child: McFocusRing(
                        borderRadius: McTokens.pillRadius,
                        child: McActionPill(
                          label: s.inLibrary ? '管理 / 追更订阅' : '订阅影片',
                          icon: McIcons.bookmarkFill,
                          primary: true,
                          expanded: true,
                          height: 44,
                          onTap: _onSubscribe,
                        ),
                      ),
                    ),
                  ),
                ),
                if (s.overview != null && s.overview!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
                    child: Text(
                      s.overview!,
                      style: McText.bodyLg.copyWith(
                        fontSize: 15,
                        height: 1.55,
                        color: const Color(0xD6F3F5F9),
                      ),
                    ),
                  ),
                if (s.cast.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const McSectionHeader(title: '演职员'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 116,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      itemCount: s.cast.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final c = s.cast[i];
                        final resolved = McImageUrls.resolve(
                          c.profileUrl,
                          widthPx: 180,
                        );
                        return SizedBox(
                          width: 74,
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: McTokens.posterPlaceholder,
                                  border: Border.all(
                                    color: McTokens.line,
                                    width: 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: resolved.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: resolved,
                                        httpHeaders: mcImageHeaders(),
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(
                                          McIcons.user,
                                          color: McTokens.textFaint,
                                        ),
                                      )
                                    : const Icon(
                                        McIcons.user,
                                        color: McTokens.textFaint,
                                      ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: McText.caption.copyWith(
                                  color: McTokens.text,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (c.role.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  c.role,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: McText.micro.copyWith(
                                    fontWeight: FontWeight.w400,
                                    color: McTokens.textFaint,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: McFloatingDetailBar(
              onBack: _back,
              title: s.title ?? '作品详情',
              titleVisible: _scrollOffset > 200,
            ),
          ),
        ],
      ),
    );
  }
}
