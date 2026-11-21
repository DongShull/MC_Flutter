import '../../../core/image/image_urls.dart';
// IMPLEMENTED — 1:1 重写自 MovieClaw feature/search/SearchScreen.kt（库内搜索分支）。
// 范围说明：search 模块只做库内搜索；站点/资源搜索属下载域，不在此实现。
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../state/search_controller.dart';
import '../../../core/designsystem/mc_icons.dart';

/// 库内搜索页：搜索框（350ms 防抖）+ 历史记录 + 输入联想 +
/// 结果列表（相关度平铺）+ 人物行（下钻）+ 游标分页。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _input;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController();
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
    ref.read(searchProvider.notifier).search(q);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(searchProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _input,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            onChanged: (v) => ref.read(searchProvider.notifier).onQuery(v),
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜索库内影片、剧集与影人',
              prefixIcon: const Icon(McIcons.search, size: 20),
              suffixIcon: s.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(McIcons.close2, size: 18),
                      onPressed: () {
                        _input.clear();
                        ref.read(searchProvider.notifier).onQuery('');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      ),
      body: s.query.trim().isEmpty
          ? _HistorySection(onPick: _submit)
          : _ResultBody(onPick: _submit),
    );
  }
}

/// 空态：历史记录（本机 SharedPreferences，最近 20 条，可单删/清空）。
class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchProvider.select((s) => s.history));
    if (history.isEmpty) {
      return const Center(
        child: Text('还没有搜索记录', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            const Icon(McIcons.history1, size: 16, color: Colors.white54),
            const SizedBox(width: 6),
            const Text('搜索历史', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: () => ref.read(searchProvider.notifier).clearHistory(),
              child: const Text('清空'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in history)
              InputChip(
                label: Text(q),
                onPressed: () => onPick(q),
                onDeleted: () =>
                    ref.read(searchProvider.notifier).removeHistory(q),
              ),
          ],
        ),
      ],
    );
  }
}

/// 结果区：联想 → 无结果（含建议词）→ 命中（人物行 + 条目平铺）。
class _ResultBody extends ConsumerWidget {
  const _ResultBody({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(searchProvider);

    if (s.searching && s.hits.isEmpty && s.people.isEmpty) {
      return const McLoadingView();
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

    // 人物行最多展示 8 个（对齐 Kotlin）。
    final people = s.people.take(8).toList();
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // 游标分页：快到底且还有 next_cursor 时追加一页。
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (s.selectedPerson != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ActionChip(
                avatar: const Icon(McIcons.close2, size: 16),
                label: Text('只看「${s.selectedPerson!.name}」的作品'),
                onPressed: () =>
                    ref.read(searchProvider.notifier).clearPerson(),
              ),
            ),
          if (!s.indexPending && s.suggestions.isNotEmpty) ...[
            _SuggestionRow(suggestions: s.suggestions, onPick: onPick),
            const SizedBox(height: 12),
          ],
          if (people.isNotEmpty && s.selectedPerson == null) ...[
            const Text('相关影人', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: people.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _PersonCell(person: people[i]),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (s.selectedPerson != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                s.selectedPerson!.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 4),
          // 相关度平铺：服务端顺序即展示顺序，不做本地重排/分组。
          for (final hit in s.hits) ...[
            _HitTile(hit: hit),
            const SizedBox(height: 8),
          ],
          if (s.searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (s.nextCursor == null && s.hits.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('已加载全部结果', style: TextStyle(color: Colors.white54)),
              ),
            ),
          if (s.indexPending)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('部分内容仍在建立索引，结果可能不全',
                  style: TextStyle(color: Colors.white54)),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 40, color: Colors.white38),
          const SizedBox(height: 12),
          Text('没有找到「${s.submittedQuery}」相关的内容'),
          if (s.suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final sug in s.suggestions)
                  ActionChip(
                    label: Text(sug.label ?? sug.text),
                    onPressed: () => onPick(sug.text),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 输入联想行（候选词，点按直接搜索）。
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestions, required this.onPick});

  final List<SearchSuggestion> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sug = suggestions[i];
          return ActionChip(
            label: Text(sug.label ?? sug.text,
                style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
            onPressed: () => onPick(sug.text),
          );
        },
      ),
    );
  }
}

/// 人物格：头像 + 名字（点击下钻该人物的库内作品）。
class _PersonCell extends ConsumerWidget {
  const _PersonCell({required this.person});

  final LibrarySearchPerson person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TV 形态包焦点环；非 TV 原样返回 child，零开销。
    return McFocusRing(
      borderRadius: 12,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => ref.read(searchProvider.notifier).selectPerson(person),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              ClipOval(
                child: person.avatarUrl != null && person.avatarUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl:
                            McImageUrls.resolve(person.avatarUrl, widthPx: 160),
                        httpHeaders: mcImageHeaders(),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _avatarFallback(),
                      )
                    : _avatarFallback(),
              ),
              const SizedBox(height: 6),
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() => Container(
        width: 64,
        height: 64,
        color: McColors.surfaceDark,
        child: const Icon(McIcons.user, color: Colors.white38),
      );
}

/// 命中条目行：海报 + 标题/年份 + 命中原因（match.label）+ 所在库数。
class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit});

  final LibrarySearchHit hit;

  @override
  Widget build(BuildContext context) {
    // TV 形态包焦点环；非 TV 原样返回 child，零开销。
    return McFocusRing(
      borderRadius: 14,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            // 库内条目 → 全局详情路由（播放一律交播放器域）。
            if (hit.libraryIds.isEmpty) return;
            context.push('/detail/${hit.libraryIds.first}/${hit.itemId}');
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: hit.posterUrl != null && hit.posterUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl:
                              McImageUrls.resolve(hit.posterUrl, widthPx: 360),
                          httpHeaders: mcImageHeaders(),
                          width: 52,
                          height: 78,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _posterFallback(),
                        )
                      : _posterFallback(),
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (hit.year != null) hit.year.toString(),
                          if (hit.matchLabel.isNotEmpty) hit.matchLabel,
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white54),
                      ),
                      if (hit.libraryIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            hit.libraryIds.length > 1
                                ? '在 ${hit.libraryIds.length} 个媒体库中'
                                : '在库',
                            style: const TextStyle(
                                fontSize: 12, color: McColors.accent),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(McIcons.arrowRight, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _posterFallback() => Container(
        width: 52,
        height: 78,
        color: McColors.surfaceDark,
        child: const Icon(McIcons.movie, color: Colors.white24, size: 20),
      );
}
