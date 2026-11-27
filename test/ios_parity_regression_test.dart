import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/api/agent_sse_client.dart';
import 'package:mc_flutter/core/auth/pairing_qr_parser.dart';
import 'package:mc_flutter/core/designsystem/rule_set_editor_sheet.dart';
import 'package:mc_flutter/core/l10n/mc_l10n.dart';
import 'package:mc_flutter/core/navigation/external_media_link.dart';
import 'package:mc_flutter/core/network/server_routes.dart';
import 'package:mc_flutter/core/player/playback_watchdogs.dart';
import 'package:mc_flutter/core/player/session/playback_session_api.dart';
import 'package:mc_flutter/core/push/push_crypto.dart';
import 'package:mc_flutter/core/session/permissions.dart';
import 'package:mc_flutter/features/agent/state/models.dart';
import 'package:mc_flutter/features/offline/state/models.dart';
import 'package:mc_flutter/features/share/state/share_local_progress.dart';

void main() {
  group('iOS 宿主合规与 ATS 安全校验', () {
    test('Info.plist 移除冲突的 NSAllowsLocalNetworking 并包含暗色模式/出口合规/四语种', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('NSAllowsArbitraryLoads'));
      expect(plist, isNot(contains('NSAllowsLocalNetworking')));
      expect(plist, contains('UIUserInterfaceStyle'));
      expect(plist, contains('<string>Dark</string>'));
      expect(plist, contains('ITSAppUsesNonExemptEncryption'));
      expect(plist, contains('<string>zh-Hans</string>'));
      expect(plist, contains('<string>zh-Hant</string>'));
      expect(plist, contains('<string>en</string>'));
      expect(plist, contains('<string>de</string>'));
      expect(File('ios/Runner/PrivacyInfo.xcprivacy').existsSync(), isTrue);
      expect(File('ios/Runner/Runner.entitlements').existsSync(), isTrue);
    });
  });

  group('ServerRoutes Ed25519 主机验签与网络分类', () {
    test('Ed25519 host_key 质询签名校验通过且拦截篡改/空 instance_id', () async {
      final algo = Ed25519();
      final keyPair = await algo.newKeyPair();
      final pubKey = await keyPair.extractPublicKey();
      final pubB64 = base64Encode(pubKey.bytes);
      final nonce = ServerRoutes.generateNonce();
      const instanceId = 'inst-prod-01';
      final msg = utf8.encode('movieclaw-health\n$instanceId\n$nonce');
      final sig = await algo.sign(msg, keyPair: keyPair);
      final proofB64 = base64Encode(sig.bytes);

      final book = ServerRouteBook(
        instanceId: instanceId,
        hostKey: pubB64,
        endpoints: const [],
        lanSubnets: const ['192.168.50.0/24'],
      );

      expect(
        await ServerRoutes.verifyHealthProof(
          health: {'instance_id': instanceId, 'proof': proofB64},
          nonce: nonce,
          book: book,
          hasSpecHashHeader: true,
        ),
        isTrue,
      );
      expect(
        await ServerRoutes.verifyHealthProof(
          health: {'instance_id': '', 'proof': proofB64},
          nonce: nonce,
          book: book,
          hasSpecHashHeader: true,
        ),
        isFalse,
      );
      expect(
        await ServerRoutes.verifyHealthProof(
          health: {'instance_id': instanceId, 'proof': proofB64},
          nonce: 'tampered-nonce',
          book: book,
          hasSpecHashHeader: true,
        ),
        isFalse,
      );
      expect(
        await ServerRoutes.verifyHealthProof(
          health: {'instance_id': instanceId, 'proof': proofB64},
          nonce: nonce,
          book: book,
          hasSpecHashHeader: false,
        ),
        isFalse,
      );
    });

    test('网卡分类排除 198.18.0.0/15 代理假 IP 并正确识别 VPN 网卡', () {
      const fakeIp = (198 << 24) | (18 << 16) | 1;
      const tailscaleIp = (100 << 24) | (64 << 16) | 1;
      expect(NetworkSnapshot.isProxyFakeIp(fakeIp), isTrue);
      expect(
        NetworkSnapshot.classifyInterface('utun3', address: fakeIp),
        NetworkInterfaceKind.other,
      );
      expect(
        NetworkSnapshot.classifyInterface('utun4', address: tailscaleIp),
        NetworkInterfaceKind.vpn,
      );
    });
  });

  group('PushCrypto AES-256-GCM 端到端加密协议', () {
    test('v1.<key_id>.<nonce>.<ciphertext> 加解密往返一致且拒绝篡改', () async {
      final key = PushCrypto.generateKey();
      final keyId = PushCrypto.generateKeyId();
      const payload = PushPayload(
        title: '新剧集已入库',
        body: '第 4 集 4K HDR10',
        openPath: '/library/2/item/42?season=1&episode=4',
        category: 'item',
      );
      final token = await PushCrypto.encryptPayload(
        payload,
        key: key,
        keyId: keyId,
      );
      expect(token.startsWith('v1.$keyId.'), isTrue);
      final parsed = await PushCrypto.decryptPayload(token, key: key);
      expect(parsed.title, '新剧集已入库');
      expect(parsed.openPath, '/library/2/item/42?season=1&episode=4');

      // 篡改密文应抛出异常
      final tampered = '${token.substring(0, token.length - 2)}AA';
      expect(
        () => PushCrypto.decryptPayload(tampered, key: key),
        throwsA(isA<Object>()),
      );
    });
  });

  group('PairingQrParser / McPermissions / WebPath / ExternalMediaLink', () {
    test('PairingQrParser 保留连字符、支持 4 位简写且拒绝无关二维码', () {
      final fromUrl = PairingQrParser.parse(
        'http://192.168.50.4:3000/activate?code=mclw-7f3k',
      );
      expect(fromUrl, isNotNull);
      expect(fromUrl!.code, 'MCLW-7F3K');
      expect(fromUrl.host, '192.168.50.4:3000');

      expect(PairingQrParser.normalize('7f3k'), 'MCLW-7F3K');
      expect(PairingQrParser.normalize('MCLW7F3K'), 'MCLW-7F3K');
      expect(PairingQrParser.parse('WIFI:S:Home;T:WPA;P:12345678;;'), isNull);
      expect(PairingQrParser.parse('https://example.com/hello'), isNull);
    });

    test('McPermissions 解析 snake_case 能力开关与中英文头像首字规则', () {
      final member = McPermissions.fromJson({
        'username': 'alice',
        'role': 'member',
        'capabilities': {
          'allow_subscribe': true,
          'allow_search': false,
          'allow_video_download': true,
        },
      });
      expect(member.isAdmin, isFalse);
      expect(member.canSubscribe, isTrue);
      expect(member.canSearch, isFalse);
      expect(member.canDownloadVideo, isTrue);
      expect(McPermissions.avatarInitials('alice'), 'AL');
      expect(McPermissions.avatarInitials('张明'), '张');
    });

    test('AppWebPathResolver 与 ExternalMediaLink 路由映射', () {
      expect(
        AppWebPathResolver.resolve('/library/2/item/42?season=1&episode=3'),
        contains('/detail/2/42'),
      );
      expect(
        AppWebPathResolver.resolve('/settings/cloud'),
        '/settings/cloud',
      );
      expect(
        AppWebPathResolver.resolve('/settings/mcp'),
        '/settings/mcp',
      );
      expect(
        ExternalMediaLink.doubanAppUri(
          Uri.parse('https://movie.douban.com/subject/1292052/'),
        ),
        Uri.parse('douban://douban.com/movie/1292052'),
      );
    });

    test('McL10n 四语种本地化完整切换', () {
      final zh = McL10n.forLocale(const Locale('zh', 'CN'));
      final en = McL10n.forLocale(const Locale('en'));
      final de = McL10n.forLocale(const Locale('de'));
      expect(zh.t('tab.library'), isNot(en.t('tab.library')));
      expect(en.t('tab.library'), isNot(de.t('tab.library')));
    });
  });

  group('播放器能力协商 / 看门狗 / SSE 字节分行 / 规则组 / Agent / 离线 / 分享', () {
    test('PlaybackSessionApi.buildCapability 按引擎如实上报 universal', () {
      final universal = PlaybackSessionApi.buildCapability(
        universalEngine: true,
      );
      final fallback = PlaybackSessionApi.buildCapability(
        universalEngine: false,
      );
      expect(universal['universal'], isTrue);
      expect(fallback.containsKey('universal'), isFalse);
      expect(fallback['containers'], contains('mp4'));
    });

    test('PrematureEndGuard 拦截距结尾超 30 秒的断流伪 EOF', () {
      final guard = PrematureEndGuard();
      expect(guard.shouldResume(positionMs: 60000, durationMs: 3600000), isTrue);
      expect(
        guard.shouldResume(positionMs: 3590000, durationMs: 3600000),
        isFalse,
      );
    });

    test('SseLineParser 按字节 0x0A 切行，不被 U+2028 截断 JSON 帧', () {
      final parser = SseLineParser();
      final bytes = utf8.encode(
        'event: text_delta\ndata: {"text":"a\u2028b"}\n\n',
      );
      final events = [...parser.feedChunk(bytes), ...parser.finish()];
      expect(events, hasLength(1));
      expect(events.first.name, 'text_delta');
      expect(events.first.decodeJson()?['text'], 'a\u2028b');
    });

    test('RuleSetSpec 读写后端真实 snake_case 规则组键名', () {
      final spec = RuleSetSpec.fromJson({
        'resolutions': ['2160p'],
        'media_sources': ['remux', 'web-dl'],
        'video_codecs': ['HEVC'],
        'hdr_block': ['DV P5'],
        'free_only': true,
      });
      final out = spec.toJson();
      expect(out['media_sources'], containsAll(['remux', 'web-dl']));
      expect(out['free_only'], isTrue);
      expect(out['hdr_block'], contains('DV P5'));
    });

    test('AgentSkillText 剥离 <skill> XML 并提取 /skill:name 与真实 ID 媒体卡', () {
      const raw =
          '<skill name="sub-fix" location="/app/skills/sub-fix.md">很长的提示词</skill>\n请帮我修复字幕';
      final parsed = AgentSkillText.parseTokens(raw);
      expect(parsed.names, ['sub-fix']);
      expect(parsed.text, '请帮我修复字幕');
      expect(AgentSkillText.token('sub-fix'), '/skill:sub-fix ');

      final call = ToolCall(
        id: 'tc-live-1',
        name: 'show_media_cards_v1',
        arguments: jsonEncode({
          'component': 'library_item',
          'title': '为您找到',
          'items': [
            {'media_item_id': 42, 'season_number': 1, 'episode_number': 2},
          ],
        }),
      );
      final group = AgentMediaCardGroup.parseToolCall(call);
      expect(group, isNotNull);
      expect(group!.component, 'library_item');
      expect(group.specs.single.mediaItemId, 42);
      expect(AgentMediaCard.extractFromToolCalls([call]), isEmpty);
    });

    test('OfflineDownloadChoices 当前季智能去重与 ShareLinkKit 解析', () {
      final choices = OfflineDownloadChoices.make(
        multiSeason: false,
        episodes: const [
          OfflineChoiceEpisode(
            season: 1,
            episode: 1,
            fileId: 101,
            played: true,
            local: OfflineChoiceLocalState.done,
          ),
          OfflineChoiceEpisode(
            season: 1,
            episode: 2,
            fileId: 102,
            played: false,
          ),
          OfflineChoiceEpisode(
            season: 1,
            episode: 3,
            fileId: 103,
            played: false,
          ),
        ],
        selected: (season: 1, episode: 2),
      );
      expect(choices.note, contains('1'));
      expect(choices.scopes, isNotEmpty);

      final unit = ShareLinkKit.parsePlayUnit('s02e05');
      expect(unit.season, 2);
      expect(unit.episode, 5);
    });
  });
}
