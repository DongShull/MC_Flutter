// P2 种子搜索下载目标：纯函数单测（对照安卓 DownloadTarget.kt）。
import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/core/api/models.dart';
import 'package:mc_flutter/features/search/state/torrent_models.dart';

Map<String, dynamic> hitJson({
  String downloadUrl = 'magnet:?xt=urn:btih:abc',
  Map<String, dynamic>? attrs,
}) =>
    {
      'torrent_id': 't1',
      'title': 'Test Movie 2024 1080p',
      'subtitle': 'sub',
      'category': 'movie',
      'size': '1.5 GB',
      'size_bytes': 1500000000,
      'seeders': 10,
      'leechers': 2,
      'site_id': 'site-a',
      'site_name': '站点 A',
      'download_url': downloadUrl,
      if (attrs != null) 'attrs': attrs,
    };

void main() {
  test('TorrentHit 解析与行键', () {
    final hit = TorrentHit.fromJson(hitJson());
    expect(hit.title, 'Test Movie 2024 1080p');
    expect(hitKey(hit), 'site-a:t1');
    expect(hit.sizeBytes, 1500000000);
    expect(hit.seeders, 10);
  });

  test('DownloadTargetRequest.of：身份三件套齐全才采信', () {
    final identified = TorrentHit.fromJson(hitJson(attrs: {
      'media_type': 'movie',
      'titles_zh': ['测试影片'],
      'year': 2024,
    }));
    final req = DownloadTargetRequest.of(identified, '测试影片');
    expect(req, isNotNull);
    expect(req!.identityKind, 'movie');
    expect(req.identityTitle, '测试影片');
    expect(req.identityYear, 2024);
    expect(req.hint, '测试影片');

    final unknown = TorrentHit.fromJson(hitJson(attrs: {
      'media_type': 'movie',
      'titles_zh': ['测试影片'],
      // 缺年份 → 身份不采信
    }));
    final req2 = DownloadTargetRequest.of(unknown, '测试影片');
    expect(req2!.identityKind, isNull);
    expect(req2.identityTitle, isNull);
  });

  test('DownloadTargetRequest.of：无下载链接返回 null', () {
    final hit = TorrentHit.fromJson(hitJson(downloadUrl: ''));
    expect(DownloadTargetRequest.of(hit, 'x'), isNull);
  });

  test('computeTargetOptions 成员版：类型匹配的库在前 + 默认兜底', () {
    const req = DownloadTargetRequest(
      siteId: 'site-a',
      downloadUrl: 'magnet:?xt=urn:btih:abc',
      identityKind: 'tv',
      category: 'tv',
      hitKey: 'site-a:t1',
    );
    final options = computeTargetOptions(
      isAdmin: false,
      target: null,
      showOther: false,
      downloader: null,
      memberLibraries: const [
        LibraryView(id: 1, name: '电影库', kind: 'movie'),
        LibraryView(id: 2, name: '剧集库', kind: 'tv'),
      ],
      request: req,
    );
    expect(options.map((o) => o.id).toList(),
        ['library:2', 'library:1', 'default']);
    expect(options.first.kind, TargetOptionKind.library);
    expect(options.last.kind, TargetOptionKind.fallback);
  });

  test('computeTargetOptions 管理员版：智能入库 + 目录 + 默认', () {
    const req = DownloadTargetRequest(
      siteId: 'site-a',
      downloadUrl: 'magnet:?xt=urn:btih:abc',
      identityKind: 'movie',
      identityTitle: '测试影片',
      identityYear: 2024,
      category: 'movie',
      hitKey: 'site-a:t1',
    );
    final options = computeTargetOptions(
      isAdmin: true,
      target: const ManualDownloadTargetView(
        status: 'ready',
        tmdbId: 123,
        kind: 'movie',
        title: '测试影片',
        year: 2024,
        libraryId: 1,
        libraryName: '电影库',
        mode: 'inplace',
        path: '/data/movies',
        ok: true,
      ),
      showOther: true,
      downloader: const DownloaderView(
        id: 1,
        name: 'qBittorrent',
        savePath: '/downloads',
        usable: true,
        isDefault: true,
      ),
      memberLibraries: const [],
      request: req,
    );
    expect(options.first.id, 'smart');
    expect(options.first.kind, TargetOptionKind.smart);
    expect(options.any((o) => o.kind == TargetOptionKind.dir), isTrue);
    expect(options.last.id, 'default');
  });

  test('rememberedPrefIssue：智能入库记忆遇无身份种子要回落', () {
    const pref = DownloadTargetPrefView(
      category: 'movie',
      kind: 'smart',
    );
    const req = DownloadTargetRequest(
      siteId: 'site-a',
      downloadUrl: 'magnet:?xt=urn:btih:abc',
      category: 'movie',
      hitKey: 'site-a:t1',
    );
    expect(rememberedPrefIssue(pref, req, null), isNotNull);
  });

  test('SiteBlock.mergeResult：同站结果追加不覆盖', () {
    const block = SiteBlock(siteId: 'site-a', siteName: '站点 A');
    final result = SiteStreamResult.fromJson({
      'site_id': 'site-a',
      'site_name': '站点 A',
      'count': 1,
      'elapsed_ms': 120,
      'items': [hitJson()],
    });
    final merged = block.mergeResult(result);
    expect(merged.items.length, 1);
    expect(merged.items.first.title, 'Test Movie 2024 1080p');
    expect(merged.elapsedMs, 120);
  });
}
