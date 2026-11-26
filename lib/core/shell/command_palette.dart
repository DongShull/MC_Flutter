import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/root/state/main_tab_bus.dart';
import '../api/mc_client.dart';
import '../api/session_providers.dart';
import '../designsystem/mc_chrome.dart';
import '../designsystem/mc_glass.dart';
import '../designsystem/mc_icons.dart';
import '../designsystem/theme.dart';
import '../image/image_urls.dart';
import '../router.dart';
import '../session/session_store.dart';

/// 全局 `⌘K` / `Ctrl+K` Spotlight 命令与三合一搜索面板控制器。
class McCommandPaletteController extends ValueNotifier<bool> {
  McCommandPaletteController._() : super(false);

  static final McCommandPaletteController instance =
      McCommandPaletteController._();

  void open() {
    if (!appSession.isReady) return;
    value = true;
  }

  void close() => value = false;

  void toggle() {
    if (!appSession.isReady) return;
    value = !value;
  }
}

enum _PaletteVertical { media, torrent, library }

class _PaletteItem {
  const _PaletteItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.posterUrl,
    this.badge,
    required this.onActivate,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? posterUrl;
  final String? badge;
  final VoidCallback onActivate;
}

/// 挂载在 `McApp.builder` 顶层，承接全端快捷键与 `⌘K` / `Ctrl+K` Spotlight 浮层。
class McCommandPaletteHost extends ConsumerStatefulWidget {
  const McCommandPaletteHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<McCommandPaletteHost> createState() =>
      _McCommandPaletteHostState();
}

