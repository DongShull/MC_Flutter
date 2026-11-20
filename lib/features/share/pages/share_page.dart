import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/designsystem/state_views.dart';
import '../state/models.dart';
import '../state/share_controller.dart';
import '../../../core/designsystem/mc_icons.dart';

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
      Future.microtask(() => ref.read(shareOriginProvider.notifier).state = widget.origin!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slug = widget.slug;
    if (slug.isEmpty) {
      return const Scaffold(body: Center(child: Text('分享不存在或已取消')));
    }
    final state = ref.watch(shareControllerFamily(slug));
    final controller = ref.read(shareControllerFamily(slug).notifier);
    final form = McFormWatch.of(context);
    final contentWidth = mcWindowClassOf(form) == McWindowClass.compact ? 560.0 : 720.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 内容居中限宽（compact<=560，其余 720）。
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Row(
              children: [
                McFocusRing(
                  borderRadius: 24,
                  child: IconButton(
                    icon: const Icon(McIcons.arrowLeft),
                    tooltip: '返回',
                    onPressed: () => context.pop(),
                  ),
                ),
                const Expanded(
                  child: Text('分享', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                if (state.probe?.expiresAt != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text('有效期至 ${state.probe!.expiresAt!}',
                        style: const TextStyle(fontSize: 11)),
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
      ),
    );
  }

  Widget _body(BuildContext context, ShareUiState state, ShareController controller) {
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
      return _SharedCollectionList(controller: controller, collection: collection);
    }
    final item = state.item;
    if (item != null) {
      return _SharedItemDetail(state: state, controller: controller, item: item);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(McIcons.lock, color: McColors.accent, size: 30),
            const SizedBox(height: 10),
            const Center(child: Text('这是一个加密分享',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
            const SizedBox(height: 6),
            const Center(child: Text('请输入分享者提供的密码',
                style: TextStyle(fontSize: 13))),
            const SizedBox(height: 14),
            TextField(
              obscureText: true,
              autofocus: true,
              onChanged: controller.onPassword,
              decoration: const InputDecoration(
                hintText: '密码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            McFocusRing(
              borderRadius: 20,
              child: FilledButton(
                onPressed: state.password.isEmpty ? null : controller.unlock,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                child: const Text('解锁'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedCollectionList extends StatelessWidget {
  const _SharedCollectionList({required this.controller, required this.collection});

  final ShareController controller;
  final SharedCollection collection;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(collection.name.isEmpty ? '分享合集' : collection.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        if (collection.description != null && collection.description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(collection.description!, style: const TextStyle(fontSize: 12)),
        ],
        const SizedBox(height: 10),
        for (final item in collection.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.year != null ? '${item.title}（${item.year}）' : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(item.kind == 'tv' ? '剧集' : '电影',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
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
  });

  final ShareUiState state;
  final ShareController controller;
  final SharedItem item;

  @override
  Widget build(BuildContext context) {
    final metaLine = [
      if (item.year != null) item.year.toString(),
      if (item.files.isNotEmpty && item.files.first.resolution != null) item.files.first.resolution!,
      if (item.files.isNotEmpty && item.files.first.videoCodec != null)
        item.files.first.videoCodec!.toUpperCase(),
    ].join(' · ');

    return ListView(
      children: [
        Stack(
          children: [
            if (item.backdropUrl != null)
              Container(height: 200, color: Theme.of(context).cardColor),
            Positioned(
              left: 16,
              bottom: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 84,
                    height: 126,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    // TODO: RemoteImage 加载分享通道海报（路径经 GuestShareApi.imageUrl 拼基址）。
                    child: const Icon(McIcons.movie),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 200,
                        child: Text(item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 4),
                      Text(metaLine, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              McFocusRing(
              borderRadius: 20,
              child: FilledButton.icon(
                onPressed: state.opening
                    ? null
                    : () => controller.play(
                        item.kind == 'tv'
                            ? (state.episodes.firstWhere((e) => e.owned,
                                    orElse: () => const ShareEpisodeView(episodeNumber: 0))
                                .episodeNumber)
                            : 0),
                icon: const Icon(McIcons.play2Fill, size: 18),
                label: Text(item.kind == 'tv' ? '播放第一集' : '播放'),
              ),
            ),
              const SizedBox(width: 12),
              const Text('访客播放 · 不记录到成员进度', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
        if (item.localMeta?.plot != null && item.localMeta!.plot!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(item.localMeta!.plot!,
                style: const TextStyle(fontSize: 13, height: 1.5)),
          ),
        if (item.kind == 'tv' && item.seasons.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final season in item.seasons)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('第 $season 季'),
                      selected: season == state.selectedSeason,
                      onSelected: (_) => controller.selectSeason(season),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final episode in state.episodes)
            McFocusRing(
              borderRadius: 10,
              child: InkWell(
              onTap: episode.owned ? () => controller.play(episode.episodeNumber) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '第 ${episode.episodeNumber} 集${episode.name != null ? ' · ${episode.name}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (episode.overview != null && episode.overview!.isNotEmpty)
                            Text(episode.overview!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    if (episode.played)
                      const Icon(McIcons.checkCircleFill, color: Colors.green, size: 18)
                    else if (!episode.owned)
                      const Text('缺集', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('分享说明', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(height: 5),
                Text(
                  '你正在以访客身份观看分享内容。播放记录不会写入任何成员的观看进度，退出即结束会话；'
                  '分享链接有有效期，过期后需要分享者重新生成。',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
