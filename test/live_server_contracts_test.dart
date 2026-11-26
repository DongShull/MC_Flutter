import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/models/format.dart';
import 'package:mc_flutter/core/player/session/playback_session_api.dart';
import 'package:mc_flutter/features/agent/state/models.dart';
import 'package:mc_flutter/features/detail/state/detail_controller.dart';

void main() {
  group('MovieClaw v0.52.0 实盘契约与格式化回归测试', () {
    test('mcFormatBytes 严格按 1024 阶梯换算，不放大 1024 倍', () {
      expect(mcFormatBytes(512), '512 B');
      expect(mcFormatBytes(1024), '1.0 KB');
      expect(mcFormatBytes(1024 * 1024), '1.0 MB');
      expect(mcFormatBytes(1024 * 1024 * 1024), '1.0 GB');
      expect(mcFormatBytes(1450 * 1024 * 1024 * 1024), '1.4 TB');
    });

    test('PlaybackSession.fromJson 解析 source/decision/watch/chapters 真实响应', () {
      final session = PlaybackSession.fromJson({
        'session_id': 'sess-live-01',
        'stream_url': 'http://192.168.50.4:13000/api/v1/playback/direct/99?token=tok123',
        'subtitle_urls': ['http://192.168.50.4:13000/sub/0.vtt'],
        'source': {
          'container': 'mkv',
          'resolution': '2160p',
          'video_codec': 'hevc',
          'hdr': 'HDR10',
          'bit_rate': 19800000,
          'frame_rate': 59.94,
        },
        'decision': {
          'outcome': 'plan',
          'video': {'action': 'copy', 'codec': 'hevc'},
          'audio': {'action': 'copy', 'codec': 'eac3'},
          'audio_tracks': [
            {
              'ref': 'a:0',
              'codec': 'eac3',
              'channels': 6,
              'language': 'cmn',
              'is_default': true,
            },
          ],
          'subtitles': [
            {
              'ref': 's:0',
              'kind': 'vtt',
              'language': 'chs',
              'title': '简体中文',
              'is_default': true,
            },
          ],
        },
        'watch': {'duration_ms': 6210000},
        'chapters': [
          {'start_ms': 0, 'title': '序幕'},
          {'start_ms': 540000, 'title': '高潮'},
        ],
      });

      expect(session.playable, isTrue);
      expect(session.deliveryMode, 'direct_play');
      expect(session.streamToken, 'tok123');
      expect(session.resolution, '2160p');
      expect(session.hdr, 'HDR10');
      expect(session.videoCodec, 'hevc');
      expect(session.audioCodec, 'eac3');
      expect(session.durationMs, 6210000);
      expect(session.audioTracks.single.ref, 'a:0');
      expect(session.subtitles.single.url, 'http://192.168.50.4:13000/sub/0.vtt');
      expect(session.chapters.length, 2);
      expect(session.chapters[1].title, '高潮');
    });

    test('DetailEntry.fromJson 兼容 local_meta / files[0] / seasons 整型列表 / collections 对象数组', () {
      final entry = DetailEntry.fromJson({
        'id': 42,
        'library_id': 2,
        'kind': 'tv',
        'title': '聪明镇',
        'year': 2026,
        'seasons': [1, 2],
        'collections': [
          {'id': 22, 'name': 'HDR'},
          '华语悬疑',
        ],
        'local_meta': {
          'plot': '搬进了升学率百分之百的神秘聪明镇。',
          'rating': 7.6,
          'runtime_minutes': 53,
          'genres': ['悬疑', '惊悚'],
          'director_credits': [
            {'name': '谢骏毅', 'tmdb_person_id': 101},
          ],
          'actors': [
            {'name': '梁咏琪', 'role': '母亲', 'tmdb_person_id': 102},
          ],
        },
        'files': [
          {'id': 801, 'resolution': '2160p', 'hdr': 'HDR10', 'duration_seconds': 3180},
        ],
      });

      expect(entry.isTv, isTrue);
      expect(entry.overview, contains('神秘聪明镇'));
      expect(entry.rating, 7.6);
      expect(entry.runtimeMinutes, 53);
      expect(entry.resolution, '2160p');
      expect(entry.hdr, isTrue);
      expect(entry.hdrLabel, 'HDR10');
      expect(entry.seasons.map((s) => s.number).toList(), [1, 2]);
      expect(entry.collections, ['HDR', '华语悬疑']);
      expect(entry.collectionIds['HDR'], 22);
      expect(entry.cast.length, 2);
      expect(entry.cast.first.role, '导演');
    });

    test('SessionMessage.fromJson 拆分多段 thinking + text 与嵌套 function tool_calls', () {
      final msg = SessionMessage.fromJson({
        'role': 'assistant',
        'content': [
          {'type': 'thinking', 'text': '先检索本地媒体库状态…'},
          {'type': 'text', 'text': '已为您找到 3 部 4K HDR 影片。'},
        ],
        'tool_calls': [
          {
            'id': 'call_1',
            'function': {
              'name': 'search_library',
              'arguments': {'hdr': 'HDR10'},
            },
          },
        ],
      });

      expect(msg.thinking, '先检索本地媒体库状态…');
      expect(msg.content, '已为您找到 3 部 4K HDR 影片。');
      expect(msg.toolCalls.single.name, 'search_library');
      expect(msg.toolCalls.single.arguments, contains('HDR10'));
    });
  });
}
