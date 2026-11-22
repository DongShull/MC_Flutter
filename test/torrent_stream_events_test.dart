// P2：种子搜索 SSE 事件解析（`SearchStreamStart` / `SiteStreamResult` /
// `SiteStreamError` / `SearchStreamDone`，`GET /api/v1/search/torrents/stream`）。
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/features/search/state/torrent_models.dart';

void main() {
  test('start 事件：关键词 + 分类 + 站点列表', () {
    final e = SearchStreamStart.fromJson({
      'keyword': 'dune',
      'label': '沙丘',
      'categories': ['movie'],
      'sites': [
        {'site_id': 's1', 'site_name': '站点一'},
      ],
    });
    expect(e.keyword, 'dune');
    expect(e.label, '沙丘');
    expect(e.categories, ['movie']);
    expect(e.sites, [(siteId: 's1', siteName: '站点一')]);
  });

  test('site_result 事件：命中列表按 snake_case 解析', () {
    final e = SiteStreamResult.fromJson({
      'site_id': 's1',
      'site_name': '站点一',
      'count': 2,
      'elapsed_ms': 120,
      'items': [
        {
          'torrent_id': 't1',
          'title': 'Dune 2021',
          'size_bytes': 1024,
          'seeders': 5,
          'site_id': 's1',
        },
        {'torrent_id': 't2', 'title': 'Dune Part Two', 'site_id': 's1'},
      ],
    });
    expect(e.count, 2);
    expect(e.elapsedMs, 120);
    expect(e.items.length, 2);
    expect(e.items.first.title, 'Dune 2021');
    expect(e.items.first.sizeBytes, 1024);
    expect(hitKey(e.items.first), 's1:t1');
  });

  test('site_error 事件：站点失败不影响其他站点', () {
    final e = SiteStreamError.fromJson({
      'site_id': 's2',
      'site_name': '站点二',
      'error': 'timeout',
      'elapsed_ms': 3000,
    });
    expect(e.siteId, 's2');
    expect(e.error, 'timeout');
  });

  test('done 事件：总数 + 耗时', () {
    final e = SearchStreamDone.fromJson({'total': 7, 'elapsed_ms': 450});
    expect(e.total, 7);
    expect(e.elapsedMs, 450);
  });

  test('缺失字段容错：空 JSON 不抛错', () {
    expect(SearchStreamStart.fromJson({}).keyword, '');
    expect(SiteStreamResult.fromJson({}).items, isEmpty);
    expect(SearchStreamDone.fromJson({}).total, 0);
  });
}
