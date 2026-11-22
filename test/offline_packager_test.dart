import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_flutter/core/offline/offline_packager.dart';
import 'package:mc_flutter/features/offline/state/models.dart';

OfflineManifest manifest({
  String profile = 'original',
  List<OfflineSubtitleRef> subtitles = const [],
  Map<String, dynamic>? item,
  Map<String, dynamic>? season,
  dynamic audioTracks,
  String? defaultAudio,
}) =>
    OfflineManifest(
      fileId: '1',
      mediaItemId: 7,
      seasonNumber: 1,
      durationMs: 600000,
      container: 'mkv',
      item: item ??
          {
            'title': '测试片',
            'files': [
              {
                'id': '1',
                'resolution': '1080p',
                'videoCodec': 'h264',
              },
            ],
          },
      season: season,
      audioTracks: audioTracks,
      defaultAudio: defaultAudio,
      subtitles: subtitles,
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mc_packager_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<String> fakeMedia() async {
    final file = File('${tempDir.path}/item.mp4');
    await file.writeAsBytes([0, 1, 2, 3]);
    return file.path;
  }

  test('原画档：文本字幕请服务端转 VTT，ASS 原样，内封轨跳过', () async {
    final requested = <String>[];
    final savePath = await fakeMedia();
    final packager = OfflinePackager(
      manifest: manifest(subtitles: [
        const OfflineSubtitleRef(
          trackRef: 'sub-zh',
          format: 'srt',
          language: 'zh',
          url: '/api/v1/sub?format=srt&token=abc',
        ),
        const OfflineSubtitleRef(
          trackRef: 'sub-en',
          format: 'ass',
          language: 'en',
          url: '/api/v1/sub2?token=def',
        ),
        const OfflineSubtitleRef(
          trackRef: 'sub-embedded',
          format: 'srt',
          language: 'ja',
          embedded: true,
          url: '/api/v1/sub3?format=srt',
        ),
      ]),
      savePath: savePath,
      profile: 'original',
      baseUrl: 'https://example.com',
      fetchBytes: (url) async {
        requested.add(url);
        return utf8.encode('WEBVTT\n\n');
      },
    );

    final result = await packager.run();
    expect(result.subtitleCount, 2);
    expect(result.imageCount, 0);

    // 文本轨的请求里 format=vtt、不含 format=srt；ASS 走原地址。
    expect(
        requested.where((u) => u.contains('format=vtt')).length, 1);
    expect(requested.any((u) => u.contains('format=srt')), isFalse);
    expect(requested.any((u) => u.contains('/api/v1/sub2')), isTrue);
    expect(requested.any((u) => u.contains('/api/v1/sub3')), isFalse);

    expect(await File('$savePath.subs/0-zh.vtt').exists(), isTrue);
    expect(await File('$savePath.subs/1-en.ass').exists(), isTrue);
    expect(await File('$savePath.subs/2-ja.vtt').exists(), isFalse);

    final spec = jsonDecode(
        await File('$savePath.playback.json').readAsString())
        as Map<String, dynamic>;
    expect(spec['container'], 'mkv');
    expect(spec['resolution'], '1080p');
    expect(spec['videoCodec'], 'h264');
    expect(spec['durationMs'], 600000);
    final subs = spec['subtitles'] as List;
    expect(subs.length, 2);
    expect(subs[0]['ref'], 'external:0-zh.vtt');
    expect(subs[0]['kind'], 'vtt');
    expect(subs[1]['ref'], 'external:1-en.ass');
    expect(subs[1]['kind'], 'ass');
  });

  test('转码档：内封轨也下载；resolution 取档位 id；只留默认音轨', () async {
    final savePath = await fakeMedia();
    final packager = OfflinePackager(
      manifest: manifest(
        subtitles: [
          const OfflineSubtitleRef(
            trackRef: 'sub-embedded',
            format: 'srt',
            language: 'ja',
            embedded: true,
            url: '/api/v1/sub3?format=srt',
          ),
        ],
        audioTracks: [
          {'ref': 'a1', 'language': 'zh'},
          {'ref': 'a2', 'language': 'ja'},
        ],
        defaultAudio: 'a2',
      ),
      savePath: savePath,
      profile: '720p',
      baseUrl: 'https://example.com',
      fetchBytes: (url) async => utf8.encode('WEBVTT\n\n'),
    );

    final result = await packager.run();
    expect(result.subtitleCount, 1);
    final spec = jsonDecode(
        await File('$savePath.playback.json').readAsString())
        as Map<String, dynamic>;
    expect(spec['container'], 'mp4');
    expect(spec['resolution'], '720p');
    expect(spec.containsKey('videoCodec'), isFalse);
    final audio = spec['audioTracks'] as List;
    expect(audio.length, 1);
    expect(audio[0]['ref'], 'a2');
    expect(spec['defaultAudio'], 'a2');
  });

  test('字幕拉取失败：抛 OfflinePackageException，不静默跳过', () async {
    final savePath = await fakeMedia();
    final packager = OfflinePackager(
      manifest: manifest(subtitles: [
        const OfflineSubtitleRef(
          trackRef: 'sub-zh',
          format: 'srt',
          language: 'zh',
          url: '/api/v1/sub?format=srt',
        ),
      ]),
      savePath: savePath,
      profile: 'original',
      baseUrl: 'https://example.com',
      fetchBytes: (url) async =>
          throw const HttpException('404 Not Found'),
    );
    await expectLater(
        packager.run(), throwsA(isA<OfflinePackageException>()));
  });

  test('图片 best-effort：拉取失败不影响完成；PNG 按嗅探存 .png', () async {
    // 失败路径：海报拉不到，打包照常完成。
    var savePath = await fakeMedia();
    final failing = OfflinePackager(
      manifest: manifest(item: {
        'title': '测试片',
        'posterUrl': '/images/poster.jpg',
        'files': [
          {'id': '1', 'resolution': '1080p'},
        ],
      }),
      savePath: savePath,
      profile: 'original',
      baseUrl: 'https://example.com',
      fetchBytes: (url) async => throw const HttpException('404'),
    );
    final failedResult = await failing.run();
    expect(failedResult.imageCount, 0);

    // 成功路径：PNG 魔数 → 存 .png。
    savePath = await fakeMedia();
    final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3];
    final ok = OfflinePackager(
      manifest: manifest(item: {
        'title': '测试片',
        'posterUrl': '/images/poster.jpg',
        'files': [
          {'id': '1', 'resolution': '1080p'},
        ],
      }),
      savePath: savePath,
      profile: 'original',
      baseUrl: 'https://example.com',
      fetchBytes: (url) async => png,
    );
    final okResult = await ok.run();
    expect(okResult.imageCount, 1);
    final images = Directory('$savePath.images').listSync();
    expect(images.length, 1);
    expect(images.first.path.endsWith('.png'), isTrue);
  });
}
