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
import '../../../core/designsystem/theme.dart';
import '../../../core/image/image_urls.dart';
import '../state/search_controller.dart';

/// 全局库内搜索页（银玻璃深色胶囊搜索栏 + 历史记录胶囊 + 相关影人圆头像 + 结果卡片）。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _input = TextEditingController();

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

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(searchProvider);
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, topPad + 8, 16, 10),
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
                            decoration: const InputDecoration(
                              isCollapsed: true,
                              filled: false,
                              hintText: '搜索影片、剧集与影人…',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (s.query.isNotEmpty)
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
                                McIcons.close2,
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
          const Divider(height: 1, color: McTokens.line),
          Expanded(
            child: s.query.trim().isEmpty
                ? _HistorySection(onPick: _submit)
                : _ResultBody(onPick: _submit),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchProvider.select((s) => s.history));
    if (history.isEmpty) {
      return const McEmptyView(
        icon: McIcons.search,
        title: '搜索你的媒体库',
        text: '输入片名、原名、导演或演员姓名立即查找',
      );
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
                          McIcons.close2,
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

class _ResultBody extends ConsumerWidget {
  const _ResultBody({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(searchProvider);

    if (s.searching && s.hits.isEmpty && s.people.isEmpty) {
      return const McLoadingView(label: '正在搜索…');
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
                  icon: McIcons.close2,
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

class _NoResults extends StatelessWidget {
  const _NoResults({required this.s, required this.onPick});

  final SearchState s;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(McIcons.search, size: 36, color: McTokens.textFaint),
            const SizedBox(height: 14),
            Text(
              '没有找到「${s.submittedQuery}」相关的内容',
              textAlign: TextAlign.center,
              style: McText.ui,
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
                  child: person.avatarUrl != null && person.avatarUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl:
                              McImageUrls.resolve(person.avatarUrl, widthPx: 160),
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

  @override
  Widget build(BuildContext context) {
    return McFocusRing(
      borderRadius: McTokens.cardRadius,
      child: McPressable(
        scaleDown: 0.985,
        onTap: () {
          if (hit.libraryIds.isEmpty) return;
          context.push('/detail/${hit.libraryIds.first}/${hit.itemId}');
        },
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
