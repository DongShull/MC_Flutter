import '../../../core/api/models.dart';

/// 种子搜索与下载目标选择（P2 移植自安卓 `feature/search/DownloadTarget.kt`、
/// `core/model/Search.kt`、`feature/search/SearchViewModel.kt` 的
/// `DownloadFlow` / `SiteBlock` 部分）。
///
/// 本文件只含纯数据与纯函数（无网络、无 Riverpod），可直接单测。
/// 服务端字段名按 snake_case 解析，缺失时按安卓默认值兜底。

/// 种子分类（安卓 `TorrentCategory`；id 与服务端 `categories` 参数同值）。
enum TorrentCategory {
  movie('movie', '电影'),
  tv('tv', '剧集'),
  documentary('documentary', '纪录片'),
  anime('anime', '动画'),
  music('music', '音乐'),
  game('game', '游戏'),
  av('av', '其他视频'),
  other('other', '其他');

  const TorrentCategory(this.id, this.label);

  final String id;
  final String label;

  static TorrentCategory? of(String? id) {
    for (final c in TorrentCategory.values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// 下载 / 投递按钮的按行状态（安卓 `TorrentSubmitState`；终态不可再点）。
enum TorrentSubmitState {
  idle,
  submitting,
  done,
  exists,
  error;

  String get downloadLabel => switch (this) {
        TorrentSubmitState.idle => '下载',
        TorrentSubmitState.submitting => '提交中…',
        TorrentSubmitState.done => '已提交',
        TorrentSubmitState.exists => '已在下载器',
        TorrentSubmitState.error => '失败·重试',
      };

  String get grabLabel => switch (this) {
        TorrentSubmitState.idle => '投给订阅',
        TorrentSubmitState.submitting => '投递中…',
        TorrentSubmitState.done || TorrentSubmitState.exists => '已投递',
        TorrentSubmitState.error => '失败·重试',
      };
}

/// 数据扩充层从标题/副标题推导的结构化属性（服务端 `TorrentAttrs`）。
/// 全部可空：提取不到就保持空值，绝不猜测。
class TorrentAttrs {
  const TorrentAttrs({
    this.mediaType,
    this.titlesZh = const [],
    this.titlesEn = const [],
    this.year,
    this.seasons = const [],
    this.episodes = const [],
  });

  factory TorrentAttrs.fromJson(Map<String, dynamic> j) => TorrentAttrs(
        mediaType: j['media_type']?.toString(),
        titlesZh: [for (final t in (j['titles_zh'] as List? ?? const [])) t.toString()],
        titlesEn: [for (final t in (j['titles_en'] as List? ?? const [])) t.toString()],
        year: (j['year'] as num?)?.toInt(),
        seasons: [for (final s in (j['seasons'] as List? ?? const [])) if (s is num) s.toInt()],
        episodes: [for (final s in (j['episodes'] as List? ?? const [])) if (s is num) s.toInt()],
      );

  /// "movie" / "tv" / null（无法确定）。
  final String? mediaType;
  final List<String> titlesZh;
  final List<String> titlesEn;
  final int? year;
  final List<int> seasons;
  final List<int> episodes;
}

/// 搜索结果里的一条种子（字段对齐服务端 `TorrentListItem` + 安卓 `TorrentHit`）。
class TorrentHit {
  const TorrentHit({
    this.torrentId = '',
    this.title = '',
    this.subtitle = '',
    this.category,
    this.size,
    this.sizeBytes = 0,
    this.seeders = 0,
    this.leechers = 0,
    this.snatched = 0,
    this.uploadTime,
    this.uploader = '',
    this.posterUrl,
    this.free = false,
    this.downloadVolumeFactor = 1,
    this.uploadVolumeFactor = 1,
    this.hitAndRun,
    this.detailUrl,
    this.downloadUrl,
    this.siteId = '',
    this.siteName = '',
    this.siteCategoryName,
    this.attrs,
  });

  factory TorrentHit.fromJson(Map<String, dynamic> j) => TorrentHit(
        torrentId: (j['torrent_id'] ?? j['torrentId'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        subtitle: (j['subtitle'] ?? '').toString(),
        category: j['category']?.toString(),
        size: j['size']?.toString(),
        sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
        seeders: (j['seeders'] as num?)?.toInt() ?? 0,
        leechers: (j['leechers'] as num?)?.toInt() ?? 0,
        snatched: (j['snatched'] as num?)?.toInt() ?? 0,
        uploadTime: j['upload_time']?.toString(),
        uploader: (j['uploader'] ?? '').toString(),
        posterUrl: j['poster_url']?.toString(),
        free: j['free'] as bool? ?? false,
        downloadVolumeFactor:
            (j['download_volume_factor'] as num?)?.toDouble() ?? 1,
        uploadVolumeFactor: (j['upload_volume_factor'] as num?)?.toDouble() ?? 1,
        hitAndRun: j['hit_and_run'] as bool?,
        detailUrl: j['detail_url']?.toString(),
        downloadUrl: j['download_url']?.toString(),
        siteId: (j['site_id'] ?? '').toString(),
        siteName: (j['site_name'] ?? '').toString(),
        siteCategoryName: j['site_category_name']?.toString(),
        attrs: j['attrs'] is Map
            ? TorrentAttrs.fromJson(
                (j['attrs'] as Map).cast<String, dynamic>())
            : null,
      );

  final String torrentId;
  final String title;
  final String subtitle;
  final String? category;
  final String? size;
  final int sizeBytes;
  final int seeders;
  final int leechers;
  final int snatched;
  final String? uploadTime;
  final String uploader;
  final String? posterUrl;
  final bool free;
  final double downloadVolumeFactor;
  final double uploadVolumeFactor;
  final bool? hitAndRun;
  final String? detailUrl;
  final String? downloadUrl;
  final String siteId;
  final String siteName;
  final String? siteCategoryName;
  final TorrentAttrs? attrs;

  /// 展示用标题（中文名优先，同安卓 `TorrentActionsSheet`）。
  String get displayTitle =>
      attrs?.titlesZh.firstOrNull ?? attrs?.titlesEn.firstOrNull ?? title;
}

/// 行键：站点 + 站点内种子 ID（同安卓 `hitKey` / iOS `rowKey`）。
String hitKey(TorrentHit hit) => '${hit.siteId}:${hit.torrentId}';

/// 落点弹窗需要的种子身份切片（由 [TorrentHit] 提炼，照安卓
/// `DownloadTargetRequest`；三件套齐全时服务端能自动收敛出唯一条目，
/// 走「自动入库」；缺任一项就只能让用户确认「这是哪部作品」）。
class DownloadTargetRequest {
  const DownloadTargetRequest({
    required this.siteId,
    required this.downloadUrl,
    this.torrentId,
    this.identityKind,
    this.identityTitle,
    this.identityYear,
    this.subtitle,
    this.hint,
    this.category = 'other',
    required this.hitKey,
    this.reason,
  });

  /// null = 没有可下载的链接（不能开落点弹窗）。
  static DownloadTargetRequest? of(TorrentHit hit, String keyword) {
    final url = hit.downloadUrl?.trim();
    if (url == null || url.isEmpty) return null;
    final attrs = hit.attrs;
    final kind = attrs?.mediaType;
    final kindOk = kind == 'movie' || kind == 'tv';
    final title = attrs?.titlesZh.firstOrNull ?? attrs?.titlesEn.firstOrNull;
    final year = attrs?.year;
    final identified = kindOk && title != null && year != null;
    return DownloadTargetRequest(
      siteId: hit.siteId,
      downloadUrl: url,
      torrentId: hit.torrentId.isEmpty ? null : hit.torrentId,
      identityKind: identified ? kind : null,
      identityTitle: identified ? title : null,
      identityYear: identified ? year : null,
      subtitle: hit.subtitle.isEmpty ? null : hit.subtitle,
      hint: keyword.trim().isEmpty ? null : keyword.trim(),
      category: hit.category ?? 'other',
      // 注意：这里不能调同名顶层函数 hitKey（类内字段名遮蔽），直接拼行键。
      hitKey: '${hit.siteId}:${hit.torrentId}',
    );
  }

  final String siteId;
  final String downloadUrl;
  final String? torrentId;
  final String? identityKind;
  final String? identityTitle;
  final int? identityYear;
  final String? subtitle;

  /// 用户的搜索关键词：身份识别失败时服务端拿它检索 TMDB 候选。
  final String? hint;

  /// 记忆的桶键：站点声明的一级分类（缺省 other）。
  final String category;

  /// 对应搜索结果行（下载按钮状态按行记）。
  final String hitKey;

  /// 记忆失效等原因（显示在弹窗顶部，静默回落最让人困惑）。
  final String? reason;

  String get id => '$siteId:$downloadUrl';

  DownloadTargetRequest copyWith({String? reason}) => DownloadTargetRequest(
        siteId: siteId,
        downloadUrl: downloadUrl,
        torrentId: torrentId,
        identityKind: identityKind,
        identityTitle: identityTitle,
        identityYear: identityYear,
        subtitle: subtitle,
        hint: hint,
        category: category,
        hitKey: hitKey,
        reason: reason ?? this.reason,
      );
}

/// 一个可选的保存目标（三层候选的渲染与提交共用一份计算）。
class TargetOption {
  const TargetOption({
    required this.id,
    required this.kind,
    this.savePath,
    this.libraryId,
    required this.label,
    this.detail,
  });

  /// smart / dir:… / library:… / default。
  final String id;
  final TargetOptionKind kind;
  final String? savePath;
  final int? libraryId;
  final String label;
  final String? detail;
}

enum TargetOptionKind { smart, dir, library, fallback }

/// 候选列表。管理员三层（智能入库 / 已配目录 / 下载器默认），
/// 成员两层（可见库 / 下载器默认）——下载器配置与智能入库预检都是
/// 超管接口，成员提交也不许带目录与下载器（服务端强制）。
List<TargetOption> computeTargetOptions({
  required bool isAdmin,
  required ManualDownloadTargetView? target,
  required bool showOther,
  required DownloaderView? downloader,
  required List<LibraryView> memberLibraries,
  required DownloadTargetRequest request,
}) {
  if (!isAdmin) {
    final kind = request.identityKind;
    final fit = memberLibraries.where((l) => l.kind != 'photo').toList();
    final ordered = [
      ...fit.where((l) => l.kind == kind),
      ...fit.where((l) => l.kind != kind),
    ];
    return [
      for (final library in ordered)
        TargetOption(
          id: 'library:${library.id}',
          kind: TargetOptionKind.library,
          libraryId: library.id,
          label: '下载到「${library.name}」',
          detail: '${libraryKindLabel(library.kind)}；按库的设置决定保存目录，完成后自动入库',
        ),
      const TargetOption(
        id: 'default',
        kind: TargetOptionKind.fallback,
        label: '下载器默认目录',
        detail: '由下载器按自身设置决定保存位置；不会自动整理入库',
      ),
    ];
  }
  final result = <TargetOption>[];
  if (target != null &&
      target.status == 'ready' &&
      target.tmdbId != null &&
      target.libraryId != null &&
      target.ok) {
    final entryDir = target.entryDir ?? target.path;
    final reason = target.routeReason ?? '';
    final String? detail;
    switch (target.mode) {
      case 'watch':
        detail = target.stagingPath != null
            ? '$reason；投递到自动入库的监听目录 ${target.path ?? ''}，完成后整理到 ${target.stagingPath}（外部流转回库根后入账）'
            : '$reason；投递到自动入库的监听目录 ${target.path ?? ''}，完成后自动整理入库';
      case 'inplace':
        detail = '$reason；直接下载到 ${trimPath(entryDir ?? '')}，完成后自动入账';
      default:
        detail = null;
    }
    result.add(TargetOption(
      id: 'smart',
      kind: TargetOptionKind.smart,
      label: '自动入库到「${target.libraryName ?? ''}」',
      detail: detail,
    ));
  }
  if (showOther) {
    final dirs = <(String, String)>[];
    final savePath = downloader?.savePath;
    if (savePath != null) dirs.add((savePath, '默认保存目录'));
    for (final m in downloader?.pathMappings ?? const <PathMapping>[]) {
      if (m.local.isNotEmpty && m.local != downloader?.savePath) {
        dirs.add((m.local, '路径映射'));
      }
    }
    for (final (path, source) in dirs) {
      final remote = remoteView(path, downloader?.pathMappings);
      result.add(TargetOption(
        id: 'dir:$path',
        kind: TargetOptionKind.dir,
        savePath: path,
        label: path,
        detail: remote != path ? '下载器视角：$remote（$source）' : source,
      ));
    }
    result.add(const TargetOption(
      id: 'default',
      kind: TargetOptionKind.fallback,
      label: '下载器默认目录',
      detail: '不指定路径，由下载器按自身设置决定；movieclaw 不会自动整理入库',
    ));
  }
  return result;
}

/// 媒体库类型的中文名（DiscoverScreen.kindLabel 同口径）。
String libraryKindLabel(String kind) => switch (kind) {
      'movie' => '电影',
      'tv' => '剧集',
      'photo' => '图片',
      _ => '其他',
    };

/// 目录比较用的归一化：去掉尾部斜杠（同安卓 `trimPath`）。
String trimPath(String path) {
  var p = path;
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}

/// 与后端 `translate_save_path` 同规则（仅用于展示下载器视角）。
String remoteView(String path, List<PathMapping>? mappings) {
  if (mappings == null || mappings.isEmpty) return path;
  PathMapping? best;
  for (final m in mappings) {
    final local = trimPath(m.local);
    if ((path == local || path.startsWith('$local/')) &&
        (best == null || local.length > trimPath(best.local).length)) {
      best = m;
    }
  }
  final chosen = best;
  if (chosen == null) return path;
  final local = trimPath(chosen.local);
  return trimPath(chosen.remote) + path.substring(local.length);
}

/// 记住的固定目录已不在候选里（库被删、路径映射改了）：记忆失效，回落完整弹窗。
bool isStaleDir(DownloadTargetPrefView pref, Set<String>? dirs) {
  if (pref.kind != 'dir') return false;
  final path = pref.savePath;
  if (path == null || dirs == null) return false;
  return !dirs.contains(trimPath(path));
}

/// 记忆命中的原因说明（null = 记忆可用，直接弹确认条）。
String? rememberedPrefIssue(
  DownloadTargetPrefView pref,
  DownloadTargetRequest request,
  Set<String>? dirs,
) {
  if (pref.kind == 'smart' && request.identityKind == null) {
    return '这条种子没解析出条目身份，用不了记住的「智能入库」，请确认是哪部作品。';
  }
  if (pref.downloaderId != null && pref.downloaderName == null) {
    return '上次使用的下载器已不可用，请重新选择保存位置。';
  }
  if (isStaleDir(pref, dirs)) {
    return '上次的保存位置 ${pref.savePath ?? ''} 已不存在，请重新选择。';
  }
  return null;
}

/// 下载器可选目录集合（判断记忆是否失效；null = 拉不到下载器，宁可不判失效）。
Set<String>? downloaderDirs(List<DownloaderView>? downloaders) {
  if (downloaders == null) return null;
  final out = <String>{};
  for (final d in downloaders.where((d) => d.usable)) {
    final savePath = d.savePath;
    if (savePath != null) out.add(trimPath(savePath));
    for (final m in d.pathMappings ?? const <PathMapping>[]) {
      out.add(trimPath(m.local));
    }
  }
  return out;
}

// —— 流式搜索事件载荷（`GET /search/torrents/stream` 的 SSE 事件）——

/// 一个站点的结果块（`start` 事件建空块，`site_result`/`site_error` 合并）。
class SiteBlock {
  const SiteBlock({
    required this.siteId,
    required this.siteName,
    this.items = const [],
    this.error,
    this.elapsedMs = 0,
  });

  final String siteId;
  final String siteName;
  final List<TorrentHit> items;
  final String? error;
  final int elapsedMs;

  SiteBlock copyWith({
    List<TorrentHit>? items,
    String? error,
    int? elapsedMs,
  }) =>
      SiteBlock(
        siteId: siteId,
        siteName: siteName,
        items: items ?? this.items,
        error: error ?? this.error,
        elapsedMs: elapsedMs ?? this.elapsedMs,
      );

  /// 把 `site_result` 合并进块（同站多次结果追加，不覆盖旧条目）。
  SiteBlock mergeResult(SiteStreamResult result) => copyWith(
        items: [...items, ...result.items],
        elapsedMs: result.elapsedMs,
      );
}

class SearchStreamStart {
  const SearchStreamStart({
    this.keyword = '',
    this.label,
    this.categories = const [],
    this.sites = const [],
  });

  factory SearchStreamStart.fromJson(Map<String, dynamic> j) =>
      SearchStreamStart(
        keyword: (j['keyword'] ?? '').toString(),
        label: j['label']?.toString(),
        categories: [
          for (final c in (j['categories'] as List? ?? const [])) c.toString()
        ],
        sites: [
          for (final s in (j['sites'] as List? ?? const []))
            if (s is Map)
              (siteId: (s['site_id'] ?? '').toString(), siteName: (s['site_name'] ?? '').toString())
        ],
      );

  final String keyword;
  final String? label;
  final List<String> categories;

  /// (siteId, siteName) —— `start` 事件建空块用。
  final List<({String siteId, String siteName})> sites;
}

class SiteStreamResult {
  const SiteStreamResult({
    this.siteId = '',
    this.siteName = '',
    this.count = 0,
    this.elapsedMs = 0,
    this.items = const [],
  });

  factory SiteStreamResult.fromJson(Map<String, dynamic> j) =>
      SiteStreamResult(
        siteId: (j['site_id'] ?? '').toString(),
        siteName: (j['site_name'] ?? '').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
        elapsedMs: (j['elapsed_ms'] as num?)?.toInt() ?? 0,
        items: [
          for (final it in (j['items'] as List? ?? const []))
            if (it is Map) TorrentHit.fromJson(it.cast<String, dynamic>())
        ],
      );

  final String siteId;
  final String siteName;
  final int count;
  final int elapsedMs;
  final List<TorrentHit> items;
}

class SiteStreamError {
  const SiteStreamError({
    this.siteId = '',
    this.siteName = '',
    this.error = '',
    this.elapsedMs = 0,
  });

  factory SiteStreamError.fromJson(Map<String, dynamic> j) => SiteStreamError(
        siteId: (j['site_id'] ?? '').toString(),
        siteName: (j['site_name'] ?? '').toString(),
        error: (j['error'] ?? '').toString(),
        elapsedMs: (j['elapsed_ms'] as num?)?.toInt() ?? 0,
      );

  final String siteId;
  final String siteName;
  final String error;
  final int elapsedMs;
}

class SearchStreamDone {
  const SearchStreamDone({
    this.total = 0,
    this.elapsedMs = 0,
  });

  factory SearchStreamDone.fromJson(Map<String, dynamic> j) =>
      SearchStreamDone(
        total: (j['total'] as num?)?.toInt() ?? 0,
        elapsedMs: (j['elapsed_ms'] as num?)?.toInt() ?? 0,
      );

  final int total;
  final int elapsedMs;
}

/// 「选择保存位置」弹窗的整套状态（安卓 `DownloadFlow` 的 Dart 移植）。
/// [request] 为 null = 弹层关着；有保存位置记忆时先走 [confirmOnly] 的
/// 确认条，用户点「更改 / 不再记住」才进完整弹窗。
class DownloadFlow {
  const DownloadFlow({
    this.request,
    this.remembered,
    this.confirmOnly = false,
    this.target,
    this.candidates = const [],
    this.selectedCandidate,
    this.picking = false,
    this.hint,
    this.hintDraft = '',
    this.showOther = false,
    this.downloaders = const [],
    this.dirs,
    this.memberLibraries = const [],
    this.memberLibrariesLoaded = false,
    this.downloaderId,
    this.selected,
    this.remember = false,
    this.loadingTarget = false,
    this.loadingDownloaders = false,
    this.busy = false,
    this.error,
  });

  final DownloadTargetRequest? request;
  final DownloadTargetPrefView? remembered;
  final bool confirmOnly;
  final ManualDownloadTargetView? target;
  final List<ManualDownloadCandidateView> candidates;
  final ManualDownloadCandidateView? selectedCandidate;

  /// 「这是哪部作品？」确认模式：自动识别没收敛（或种子没身份）时常驻候选与搜索框。
  final bool picking;
  final String? hint;
  final String hintDraft;
  final bool showOther;
  final List<DownloaderView> downloaders;
  final Set<String>? dirs;
  final List<LibraryView> memberLibraries;
  final bool memberLibrariesLoaded;
  final int? downloaderId;
  final String? selected;
  final bool remember;
  final bool loadingTarget;
  final bool loadingDownloaders;
  final bool busy;
  final String? error;

  bool get isOpen => request != null;

  DownloadFlow copyWith({
    DownloadTargetRequest? request,
    DownloadTargetPrefView? remembered,
    bool? confirmOnly,
    ManualDownloadTargetView? target,
    List<ManualDownloadCandidateView>? candidates,
    ManualDownloadCandidateView? selectedCandidate,
    bool? picking,
    String? hint,
    String? hintDraft,
    bool? showOther,
    List<DownloaderView>? downloaders,
    Set<String>? dirs,
    List<LibraryView>? memberLibraries,
    bool? memberLibrariesLoaded,
    int? downloaderId,
    String? selected,
    bool? remember,
    bool? loadingTarget,
    bool? loadingDownloaders,
    bool? busy,
    String? error,
    bool clearRequest = false,
    bool clearTarget = false,
    bool clearSelectedCandidate = false,
    bool clearError = false,
  }) =>
      DownloadFlow(
        request: clearRequest ? null : (request ?? this.request),
        remembered: remembered ?? this.remembered,
        confirmOnly: confirmOnly ?? this.confirmOnly,
        target: clearTarget ? null : (target ?? this.target),
        candidates: candidates ?? this.candidates,
        selectedCandidate: clearSelectedCandidate
            ? null
            : (selectedCandidate ?? this.selectedCandidate),
        picking: picking ?? this.picking,
        hint: hint ?? this.hint,
        hintDraft: hintDraft ?? this.hintDraft,
        showOther: showOther ?? this.showOther,
        downloaders: downloaders ?? this.downloaders,
        dirs: dirs ?? this.dirs,
        memberLibraries: memberLibraries ?? this.memberLibraries,
        memberLibrariesLoaded:
            memberLibrariesLoaded ?? this.memberLibrariesLoaded,
        downloaderId: downloaderId ?? this.downloaderId,
        selected: selected ?? this.selected,
        remember: remember ?? this.remember,
        loadingTarget: loadingTarget ?? this.loadingTarget,
        loadingDownloaders: loadingDownloaders ?? this.loadingDownloaders,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );
}
