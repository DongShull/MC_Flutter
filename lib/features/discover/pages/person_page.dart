// IMPLEMENTED — 1:1 重写自 MovieClaw feature/discover/PersonScreen.kt。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../state/discover_controller.dart' show DiscTitle;
import '../../../core/designsystem/poster_card.dart';
import '../../../core/designsystem/state_views.dart';

/// 本 feature 会话入口（core 不发全局 provider；与 onboarding/library 同构）。
/// TMDB 影人页状态（GET /discover/people/{tmdbPersonId}）。
class PersonState {
  const PersonState({this.loading = true, this.error, this.name, this.titles = const []});

  final bool loading;
  final String? error;
  final String? name;
  final List<DiscTitle> titles;

  PersonState copyWith({
    bool? loading,
    Object? error = _sentinel,
    String? name,
    List<DiscTitle>? titles,
  }) =>
      PersonState(
        loading: loading ?? this.loading,
        error: identical(error, _sentinel) ? this.error : error as String?,
        name: name ?? this.name,
        titles: titles ?? this.titles,
      );

  static const _sentinel = Object();
}

class PersonController extends Notifier<PersonState> {
  McClient? _client;
  McClient get _mc => _client ??= McClient(session: ref.read(sessionStoreProvider));

  @override
  PersonState build() => const PersonState();

  Future<void> load(int personId) async {
    if (personId <= 0) {
      state = state.copyWith(loading: false, error: '缺少人物 id');
      return;
    }
    state = const PersonState();
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
      state = state.copyWith(
        loading: false,
        name: (raw['name'] ?? '').toString(),
        titles: titles,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.friendlyMessage);
    } catch (_) {
      state = state.copyWith(loading: false, error: '网络错误，请稍后重试');
    }
  }
}

final personProvider = NotifierProvider<PersonController, PersonState>(PersonController.new);

/// 发现侧人物页（走 TMDB id；库侧走本地人物主键，两者不做混用）。
class PersonPage extends ConsumerStatefulWidget {
  const PersonPage({super.key, required this.personId});

  final int personId;

  @override
  ConsumerState<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends ConsumerState<PersonPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(personProvider.notifier).load(widget.personId));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(personProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('TMDB 影人')),
      body: s.loading
          ? const McLoadingView()
          : s.error != null
              ? Center(child: Text(s.error!))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.55,
                  ),
                  itemCount: s.titles.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name ?? '',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '共 ${s.titles.length} 部影视作品',
                            style: TextStyle(
                                fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
                          ),
                        ],
                      );
                    }
                    final t = s.titles[i - 1];
                    return McPosterCard(
                      title: t.title,
                      posterUrl: t.posterUrl,
                      width: null,
                      radius: 12,
                      subtitle: [if (t.year != null) t.year.toString()].join(' · '),
                      rating: (t.rating ?? 0) > 0 ? t.rating : null,
                      // TODO(player/detail): 跳 title 详情路由（导航意图，不做播放）。
                      onTap: () {},
                    );
                  },
                ),
    );
  }
}
