import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/session/permissions.dart';
import '../state/controllers.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../widgets/subs_home_sections.dart';

/// 订阅墙（1:1 对齐 iOS `SubscriptionWallView.swift`）：
/// 与订阅首页共享 `subscriptionsHomeProvider`（同 `today`/`recent`/`etas`/`tasks` 口径，
/// 排序与状态签完全一致）；墙上多一行「规则组 / 智能选择 → 媒体库」流向。
class SubscriptionWallPage extends ConsumerStatefulWidget {
  const SubscriptionWallPage({super.key, this.subscriptionId, this.kind});

  final int? subscriptionId;
  final String? kind;

  @override
  ConsumerState<SubscriptionWallPage> createState() =>
      _SubscriptionWallPageState();
}

class _SubscriptionWallPageState extends ConsumerState<SubscriptionWallPage> {
  List<WallItem>? _items;
  Map<int, String> _ruleSetNames = {};
  List<LibraryBrief> _libraries = const [];
  String? _error;
  bool _itemsLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLoad());
  }

  Future<void> _initLoad() async {
    if (widget.subscriptionId != null) {
      await _loadSingleWall();
      return;
    }
    await Future.wait([
      ref.read(subscriptionsHomeProvider.notifier).refreshIfStale(),
      _loadNames(),
    ]);
  }

  Future<void> _loadSingleWall() async {
    setState(() {
      _itemsLoading = true;
      _error = null;
    });
    try {
      final items = await ref
          .read(subscriptionsApiProvider)
          .subscriptionItems(widget.subscriptionId!);
      if (!mounted) return;
      setState(() {
        _items = items;
        _itemsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _itemsLoading = false;
      });
    }
  }

  Future<void> _loadNames() async {
    final api = ref.read(subscriptionsApiProvider);
    final perms = ref.read(permissionsProvider);
    try {
      final libsFuture = api.libraries().catchError((_) => <LibraryBrief>[]);
      final rulesFuture = perms.canManageSubscriptions
          ? api.ruleSets().catchError((_) => <RuleSetView>[])
          : Future.value(<RuleSetView>[]);
      final res = await Future.wait([libsFuture, rulesFuture]);
      if (!mounted) return;
      final libs = res[0] as List<LibraryBrief>;
      final rules = res[1] as List<RuleSetView>;
      setState(() {
        _libraries = libs;
        _ruleSetNames = {for (final r in rules) r.id: r.name};
      });
    } catch (_) {}
  }

  Future<void> _refresh() async {
    if (widget.subscriptionId != null) {
      await _loadSingleWall();
      return;
    }
    await Future.wait([
      ref.read(subscriptionsHomeProvider.notifier).reload(),
      _loadNames(),
    ]);
  }

  String? _flowLine(SubscriptionView sub) {
    final rule = sub.isSmart
        ? '智能选择'
        : (sub.ruleSetId != null ? _ruleSetNames[sub.ruleSetId] : null);
    final lib = (sub.libraryId != null
            ? _libraries.where((l) => l.id == sub.libraryId).firstOrNull?.name
            : null) ??
        _libraries
            .where((l) => l.isDefault && l.kind == sub.media.kind)
            .firstOrNull
            ?.name;
    final parts = [
      if (rule != null && rule.isNotEmpty) rule,
      if (lib != null && lib.isNotEmpty) lib,
    ];
    return parts.isEmpty ? null : parts.join(' → ');
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.subscriptionId != null
        ? '订阅资源墙'
        : widget.kind == 'movie'
            ? McStrings.subsMovieShelfTitle
            : widget.kind == 'tv'
                ? McStrings.subsTvShelfTitle
                : '订阅墙';

    final homeState = widget.subscriptionId == null
        ? ref.watch(subscriptionsHomeProvider)
        : null;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          McFloatingDetailBar(
            onBack: () => context.canPop()
                ? context.pop()
                : context.go('/subscriptions'),
            title: title,
            titleVisible: true,
          ),
          Expanded(
            child: widget.subscriptionId != null
                ? (_itemsLoading
                    ? const McLoadingView()
                    : _error != null
                        ? McErrorView(text: _error!, onRetry: _refresh)
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: _buildSingleWallBody(),
                          ))
                : (homeState!.isLoading && !homeState.hasValue)
                    ? const McLoadingView()
                    : (homeState.hasError && !homeState.hasValue)
                        ? McErrorView(
                            text: '${homeState.error}',
                            onRetry: _refresh,
                          )
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: _buildSharedWallBody(homeState.valueOrNull),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleWallBody() {
    final form = McFormWatch.of(context);
    final items = _items ?? const <WallItem>[];
    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Center(child: Text('暂无资源', style: McText.sub.muted)),
        ],
      );
    }
    final delegate = form == McDeviceForm.phone
        ? const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            mainAxisSpacing: 14,
            crossAxisSpacing: 12,
            childAspectRatio: 0.515,
          )
        : SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: mcGridCrossAxisCount(
              form,
              BoxConstraints.tightFor(width: MediaQuery.widthOf(context) - 32),
              cellExtent: 150,
            ),
            mainAxisSpacing: 14,
            crossAxisSpacing: 12,
            childAspectRatio: 0.515,
          );

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        12,
        McTokens.pagePadding,
        32,
      ),
      gridDelegate: delegate,
      itemCount: items.length,
      itemBuilder: (context, i) => McFocusRing(
        borderRadius: McTokens.posterRadius,
        child: GestureDetector(
          onTap: () => context.push(
            '/search?q=${Uri.encodeComponent(items[i].title)}&tab=library',
          ),
          child: _PosterTile(
            title: items[i].title,
            posterUrl: items[i].posterUrl,
            subtitle: items[i].kind,
          ),
        ),
      ),
    );
  }

  Widget _buildSharedWallBody(SubsHomeBundle? bundle) {
    if (bundle == null || bundle.subs.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Center(
            child: Text(
              McStrings.subsEmptyNoPermission,
              textAlign: TextAlign.center,
              style: McText.sub.muted,
            ),
          ),
        ],
      );
    }

    final home = bundle.home();
    final kind = widget.kind ?? 'tv';
    final split = home.shelfSplit(kind);
    final activeCount = split.active.length;
    final summary = McStrings.subsWallSummary(split.all.length, activeCount);

    Widget section(String label, List<SubscriptionView> list) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              18,
              McTokens.pagePadding,
              10,
            ),
            child: Text(
              McStrings.subsWallSection(label, list.length),
              style: McText.titleSm,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final s in list)
                  McFocusRing(
                    borderRadius: McTokens.posterRadius,
                    child: SubsPosterCard(
                      sub: s,
                      home: home,
                      flowLine: _flowLine(s),
                      onOpen: () =>
                          context.push('/subscriptions/detail/${s.id}'),
                      onOpenMedia: () => subsOpenMedia(context, s.media),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            McTokens.pagePadding,
            8,
            McTokens.pagePadding,
            0,
          ),
          child: Text(summary, style: McText.caption.muted),
        ),
        section(McStrings.subsWallSectionActive, split.active),
        section(McStrings.subsWallSectionPaused, split.paused),
        section(kind == 'movie' ? '已入库' : '已收齐', split.done),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({
    required this.title,
    this.posterUrl,
    this.subtitle,
  });

  final String title;
  final String? posterUrl;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(McTokens.posterRadius),
            child: SizedBox.expand(
              child: posterUrl != null
                  ? CachedNetworkImage(
                      httpHeaders: mcImageHeaders(),
                      imageUrl: McImageUrls.resolve(posterUrl),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: McTokens.posterPlaceholder,
                      ),
                    )
                  : const ColoredBox(color: McTokens.posterPlaceholder),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: McText.posterTitle,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: McText.micro.muted,
          ),
      ],
    );
  }
}
