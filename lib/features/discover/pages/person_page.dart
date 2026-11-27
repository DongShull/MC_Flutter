import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/session/permissions.dart';
import '../routes.dart' as feat_discover;
import '../state/discover_controller.dart';

/// TMDB 影人页状态（`GET /api/v1/discover/people/{tmdbPersonId}`）。
class PersonState {
  const PersonState({
    this.loading = true,
    this.uploadingAvatar = false,
    this.error,
    this.name,
    this.originalName,
    this.avatarUrl,
    this.titles = const [],
  });

  final bool loading;
  final bool uploadingAvatar;
  final String? error;
  final String? name;
  final String? originalName;
  final String? avatarUrl;
  final List<DiscTitle> titles;

  PersonState copyWith({
    bool? loading,
    bool? uploadingAvatar,
    Object? error = _sentinel,
    String? name,
    Object? originalName = _sentinel,
    Object? avatarUrl = _sentinel,
    List<DiscTitle>? titles,
  }) =>
      PersonState(
        loading: loading ?? this.loading,
        uploadingAvatar: uploadingAvatar ?? this.uploadingAvatar,
        error: identical(error, _sentinel) ? this.error : error as String?,
        name: name ?? this.name,
        originalName: identical(originalName, _sentinel)
            ? this.originalName
            : originalName as String?,
        avatarUrl: identical(avatarUrl, _sentinel)
            ? this.avatarUrl
            : avatarUrl as String?,
        titles: titles ?? this.titles,
      );

  static const _sentinel = Object();
}

class PersonController extends AutoDisposeFamilyNotifier<PersonState, int> {
  McClient? _client;
  McClient get _mc =>
      _client ??= McClient(session: ref.read(sessionStoreProvider));

  @override
  PersonState build(int personId) {
    Future.microtask(() => load(personId));
    return const PersonState();
  }

  Future<void> load([int? overrideId]) async {
    final personId = overrideId ?? arg;
    if (personId <= 0) {
      state = state.copyWith(loading: false, error: '缺少人物 id');
      return;
    }
    state = state.copyWith(loading: state.name == null, error: null);
    try {
      final raw = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'GET',
        '/api/v1/discover/people/$personId',
      );
      final titles = <DiscTitle>[];
      for (final el in (raw['titles'] as List<dynamic>? ?? const [])) {
        if (el is Map) {
          final t = DiscTitle.fromJson(Map<String, dynamic>.from(el));
          if (t != null) titles.add(t);
        }
      }
      final avatar = (raw['avatar_url'] ?? raw['profile_url'])?.toString();
      final orig = raw['original_name']?.toString();
      state = state.copyWith(
        loading: false,
        name: (raw['name'] ?? '').toString(),
        originalName: (orig != null && orig.isNotEmpty) ? orig : null,
        avatarUrl: (avatar != null && avatar.isNotEmpty) ? avatar : null,
        titles: titles,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(loading: false, error: '网络错误，请稍后重试');
    }
  }

  /// 管理员上传自定义影人头像：`PUT /api/v1/people/$personId/avatar`（405 回退 `POST` `McClient.postMultipart`）。
  Future<String?> uploadAvatar(String filePath, {String fileName = 'avatar.jpg'}) async {
    final personId = arg;
    if (personId <= 0 || state.uploadingAvatar) return null;
    state = state.copyWith(uploadingAvatar: true);
    try {
      Map<String, dynamic>? resp;
      try {
        final form = FormData.fromMap(<String, dynamic>{
          'file': await MultipartFile.fromFile(
            filePath,
            filename: fileName,
            contentType: DioMediaType('image', 'jpeg'),
          ),
        });
        resp = await _mc.unwrap<Map<String, dynamic>>(
          Channel.general,
          'PUT',
          '/api/v1/people/$personId/avatar',
          body: form,
        );
      } on ApiException catch (e) {
        if (e.httpStatus == 405) {
          resp = await _mc.postMultipart<Map<String, dynamic>>(
            Channel.general,
            '/api/v1/people/$personId/avatar',
            fileField: 'file',
            filePath: filePath,
            fileName: fileName,
            contentType: 'image/jpeg',
          );
        } else {
          rethrow;
        }
      }
      final newAvatar = resp['avatar_url']?.toString();
      state = state.copyWith(
        uploadingAvatar: false,
        avatarUrl: (newAvatar != null && newAvatar.isNotEmpty)
            ? newAvatar
            : state.avatarUrl,
      );
      await load(personId);
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(uploadingAvatar: false);
      return e.friendlyMessage;
    } catch (_) {
      state = state.copyWith(uploadingAvatar: false);
      return '上传头像失败，请重试';
    }
  }
}

