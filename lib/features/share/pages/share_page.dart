import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../state/share_controller.dart';

/// 访客分享页（对齐 Kotlin ShareScreen）：探测 → 密码门 → 条目详情 / 合集列表。
/// 独立壳：无底栏、无侧栏、无站内入口（设计文档 05 §4.3）。
class SharePage extends ConsumerStatefulWidget {
  const SharePage({super.key, this.slug = '', this.origin});

  final String slug;
  final String? origin;

  @override
  ConsumerState<SharePage> createState() => _SharePageState();
}

class _SharePageState extends ConsumerState<SharePage> {
  @override
  void initState() {
    super.initState();
    if (widget.origin != null && widget.origin!.isNotEmpty) {
      Future.microtask(
        () => ref.read(shareOriginProvider.notifier).state = widget.origin!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slug = widget.slug;
    if (slug.isEmpty) {
      return Scaffold(
        backgroundColor: McTokens.bg,
        body: Center(child: Text('分享不存在或已取消', style: McText.sub.muted)),
      );
    }
    final state = ref.watch(shareControllerFamily(slug));
    final controller = ref.read(shareControllerFamily(slug).notifier);
    final form = McFormWatch.of(context);
    final contentWidth =
        mcWindowClassOf(form) == McWindowClass.compact ? 560.0 : 720.0;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: McFloatingDetailBar(
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go('/onboarding'),
                title: '分享',
                titleVisible: true,
                trailing: [
                  if (state.probe?.expiresAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: McTokens.surfaceInset,
                        borderRadius:
                            BorderRadius.circular(McTokens.pillRadius),
                        border: Border.all(color: McTokens.line),
                      ),
                      child: Text(
                        '至 ${state.probe!.expiresAt!}',
                        style: McText.micro.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: _body(context, state, controller),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ShareUiState state,
    ShareController controller,
  ) {
    if (state.loading) {
      return const McLoadingView();
    }
    final error = state.error;
    if (error != null) {
      return McErrorView(text: error, onRetry: controller.probe);
    }
    if (state.needsPassword) {
      return _PasswordGate(state: state, controller: controller);
    }
    final collection = state.collection;
    if (collection != null) {
      return _SharedCollectionList(
        controller: controller,
        collection: collection,
      );
    }
    final item = state.item;
    final origin = ref.read(shareOriginProvider);
    if (item != null) {
      final api = GuestShareApi(origin);
      return _SharedItemDetail(
        state: state,
        controller: controller,
        item: item,
        posterUrl: api.imageUrl(item.posterUrl),
        backdropUrl: api.imageUrl(item.backdropUrl),
      );
    }
    return const SizedBox.shrink();
  }
}

class _PasswordGate extends StatelessWidget {
  const _PasswordGate({required this.state, required this.controller});

  final ShareUiState state;
  final ShareController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: McTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(McTokens.sheetRadius),
            border: Border.all(color: McTokens.lineStrong, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                McIcons.lock,
                color: McTokens.accentStrong,
                size: 30,
              ),
              const SizedBox(height: 12),
              const Center(child: Text('这是一个加密分享', style: McText.titleSm)),
              const SizedBox(height: 6),
              Center(
                child: Text('请输入分享者提供的密码', style: McText.sub.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                obscureText: true,
                autofocus: true,
                style: McText.body,
                onChanged: controller.onPassword,
                onSubmitted: (_) {
                  if (state.password.isNotEmpty) controller.unlock();
                },
                decoration: const InputDecoration(hintText: '访问密码'),
              ),
              const SizedBox(height: 16),
              McFocusRing(
                borderRadius: McTokens.pillRadius,
                child: McActionPill(
                  label: '解锁访问',
                  primary: true,
                  expanded: true,
                  height: 44,
                  onTap: state.password.isEmpty ? null : controller.unlock,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedCollectionList extends StatelessWidget {
  const _SharedCollectionList({
    required this.controller,
    required this.collection,
  });

  final ShareController controller;
  final SharedCollection collection;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        McTokens.pagePadding,
        12,
        McTokens.pagePadding,
        32,
      ),
      children: [
        Text(
          collection.name.isEmpty ? '分享合集' : collection.name,
          style: McText.titleLg,
        ),
        if (collection.description != null &&
            collection.description!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(collection.description!, style: McText.sub.muted),
        ],
        const SizedBox(height: 16),
        McInsetGroup(
          margin: EdgeInsets.zero,
          children: [
            for (final item in collection.items)
              McInsetRow(
                icon: item.kind == 'tv' ? McIcons.tv : McIcons.movie,
                title: item.year != null
                    ? '${item.title}（${item.year}）'
                    : item.title,
                valueText: item.kind == 'tv' ? '剧集' : '电影',
              ),
          ],
        ),
      ],
    );
  }
}

class _SharedItemDetail extends StatelessWidget {
  const _SharedItemDetail({
    required this.state,
    required this.controller,
    required this.item,
    this.posterUrl,
    this.backdropUrl,
  });

  final ShareUiState state;
  final ShareController controller;
  final SharedItem item;
  final String? posterUrl;
  final String? backdropUrl;

  Future<void> _play(BuildContext context, int episodeNumber) async {
    final args = await controller.play(episodeNumber);
    if (args != null && context.mounted) {
      await context.push('/player', extra: args);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metaLine = [
      if (item.year != null) item.year.toString(),
      if (item.files.isNotEmpty && item.files.first.resolution != null)
        item.files.first.resolution!,
      if (item.files.isNotEmpty && item.files.first.videoCodec != null)
        item.files.first.videoCodec!.toUpperCase(),
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        SizedBox(
          height: 210,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (backdropUrl != null && backdropUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: backdropUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: McTokens.surface),
                )
              else
                const ColoredBox(color: McTokens.surface),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x1F000000),
                      Color(0x99000000),
                      McTokens.bg,
                    ],
                  ),
                ),
              ),
              Positioned(
                left: McTokens.pagePadding,
                right: McTokens.pagePadding,
                bottom: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 84,
                      height: 126,
                      decoration: BoxDecoration(
                        color: McTokens.posterPlaceholder,
                        borderRadius:
                            BorderRadius.circular(McTokens.posterRadius),
                        border: Border.all(color: McTokens.line, width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (posterUrl == null || posterUrl!.isEmpty)
                          ? const Icon(
                              McIcons.movie,
                              color: McTokens.textFaint,
                            )
                          : CachedNetworkImage(
                              imageUrl: posterUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Icon(
                                McIcons.movie,
                                color: McTokens.textFaint,
                              ),
                              errorWidget: (_, __, ___) => const Icon(
                                McIcons.movie,
                                color: McTokens.textFaint,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: McText.titleLg,
                          ),
                          if (metaLine.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(metaLine, style: McText.caption.muted),
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
          padding: const EdgeInsets.symmetric(
            horizontal: McTokens.pagePadding,
            vertical: 10,
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              McFocusRing(
                borderRadius: McTokens.pillRadius,
                child: McActionPill(
                  icon: McIcons.play2Fill,
                  label: item.kind == 'tv' ? '播放第一集' : '播放',
                  primary: true,
                  busy: state.opening,
                  onTap: state.opening
                      ? null
                      : () => _play(
                            context,
                            item.kind == 'tv'
                                ? (state.episodes
                                    .firstWhere(
                                      (e) => e.owned,
                                      orElse: () => const ShareEpisodeView(
                                        episodeNumber: 0,
                                      ),
                                    )
                                    .episodeNumber)
                                : 0,
                          ),
                ),
              ),
              Text('访客播放 · 不记录到成员进度', style: McText.caption.faint),
            ],
          ),
        ),
        if (item.localMeta?.plot != null && item.localMeta!.plot!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
              vertical: 6,
            ),
            child: Text(item.localMeta!.plot!, style: McText.sub.muted),
          ),
        if (item.kind == 'tv' && item.seasons.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              children: [
                for (final season in item.seasons)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: McChip(
                      label: '第 $season 季',
                      selected: season == state.selectedSeason,
                      onTap: () => controller.selectSeason(season),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          McInsetGroup(
            children: [
              for (final episode in state.episodes)
                McFocusRing(
                  borderRadius: 10,
                  child: McInsetRow(
                    title:
                        '第 ${episode.episodeNumber} 集${episode.name != null ? ' · ${episode.name}' : ''}',
                    subtitle: episode.overview,
                    trailing: episode.played
                        ? const Icon(
                            McIcons.checkCircleFill,
                            color: McTokens.ok,
                            size: 18,
                          )
                        : (!episode.owned
                            ? Text('缺集', style: McText.micro.faint)
                            : null),
                    onTap: episode.owned
                        ? () => _play(context, episode.episodeNumber)
                        : null,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: McTokens.surfaceInset,
              borderRadius: BorderRadius.circular(McTokens.cardRadius),
              border: Border.all(color: McTokens.line, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('分享说明', style: McText.sub.semibold),
                const SizedBox(height: 5),
                Text(
                  '你正在以访客身份观看分享内容。播放记录不会写入任何成员的观看进度，退出即结束会话；'
                  '分享链接有有效期，过期后需要分享者重新生成。',
                  style: McText.caption.muted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
