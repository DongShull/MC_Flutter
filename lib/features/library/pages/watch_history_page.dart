// 观看历史独立页（对照 PARITY.md 第 19 行：此前无独立页）。
//
// `GET /playback/history`（typed McApi，nextCursor 翻页），
// `DELETE /playback/history` 清空（确认框；服务端按 scope 清）。
// 条目点进详情；已看完的打勾。
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_api.dart';
import '../../../core/api/models.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/image/image_urls.dart';

class WatchHistoryState {
  const WatchHistoryState({
    this.loading = true,
    this.error,
    this.entries = const [],
    this.hasMore = false,
    this.nextCursor,
    this.loadingMore = false,
    this.clearing = false,
  });

  final bool loading;
  final String? error;
  final List<PlaybackLogEntry> entries;
  final bool hasMore;
  final int? nextCursor;
  final bool loadingMore;
  final bool clearing;

  WatchHistoryState copyWith({
    bool? loading,
    Object? error = _sentinel,
    List<PlaybackLogEntry>? entries,
    bool? hasMore,
    Object? nextCursor = _sentinel,
    bool? loadingMore,
    bool? clearing,
  }) =>
      WatchHistoryState(
        loading: loading ?? this.loading,
        error: identical(error, _sentinel) ? this.error : error as String?,
        entries: entries ?? this.entries,
        hasMore: hasMore ?? this.hasMore,
        nextCursor: identical(nextCursor, _sentinel)
            ? this.nextCursor
            : nextCursor as int?,
        loadingMore: loadingMore ?? this.loadingMore,
        clearing: clearing ?? this.clearing,
      );

  static const _sentinel = Object();
}

class WatchHistoryController extends Notifier<WatchHistoryState> {
  McApi get _api => ref.read(mcApiProvider);

  @override
  WatchHistoryState build() {
    Future.microtask(load);
    return const WatchHistoryState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _api.playbackHistory(limit: 20);
      state = state.copyWith(
        loading: false,
        entries: page.entries,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.friendlyMessage);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败：$e');
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _api.playbackHistory(
        limit: 20,
        before: state.nextCursor,
      );
      state = state.copyWith(
        loadingMore: false,
        entries: [...state.entries, ...page.entries],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loadingMore: false, error: e.friendlyMessage);
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: '加载失败：$e');
    }
  }

  /// 清空全部观看历史（服务端语义；返回 null = 成功，字符串 = 报错）。
  Future<String?> clearAll() async {
    state = state.copyWith(clearing: true);
    try {
      await _api.clearPlaybackHistory();
      state = state.copyWith(
        clearing: false,
        entries: const [],
        hasMore: false,
        nextCursor: null,
      );
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(clearing: false);
      return e.friendlyMessage;
    } catch (e) {
      state = state.copyWith(clearing: false);
      return '清空失败：$e';
    }
  }
}

final watchHistoryProvider =
    NotifierProvider<WatchHistoryController, WatchHistoryState>(
  WatchHistoryController.new,
);

/// 观看历史页。
class WatchHistoryPage extends ConsumerWidget {
  const WatchHistoryPage({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空观看历史'),
        content: const Text('确定要清空全部观看历史吗？该操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err =
        await ref.read(watchHistoryProvider.notifier).clearAll();
    if (context.mounted && err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  String _progressLabel(PlaybackLogEntry e) {
    if (e.completed) return '已看完';
    if (e.progressPercent != null) return '看到 ${e.progressPercent}%';
    if (e.watchedMs > 0) return '已看 ${e.watchedMs ~/ 60000} 分钟';
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(watchHistoryProvider);
    final notifier = ref.read(watchHistoryProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('观看历史'),
        actions: [
          if (state.entries.isNotEmpty)
            TextButton(
              onPressed:
                  state.clearing ? null : () => _confirmClear(context, ref),
              child: Text(state.clearing ? '清空中…' : '清空'),
            ),
        ],
      ),
      body: state.loading && state.entries.isEmpty
          ? const McLoadingView()
          : state.error != null && state.entries.isEmpty
              ? McErrorView(text: state.error!, onRetry: notifier.load)
              : state.entries.isEmpty
                  ? const Center(child: Text('还没有观看记录'))
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.extentAfter < 600 &&
                            !state.loadingMore) {
                          notifier.loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: state.entries.length +
                            (state.hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= state.entries.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          final entry = state.entries[i];
                          final media = entry.media;
                          final progress = _progressLabel(entry);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: media.browsable
                                    ? () => context.push(
                                          '/detail/${media.libraryId ?? 0}/${media.mediaItemId}',
                                        )
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: media.posterUrl != null &&
                                                media.posterUrl!.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: McImageUrls.resolve(
                                                  media.posterUrl,
                                                  widthPx: 360,
                                                ),
                                                httpHeaders:
                                                    mcImageHeaders(),
                                                width: 52,
                                                height: 78,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    _posterFallback(context),
                                              )
                                            : _posterFallback(context),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              media.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              [
                                                if (media.year != null)
                                                  media.year.toString(),
                                                if (media.seasonNumber > 0)
                                                  '第 ${media.seasonNumber} 季'
                                                  '第 ${media.episodeNumber} 集',
                                                if (progress.isNotEmpty)
                                                  progress,
                                              ].join(' · '),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.6),
                                                  ),
                                            ),
                                            if (entry.memberName.isNotEmpty ||
                                                entry.deviceName.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  [
                                                    if (entry
                                                        .memberName.isNotEmpty)
                                                      entry.memberName,
                                                    if (entry
                                                        .deviceName.isNotEmpty)
                                                      entry.deviceName,
                                                  ].join(' · '),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.45,
                                                            ),
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (entry.completed)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 20,
                                        )
                                      else
                                        const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _posterFallback(BuildContext context) => Container(
        width: 52,
        height: 78,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.movie, size: 20),
      );
}
