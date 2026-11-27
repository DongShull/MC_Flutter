import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/models/format.dart';
import '../state/mc_api.dart';
import '../state/models.dart';
import '../state/share_controller.dart';
import '../state/share_local_progress.dart';

/// 访客分享页（1:1 对齐 iOS SharePageView + ShareItemView）：
/// 探测 → 密码门（输错保持输入框并内联红字提示）→ 合集 2:3 海报网格 / 富影片详情 → 访客播放。
/// 独立壳：无底栏、无侧栏、无下载入口、无管理/站内跳转入口。
class SharePage extends ConsumerStatefulWidget {
  const SharePage({
    super.key,
    this.slug = '',
    this.origin,
    this.initialItemId,
    this.initialPlayUnit,
    this.initialStartSeconds,
  });

  final String slug;
  final String? origin;
  final int? initialItemId;
  final String? initialPlayUnit;
  final int? initialStartSeconds;

  @override
  ConsumerState<SharePage> createState() => _SharePageState();
}

class _SharePageState extends ConsumerState<SharePage> {
  bool _consumedDeepPlay = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      if (widget.origin != null && widget.origin!.isNotEmpty) {
        ref.read(shareOriginProvider.notifier).state = widget.origin!;
      }
      if (widget.slug.isNotEmpty && widget.initialItemId != null) {
        ref
            .read(shareControllerFamily(widget.slug).notifier)
            .setInitialItemId(widget.initialItemId);
      }
    });
  }

  Future<void> _maybeTriggerDeepPlay(
    ShareUiState state,
    ShareController controller,
  ) async {
    if (_consumedDeepPlay || widget.initialPlayUnit == null) return;
    final item = state.item;
    if (item == null || state.loadingItem) return;
    _consumedDeepPlay = true;

    final parsed = ShareLinkKit.parsePlayUnit(widget.initialPlayUnit);
    final startMs = widget.initialStartSeconds != null &&
            widget.initialStartSeconds! > 0
        ? widget.initialStartSeconds! * 1000
        : null;

    if (!item.isMovie && parsed.season != null) {
      await controller.selectSeason(
        parsed.season!,
        preferredEpisode: parsed.episode,
      );
    }
    if (!mounted) return;
    await _handlePlay(
      context,
      controller,
      episodeNumber: parsed.episode,
      startMs: startMs,
    );
  }

  Future<void> _handlePlay(
    BuildContext context,
    ShareController controller, {
    int? episodeNumber,
    int? startMs,
    bool force = false,
  }) async {
    final result = await controller.play(
      episodeNumber: episodeNumber,
      startMs: startMs,
      force: force,
    );
    if (!context.mounted) return;

    if (result.needsConsent) {
      final agreed = await showMcSheet<bool>(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('需要服务器转码播放', style: McText.titleSm),
              const SizedBox(height: 8),
              Text(result.consentMessage!, style: McText.sub.muted),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: McActionPill(
                      label: '取消',
                      primary: false,
                      expanded: true,
                      onTap: () => Navigator.of(ctx).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: McActionPill(
                      label: '继续播放',
                      primary: true,
                      expanded: true,
                      onTap: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      if (agreed == true && context.mounted) {
        await _handlePlay(
          context,
          controller,
          episodeNumber: episodeNumber,
          startMs: startMs,
          force: true,
        );
      }
      return;
    }

    if (result.errorMessage != null) {
      McToast.error(result.errorMessage!);
      return;
    }

    if (result.args != null) {
      await context.push('/player', extra: result.args);
      if (mounted) {
        await controller.refreshLocalResume();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slug = widget.slug;
    if (slug.isEmpty) {
      return const Scaffold(
        backgroundColor: McTokens.bg,
        body: _ShareUnavailableView(message: '分享不存在或已取消'),
      );
    }

    final state = ref.watch(shareControllerFamily(slug));
    final controller = ref.read(shareControllerFamily(slug).notifier);

    if (!_consumedDeepPlay &&
        widget.initialPlayUnit != null &&
        state.item != null &&
        !state.loadingItem) {
      Future.microtask(() => _maybeTriggerDeepPlay(state, controller));
    }

    return Scaffold(
      backgroundColor: McTokens.bg,
      body: _body(context, state, controller),
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
    if (state.needsPassword) {
      return _PasswordGate(state: state, controller: controller);
    }
    if (state.error != null && state.item == null && state.collection == null) {
      return _ShareUnavailableView(
        message: state.error!,
        onRetry: controller.probe,
      );
    }
    if (state.showingCollectionGrid) {
      return _ShareCollectionView(
        state: state,
        controller: controller,
        collection: state.collection!,
        api: controller.api,
      );
    }
    if (state.loadingItem && state.item == null) {
      return const McLoadingView();
    }
    if (state.item != null) {
      return _ShareItemView(
        slug: widget.slug,
        state: state,
        controller: controller,
        item: state.item!,
        api: controller.api,
        onBackToCollection:
            state.isCollection ? controller.backToCollection : null,
        onPlay: ({int? episodeNumber, int? startMs}) => _handlePlay(
          context,
          controller,
          episodeNumber: episodeNumber,
          startMs: startMs,
        ),
      );
    }
    return _ShareUnavailableView(
      message: state.error ?? '分享内容暂不可用',
      onRetry: controller.probe,
    );
  }
}

// MARK: - 失效页 & 密码门

class _ShareUnavailableView extends StatelessWidget {
  const _ShareUnavailableView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: McTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: McTokens.lineStrong),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MOVIECLAW',
                  style: McText.caption.semibold.copyWith(
                    letterSpacing: 3,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Text(message, style: McText.titleLg),
                const SizedBox(height: 6),
                Text('请确认链接是否完整，或联系分享者重新生成。', style: McText.sub.muted),
                const SizedBox(height: 16),
                Text(
                  '分享链接具有有效期，过期或被撤销后将自动失效。',
                  style: McText.caption.faint,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 18),
                  McActionPill(
                    label: '重试',
                    primary: false,
                    expanded: true,
                    onTap: onRetry,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 密码卡片（解锁前绝不露出片名或海报；输错密码保持输入框并展示内联红字提示）。
class _PasswordGate extends StatefulWidget {
  const _PasswordGate({required this.state, required this.controller});

  final ShareUiState state;
  final ShareController controller;

  @override
  State<_PasswordGate> createState() => _PasswordGateState();
}

class _PasswordGateState extends State<_PasswordGate> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;
    final canSubmit = !state.unlocking && state.password.trim().isNotEmpty;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: McTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: McTokens.lineStrong),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'MOVIECLAW',
                      style: McText.caption.semibold.copyWith(
                        letterSpacing: 3,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    if (state.probe?.expiresAt != null)
                      Text(
                        ShareLinkKit.expiryHint(state.probe!.expiresAt),
                        style: McText.micro.faint,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(McIcons.lock, color: McTokens.accentStrong, size: 22),
                    SizedBox(width: 8),
                    Text('需要访问密码', style: McText.titleLg),
                  ],
                ),
                const SizedBox(height: 6),
                Text('这是一个加密分享，请输入分享者提供的密码后查看内容。', style: McText.sub.muted),
                const SizedBox(height: 18),
                TextField(
                  controller: _textController,
                  obscureText: true,
                  autofocus: true,
                  style: McText.body,
                  textInputAction: TextInputAction.go,
                  onChanged: controller.onPassword,
                  onSubmitted: (_) {
                    if (canSubmit) controller.unlock();
                  },
                  decoration: InputDecoration(
                    hintText: '输入访问密码',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: state.passwordError != null
                            ? McTokens.danger
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: state.passwordError != null
                            ? McTokens.danger
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
                if (state.passwordError != null &&
                    state.passwordError!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: McTokens.danger.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: McTokens.danger.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      state.passwordError!,
                      style: McText.caption.copyWith(
                        color: const Color(0xFFFFBFBF),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                McFocusRing(
                  borderRadius: McTokens.pillRadius,
                  child: McActionPill(
                    label: state.unlocking ? '正在验证…' : '解锁访问',
                    primary: true,
                    busy: state.unlocking,
                    expanded: true,
                    height: 44,
                    onTap: canSubmit ? controller.unlock : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// MARK: - 合集分享 2:3 海报网格

class _ShareCollectionView extends StatelessWidget {
  const _ShareCollectionView({
    required this.state,
    required this.controller,
    required this.collection,
    required this.api,
  });

  final ShareUiState state;
  final ShareController controller;
  final SharedCollection collection;
  final GuestShareApi api;

  @override
  Widget build(BuildContext context) {
    final form = McFormWatch.of(context);
    final maxWidth =
        mcWindowClassOf(form) == McWindowClass.compact ? 640.0 : 960.0;
    final expiresAt = collection.expiresAt ?? state.probe?.expiresAt;
    final cookieHeader = api.cookieHeader;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    McTokens.pagePadding,
                    12,
                    McTokens.pagePadding,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'MOVIECLAW',
                            style: McText.caption.semibold.copyWith(
                              letterSpacing: 3,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const Spacer(),
                          if (expiresAt != null)
                            Text(
                              '链接 ${ShareLinkKit.expiryHint(expiresAt)}',
                              style: McText.caption.faint.tabular,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        collection.name.isEmpty ? '分享合集' : collection.name,
                        style: McText.titleLg,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '共 ${collection.totalCount} 部',
                        style: McText.sub.muted,
                      ),
                      if (collection.description != null &&
                          collection.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(collection.description!, style: McText.sub.muted),
                      ],
                    ],
                  ),
                ),
              ),
              if (collection.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('合集里暂时还没有影片', style: McText.sub.muted),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    McTokens.pagePadding,
                    8,
                    McTokens.pagePadding,
                    40,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 156,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.54,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = collection.items[index];
                        final posterUrl =
                            api.imageUrl(item.posterUrl, widthPx: 360);
                        return McPressable(
                          onTap: () =>
                              controller.openCollectionItem(item.mediaItemId),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AspectRatio(
                                  aspectRatio: 2 / 3,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: McTokens.posterPlaceholder,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.08),
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: posterUrl == null
                                        ? const Center(
                                            child: Icon(
                                              McIcons.movie,
                                              color: McTokens.textFaint,
                                            ),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: posterUrl,
                                            httpHeaders: {
                                              if (cookieHeader != null)
                                                'Cookie': cookieHeader,
                                            },
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                const ColoredBox(
                                              color: McTokens.posterPlaceholder,
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                const Center(
                                              child: Icon(
                                                McIcons.movie,
                                                color: McTokens.textFaint,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: McText.sub.semibold,
                              ),
                              if (item.year != null)
                                Text(
                                  '${item.year}',
                                  style: McText.caption.faint,
                                ),
                            ],
                          ),
                        );
                      },
                      childCount: collection.items.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// MARK: - 富访客影片页（ShareItemView 1:1 对齐）

class _ShareItemView extends StatefulWidget {
  const _ShareItemView({
    required this.slug,
    required this.state,
    required this.controller,
    required this.item,
    required this.api,
    this.onBackToCollection,
    required this.onPlay,
  });

  final String slug;
  final ShareUiState state;
  final ShareController controller;
  final SharedItem item;
  final GuestShareApi api;
  final VoidCallback? onBackToCollection;
  final Future<void> Function({int? episodeNumber, int? startMs}) onPlay;

  @override
  State<_ShareItemView> createState() => _ShareItemViewState();
}

class _ShareItemViewState extends State<_ShareItemView> {
  bool _plotExpanded = false;
  bool _audioExpanded = false;
  bool _subsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final state = widget.state;
    final api = widget.api;
    final cookie = api.cookieHeader;
    final headers = <String, String>{if (cookie != null) 'Cookie': cookie};

    final available = state.currentAvailableFiles;
    final currentFile = available.isNotEmpty ? available.first : null;
    final canPlay =
        available.isNotEmpty && (item.isMovie || state.selectedEpisode != null);
    final selectedEp = state.selectedEpisode;
    final plot = item.isMovie
        ? item.localMeta?.plot
        : (selectedEp?.overview?.isNotEmpty == true
            ? selectedEp!.overview
            : item.localMeta?.plot);
    final backdropUrl = api.imageUrl(
      item.backdropUrl ?? item.posterUrl,
      widthPx: 1280,
    );
    final expiresAt = item.expiresAt ?? state.probe?.expiresAt;
    final facts = _buildFacts(item, available);
    final cast = item.localMeta?.cast ?? const <SharedPerson>[];
    final form = McFormWatch.of(context);
    final maxWidth =
        mcWindowClassOf(form) == McWindowClass.compact ? 640.0 : 840.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 固定铺底剧照 + 暗色渐变板
        if (backdropUrl != null)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: backdropUrl,
              httpHeaders: headers,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const ColoredBox(color: McTokens.bg),
            ),
          )
        else
          const ColoredBox(color: McTokens.bg),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.42, 0.72, 1.0],
                colors: [
                  Color(0x2807080C),
                  Color(0xC007080C),
                  Color(0xF507080C),
                  McTokens.bg,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 56),
                children: [
                  // 顶栏：「返回合集」+ 字标 + 相对到期倒计时（无下载、无登录/管理入口）
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      McTokens.pagePadding,
                      8,
                      McTokens.pagePadding,
                      0,
                    ),
                    child: Row(
                      children: [
                        if (widget.onBackToCollection != null) ...[
                          McChip(
                            label: '返回合集',
                            selected: true,
                            compact: true,
                            onTap: widget.onBackToCollection,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          'MOVIECLAW',
                          style: McText.caption.semibold.copyWith(
                            letterSpacing: 3,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        const Spacer(),
                        if (expiresAt != null)
                          Text(
                            '链接 ${ShareLinkKit.expiryHint(expiresAt)}',
                            style: McText.caption.faint.tabular,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 132),

                  // 标题、当前集、事实徽章、类型、文件规格、只读音轨/字幕表、主播放键、简介
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: McTokens.pagePadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: McText.titleLg.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(color: Color(0x80000000), blurRadius: 8),
                            ],
                          ),
                        ),
                        if (!item.isMovie && selectedEp != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '第 ${state.selectedSeason} 季 第 ${selectedEp.episodeNumber} 集'
                            '${selectedEp.name != null && selectedEp.name!.isNotEmpty ? ' - ${selectedEp.name}' : ''}',
                            style: McText.sub.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                        if (facts.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            facts.join(' · '),
                            style: McText.sub.tabular.copyWith(
                              color: Colors.white.withValues(alpha: 0.84),
                            ),
                          ),
                        ],
                        if (item.localMeta != null &&
                            item.localMeta!.genres.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.localMeta!.genres.join(' · '),
                            style: McText.sub.muted,
                          ),
                        ],
                        if (currentFile != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            [
                              if (currentFile.container != null)
                                currentFile.container!.toUpperCase(),
                              if (currentFile.videoCodec != null)
                                currentFile.videoCodec!.toUpperCase(),
                              if (currentFile.sizeBytes > 0)
                                mcFormatBytes(currentFile.sizeBytes),
                              if (available.length > 1)
                                '${available.length} 个版本',
                            ].join(' · '),
                            style: McText.caption.faint.tabular,
                          ),
                          const SizedBox(height: 8),
                          _ReadOnlyTracksSection(
                            file: currentFile,
                            audioExpanded: _audioExpanded,
                            subsExpanded: _subsExpanded,
                            onToggleAudio: () => setState(
                              () => _audioExpanded = !_audioExpanded,
                            ),
                            onToggleSubs: () => setState(
                              () => _subsExpanded = !_subsExpanded,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        if (canPlay)
                          _buildPlayButton(state)
                        else
                          Text(
                            item.isMovie || selectedEp != null
                                ? '当前没有可播放的文件'
                                : '请先在下方选择要观看的剧集',
                            style: McText.sub.muted,
                          ),
                        if (plot != null && plot.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _plotExpanded = !_plotExpanded),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plot,
                                  maxLines: _plotExpanded ? null : 3,
                                  overflow: _plotExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: McText.sub.muted,
                                ),
                                if (plot.length > 80)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _plotExpanded ? '收起简介' : '展开简介',
                                      style: McText.caption.copyWith(
                                        color: McTokens.accentStrong,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 剧集：季选择 + 16:9 剧照横滚卡（点击切换当前集简介/规格/章节）
                  if (!item.isMovie && item.seasons.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    _ShareEpisodesSection(
                      item: item,
                      state: state,
                      controller: widget.controller,
                      api: api,
                      headers: headers,
                    ),
                  ],

                  // 章节条（点击直接从章节时间戳起播）
                  if (currentFile != null &&
                      currentFile.chapters.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    _ShareChapterStrip(
                      chapters: currentFile.chapters,
                      api: api,
                      headers: headers,
                      onTapChapter: (chapter) => widget.onPlay(
                        episodeNumber: selectedEp?.episodeNumber,
                        startMs: chapter.seekMs,
                      ),
                    ),
                  ],

                  // 演职员行（导演 + 演员，只读不跳站内影人页）
                  if (cast.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    _ShareCastRow(cast: cast, api: api, headers: headers),
                  ],

                  // 外部词条链接（TMDB / IMDb / 豆瓣）
                  if (item.tmdbId != null ||
                      item.imdbId != null ||
                      item.doubanId != null) ...[
                    const SizedBox(height: 24),
                    _ShareExternalLinks(item: item),
                  ],

                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: McTokens.pagePadding,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: McTokens.surfaceInset.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(McTokens.cardRadius),
                        border: Border.all(color: McTokens.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('访客播放说明', style: McText.sub.semibold),
                          const SizedBox(height: 4),
                          Text(
                            '你正在以访客身份观看分享内容。观看进度仅保存在当前设备，不会写入任何成员账号记录。',
                            style: McText.caption.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton(ShareUiState state) {
    final resume = state.localResume;
    final hasResume = resume != null && resume.positionMs > 0;
    final clock = hasResume ? mcFormatClock(resume.positionMs ~/ 1000) : null;
    final label = hasResume ? '继续观看 · 看到 $clock' : '播放';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        McFocusRing(
          borderRadius: McTokens.pillRadius,
          child: McActionPill(
            icon: McIcons.play2Fill,
            label: label,
            primary: true,
            busy: state.opening,
            expanded: true,
            height: 44,
            onTap: state.opening
                ? null
                : () => widget.onPlay(
                      episodeNumber: state.selectedEpisode?.episodeNumber,
                    ),
          ),
        ),
        if (hasResume) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 4,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '上次看到 $clock（本机访客进度）',
            style: McText.caption.faint.tabular,
          ),
        ],
      ],
    );
  }

  List<String> _buildFacts(SharedItem item, List<SharedFile> available) {
    var runtime = item.localMeta?.runtimeMinutes;
    if (runtime == null || runtime == 0) {
      for (final f in item.files) {
        if (f.durationSeconds != null && f.durationSeconds! >= 60) {
          runtime = (f.durationSeconds! / 60).round();
          break;
        }
      }
    }
    final resolutions = <String>{
      for (final f in available)
        if (f.resolution != null && f.resolution!.isNotEmpty)
          ShareLinkKit.resolutionLabel(f.resolution!),
    }.toList();
    final hdrs = <String>[];
    for (final f in available) {
      final h = f.hdr;
      if (h != null && h.isNotEmpty && !hdrs.contains(h)) hdrs.add(h);
    }
    return [
      if (item.year != null) '${item.year}',
      if (runtime != null && runtime > 0) ShareLinkKit.runtimeLabel(runtime),
      if (resolutions.isNotEmpty) resolutions.join(' / '),
      if (hdrs.isNotEmpty) hdrs.join(' / '),
    ];
  }
}

/// 只读音轨 / 字幕折叠表格（无下载、无编辑操作）。
class _ReadOnlyTracksSection extends StatelessWidget {
  const _ReadOnlyTracksSection({
    required this.file,
    required this.audioExpanded,
    required this.subsExpanded,
    required this.onToggleAudio,
    required this.onToggleSubs,
  });

  final SharedFile file;
  final bool audioExpanded;
  final bool subsExpanded;
  final VoidCallback onToggleAudio;
  final VoidCallback onToggleSubs;

  @override
  Widget build(BuildContext context) {
    if (file.audioStreams.isEmpty && file.subtitleStreams.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        if (file.audioStreams.isNotEmpty)
          _collapsibleBlock(
            title: '音轨',
            summary: '${file.audioStreams.length} 条',
            expanded: audioExpanded,
            onToggle: onToggleAudio,
            rows: [
              for (final a in file.audioStreams)
                [
                  if (a.language != null) a.language!.toUpperCase(),
                  if (a.displayCodec.isNotEmpty) a.displayCodec,
                  if (a.displayChannels.isNotEmpty) a.displayChannels,
                  if (a.title != null && a.title!.isNotEmpty) a.title!,
                  if (a.isDefault) '默认',
                ].join(' · '),
            ],
          ),
        if (file.subtitleStreams.isNotEmpty) ...[
          const SizedBox(height: 6),
          _collapsibleBlock(
            title: '字幕',
            summary: '${file.subtitleStreams.length} 条',
            expanded: subsExpanded,
            onToggle: onToggleSubs,
            rows: [
              for (final s in file.subtitleStreams)
                [
                  if (s.language != null) s.language!.toUpperCase(),
                  if (s.codec != null) s.codec!.toUpperCase(),
                  if (s.title != null && s.title!.isNotEmpty) s.title!,
                  if (s.external) '外挂',
                  if (s.forced) '强制',
                  if (s.isDefault) '默认',
                ].join(' · '),
            ],
          ),
        ],
      ],
    );
  }

  Widget _collapsibleBlock({
    required String title,
    required String summary,
    required bool expanded,
    required VoidCallback onToggle,
    required List<String> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McPressable(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Text(title, style: McText.caption.semibold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(summary, style: McText.caption.faint),
                  ),
                  Icon(
                    expanded
                        ? McIcons.arrowDownMFill
                        : McIcons.arrowRightMFill,
                    size: 14,
                    color: McTokens.textFaint,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        r.isEmpty ? '未知轨道' : r,
                        style: McText.micro.muted,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 分享剧集季选择 + 16:9 剧照横滚卡（点击切换选中集，更新上方简介、规格与章节）。
class _ShareEpisodesSection extends StatelessWidget {
  const _ShareEpisodesSection({
    required this.item,
    required this.state,
    required this.controller,
    required this.api,
    required this.headers,
  });

  final SharedItem item;
  final ShareUiState state;
  final ShareController controller;
  final GuestShareApi api;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final ownedSeasons = {for (final f in item.files) f.seasonNumber};
    final ownedCount = state.episodes.where((e) => e.owned).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
          child: Row(
            children: [
              const Text('剧集', style: McText.titleSm),
              const SizedBox(width: 10),
              if (state.episodes.isNotEmpty)
                Text(
                  '$ownedCount / ${state.episodes.length} 集',
                  style: McText.caption.faint.tabular,
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
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
                    label: (season == 0 ? '特别篇' : '第 $season 季') +
                        (ownedSeasons.contains(season) ? '' : '（未入库）'),
                    selected: season == state.selectedSeason,
                    onTap: () => controller.selectSeason(season),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (state.loadingEpisodes)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
              vertical: 16,
            ),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (state.episodes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
            ),
            child: Text('暂无分集信息', style: McText.caption.muted),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: McTokens.pagePadding,
              ),
              itemCount: state.episodes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final ep = state.episodes[index];
                final isSelected =
                    ep.episodeNumber == state.selectedEpisode?.episodeNumber;
                final stillUrl = api.imageUrl(ep.stillUrl, widthPx: 480);

                return Opacity(
                  opacity: ep.owned ? 1.0 : 0.45,
                  child: McPressable(
                    onTap: () => controller.selectEpisode(ep.episodeNumber),
                    child: SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              decoration: BoxDecoration(
                                color: McTokens.surfaceRaised,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.88)
                                      : Colors.white.withValues(alpha: 0.1),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (stillUrl != null)
                                    CachedNetworkImage(
                                      imageUrl: stillUrl,
                                      httpHeaders: headers,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Center(
                                        child: Text(
                                          '${ep.episodeNumber}',
                                          style: McText.titleSm.faint,
                                        ),
                                      ),
                                    )
                                  else
                                    Center(
                                      child: Text(
                                        '${ep.episodeNumber}',
                                        style: McText.titleSm.faint,
                                      ),
                                    ),
                                  if (!ep.owned)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.65),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '缺集',
                                          style: McText.micro.copyWith(
                                            color: McTokens.warning,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${ep.episodeNumber}. ${ep.name?.isNotEmpty == true ? ep.name! : '第 ${ep.episodeNumber} 集'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: isSelected
                                ? McText.caption.semibold
                                : McText.caption.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// 章节横滚条（点击直接从该章节时间戳起播）。
class _ShareChapterStrip extends StatelessWidget {
  const _ShareChapterStrip({
    required this.chapters,
    required this.api,
    required this.headers,
    required this.onTapChapter,
  });

  final List<SharedChapter> chapters;
  final GuestShareApi api;
  final Map<String, String> headers;
  final ValueChanged<SharedChapter> onTapChapter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
          child: Text('场景章节', style: McText.titleSm),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
            ),
            itemCount: chapters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final ch = chapters[index];
              final img = api.imageUrl(ch.imageUrl, widthPx: 360);
              final timeLabel = mcFormatClock(ch.seekMs ~/ 1000);
              return McPressable(
                onTap: () => onTapChapter(ch),
                child: SizedBox(
                  width: 164,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (img != null)
                                CachedNetworkImage(
                                  imageUrl: img,
                                  httpHeaders: headers,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const ColoredBox(
                                    color: McTokens.surfaceRaised,
                                  ),
                                )
                              else
                                const ColoredBox(
                                  color: McTokens.surfaceRaised,
                                  child: Icon(
                                    McIcons.play2Fill,
                                    color: McTokens.textFaint,
                                  ),
                                ),
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.72),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    timeLabel,
                                    style: McText.micro.tabular
                                        .copyWith(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        ch.title?.isNotEmpty == true
                            ? ch.title!
                            : '场景 ${index + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: McText.caption.muted,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 演职员行（只读：不提供站内影人跳转入口）。
class _ShareCastRow extends StatelessWidget {
  const _ShareCastRow({
    required this.cast,
    required this.api,
    required this.headers,
  });

  final List<SharedPerson> cast;
  final GuestShareApi api;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
          child: Text('演职员', style: McText.titleSm),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: McTokens.pagePadding,
            ),
            itemCount: cast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final person = cast[index];
              final avatar = api.imageUrl(person.thumbUrl, widthPx: 240);
              return SizedBox(
                width: 78,
                child: Column(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: avatar != null
                            ? CachedNetworkImage(
                                imageUrl: avatar,
                                httpHeaders: headers,
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
                      textAlign: TextAlign.center,
                      style: McText.caption,
                    ),
                    if (person.subtitle != null)
                      Text(
                        person.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: McText.micro.faint,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback() => const ColoredBox(
        color: McTokens.surfaceRaised,
        child: Icon(McIcons.group, color: McTokens.textFaint, size: 24),
      );
}

/// 外部词条链接（TMDB / IMDb / 豆瓣，不暴露任何站内/管理入口）。
class _ShareExternalLinks extends StatelessWidget {
  const _ShareExternalLinks({required this.item});

  final SharedItem item;

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kindSegment = item.kind == 'tv' ? 'tv' : 'movie';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: McTokens.pagePadding),
      child: Container(
        padding: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('相关词条', style: McText.caption.faint),
            if (item.tmdbId != null)
              GestureDetector(
                onTap: () => _open(
                  'https://www.themoviedb.org/$kindSegment/${item.tmdbId}',
                ),
                child: Text(
                  'TMDB ↗',
                  style: McText.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ),
            if (item.imdbId != null)
              GestureDetector(
                onTap: () => _open(
                  'https://www.imdb.com/title/${item.imdbId}/',
                ),
                child: Text(
                  'IMDb ↗',
                  style: McText.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ),
            if (item.doubanId != null)
              GestureDetector(
                onTap: () => _open(
                  'https://movie.douban.com/subject/${item.doubanId}/',
                ),
                child: Text(
                  '豆瓣 ↗',
                  style: McText.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
