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
import '../state/home_model.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../widgets/subs_home_sections.dart';

/// 订阅墙（对齐鸿蒙 SubscriptionWallPage.ets）：
/// 传 [subscriptionId] = 单订阅资源墙；否则按 kind 分三段海报墙。
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
  List<SubscriptionView>? _subs;
  Map<int, String> _ruleSetNames = {};
  Map<int, String> _libraryNames = {};
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = ref.read(subscriptionsApiProvider);
    try {
      if (widget.subscriptionId != null) {
        final items = await api.subscriptionItems(widget.subscriptionId!);
        if (!mounted) return;
        setState(() {
          _items = items;
          _loading = false;
        });
        return;
      }
      final subs = await api.subscriptions(kind: widget.kind);
      try {
        final rules = await api.ruleSets();
        final libs = await api.libraries(kind: widget.kind);
        if (!mounted) return;
        setState(() {
          _ruleSetNames = {for (final r in rules) r.id: r.name};
          _libraryNames = {for (final l in libs) l.id: l.name};
        });
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _subs = subs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String? _flowLine(SubscriptionView sub) {
    if (_ruleSetNames.isEmpty) return null;
    final rule =
        sub.ruleSetId == null ? '默认' : (_ruleSetNames[sub.ruleSetId] ?? '');
    final lib =
        sub.libraryId == null ? '' : (_libraryNames[sub.libraryId] ?? '');
    if (rule.isEmpty && lib.isEmpty) return null;
    return '$rule → $lib';
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
            child: _loading
                ? const McLoadingView()
                : _error != null
                    ? McErrorView(text: _error!, onRetry: _load)
                    : RefreshIndicator(onRefresh: _load, child: _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final form = McFormWatch.of(context);
    SliverGridDelegate wallDelegate(McDeviceForm form) {
      if (form == McDeviceForm.phone) {
        return const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 126 / 220,
        );
      }
      return SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: mcGridCrossAxisCount(
          form,
          BoxConstraints.tightFor(width: MediaQuery.widthOf(context) - 32),
          cellExtent: 150,
        ),
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 126 / 220,
      );
    }

    final items = _items;
    if (items != null) {
      if (items.isEmpty) {
        return ListView(
          children: [
            const SizedBox(height: 96),
            Center(child: Text('暂无资源', style: McText.sub.muted)),
          ],
        );
      }
      return GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          McTokens.pagePadding,
          12,
          McTokens.pagePadding,
          32,
        ),
        gridDelegate: wallDelegate(form),
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

    final subs = _subs ?? const <SubscriptionView>[];
    if (subs.isEmpty) {
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
    final home = SubsHome(subs, const [], const [], const {});
    final kind = widget.kind ?? 'tv';
    final split = home.shelfSplit(kind);
    final activeCount = split.active.length;
    final summary = McStrings.subsWallSummary(split.all.length, activeCount);

    Widget section(
      String label,
      List<SubscriptionView> list, {
      bool dim = false,
    }) {
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
                  Opacity(
                    opacity: dim ? 0.55 : 1,
                    child: McFocusRing(
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
        section(McStrings.subsWallSectionPaused, split.paused, dim: true),
        section(home.restingLabel(kind), split.done, dim: true),
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
