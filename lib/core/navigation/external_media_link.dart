import 'package:url_launcher/url_launcher.dart';

/// 外部媒体词条跳转工具（1:1 对齐 iOS `MovieClaw/App/Routing/ExternalMediaLink.swift`）。
///
/// 遇到豆瓣电影/剧集词条地址时，优先尝试唤起豆瓣 App（`douban://douban.com/movie/<id>`），
/// 未安装或唤起失败时回落到系统外部浏览器打开原网页；其他站点直接交给系统处理。
abstract final class ExternalMediaLink {
  static const _doubanHosts = <String>{
    'movie.douban.com',
    'm.douban.com',
    'www.douban.com',
    'douban.com',
  };

  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  /// 解析豆瓣词条网页链接对应的 App Scheme URI；非豆瓣词条返回 `null`。
  static Uri? doubanAppUri(Uri url) {
    final scheme = url.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    if (!_doubanHosts.contains(url.host.toLowerCase())) return null;

    final parts = url.pathSegments.where((s) => s.isNotEmpty).toList();
    String? id;
    if (parts.length == 2 && parts[0] == 'subject') {
      id = parts[1];
    } else if (parts.length == 3 &&
        parts[0] == 'movie' &&
        parts[1] == 'subject') {
      id = parts[2];
    }
    if (id == null || !_digitsOnly.hasMatch(id)) return null;
    // 豆瓣电影、电视剧词条共用 movie 路径。
    return Uri.parse('douban://douban.com/movie/$id');
  }

  /// 打开外部媒体链接（字符串入口）。
  static Future<bool> open(
    String rawUrl, {
    Future<bool> Function(Uri uri)? launcher,
  }) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return false;
    return openUri(uri, launcher: launcher);
  }

  /// 打开外部媒体链接（URI 入口）。
  static Future<bool> openUri(
    Uri uri, {
    Future<bool> Function(Uri uri)? launcher,
  }) async {
    final opener = launcher ??
        (Uri target) => launchUrl(target, mode: LaunchMode.externalApplication);

    final doubanApp = doubanAppUri(uri);
    if (doubanApp != null) {
      try {
        if (await opener(doubanApp)) return true;
      } catch (_) {}
    }
    try {
      return await opener(uri);
    } catch (_) {
      return false;
    }
  }
}

/// 站内路径解析结果（附带目标 `GoRouter` 地址与主壳页签索引）。
class ResolvedWebPath {
  const ResolvedWebPath({
    required this.location,
    this.tabIndex,
    this.query = const {},
  });

  /// 可直接传给 `GoRouter.go` / `GoRouter.push` 的路径。
  final String location;

  /// 若落点属于主壳一级页签，标明其索引：0=媒体库 / 1=订阅 / 2=发现 / 3=活动 / 4=我的。
  final int? tabIndex;

  /// 解析后的查询参数快照。
  final Map<String, String> query;
}

/// MovieClaw 站内 Web 路径 → Flutter `GoRouter` 路径解析器。
///
/// 全量覆盖上游 `AppRoute.init?(webPath:)` 全部 30+ 站内路由及旧地址重定向：
/// 通知跳转、推送 `open` 路径、AI 卡片链接、二维码与外部深链均统一走此处。
abstract final class AppWebPathResolver {
  static const _mediaKinds = <String>{'movie', 'tv', 'video'};
  static const _webScopeKeys = <String>{
    'label',
    'cats',
    'sites',
    'poster',
    'private',
    'browse',
  };

  /// 将 Web 站内路径解析为 Flutter `GoRouter` 地址；无法识别返回 `null`。
  static String? resolve(String webPath) => resolveDetailed(webPath)?.location;

  /// 解析并返回结构化路由信息（包含一级页签索引）。
  static ResolvedWebPath? resolveDetailed(String webPath) {
    final trimmed = webPath.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('//') || trimmed.contains('\\')) return null;

