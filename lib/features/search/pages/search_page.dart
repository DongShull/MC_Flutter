import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/subscribe_sheet.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/models/format.dart';
import '../../../core/player/player_page_args.dart';
import '../state/search_controller.dart';

/// 全平台三合一统一搜索页（对齐并超越 Web `SearchView` + iOS `SearchView`）：
/// - `本地媒体库`：库内条目 + 相关影人圆头像 + 联想词 + 无限游标分页 + 右键快捷播/详情；
/// - `影视发现`：TMDB / 豆瓣实时检索 + 在库绿标 + 一键弹层订阅；
/// - `种子资源 PT`：跨站点聚合搜种 + FREE/H&R/画质标签 + 一键直推下载器或为指定订阅抓源入库。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({
    super.key,
    this.initialQuery,
    this.initialMode,
    this.forSubscriptionId,
  });

  final String? initialQuery;
  final String? initialMode;
  final int? forSubscriptionId;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _input =
      TextEditingController(text: widget.initialQuery ?? '');

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final mode = widget.initialMode ??
          (widget.forSubscriptionId != null ? 'torrent' : null);
      if ((widget.initialQuery != null && widget.initialQuery!.isNotEmpty) ||
          mode != null) {
        await ref.read(searchProvider.notifier).applyRouteArgs(
              query: widget.initialQuery,
              mode: mode,
            );
      } else {
        final cur = ref.read(searchProvider).query;
        if (cur.isNotEmpty && _input.text.isEmpty) {
          _input.text = cur;
        }
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit(String q) {
    FocusScope.of(context).unfocus();
    _input.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
    ref.read(searchProvider.notifier).onQuery(q);
    ref.read(searchProvider.notifier).search(q);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  String _hintFor(String mode) => switch (mode) {
        'media' => '搜索 TMDB / 豆瓣电影与剧集，一键订阅…',
        'torrent' => '搜索 PT 站点种子关键词（片名 / IMDb / 分辨率）…',
        _ => '搜索本地媒体库影片、剧集与影人…',
      };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(searchProvider);
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, topPad + 8, 16, 8),
            child: Row(
              children: [
                McGlassIconButton(
                  icon: McIcons.arrowLeftS,
                  iconSize: 22,
                  tooltip: '返回',
                  onTap: _back,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: McTokens.surfaceInset,
                      borderRadius: BorderRadius.circular(McTokens.pillRadius),
                      border: Border.all(color: McTokens.lineStrong, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(
                          McIcons.search,
                          size: 17,
                          color: McTokens.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _input,
                            autofocus: true,
                            style: McText.body,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _submit,
                            onChanged: (v) =>
                                ref.read(searchProvider.notifier).onQuery(v),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              filled: false,
                              hintText: _hintFor(s.mode),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (s.query.isNotEmpty || _input.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _input.clear();
                              ref.read(searchProvider.notifier).onQuery('');
                            },
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Color(0x29FFFFFF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                McIcons.close,
                                size: 12,
                                color: McTokens.text,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 三合一银玻璃分区切换条
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      McChip(
                        label: '本地媒体库',
                        icon: McIcons.mediaLibraryFill,
                        selected: s.mode == 'library',
                        onTap: () => ref
                            .read(searchProvider.notifier)
                            .switchMode('library'),
                      ),
                      const SizedBox(width: 8),
                      McChip(
                        label: '影视发现',
                        icon: McIcons.compass,
                        selected: s.mode == 'media',
                        onTap: () => ref
                            .read(searchProvider.notifier)
                            .switchMode('media'),
                      ),
                      const SizedBox(width: 8),
                      McChip(
                        label: '种子资源 PT',
                        icon: McIcons.fileSeed,
                        selected: s.mode == 'torrent',
                        onTap: () => ref
                            .read(searchProvider.notifier)
                            .switchMode('torrent'),
                      ),
                    ],
                  ),
                ),
                if (s.mode == 'media') ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (val, label) in const [
                          ('all', '全部'),
                          ('movie', '电影'),
                          ('tv', '剧集'),
                        ]) ...[
                          McChip(
                            label: label,
                            compact: true,
                            selected: s.mediaType == val,
                            onTap: () => ref
                                .read(searchProvider.notifier)
                                .setMediaFilter(mediaType: val),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const SizedBox(width: 6),
                        Container(width: 1, height: 16, color: McTokens.line),
                        const SizedBox(width: 10),
                        for (final (prov, label) in const [
                          ('tmdb', 'TMDB'),
                          ('douban', '豆瓣'),
                        ]) ...[
                          McChip(
                            label: label,
                            compact: true,
                            selected: s.mediaProvider == prov,
                            onTap: () => ref
                                .read(searchProvider.notifier)
                                .setMediaFilter(provider: prov),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ],
                if (widget.forSubscriptionId != null &&
                    s.mode == 'torrent') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1F7FB0FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x4D7FB0FF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          McIcons.bookmarkFill,
                          size: 14,
                          color: McTokens.info,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '正在为订阅 #${widget.forSubscriptionId} 手动挑种抓源，点击「抓源入库」将直接关联该订阅自动整理。',
                            style: McText.caption.copyWith(color: McTokens.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Expanded(
            child: s.query.trim().isEmpty && s.submittedQuery.trim().isEmpty
                ? _HistorySection(mode: s.mode, onPick: _submit)
                : switch (s.mode) {
                    'media' => _MediaResultBody(onPick: _submit),
                    'torrent' => _TorrentResultBody(
                        forSubscriptionId: widget.forSubscriptionId,
                      ),
                    _ => _LibraryResultBody(onPick: _submit),
                  },
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.mode, required this.onPick});

  final String mode;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchProvider.select((s) => s.history));
    if (history.isEmpty) {
      final (icon, title, text) = switch (mode) {
        'media' => (
            McIcons.compass,
            '搜索全球影视库',
            '检索 TMDB 与豆瓣片单，查看演职员或一键加入追更订阅'
          ),
        'torrent' => (
            McIcons.fileSeed,
            '聚合检索 PT 站点资源',
            '输入中英文片名、IMDb 编号或分辨率，支持一键直推下载器'
          ),
        _ => (
            McIcons.search,
            '搜索你的本地媒体库',
            '输入片名、原名、导演或演员姓名立即查找'
          ),
      };
      return McEmptyView(icon: icon, title: title, text: text);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        McSectionHeader(
          title: '最近搜索',
          padding: EdgeInsets.zero,
          trailing: TextButton(
            onPressed: () => ref.read(searchProvider.notifier).clearHistory(),
            child: const Text('清空'),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in history)
              Container(
                decoration: BoxDecoration(
                  color: McTokens.surfaceInset,
                  borderRadius: BorderRadius.circular(McTokens.pillRadius),
                  border: Border.all(color: McTokens.line, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => onPick(q),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(13, 7, 6, 7),
                        child: Text(
                          q,
                          style: McText.sub.copyWith(color: McTokens.text),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ref.read(searchProvider.notifier).removeHistory(q),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(4, 7, 10, 7),
                        child: Icon(
                          McIcons.close,
                          size: 13,
                          color: McTokens.textFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MediaResultBody extends ConsumerWidget {
  const _MediaResultBody({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(searchProvider);
    if (s.searching && s.mediaHits.isEmpty) {
      return const McLoadingView(label: '正在检索影视资料…');
    }
    if (s.error != null && s.mediaHits.isEmpty) {
      return McErrorView(
        text: s.error!,
        onRetry: () => ref.read(searchProvider.notifier).search(
              s.submittedQuery.isEmpty ? s.query : s.submittedQuery,
            ),
      );
    }
    if (s.mediaHits.isEmpty) {
      return const McEmptyView(
        icon: McIcons.compass,
        title: '未检索到相关影视',
        text: '试试切换英文原名、年份或切换 TMDB / 豆瓣数据源',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final form = McFormWatch.of(context);
        final pad = form == McDeviceForm.phone
            ? McTokens.pagePadding
            : McTokens.pagePaddingWide;
        final cols = mcGridCrossAxisCount(form, constraints, cellExtent: 126);
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(pad, 14, pad, 40),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 18,
            crossAxisSpacing: 12,
            childAspectRatio: 0.515,
          ),
          itemCount: s.mediaHits.length,
          itemBuilder: (context, i) {
            final hit = s.mediaHits[i];
            return McFocusRing(
              borderRadius: McTokens.posterRadius,
              child: McPosterCard(
                title: hit.title,
                posterUrl: hit.posterUrl,
                width: null,
                subtitle: [
                  if (hit.year != null) '${hit.year}',
                  hit.mediaType == 'tv' ? '剧集' : '电影',
                ].join(' · '),
                rating: (hit.rating ?? 0) > 0 ? hit.rating : null,
                badge: hit.inLibrary ? '在库' : null,
                badgeDotColor: hit.inLibrary ? McTokens.ok : null,
                onTap: () => context.push(
                  '/discover/title?ref=${Uri.encodeComponent(hit.titleRef)}',
                ),
                onQuickPlay: hit.inLibrary &&
                        hit.libraryId != null &&
                        hit.mediaItemId != null
                    ? () => context.push(
                          '/detail/${hit.libraryId}/${hit.mediaItemId}',
                        )
                    : null,
                contextActions: [
                  McPosterMenuAction(
                    icon: McIcons.film,
                    label: '查看影视详情',
                    onTap: () => context.push(
                      '/discover/title?ref=${Uri.encodeComponent(hit.titleRef)}',
                    ),
                  ),
                  if (hit.inLibrary &&
                      hit.libraryId != null &&
                      hit.mediaItemId != null)
                    McPosterMenuAction(
                      icon: McIcons.play2Fill,
                      label: '前往本地媒体库观看',
                      onTap: () => context.push(
                        '/detail/${hit.libraryId}/${hit.mediaItemId}',
                      ),
                    ),
                  McPosterMenuAction(
                    icon: McIcons.bookmarkFill,
                    label: hit.inLibrary ? '管理订阅 / 洗版' : '加入追更订阅',
                    onTap: () async {
                      final outcome = await showSubscribeSheet(
                        context,
                        ref,
                        titleRef: hit.titleRef,
                      );
                      if (!context.mounted || outcome == null) return;
                      if (outcome == SubscribeSheetOutcome.created) {
                        McToast.success('已加入追更订阅');
                      } else {
                        context.push('/subscriptions');
                      }
                    },
                  ),
                  McPosterMenuAction(
                    icon: McIcons.fileSeed,
                    label: '搜 PT 种子资源',
                    onTap: () {
                      onPick(hit.title);
                      ref.read(searchProvider.notifier).switchMode('torrent');
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TorrentResultBody extends ConsumerWidget {
  const _TorrentResultBody({this.forSubscriptionId});

  final int? forSubscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(searchProvider);
    if (s.searching && s.torrentHits.isEmpty) {
      return const McLoadingView(label: '正在并发检索 PT 站点…');
    }
    if (s.error != null && s.torrentHits.isEmpty) {
      return McErrorView(
        text: s.error!,
        onRetry: () => ref.read(searchProvider.notifier).search(
              s.submittedQuery.isEmpty ? s.query : s.submittedQuery,
            ),
      );
    }
    if (s.torrentHits.isEmpty) {
      return const McEmptyView(
        icon: McIcons.fileSeed,
        title: '未找到匹配的种子资源',
        text: '请检查关键词，或在「设置 → 索引站点」确认站点连通性',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      itemCount: s.torrentHits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final hit = s.torrentHits[i];
        final busy = s.busyTorrentKeys.contains(hit.key);
        final done = s.downloadedTorrentKeys.contains(hit.key);
        return _TorrentCard(
          hit: hit,
          busy: busy,
          done: done,
          forSubscriptionId: forSubscriptionId,
          onAction: () async {
            final notifier = ref.read(searchProvider.notifier);
            final err = forSubscriptionId != null
                ? await notifier.grabForSubscription(forSubscriptionId!, hit)
                : await notifier.directDownloadTorrent(hit);
            if (!context.mounted) return;
            if (err != null) {
              McToast.error(err);
            } else {
              McToast.success(
                forSubscriptionId != null
                    ? '已抓取种子并关联订阅入库流水线'
                    : '已推送至默认下载器',
              );
            }
          },
        );
      },
    );
  }
}

class _TorrentCard extends StatelessWidget {
  const _TorrentCard({
    required this.hit,
    required this.busy,
    required this.done,
    required this.forSubscriptionId,
    required this.onAction,
  });

  final TorrentSearchHit hit;
  final bool busy;
  final bool done;
  final int? forSubscriptionId;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final badges = hit.techBadges;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: McTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(McTokens.cardRadius),
        border: Border.all(color: McTokens.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PillTag(
                text: hit.siteName,
                bg: const Color(0x26FFFFFF),
                fg: McTokens.accentStrong,
              ),
              if (hit.isFree)
                _PillTag(
                  text: hit.freeLabel.isEmpty ? 'FREE' : hit.freeLabel,
                  bg: const Color(0x244ADE80),
                  fg: McTokens.ok,
                ),
              if (hit.hitAndRun)
                const _PillTag(
                  text: 'H&R',
                  bg: Color(0x29FF6B6B),
                  fg: McTokens.danger,
                ),
              for (final b in badges)
                _PillTag(
                  text: b,
                  bg: McTokens.surfaceInset,
                  fg: McTokens.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hit.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: McText.ui.semibold,
          ),
          if (hit.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              hit.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: McText.caption.muted,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (hit.sizeBytes > 0)
                      Text(
                        mcFormatBytes(hit.sizeBytes),
                        style: McText.caption.semibold.tabular,
                      ),
                    Text(
                      '↑ ${hit.seeders}',
                      style: McText.caption
                          .copyWith(color: McTokens.ok)
                          .tabular,
                    ),
                    Text(
                      '↓ ${hit.leechers}',
                      style: McText.caption.muted.tabular,
                    ),
                    if (hit.publishTime.isNotEmpty)
                      Text(
                        mcFromNowIso(hit.publishTime, empty: hit.publishTime),
                        style: McText.caption.faint,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              McGlassButton(
                onTap: busy || done ? null : onAction,
                tone: done ? McGlassTone.strong : McGlassTone.primary,
                radius: McTokens.pillRadius,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: McTokens.onAccent,
                        ),
                      )
                    else
                      Icon(
                        done ? McIcons.check : McIcons.download,
                        size: 15,
                      ),
                    const SizedBox(width: 5),
                    Text(
                      done
                          ? '已推送'
                          : (forSubscriptionId != null ? '抓源入库' : '推送下载'),
                      style: McText.caption.semibold,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillTag extends StatelessWidget {
  const _PillTag({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.28), width: 0.8),
      ),
      child: Text(
        text,
        style: McText.micro.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LibraryResultBody extends ConsumerWidget {
  const _LibraryResultBody({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(searchProvider);

    if (s.searching && s.hits.isEmpty && s.people.isEmpty) {
      return const McLoadingView(label: '正在搜索媒体库…');
    }
    if (s.error != null) {
      return McErrorView(
        text: s.error!,
        onRetry: () => ref.read(searchProvider.notifier).search(
              s.submittedQuery.isEmpty ? s.query : s.submittedQuery,
            ),
      );
    }

    final hasResults = s.hits.isNotEmpty || s.people.isNotEmpty;
    if (!hasResults) {
      return _NoResults(s: s, onPick: onPick);
    }

    final people = s.people.take(8).toList();
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600 &&
            s.nextCursor != null &&
            !s.searching) {
          ref.read(searchProvider.notifier).search(
                s.submittedQuery.isEmpty ? s.query : s.submittedQuery,
                cursor: s.nextCursor,
              );
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
        children: [
          if (s.selectedPerson != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: McChip(
                  icon: McIcons.close,
                  label: '只看「${s.selectedPerson!.name}」的作品',
                  selected: true,
                  onTap: () => ref.read(searchProvider.notifier).clearPerson(),
                ),
              ),
            ),
          if (!s.indexPending && s.suggestions.isNotEmpty) ...[
            _SuggestionRow(suggestions: s.suggestions, onPick: onPick),
            const SizedBox(height: 14),
          ],
          if (people.isNotEmpty && s.selectedPerson == null) ...[
            const Text('相关影人', style: McText.titleSm),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: people.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _PersonCell(person: people[i]),
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (s.selectedPerson != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(s.selectedPerson!.name, style: McText.title),
            ),
          for (final hit in s.hits) ...[
            _HitTile(hit: hit),
            const SizedBox(height: 10),
          ],
          if (s.searching)
            const McLoadingView()
          else if (s.nextCursor == null && s.hits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  '已显示全部结果',
                  style: McText.caption.copyWith(color: McTokens.textFaint),
                ),
              ),
            ),
          if (s.indexPending)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '部分内容仍在建立索引，结果可能尚不完整',
                textAlign: TextAlign.center,
                style: McText.caption.copyWith(color: McTokens.textFaint),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoResults extends ConsumerWidget {
  const _NoResults({required this.s, required this.onPick});

  final SearchState s;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(McIcons.search, size: 36, color: McTokens.textFaint),
            const SizedBox(height: 14),
            Text(
              '本地库未找到「${s.submittedQuery}」',
              textAlign: TextAlign.center,
              style: McText.ui,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                McChip(
                  icon: McIcons.compass,
                  label: '去影视发现搜索并订阅',
                  onTap: () =>
                      ref.read(searchProvider.notifier).switchMode('media'),
                ),
                McChip(
                  icon: McIcons.fileSeed,
                  label: '直接搜 PT 种子',
                  onTap: () =>
                      ref.read(searchProvider.notifier).switchMode('torrent'),
                ),
              ],
            ),
            if (s.suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final sug in s.suggestions)
                    McChip(
                      label: sug.label ?? sug.text,
                      compact: true,
                      onTap: () => onPick(sug.text),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestions, required this.onPick});

  final List<SearchSuggestion> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sug = suggestions[i];
          return McChip(
            label: sug.label ?? sug.text,
            compact: true,
            onTap: () => onPick(sug.text),
          );
        },
      ),
    );
  }
}

class _PersonCell extends ConsumerWidget {
  const _PersonCell({required this.person});

  final LibrarySearchPerson person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return McFocusRing(
      borderRadius: 12,
      child: McPressable(
        onTap: () => ref.read(searchProvider.notifier).selectPerson(person),
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: McTokens.line, width: 1),
                ),
                child: ClipOval(
                  child: person.avatarUrl != null &&
                          person.avatarUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: McImageUrls.resolve(
                            person.avatarUrl,
                            widthPx: 160,
                          ),
                          httpHeaders: mcImageHeaders(),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _avatarFallback(),
                        )
                      : _avatarFallback(),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: McText.caption.copyWith(color: McTokens.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() => Container(
        color: McTokens.posterPlaceholder,
        alignment: Alignment.center,
        child: const Icon(McIcons.user, color: McTokens.textFaint, size: 22),
      );
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit});

  final LibrarySearchHit hit;

  List<McPosterMenuAction> _actions(BuildContext context) {
    if (hit.libraryIds.isEmpty) return const [];
    final lid = hit.libraryIds.first;
    return [
      McPosterMenuAction(
        icon: McIcons.play2Fill,
        label: '立即播放',
        onTap: () => context.push(
          '/player',
          extra: PlayerPageArgs(
            mediaItemId: hit.itemId,
            title: hit.itemName,
          ),
        ),
      ),
      McPosterMenuAction(
        icon: McIcons.film,
        label: '查看详情',
        onTap: () => context.push('/detail/$lid/${hit.itemId}'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions(context);
    return McFocusRing(
      borderRadius: McTokens.cardRadius,
      child: McPressable(
        scaleDown: 0.985,
        onTap: () {
          if (hit.libraryIds.isEmpty) return;
          context.push('/detail/${hit.libraryIds.first}/${hit.itemId}');
        },
        onSecondaryTapUp: actions.isEmpty
            ? null
            : (d) => showMcContextActions(
                  context: context,
                  title: hit.itemName,
                  actions: actions,
                  globalPosition: d.globalPosition,
                ),
        onLongPress: actions.isEmpty
            ? null
            : () => showMcContextActions(
                  context: context,
                  title: hit.itemName,
                  actions: actions,
                ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: McTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(McTokens.cardRadius),
            border: Border.all(color: McTokens.line, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 81,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: McTokens.line, width: 0.8),
                ),
                clipBehavior: Clip.antiAlias,
                child: McArtwork(
                  url: hit.posterUrl,
                  widthPx: 240,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.ui.semibold,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (hit.year != null) '${hit.year}',
                        if (hit.matchLabel.isNotEmpty) hit.matchLabel,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: McText.caption,
                    ),
                    if (hit.libraryIds.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: McTokens.ok,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hit.libraryIds.length > 1
                                ? '在 ${hit.libraryIds.length} 个媒体库中'
                                : '在库',
                            style: McText.micro.copyWith(
                              color: McTokens.ok,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                McIcons.chevronRight,
                size: 16,
                color: McTokens.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