class _McCommandPaletteHostState extends ConsumerState<McCommandPaletteHost> {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  _PaletteVertical _vertical = _PaletteVertical.media;
  int _selectedIndex = 0;
  bool _loading = false;
  List<_PaletteItem> _remoteItems = const [];
  Timer? _debounce;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    McCommandPaletteController.instance.addListener(_onVisibilityChanged);
  }

  @override
  void dispose() {
    McCommandPaletteController.instance.removeListener(_onVisibilityChanged);
    _debounce?.cancel();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onVisibilityChanged() {
    if (!mounted) return;
    setState(() {
      if (McCommandPaletteController.instance.value) {
        _selectedIndex = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _inputFocus.requestFocus();
        });
      }
    });
  }

  void _switchMainTab(MainTab tab) {
    McCommandPaletteController.instance.close();
    MainTabBus.instance.open(tab);
    mcRouter.go('/home');
  }

  void _navigate(String route) {
    McCommandPaletteController.instance.close();
    mcRouter.push(route);
  }

  List<_PaletteItem> _quickCommands(String q) {
    final all = <_PaletteItem>[
      _PaletteItem(
        icon: McIcons.mediaLibraryFill,
        title: '前往 媒体库首页',
        subtitle: '浏览继续观看、收藏与全部分类货架',
        badge: '⌘1',
        onActivate: () => _switchMainTab(MainTab.library),
      ),
      _PaletteItem(
        icon: McIcons.bookmarkFill,
        title: '前往 订阅追更',
        subtitle: '查看追更日历、近期入库与进行中订阅',
        badge: '⌘2',
        onActivate: () => _switchMainTab(MainTab.subscriptions),
      ),
      _PaletteItem(
        icon: McIcons.aiSearchFill,
        title: '前往 发现新片',
        subtitle: '探索 TMDB 与豆瓣热门榜单和片单',
        badge: '⌘3',
        onActivate: () => _switchMainTab(MainTab.discover),
      ),
      _PaletteItem(
        icon: McIcons.waveform,
        title: '前往 活动与观看统计',
        subtitle: '实时播放、下载队列、任务进度与热力图',
        badge: '⌘4',
        onActivate: () => _switchMainTab(MainTab.activity),
      ),
      _PaletteItem(
        icon: McIcons.aiStarFill,
        title: '打开 AI 智能助手工作台',
        subtitle: '自然语言找片、订阅、查任务与排障',
        onActivate: () => _navigate('/agent'),
      ),
      _PaletteItem(
        icon: McIcons.search,
        title: '打开 完整三合一搜索页',
        subtitle: '影视 · PT 种子资源 · 本地媒体库深度检索',
        onActivate: () => _navigate('/search'),
      ),
      _PaletteItem(
        icon: McIcons.folderSettings,
        title: '媒体库管理中心',
        subtitle: '新建/扫描/整理媒体库、回收站、重复文件与分享管理',
        onActivate: () => _navigate('/library/manage'),
      ),
      _PaletteItem(
        icon: McIcons.stack,
        title: '全部合集管理',
        subtitle: '查看、新建与编排智能合集和手动片单',
        onActivate: () => _navigate('/library/collections'),
      ),
      _PaletteItem(
        icon: McIcons.heart2Fill,
        title: '我的收藏墙',
        subtitle: '查看全部已收藏电影与剧集',
        onActivate: () => _navigate('/library/favorites'),
      ),
      _PaletteItem(
        icon: McIcons.play2,
        title: '片段 Reels 快刷',
        subtitle: '沉浸浏览私人片库高光片段',
        onActivate: () => _navigate('/reels'),
      ),
      _PaletteItem(
        icon: McIcons.downloadCloudOut,
        title: '本机离线下载中心',
        subtitle: '管理离线缓存队列与零网本地播放',
        onActivate: () => _navigate('/offline'),
      ),
      _PaletteItem(
        icon: McIcons.setting1,
        title: '全能设置与服务器管理中心',
        subtitle: '成员、规则组、PT 站点、下载器、刮削、AI、网络与日志',
        badge: '⌘,',
        onActivate: () => _navigate('/settings'),
      ),
    ];
    if (q.isEmpty) return all;
    final lower = q.toLowerCase();
    return all
        .where(
          (c) =>
              c.title.toLowerCase().contains(lower) ||
              (c.subtitle?.toLowerCase().contains(lower) ?? false),
        )
        .toList();
  }

  void _onQueryChanged(String raw) {
    setState(() => _selectedIndex = 0);
    _debounce?.cancel();
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _loading = false;
        _remoteItems = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () => _fetch(q));
  }

  void _cycleVertical() {
    final next = _PaletteVertical
        .values[(_vertical.index + 1) % _PaletteVertical.values.length];
    setState(() {
      _vertical = next;
      _selectedIndex = 0;
    });
    final q = _inputCtrl.text.trim();
    if (q.isNotEmpty) _fetch(q);
  }

  Future<void> _fetch(String q) async {
    final mySeq = ++_seq;
    setState(() => _loading = true);
    final client = ref.read(mcClientProvider);
    try {
      final results = <_PaletteItem>[];
      switch (_vertical) {
        case _PaletteVertical.media:
          final data = await client.unwrap<dynamic>(
            Channel.general,
            'POST',
            '/api/v1/search/titles',
            body: {'query': q, 'page': 1},
          );
          final list = data is Map
              ? (data['items'] ?? data['results'] ?? data['titles'] ?? const [])
              : (data is List ? data : const []);
          if (list is List) {
            for (final raw in list.whereType<Map>().take(10)) {
              final m = raw.cast<String, dynamic>();
              final title = (m['title'] ?? m['name'] ?? '').toString();
              if (title.isEmpty) continue;
              final refStr = (m['title_ref'] ??
                      m['ref'] ??
                      'tmdb:${m['media_type'] ?? m['kind'] ?? 'movie'}:${m['tmdb_id'] ?? m['id']}')
                  .toString();
              final year = m['year']?.toString();
              final kind = (m['media_type'] ?? m['kind']) == 'tv' ? '剧集' : '电影';
              results.add(
                _PaletteItem(
                  icon: McIcons.movie,
                  title: title,
                  subtitle: [kind, if (year != null) year].join(' · '),
                  posterUrl: (m['poster_url'] ?? m['poster'])?.toString(),
                  badge: m['in_library'] == true ? '已在库' : '可订阅',
                  onActivate: () => _navigate(
                    '/discover/title?ref=${Uri.encodeComponent(refStr)}',
                  ),
                ),
              );
            }
          }
        case _PaletteVertical.library:
          final data = await client.unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/search/library',
            query: {'q': q, 'limit': 10},
          );
          final hits = (data['items'] ?? const []) as List<dynamic>;
          for (final raw in hits.whereType<Map>()) {
            final item = raw['item'] is Map
                ? (raw['item'] as Map).cast<String, dynamic>()
                : raw.cast<String, dynamic>();
            final title = (item['title'] ?? '').toString();
            final libId = (item['library_id'] as num?)?.toInt();
            final mediaId =
                (item['media_item_id'] ?? item['id'] as num?)?.toInt();
            if (title.isEmpty || libId == null || mediaId == null) continue;
            results.add(
              _PaletteItem(
                icon: McIcons.mediaLibraryFill,
                title: title,
                subtitle: item['year']?.toString() ?? '本地媒体库',
                posterUrl: item['poster_url']?.toString(),
                badge: '媒体库',
                onActivate: () => _navigate('/detail/$libId/$mediaId'),
              ),
            );
          }
        case _PaletteVertical.torrent:
          results.add(
            _PaletteItem(
              icon: McIcons.downloadCloudOut,
              title: '在 PT 种子资源库中检索「$q」',
              subtitle: '查看各站点实时做种数、促销免费标记并一键直下或抓种',
              badge: 'Enter',
              onActivate: () => _navigate(
                '/search?q=${Uri.encodeQueryComponent(q)}&tab=torrent',
              ),
            ),
          );
      }
      if (!mounted || mySeq != _seq) return;
      setState(() {
        _remoteItems = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || mySeq != _seq) return;
      setState(() {
        _remoteItems = [
          _PaletteItem(
            icon: McIcons.search,
            title: '在搜索页检索「$q」',
            subtitle: '打开完整搜索页查看全部结果',
            onActivate: () =>
                _navigate('/search?q=${Uri.encodeQueryComponent(q)}'),
          ),
        ];
        _loading = false;
      });
    }
  }

  KeyEventResult _handleGlobalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final hw = HardwareKeyboard.instance;
    final primaryMod = hw.isMetaPressed || hw.isControlPressed;
    final key = event.logicalKey;

    if (primaryMod && key == LogicalKeyboardKey.keyK) {
      McCommandPaletteController.instance.toggle();
      return KeyEventResult.handled;
    }

    if (McCommandPaletteController.instance.value) {
      final items = _effectiveItems();
      if (key == LogicalKeyboardKey.escape) {
        McCommandPaletteController.instance.close();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.tab) {
        _cycleVertical();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown && items.isNotEmpty) {
        setState(() => _selectedIndex = (_selectedIndex + 1) % items.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp && items.isNotEmpty) {
        setState(
          () => _selectedIndex =
              (_selectedIndex - 1 + items.length) % items.length,
        );
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter && items.isNotEmpty) {
        items[_selectedIndex.clamp(0, items.length - 1)].onActivate();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (!appSession.isReady) return KeyEventResult.ignored;

    if (primaryMod && key == LogicalKeyboardKey.comma) {
      mcRouter.push('/settings');
      return KeyEventResult.handled;
    }
    if (primaryMod && key == LogicalKeyboardKey.bracketLeft) {
      if (mcRouter.canPop()) mcRouter.pop();
      return KeyEventResult.handled;
    }
    if (primaryMod) {
      final tabIdx = switch (key) {
        LogicalKeyboardKey.digit1 => 0,
        LogicalKeyboardKey.digit2 => 1,
        LogicalKeyboardKey.digit3 => 2,
        LogicalKeyboardKey.digit4 => 3,
        LogicalKeyboardKey.digit5 => 4,
        _ => null,
      };
      if (tabIdx != null) {
        MainTabBus.instance.open(MainTab.values[tabIdx]);
        mcRouter.go('/home');
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  List<_PaletteItem> _effectiveItems() {
    final q = _inputCtrl.text.trim();
    if (q.isEmpty) return _quickCommands('');
    return [..._remoteItems, ..._quickCommands(q)];
  }

  @override
  Widget build(BuildContext context) {
    final open = McCommandPaletteController.instance.value;
    final items = open ? _effectiveItems() : const <_PaletteItem>[];

    return Focus(
      autofocus: false,
      canRequestFocus: false,
      onKeyEvent: _handleGlobalKey,
      child: Stack(
        children: [
          widget.child,
          if (open)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: McCommandPaletteController.instance.close,
                child: ColoredBox(
                  color: const Color(0xA6000000),
                  child: SafeArea(
                    child: Align(
                      alignment: const Alignment(0, -0.55),
                      child: GestureDetector(
                        onTap: () {},
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 620,
                            maxHeight: 520,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildPaletteCard(items),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaletteCard(List<_PaletteItem> items) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xF0151822),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: McTokens.lineStrong, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0xCC000000),
                blurRadius: 40,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
                  child: Row(
                    children: [
                      const Icon(
                        McIcons.search,
                        size: 19,
                        color: McTokens.accentStrong,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          focusNode: _inputFocus,
                          style: McText.body,
                          onChanged: _onQueryChanged,
                          decoration: const InputDecoration(
                            hintText: '搜索全网影视、PT 种子、本地媒体库或输入跳转命令…',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 1.8),
                          ),
                        ),
                      McChip(
                        label: 'ESC',
                        compact: true,
                        onTap: McCommandPaletteController.instance.close,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      McChip(
                        label: '影视 (TMDB/豆瓣)',
                        compact: true,
                        selected: _vertical == _PaletteVertical.media,
                        onTap: () {
                          setState(() => _vertical = _PaletteVertical.media);
                          final q = _inputCtrl.text.trim();
                          if (q.isNotEmpty) _fetch(q);
                        },
                      ),
                      McChip(
                        label: '种子资源 (PT)',
                        compact: true,
                        selected: _vertical == _PaletteVertical.torrent,
                        onTap: () {
                          setState(() => _vertical = _PaletteVertical.torrent);
                          final q = _inputCtrl.text.trim();
                          if (q.isNotEmpty) _fetch(q);
                        },
                      ),
                      McChip(
                        label: '本地媒体库',
                        compact: true,
                        selected: _vertical == _PaletteVertical.library,
                        onTap: () {
                          setState(() => _vertical = _PaletteVertical.library);
                          final q = _inputCtrl.text.trim();
                          if (q.isNotEmpty) _fetch(q);
                        },
                      ),
                      Text('Tab 切换域 · ↑↓ 选择 · Enter 打开', style: McText.micro.faint),
                    ],
                  ),
                ),
                const Divider(height: 1, color: McTokens.line),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final active = i == _selectedIndex;
                      final poster = item.posterUrl == null
                          ? ''
                          : McImageUrls.resolve(item.posterUrl, widthPx: 160);
                      return McPressable(
                        onTap: item.onActivate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: active
                                ? McTokens.glassFillActive
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: active
                                ? Border.all(color: McTokens.lineStrong)
                                : null,
                          ),
                          child: Row(
                            children: [
                              if (poster.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedNetworkImage(
                                    imageUrl: poster,
                                    httpHeaders: mcImageHeaders(),
                                    width: 32,
                                    height: 46,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Icon(
                                      item.icon,
                                      size: 18,
                                      color: McTokens.textMuted,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: McTokens.surfaceInset,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    size: 17,
                                    color: active
                                        ? McTokens.accentStrong
                                        : McTokens.textMuted,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: McText.ui,
                                    ),
                                    if (item.subtitle != null &&
                                        item.subtitle!.isNotEmpty)
                                      Text(
                                        item.subtitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: McText.caption.muted,
                                      ),
                                  ],
                                ),
                              ),
                              if (item.badge != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: McTokens.surfaceInset,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: McTokens.line),
                                  ),
                                  child: Text(
                                    item.badge!,
                                    style: McText.micro.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
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