    Uri? uri;
    if (trimmed.startsWith('/')) {
      uri = Uri.tryParse(trimmed);
    } else if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      uri = Uri.tryParse(trimmed);
    } else if (!trimmed.contains('://')) {
      uri = Uri.tryParse('/$trimmed');
    } else {
      return null;
    }
    if (uri == null) return null;

    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final query = Map<String, String>.from(uri.queryParameters);

    if (parts.isEmpty) {
      return const ResolvedWebPath(location: '/home', tabIndex: 2);
    }

    switch (parts.first) {
      // ── 发现 ──
      case 'discover':
        if (parts.length >= 3 &&
            parts[1] == 'people' &&
            _isInt(parts[2])) {
          return ResolvedWebPath(
            location: _withQuery('/discover/person', {'id': parts[2]}),
            tabIndex: 2,
            query: {'id': parts[2]},
          );
        }
        if (parts.length >= 5 && parts[2] == 'collections') {
          final q = {
            'tab': 'discover',
            'kind': parts[1],
            'provider': parts[3],
            'collection': parts[4],
            ...query,
          };
          return ResolvedWebPath(
            location: _withQuery('/home', q),
            tabIndex: 2,
            query: q,
          );
        }
        if (parts.length == 3 && parts[1] == 'movie' && parts[2] == 'top250') {
          final q = {
            'tab': 'discover',
            'kind': 'movie',
            'provider': 'douban',
            'collection': 'movie_top250',
            ...query,
          };
          return ResolvedWebPath(
            location: _withQuery('/home', q),
            tabIndex: 2,
            query: q,
          );
        }
        if (parts.length == 3 &&
            parts[1] == 'movie' &&
            parts[2] == 'high-score') {
          final q = {
            'tab': 'discover',
            'kind': 'movie',
            'provider': 'douban',
            'collection': 'movie_high_score',
            ...query,
          };
          return ResolvedWebPath(
            location: _withQuery('/home', q),
            tabIndex: 2,
            query: q,
          );
        }
        final kind = parts.length > 1 ? parts[1] : 'movie';
        final q = {'tab': 'discover', 'kind': kind, ...query};
        return ResolvedWebPath(
          location: _withQuery('/home', q),
          tabIndex: 2,
          query: q,
        );

      // ── 发现条目详情：/media/{movie|tv|douban}/{id} 或 /media/{provider}/{type}/{id} ──
      case 'media':
        if (parts.length < 3) return null;
        final String titleRef;
        if (parts.length >= 4) {
          titleRef = '${parts[1]}:${parts[2]}:${parts[3]}';
        } else if (parts[1] == 'douban') {
          titleRef = 'douban:${parts[2]}';
        } else if (parts[1] == 'movie' || parts[1] == 'tv') {
          titleRef = 'tmdb:${parts[1]}:${parts[2]}';
        } else {
          titleRef = '${parts[1]}:${parts[2]}';
        }
        final q = {'ref': titleRef};
        return ResolvedWebPath(
          location: _withQuery('/discover/title', q),
          tabIndex: 2,
          query: q,
        );

      // ── 库内影人：/people/{id} ──
      case 'people':
        if (parts.length < 2 || !_isInt(parts[1])) return null;
        return ResolvedWebPath(
          location: _withQuery('/library/person/${parts[1]}', query),
          tabIndex: 0,
          query: query,
        );

      // ── 媒体库 ──
      case 'library':
        if (parts.length == 1) {
          return const ResolvedWebPath(
            location: '/home?tab=library',
            tabIndex: 0,
            query: {'tab': 'library'},
          );
        }
        switch (parts[1]) {
          case 'customize':
            return const ResolvedWebPath(
              location: '/library/customize',
              tabIndex: 0,
            );
          case 'favorites':
            return const ResolvedWebPath(
              location: '/library/favorites',
              tabIndex: 0,
            );
          case 'reels':
            return const ResolvedWebPath(location: '/reels', tabIndex: 0);
          case 'collections':
            return const ResolvedWebPath(
              location: '/library/collections',
              tabIndex: 0,
            );
          case 'kind':
            if (parts.length < 3 || !_mediaKinds.contains(parts[2])) {
              return null;
            }
            final q = <String, String>{
              if ((query['g'] ?? '').isNotEmpty) 'g': query['g']!,
            };
            return ResolvedWebPath(
              location: _withQuery('/library/kind/${parts[2]}', q),
              tabIndex: 0,
              query: q,
            );
          case 'manage':
            final q = <String, String>{
              if (query['create'] == '1') 'create': '1',
              if ((query['tab'] ?? '').isNotEmpty) 'tab': query['tab']!,
              if (_isInt(query['item'])) 'item': query['item']!,
            };
            return ResolvedWebPath(
              location: _withQuery('/library/manage', q),
              tabIndex: 0,
              query: q,
            );
          case 'c':
            if (parts.length < 3 || !_isInt(parts[2])) return null;
            return ResolvedWebPath(
              location: '/library/collection/${parts[2]}',
              tabIndex: 0,
            );
          default:
            if (!_isInt(parts[1])) return null;
            final libId = parts[1];
            if (parts.length >= 4 &&
                parts[2] == 'item' &&
                _isInt(parts[3])) {
              final q = <String, String>{
                if (_isInt(query['season'])) 'season': query['season']!,
                if (_isInt(query['episode'])) 'episode': query['episode']!,
              };
              return ResolvedWebPath(
                location: _withQuery('/detail/$libId/${parts[3]}', q),
                tabIndex: 0,
                query: q,
              );
            }
            if (parts.length >= 4 && parts[2] == 'c' && _isInt(parts[3])) {
              final q = {'library_id': libId};
              return ResolvedWebPath(
                location: _withQuery('/library/collection/${parts[3]}', q),
                tabIndex: 0,
                query: q,
              );
            }
            final q = <String, String>{
              if ((query['view'] ?? '').isNotEmpty) 'view': query['view']!,
              if (query['pending'] == '1') 'pending': '1',
              if ((query['actor'] ?? '').trim().isNotEmpty)
                'actor': query['actor']!.trim(),
            };
            return ResolvedWebPath(
              location: _withQuery('/library/detail/$libId', q),
              tabIndex: 0,
              query: q,
            );
        }

      // ── 片段直达 ──
      case 'reels':
        return const ResolvedWebPath(location: '/reels', tabIndex: 0);

      // ── 搜索 ──
      case 'search':
        final q = <String, String>{};
        if ((query['q'] ?? '').isNotEmpty) q['q'] = query['q']!;
        if ((query['tab'] ?? '').isNotEmpty) q['tab'] = query['tab']!;
        if ((query['snapshot'] ?? '').isNotEmpty) {
          q['snapshot'] = query['snapshot']!;
        }
        if ((query['for_sub'] ?? '').isNotEmpty) {
          q['for_sub'] = query['for_sub']!;
        }
        if ((query['scope'] ?? '').isNotEmpty) {
          q['scope'] = query['scope']!;
        } else {
          final scopeParts = <String>[];
          for (final entry in query.entries) {
            if (_webScopeKeys.contains(entry.key) && entry.value.isNotEmpty) {
              scopeParts.add('${entry.key}=${entry.value}');
            }
          }
          if (scopeParts.isNotEmpty) q['scope'] = scopeParts.join('&');
        }
        return ResolvedWebPath(
          location: _withQuery('/search', q),
          query: q,
        );

      // ── 订阅 ──
      case 'subscriptions':
        if (parts.length >= 2 && _isInt(parts[1])) {
          final q = <String, String>{
            if (query['upgrade-run'] == '1') 'upgrade-run': '1',
          };
          return ResolvedWebPath(
            location: _withQuery('/subscriptions/detail/${parts[1]}', q),
            tabIndex: 1,
            query: q,
          );
        }
        if (parts.length >= 2 && parts[1] == 'wall') {
          if (parts.length >= 3 && _isInt(parts[2])) {
            return ResolvedWebPath(
              location: '/subscriptions/wall/${parts[2]}',
              tabIndex: 1,
            );
          }
          return ResolvedWebPath(
            location: _withQuery('/subscriptions/wall', query),
            tabIndex: 1,
            query: query,
          );
        }
        return const ResolvedWebPath(
          location: '/home?tab=subscriptions',
          tabIndex: 1,
          query: {'tab': 'subscriptions'},
        );

      // ── 活动 / 任务（含旧路径 /tasks） ──
      case 'activity':
      case 'tasks':
        final q = <String, String>{
          'tab': 'activity',
          if ((query['view'] ?? '').isNotEmpty) 'view': query['view']!,
        };
        return ResolvedWebPath(
          location: _withQuery('/home', q),
          tabIndex: 3,
          query: q,
        );

      // ── 通知 ──
      case 'notices':
        return ResolvedWebPath(
          location: _withQuery('/notices', query),
          query: query,
        );

      // ── AI 会话 ──
      case 'new':
        return const ResolvedWebPath(location: '/agent/new');
      case 'sessions':
        if (parts.length >= 2) {
          return ResolvedWebPath(
            location: '/agent/session/${Uri.encodeComponent(parts[1])}',
          );
        }
        return const ResolvedWebPath(location: '/agent');
      case 'agent':
        if (parts.length >= 3 &&
            (parts[1] == 'sessions' || parts[1] == 'session')) {
          return ResolvedWebPath(
            location: '/agent/session/${Uri.encodeComponent(parts[2])}',
          );
        }
        if (parts.length >= 2 && parts[1] == 'new') {
          return const ResolvedWebPath(location: '/agent/new');
        }
        return const ResolvedWebPath(location: '/agent');

      // ── 我的 / 离线下载 ──
      case 'my':
        if (parts.length >= 2 && parts[1] == 'downloads') {
          return const ResolvedWebPath(location: '/offline', tabIndex: 4);
        }
        return const ResolvedWebPath(
          location: '/home?tab=more',
          tabIndex: 4,
          query: {'tab': 'more'},
        );
      case 'offline':
        return const ResolvedWebPath(location: '/offline', tabIndex: 4);

      // ── 批准设备登录：/activate?code=… ──
      case 'activate':
        final q = <String, String>{
          if ((query['code'] ?? '').isNotEmpty) 'code': query['code']!,
        };
        return ResolvedWebPath(
          location: _withQuery('/settings/devices', q),
          query: q,
        );

      // ── 账号与更新 ──
      case 'account':
        if (parts.length >= 2 && parts[1] == 'devices') {
          return ResolvedWebPath(
            location: _withQuery('/account/devices', query),
            query: query,
          );
        }
        return const ResolvedWebPath(location: '/account');
      case 'update':
        return const ResolvedWebPath(location: '/update');

      // ── 设置分区（全量映射含旧路径重定向） ──
      case 'settings':
        if (parts.length < 2) {
          return const ResolvedWebPath(location: '/settings');
        }
        final section = parts[1];
        switch (section) {
          case 'profile':
            return ResolvedWebPath(
              location: _withQuery('/settings/profile', query),
              query: query,
            );
          case 'devices':
            return ResolvedWebPath(
              location: _withQuery('/settings/devices', query),
              query: query,
            );
          case 'notifications':
            return ResolvedWebPath(
              location: _withQuery('/settings/notifications', query),
              query: query,
            );
          case 'language':
            return ResolvedWebPath(
              location: _withQuery('/settings/language', query),
              query: query,
            );
          case 'about':
            return ResolvedWebPath(
              location: _withQuery('/settings/about', query),
              query: query,
            );
          case 'cloud':
            return ResolvedWebPath(
              location: _withQuery('/settings/cloud', query),
              query: query,
            );
          case 'overview':
            return ResolvedWebPath(
              location: _withQuery('/settings/overview', query),
              query: query,
            );
          case 'members':
            return ResolvedWebPath(
              location: _withQuery('/settings/members', query),
              query: query,
            );
          case 'subscription':
          case 'rules':
            return ResolvedWebPath(
              location: _withQuery('/settings/rules', query),
              query: query,
            );
          case 'sites':
          case 'search':
            return ResolvedWebPath(
              location: _withQuery('/settings/sites', query),
              query: query,
            );
          case 'downloaders':
            return ResolvedWebPath(
              location: _withQuery('/settings/downloaders', query),
              query: query,
            );
          case 'import-watch':
          case 'scrape':
            final q = {'section': section, ...query};
            return ResolvedWebPath(
              location: _withQuery('/settings/scrape', q),
              query: q,
            );
          case 'playback':
            return ResolvedWebPath(
              location: _withQuery('/settings/playback', query),
              query: query,
            );
          case 'app':
            if (query['tab'] == 'remote') {
              return ResolvedWebPath(
                location: _withQuery('/settings/playback', query),
                query: query,
              );
            }
            final q = {'section': 'app', ...query};
            return ResolvedWebPath(
              location: _withQuery('/settings/maintenance', q),
              query: q,
            );
          case 'maintenance':
            return ResolvedWebPath(
              location: _withQuery('/settings/maintenance', query),
              query: query,
            );
          case 'app-push':
          case 'im-push':
          case 'push':
            return ResolvedWebPath(
              location: _withQuery('/settings/push', query),
              query: query,
            );
          case 'webhook':
            return ResolvedWebPath(
              location: _withQuery('/settings/webhook', query),
              query: query,
            );
          case 'mcp':
            return ResolvedWebPath(
              location: _withQuery('/settings/mcp', query),
              query: query,
            );
          case 'llm':
          case 'ai':
            final q = {'section': section, ...query};
            return ResolvedWebPath(
              location: _withQuery('/settings/ai', q),
              query: q,
            );
          case 'network':
          case 'logs':
          case 'system':
            final q = {'section': section, ...query};
            return ResolvedWebPath(
              location: _withQuery('/settings/system', q),
              query: q,
            );
          case 'appearance':
            return const ResolvedWebPath(location: '/settings');
          default:
            return const ResolvedWebPath(location: '/settings');
        }

      // ── 访客分享：/s/{slug} 及 /s/{slug}/play/... ──
      case 's':
      case 'share':
        if (parts.length < 2) return null;
        final slug = parts[1];
        final q = <String, String>{...query};
        if (parts.length >= 3 && parts[2] == 'play') {
          q['play'] = '1';
          if (parts.length >= 4) {
            q['target'] = parts.sublist(3).join('/');
          }
        }
        return ResolvedWebPath(
          location: _withQuery('/share/${Uri.encodeComponent(slug)}', q),
          query: q,
        );

      default:
        return null;
    }
  }

  static bool _isInt(String? s) => s != null && int.tryParse(s) != null;

  static String _withQuery(String basePath, Map<String, String> query) {
    if (query.isEmpty) return basePath;
    return Uri(path: basePath, queryParameters: query).toString();
  }
}
