// IMPLEMENTED — 1:1 重写自 MovieClaw feature/discover/TitleDetailScreen.kt。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/subscribe_sheet.dart';

/// 本 feature 会话入口（core 不发全局 provider；与 onboarding/library 同构）。
/// 发现侧条目详情状态（GET /discover/titles/{titleRef}；展示信息实时拉取不落缓存）。
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
  McClient get _mc => _client ??= McClient(session: ref.read(sessionStoreProvider));

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
          .map((c) => (
                name: (c['name'] ?? '').toString(),
                role: (c['character'] ?? c['role'] ?? '').toString(),
                profileUrl: c['profile_url']?.toString() ?? c['avatar_url']?.toString(),
              ))
          .toList();
      state = state.copyWith(
        loading: false,
        title: (d['title'] ?? '').toString(),
        overview: d['overview']?.toString(),
        year: (d['release_year'] as num?)?.toInt(),
        rating: (d['provider_rating'] as num?)?.toDouble(),
        posterUrl: d['poster_url']?.toString(),
        backdropUrl: d['backdrop_url']?.toString() ?? d['poster_url']?.toString(),
        genres: [for (final g in (d['genres'] as List<dynamic>? ?? const [])) g.toString()],
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
    NotifierProvider<TitleDetailController, TitleDetailState>(TitleDetailController.new);

/// 发现条目详情页：承载订阅入口（title_ref 原样交给订阅弹层，本页不预先建档）。
class TitleDetailPage extends ConsumerStatefulWidget {
  const TitleDetailPage({super.key, required this.titleRef});

  final String titleRef;

  @override
  ConsumerState<TitleDetailPage> createState() => _TitleDetailPageState();
}

class _TitleDetailPageState extends ConsumerState<TitleDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(titleDetailProvider.notifier).load(widget.titleRef));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(titleDetailProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.title ?? '详情')),
      body: s.loading
          ? const McLoadingView()
          : s.error != null
              ? Center(child: Text(s.error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: McPosterCard(
                            title: s.title ?? '',
                            posterUrl: s.posterUrl,
                            rating: s.rating,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (s.year != null || s.genres.isNotEmpty)
                                Text(
                                  [
                                    if (s.year != null) s.year.toString(),
                                    ...s.genres.take(3),
                                  ].join(' · '),
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.white.withValues(alpha: 0.65)),
                                ),
                              if (s.rating != null && s.rating! > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '★ ${s.rating!.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              if (s.inLibrary)
                                const Text(
                                  '在库',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF99F2CC)),
                                ),
                              // 订阅入口：未订阅 → 订阅弹层；已订阅 → 订阅管理。
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () async {
                                  // 订阅弹层（core 共用；§5.2，传 widget.titleRef）。
                                  final outcome = await showSubscribeSheet(
                                    context,
                                    ref,
                                    titleRef: widget.titleRef,
                                  );
                                  if (!context.mounted || outcome == null) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        outcome == SubscribeSheetOutcome.created
                                            ? '订阅成功'
                                            : '前往订阅管理',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(McIcons.bellOnFill),
                                label: const Text('订阅影片'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (s.overview != null && s.overview!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('简介',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        s.overview!,
                        style: TextStyle(
                            fontSize: 14, height: 1.5, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                    if (s.cast.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('演职员',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: s.cast.length,
                          itemBuilder: (context, i) {
                            final c = s.cast[i];
                            return SizedBox(
                              width: 90,
                              child: Column(
                                children: [
                                  ClipOval(
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      color: Colors.white.withValues(alpha: 0.08),
                                      child: c.profileUrl != null
                                          ? Image.network(c.profileUrl!, fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(McIcons.user, color: Colors.white24))
                                          : const Icon(McIcons.user, color: Colors.white24),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    c.role,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}
