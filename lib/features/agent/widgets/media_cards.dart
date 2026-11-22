// Agent 生成式 UI：媒体卡片组渲染。
// 对齐 web components/agent-media-cards.tsx：按编号调产品既有接口现取数据，
// 横向卡片列展示；点卡片跳对应详情页。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/mc_icons.dart';
import '../../../core/image/image_urls.dart';
import '../state/agent_state.dart';
import '../state/media_cards.dart';

class _CardData {
  const _CardData({
    required this.title,
    this.subtitle,
    this.posterUrl,
    this.route,
  });

  final String title;
  final String? subtitle;
  final String? posterUrl;
  final String? route;
}

/// 一组媒体卡片（横向滚动）。
class MediaCardsWidget extends StatelessWidget {
  const MediaCardsWidget({super.key, required this.group});

  final MediaCardGroup group;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.title != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                group.title!,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: group.cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) =>
                  _MediaCard(spec: group.cards[i]),
            ),
          ),
        ],
      );
}

class _MediaCard extends ConsumerStatefulWidget {
  const _MediaCard({required this.spec});

  final MediaCardSpec spec;

  @override
  ConsumerState<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends ConsumerState<_MediaCard> {
  late final Future<_CardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  MediaCardSpec get spec => widget.spec;

  Future<_CardData> _load() async {
    final api = ref.read(agentApiProvider);
    switch (spec.kind) {
      case 'title':
        final details = await api.titleDetails(spec.titleRef!);
        final t = details.title;
        return _CardData(
          title: t.title,
          subtitle: [
            if (t.releaseYear != null) t.releaseYear.toString(),
            if (t.providerRating > 0)
              '评分 ${t.providerRating.toStringAsFixed(1)}',
          ].join(' · '),
          posterUrl: t.posterUrl,
          route:
              '/discover/title?ref=${Uri.encodeComponent(spec.titleRef!)}',
        );
      case 'library_item':
        final item = await api.playbackItem(spec.mediaItemId!);
        return _CardData(
          title: item.title,
          subtitle: [
            if (item.year != null) item.year.toString(),
            if (spec.seasonNumber != null &&
                spec.episodeNumber != null)
              'S${spec.seasonNumber}E${spec.episodeNumber}',
          ].join(' · '),
          posterUrl: item.posterUrl,
          route: item.libraryId > 0
              ? '/detail/${item.libraryId}/${item.mediaItemId}'
              : null,
        );
      case 'subscription':
        final sub = await api.subscription(spec.subscriptionId!);
        final m = sub.media;
        return _CardData(
          title: m.title,
          subtitle: m.year?.toString(),
          posterUrl: m.posterUrl,
          route: '/subscriptions/detail/${spec.subscriptionId}',
        );
      default: // library
        final lib = await api.libraryById(spec.libraryId!);
        return _CardData(
          title: lib.name,
          subtitle: lib.kind,
          route: '/library/detail/${spec.libraryId}',
        );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_CardData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final scheme = Theme.of(context).colorScheme;
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: data?.route == null
                ? null
                : () => context.push(data!.route!),
            child: SizedBox(
              width: 108,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: scheme.surfaceContainerHighest,
                        width: double.infinity,
                        child: data?.posterUrl == null ||
                                data!.posterUrl!.isEmpty
                            ? Icon(McIcons.movie,
                                color: scheme.onSurface.withValues(alpha: 0.3))
                            : CachedNetworkImage(
                                imageUrl: McImageUrls.resolve(
                                    data.posterUrl,
                                    widthPx: 320),
                                httpHeaders: mcImageHeaders(),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Icon(
                                    McIcons.movie,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.3)),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    snapshot.hasError
                        ? '加载失败'
                        : (data?.title ?? '加载中…'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  if ((data?.subtitle ?? '').isNotEmpty)
                    Text(
                      data!.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          );
        },
      );
}
