import 'package:flutter_test/flutter_test.dart';

import 'package:mc_flutter/features/agent/state/media_cards.dart';
import 'package:mc_flutter/features/settings/state/raw_models.dart';

void main() {
  group('parseMediaCardsArgs', () {
    test('title component with title_ref', () {
      final group = parseMediaCardsArgs('show_media_cards_v1',
          '{"component":"title","title":"你可能会喜欢","items":[{"title_ref":"tmdb:movie:123"},{"tmdb_id":456,"media_type":"tv"}]}');
      expect(group, isNotNull);
      expect(group!.component, 'title');
      expect(group.title, '你可能会喜欢');
      expect(group.cards.length, 2);
      expect(group.cards[0].titleRef, 'tmdb:movie:123');
      expect(group.cards[1].titleRef, 'tmdb:tv:456');
    });

    test('library_item with season/episode pair', () {
      final group = parseMediaCardsArgs('show_media_cards_v1',
          '{"component":"library_item","items":[{"media_item_id":7,"season_number":2,"episode_number":3}]}');
      expect(group!.cards.single.kind, 'library_item');
      expect(group.cards.single.mediaItemId, 7);
      expect(group.cards.single.seasonNumber, 2);
      expect(group.cards.single.episodeNumber, 3);
    });

    test('half season/episode falls back to whole title', () {
      final group = parseMediaCardsArgs('show_media_cards_v1',
          '{"component":"library_item","items":[{"media_item_id":7,"season_number":2}]}');
      expect(group!.cards.single.episodeNumber, isNull);
      expect(group.cards.single.seasonNumber, isNull);
    });

    test('subscription and library kinds', () {
      final sub = parseMediaCardsArgs('show_media_cards_v1',
          '{"component":"subscription","items":[{"subscription_id":9}]}');
      expect(sub!.cards.single.subscriptionId, 9);
      final lib = parseMediaCardsArgs('show_media_cards_v1',
          '{"component":"library","items":[{"library_id":4}]}');
      expect(lib!.cards.single.libraryId, 4);
    });

    test('unknown tool, bad json, invalid items return null', () {
      expect(
          parseMediaCardsArgs('other_tool', '{"component":"title"}'), isNull);
      expect(parseMediaCardsArgs('show_media_cards_v1', 'not json'), isNull);
      expect(
          parseMediaCardsArgs('show_media_cards_v1',
              '{"component":"title","items":[{"title_ref":"bogus"}]}'),
          isNull);
      expect(
          parseMediaCardsArgs('show_media_cards_v1',
              '{"component":"nope","items":[]}'),
          isNull);
    });

    test('duplicate cards are deduped', () {
      final group = parseMediaCardsArgs('show_media_cards_v1',
          '{"component":"title","items":[{"title_ref":"tmdb:movie:1"},{"title_ref":"tmdb:movie:1"}]}');
      expect(group!.cards.length, 1);
    });
  });

  group('raw models', () {
    test('PluginInfo parses web shape', () {
      final p = PluginInfo.fromJson({
        'id': 'core',
        'title': '核心',
        'state': 'active',
        'critical': true,
        'switchable': true,
        'blocked_by': [
          {'key': 'svc', 'reason': '缺服务'},
        ],
      });
      expect(p.active, isTrue);
      expect(p.canToggle, isTrue);
      expect(p.stateLabel, '运行中');
      expect(p.blockedReasons, ['缺服务']);
    });

    test('PluginsOverview parses safe mode', () {
      final o = PluginsOverview.fromJson({
        'plugins': [],
        'safe_mode': {'active': true, 'reason': '上次崩溃'},
      });
      expect(o.safeModeActive, isTrue);
      expect(o.safeModeReason, '上次崩溃');
    });

    test('DriveAccount parses web shape', () {
      final a = DriveAccount.fromJson({
        'id': 3,
        'backend': 'aliyun',
        'backend_title': '阿里云盘',
        'name': '我的盘',
        'status': 'auth_expired',
        'quota_total': 1000,
        'quota_used': 250,
        'used_today': 5,
      });
      expect(a.statusLabel, '登录过期');
      expect(a.quotaTotal, 1000);
    });

    test('SyncTokenView parses web shape', () {
      final t = SyncTokenView.fromJson({
        'enabled': true,
        'token': 'secret',
        'created_at': '2026-01-01',
      });
      expect(t.enabled, isTrue);
      expect(t.token, 'secret');
    });

    test('DriveSettings round-trips', () {
      const s = DriveSettings(removeDownloadTasks: true);
      expect(DriveSettings.fromJson(s.toJson()).removeDownloadTasks, isTrue);
    });
  });
}
