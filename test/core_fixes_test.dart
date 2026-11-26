import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/cast/dlna_discovery.dart';
import 'package:mc_flutter/core/player/session/playback_session_api.dart';
import 'package:mc_flutter/core/session/session_store.dart';
import 'package:mc_flutter/features/player/state/player_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaybackSession.fromJson (/api/v1/playback/sessions)', () {
    test('parses nested decision diagnostics, tracks, and skip segments', () {
      final session = PlaybackSession.fromJson(<String, dynamic>{
        'session_id': 'sess-99',
        'stream_url': '/api/v1/playback/hls/sess-99/master.m3u8',
        'start_ms': 42000,
        'hw_backend': 'nvenc',
        'decision': <String, dynamic>{
          'outcome': 'plan',
          'mode': 'direct_stream',
          'video_codec': 'hevc',
          'audio_codec': 'eac3',
          'resolution': '3840x2160',
          'container': 'mkv',
          'audio_tracks': <Map<String, dynamic>>[
            <String, dynamic>{
              'track_ref': 'a:0',
              'language': 'jpn',
              'codec': 'eac3',
              'channels': 6,
              'is_default': true,
            },
          ],
          'subtitles': <Map<String, dynamic>>[
            <String, dynamic>{
              'track_ref': 'external:zh.vtt',
              'kind': 'vtt',
              'language': 'zho',
              'is_ai': true,
              'is_default': true,
              'url': '/api/v1/subtitles/99.vtt',
            },
          ],
        },
        'segments': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'intro',
            'start_ms': 10000,
            'end_ms': 95000,
          },
        ],
      });

      expect(session.playable, isTrue);
      expect(session.sessionId, 'sess-99');
      expect(session.deliveryMode, 'direct_stream');
      expect(session.videoCodec, 'hevc');
      expect(session.audioCodec, 'eac3');
      expect(session.resolution, '3840x2160');
      expect(session.hwBackend, 'nvenc');
      expect(session.audioTracks, hasLength(1));
      expect(session.audioTracks.first.label, contains('日语'));
      expect(session.subtitles, hasLength(1));
      expect(session.subtitles.first.isAi, isTrue);
      expect(session.subtitles.first.url, '/api/v1/subtitles/99.vtt');
      expect(session.skipSegments, hasLength(1));
      expect(session.skipSegments.first.type, 'intro');
    });
  });

  group('DlnaDiscovery XML parser', () {
    test('parses multiline <service> blocks for AVTransport controlURL', () {
      const xml = '''
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <friendlyName>Living Room Apple TV</friendlyName>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <controlURL>/upnp/control/render</controlURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
        <controlURL>/upnp/control/avtransport</controlURL>
      </service>
    </serviceList>
  </device>
</root>
''';
      expect(
        DlnaDiscovery.parseAvTransportControlUrl(xml),
        '/upnp/control/avtransport',
      );
    });
  });

  group('parseSubtitleText (WebVTT & SRT)', () {
    test('parses WebVTT and SRT cues while stripping HTML/ASS tags', () {
      const rawVtt = '''
WEBVTT

00:00:01.500 --> 00:00:04.000
<i>欢迎来到</i> MovieClaw 影院

2
00:01:02,000 --> 00:01:05,250
{\\an8}第二条 SRT 兼容字幕
''';
      final cues = parseSubtitleText(rawVtt);
      expect(cues, hasLength(2));
      expect(cues[0].startMs, 1500);
      expect(cues[0].endMs, 4000);
      expect(cues[0].text, '欢迎来到 MovieClaw 影院');
      expect(cues[1].startMs, 62000);
      expect(cues[1].endMs, 65250);
      expect(cues[1].text, '第二条 SRT 兼容字幕');
    });
  });

  group('SessionStore multi-account vault', () {
    test('persists mc_servers entries and switches accounts cleanly', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final store = SessionStore();

      await store.login(
        baseUrl: 'https://nas-a.example.com',
        token: 'tok-alice',
        username: 'alice',
        deviceName: 'Mac Studio',
      );
      await store.saveProfile(
        accountUsername: 'alice',
        username: 'Alice',
        role: 'admin',
      );

      await store.login(
        baseUrl: 'https://nas-b.example.com',
        token: 'tok-bob',
        username: 'bob',
      );

      expect(store.baseUrl, 'https://nas-b.example.com');
      expect(store.token, 'tok-bob');

      final switched = await store.switchAccount(
        origin: 'https://nas-a.example.com',
        username: 'alice',
      );
      expect(switched, isTrue);
      expect(store.baseUrl, 'https://nas-a.example.com');
      expect(store.token, 'tok-alice');
    });
  });
}