final personProvider = NotifierProvider.autoDispose
    .family<PersonController, PersonState, int>(PersonController.new);

/// 发现侧 TMDB 影人页（对齐 iOS `DiscoveredPersonView.swift` + `PersonHeader` + 管理员自定义头像上传）。
class PersonPage extends ConsumerStatefulWidget {
  const PersonPage({super.key, required this.personId});

  final int personId;

  @override
  ConsumerState<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends ConsumerState<PersonPage> {
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _scrollOffset.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home?tab=discover');
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    final err = await ref
        .read(personProvider(widget.personId).notifier)
        .uploadAvatar(picked.path, fileName: picked.name);
    if (!mounted) return;
    if (err != null) {
      McToast.error(err);
    } else {
      McToast.success('影人头像已更新');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(personProvider(widget.personId));
    final perms = ref.watch(permissionsProvider);
    final subs = ref.watch(discoverSubscriptionIndexProvider);
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final form = McFormWatch.of(context);
    final pad = form == McDeviceForm.phone
        ? McTokens.pagePadding
        : McTokens.pagePaddingWide;

    final movieCount = s.titles.where((t) => t.mediaType != 'tv').length;
    final tvCount = s.titles.where((t) => t.mediaType == 'tv').length;
    final summary = movieCount > 0 && tvCount > 0
        ? '共 ${s.titles.length} 部作品（电影 $movieCount · 剧集 $tvCount）'
        : '共 ${s.titles.length} 部影视作品';

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (s.loading)
            const McFeedSkeleton(showHero: false)
          else if (s.error != null)
            McErrorView(
              text: s.error!,
              onRetry: () =>
                  ref.read(personProvider(widget.personId).notifier).load(),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = mcGridCrossAxisCount(
                  form,
                  constraints,
                  cellExtent: 122,
                );
                final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.515,
                );
                return NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.axis == Axis.vertical && n.depth == 0) {
                      _scrollOffset.value = n.metrics.pixels;
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    edgeOffset: topPad + 56,
                    color: McTokens.accentStrong,
                    backgroundColor: McTokens.surfaceSolid,
                    onRefresh: () => ref
                        .read(personProvider(widget.personId).notifier)
                        .load(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // 2:3 PersonHeader（头像 + 眉题 + 姓名 + 原名 + 作品统计 + 管理员上传头像）
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              pad,
                              topPad + 64,
                              pad,
                              22,
                            ),
                            child: _PersonHeader(
                              name: s.name ?? '影人',
                              originalName: s.originalName != null &&
                                      s.originalName != s.name
                                  ? s.originalName
                                  : null,
                              avatarUrl: s.avatarUrl,
                              eyebrow: 'TMDB 影人',
                              summary: summary,
                              canUploadAvatar: perms.isAdmin,
                              uploadingAvatar: s.uploadingAvatar,
                              onUploadAvatar: _pickAndUploadAvatar,
                            ),
                          ),
                        ),
                        if (s.titles.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: McEmptyView(text: '暂无相关影视作品'),
                          )
                        else ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  const Text('全部作品', style: McText.title),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${s.titles.length}',
                                    style: McText.sub.faint.tabular,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              pad,
                              0,
                              pad,
                              48 + bottomPad,
                            ),
                            sliver: SliverGrid(
                              gridDelegate: gridDelegate,
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final t = s.titles[i];
                                  final sub = subs.findByTitle(t);
                                  final badge = t.owned
                                      ? '已入库'
                                      : (sub != null ? '已订阅' : null);
                                  final badgeColor = t.owned
                                      ? McTokens.ok
                                      : (sub != null ? McTokens.info : null);
                                  return McFocusRing(
                                    borderRadius: McTokens.posterRadius,
                                    child: McPosterCard(
                                      title: t.title,
                                      posterUrl: t.posterUrl,
                                      width: null,
                                      subtitle: [
                                        if (t.year != null) '${t.year}',
                                        if (t.extentLabel.isNotEmpty)
                                          t.extentLabel,
                                      ].join(' · '),
                                      rating: (t.rating ?? 0) > 0
                                          ? t.rating
                                          : null,
                                      badge: badge,
                                      badgeDotColor: badgeColor,
                                      onTap: () => feat_discover.pushTitle(
                                        context,
                                        t.ref,
                                        seed: t,
                                      ),
                                      contextActions: [
                                        McPosterMenuAction(
                                          icon: McIcons.film,
                                          label: '查看详情',
                                          onTap: () => feat_discover.pushTitle(
                                            context,
                                            t.ref,
                                            seed: t,
                                          ),
                                        ),
                                        if (perms.canSubscribe)
                                          McPosterMenuAction(
                                            icon: McIcons.bookmarkFill,
                                            label:
                                                sub != null ? '管理订阅' : '订阅影片',
                                            onTap: () async {
                                              final out =
                                                  await showSubscribeSheet(
                                                context,
                                                ref,
                                                titleRef: t.ref,
                                              );
                                              if (!mounted || out == null) {
                                                return;
                                              }
                                              ref
                                                  .read(
                                                    discoverSubscriptionIndexProvider
                                                        .notifier,
                                                  )
                                                  .refresh();
                                              if (out ==
                                                  SubscribeSheetOutcome
                                                      .created) {
                                                McToast.success('已加入追更订阅');
                                              } else if (out ==
                                                  SubscribeSheetOutcome
                                                      .managed) {
                                                this.context.push(
                                                      '/subscriptions',
                                                    );
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                  );
                                },
                                childCount: s.titles.length,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (_, offset, __) => McFloatingDetailBar(
                onBack: _back,
                title: s.name ?? '影人',
                titleVisible: offset > 88,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2:3 影人头部（对齐 iOS `PersonHeader` + 管理员自定义头像上传）。
class _PersonHeader extends StatelessWidget {
  const _PersonHeader({
    required this.name,
    required this.eyebrow,
    required this.summary,
    this.originalName,
    this.avatarUrl,
    this.canUploadAvatar = false,
    this.uploadingAvatar = false,
    this.onUploadAvatar,
  });

  final String name;
  final String? originalName;
  final String? avatarUrl;
  final String eyebrow;
  final String summary;
  final bool canUploadAvatar;
  final bool uploadingAvatar;
  final VoidCallback? onUploadAvatar;

  @override
  Widget build(BuildContext context) {
    final resolved = McImageUrls.resolve(avatarUrl, widthPx: 240);
    final initial = name.trim().isNotEmpty ? name.trim().substring(0, 1) : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: canUploadAvatar && !uploadingAvatar ? onUploadAvatar : null,
          child: Container(
            width: 92,
            height: 138,
            decoration: BoxDecoration(
              color: const Color(0x0FFFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: McTokens.lineStrong, width: 0.8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 34,
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
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                if (uploadingAvatar)
                  const ColoredBox(
                    color: Color(0x88000000),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else if (canUploadAvatar)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xA6000000),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: McTokens.lineStrong,
                          width: 0.6,
                        ),
                      ),
                      child: const Icon(
                        McIcons.imageUpload,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: McText.micro.copyWith(
                  color: McTokens.accent2,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(name, style: McText.titleLg),
              if (originalName != null) ...[
                const SizedBox(height: 2),
                Text(
                  originalName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: McText.sub.copyWith(color: const Color(0x8CFFFFFF)),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                summary,
                style: McText.sub
                    .copyWith(color: const Color(0xB3FFFFFF))
                    .tabular,
              ),
              if (canUploadAvatar) ...[
                const SizedBox(height: 10),
                McGlassButton(
                  onTap: uploadingAvatar ? null : onUploadAvatar,
                  tone: McGlassTone.secondary,
                  radius: McTokens.pillRadius,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(McIcons.imageUpload, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        uploadingAvatar ? '正在上传…' : '更换头像',
                        style: McText.caption.semibold,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
