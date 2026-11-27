import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/image/image_urls.dart';
import '../../../core/network/server_routes.dart';
import '../../../core/platform/download_channel.dart';
import 'models.dart';

/// 离线磁盘存档目录约定与原子读写（对齐 iOS OfflineDisk.swift）：
///
/// ```
/// <ApplicationSupport>/Offline/<sha256(origin|username)>/
///   owner.json
///   items/<itemId>/
///     summary.json · item.json · library.json · progress.json
///     seasons/season-<XX>.json
///     images/index.json · <sha>.jpg|png|webp
///     units/<fileId>/
///       unit.json · playback.json · chapters.json · segments.json
///       media.<ext> · subs/ · fonts/
///   viewings/<viewingId>.json
/// ```
abstract final class OfflineDisk {
  static Directory itemsDir(Directory ownerDir) =>
      Directory('${ownerDir.path}/items');

  static Directory itemDir(Directory ownerDir, int itemId) =>
      Directory('${ownerDir.path}/items/$itemId');

  static Directory unitDir(Directory ownerDir, int itemId, int fileId) =>
      Directory('${ownerDir.path}/items/$itemId/units/$fileId');

  static Directory imagesDir(Directory ownerDir, int itemId) =>
      Directory('${ownerDir.path}/items/$itemId/images');

  static Directory viewingsDir(Directory ownerDir) =>
      Directory('${ownerDir.path}/viewings');

  static File ownerFile(Directory ownerDir) =>
      File('${ownerDir.path}/owner.json');

  static File summaryFile(Directory ownerDir, int itemId) =>
      File('${itemDir(ownerDir, itemId).path}/summary.json');

  static File itemDetailFile(Directory ownerDir, int itemId) =>
      File('${itemDir(ownerDir, itemId).path}/item.json');

  static File libraryFile(Directory ownerDir, int itemId) =>
      File('${itemDir(ownerDir, itemId).path}/library.json');

  static File seasonFile(Directory ownerDir, int itemId, int season) {
    final padded = season.toString().padLeft(2, '0');
    return File('${itemDir(ownerDir, itemId).path}/seasons/season-$padded.json');
  }

  static File progressFile(Directory ownerDir, int itemId) =>
      File('${itemDir(ownerDir, itemId).path}/progress.json');

  static File unitFile(Directory ownerDir, int itemId, int fileId) =>
      File('${unitDir(ownerDir, itemId, fileId).path}/unit.json');

  static File playbackFile(Directory ownerDir, int itemId, int fileId) =>
      File('${unitDir(ownerDir, itemId, fileId).path}/playback.json');

  static File chaptersFile(Directory ownerDir, int itemId, int fileId) =>
      File('${unitDir(ownerDir, itemId, fileId).path}/chapters.json');

  static File segmentsFile(Directory ownerDir, int itemId, int fileId) =>
      File('${unitDir(ownerDir, itemId, fileId).path}/segments.json');

  static File viewingFile(Directory ownerDir, String viewingId) =>
      File('${viewingsDir(ownerDir).path}/$viewingId.json');

  static File mediaFile(
    Directory ownerDir,
    int itemId,
    int fileId,
    String ext,
  ) {
    final clean = McDownloadPaths.sanitizeExtension(ext);
    return File('${unitDir(ownerDir, itemId, fileId).path}/media.$clean');
  }

  /// 原子写入 JSON：先写 `.tmp` 再改名覆盖，避免中途断电或强退留下半截 JSON。
  static Future<void> writeJson(File file, Object? value) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp.${DateTime.now().microsecondsSinceEpoch}');
    await tmp.writeAsString(jsonEncode(value));
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    await tmp.rename(file.path);
  }

  static Future<void> writeBytesAtomic(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp.${DateTime.now().microsecondsSinceEpoch}');
    await tmp.writeAsBytes(bytes, flush: true);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    await tmp.rename(file.path);
  }

  static Future<Map<String, dynamic>?> readJsonMap(File file) async {
    if (!await file.exists()) return null;
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map) return raw.cast<String, dynamic>();
    } catch (_) {}
    return null;
  }

  static Future<List<dynamic>?> readJsonList(File file) async {
    if (!await file.exists()) return null;
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is List) return raw;
    } catch (_) {}
    return null;
  }

  static Future<void> removeDir(Directory dir) async {
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }
}

/// 离线本地图片索引（对齐 iOS OfflineImages.swift）：
/// 同一张图在不同页面按不同 `w` 宽度请求，本机按规范化后的「图片键」只存一份。
class OfflineImages {
  OfflineImages._();

  static final OfflineImages shared = OfflineImages._();

  final Map<String, File> _files = {};
  final Map<int, Set<String>> _byItem = {};

  /// 计算图片键：去掉服务器前缀、`/api/v1/`、宽度/账号参数，归一化 TMDB 尺寸段。
  static String? keyForUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    var path = uri.path;
    final apiIdx = path.indexOf('/api/v1/');
    if (apiIdx >= 0) {
      path = '/${path.substring(apiIdx + '/api/v1/'.length)}';
    } else if (!path.startsWith('/')) {
      path = '/$path';
    }

    const dropped = {'w', 'variant', 'mc_account'};
    final entries = <MapEntry<String, String>>[];
    uri.queryParameters.forEach((k, v) {
      if (dropped.contains(k)) return;
      if (k == 'url') {
        final normalized = v.replaceAll(RegExp(r'/t/p/[^/]+/'), '/t/p/*/');
        entries.add(MapEntry(k, normalized));
      } else {
        entries.add(MapEntry(k, v));
      }
    });
    entries.sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return path;
    final query = entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return '$path?$query';
  }

  static String fileNameForKey(String key, String ext) {
    final digest = sha256.convert(utf8.encode(key)).bytes;
    final buf = StringBuffer();
    for (var i = 0; i < 16 && i < digest.length; i++) {
      buf.write(digest[i].toRadixString(16).padLeft(2, '0'));
    }
    return '${buf.toString()}.$ext';
  }

  /// 启动或切账号时扫描所有条目的 `images/index.json`。
  Future<void> load(Directory ownerDir, Iterable<int> itemIds) async {
    final loaded = <String, File>{};
    final items = <int, Set<String>>{};
    for (final itemId in itemIds) {
      final dir = OfflineDisk.imagesDir(ownerDir, itemId);
      final idxFile = File('${dir.path}/index.json');
      final map = await OfflineDisk.readJsonMap(idxFile);
      if (map == null) continue;
      for (final entry in map.entries) {
        final f = File('${dir.path}/${entry.value}');
        if (await f.exists()) {
          loaded[entry.key] = f;
          items.putIfAbsent(itemId, () => <String>{}).add(entry.key);
        }
      }
    }
    _files
      ..clear()
      ..addAll(loaded);
    _byItem
      ..clear()
      ..addAll(items);
  }

  void reset() {
    _files.clear();
    _byItem.clear();
  }

  void register(String key, File file, int itemId) {
    _files[key] = file;
    _byItem.putIfAbsent(itemId, () => <String>{}).add(key);
  }

  void forget(int itemId) {
    final keys = _byItem.remove(itemId);
    if (keys == null) return;
    for (final k in keys) {
      _files.remove(k);
    }
  }

  File? localFileFor(String? url) {
    final key = keyForUrl(url);
    if (key == null) return null;
    final f = _files[key];
    if (f != null && f.existsSync()) return f;
    return null;
  }

  bool has(String? url) => localFileFor(url) != null;
}

/// 打包一个单元视频之外的全部离线资产（对齐 iOS OfflinePackager.swift）：
/// - `item.json` / `library.json` / `seasons/season-XX.json`
/// - 全部旁挂与转码所需字幕（`subs/`）
/// - ASS 特效字幕所需字体（`fonts_url` → `fonts/`）
/// - 章节与跳过片段（`chapters.json`、`segments.json`、`playback.json`）
/// - 去重后的海报、背景剧照、分集剧照、演职员头像（`images/` + `OfflineImages`）
class OfflinePackager {
  OfflinePackager({
    required this.client,
    required this.ownerDir,
    required this.manifest,
    required this.profile,
  });

  final McClient client;
  final Directory ownerDir;
  final OfflineManifest manifest;
  final String profile;

  Future<OfflinePlaybackSpec> run() async {
    final itemId = manifest.mediaItemId;
    final fileId = manifest.fileIdInt;
    final unitDir = OfflineDisk.unitDir(ownerDir, itemId, fileId);
    await unitDir.create(recursive: true);

    // 1. 落盘条目元数据、媒体库与当季分集清单
    if (manifest.itemJson != null) {
      await OfflineDisk.writeJson(
        OfflineDisk.itemDetailFile(ownerDir, itemId),
        manifest.itemJson,
      );
    }
    if (manifest.libraryJson != null) {
      await OfflineDisk.writeJson(
        OfflineDisk.libraryFile(ownerDir, itemId),
        manifest.libraryJson,
      );
    }
    if (manifest.seasonJson != null) {
      final seasonNum =
          (manifest.seasonJson!['season_number'] as num?)?.toInt() ??
              (manifest.seasonJson!['seasonNumber'] as num?)?.toInt() ??
              manifest.seasonNumber;
      await OfflineDisk.writeJson(
        OfflineDisk.seasonFile(ownerDir, itemId, seasonNum),
        manifest.seasonJson,
      );
    }

    // 2. 落盘章节与片头片尾跳过片段 JSON
    await OfflineDisk.writeJson(
      OfflineDisk.chaptersFile(ownerDir, itemId, fileId),
      manifest.chaptersJson,
    );
    await OfflineDisk.writeJson(
      OfflineDisk.segmentsFile(ownerDir, itemId, fileId),
      manifest.segmentsJson,
    );

    // 3. 落盘条目摘要 summary.json（供离线媒体库秒开）
    final summary = OfflineItemSummary(
      mediaItemId: itemId,
      libraryId: manifest.libraryId,
      libraryName: manifest.libraryName,
      libraryKind: manifest.libraryKind,
      kind: manifest.itemKind,
      title: manifest.itemTitle,
      year: manifest.itemYear,
      posterUrl: manifest.itemPosterUrl,
      backdropUrl: manifest.itemBackdropUrl,
      addedAt: DateTime.now(),
    );
    await OfflineDisk.writeJson(
      OfflineDisk.summaryFile(ownerDir, itemId),
      summary.toJson(),
    );

    // 4. 下载字幕（原画跳过内封轨由引擎直读；外挂与转码档下载全部文字轨）
    final original = profile == 'original';
    final localSubs = <OfflineLocalSubtitle>[];
    for (var i = 0; i < manifest.subtitles.length; i++) {
      final sub = manifest.subtitles[i];
      if (original && sub.embedded) continue;
      if (sub.url.isEmpty) continue;
      try {
        final bytes = await _fetchBytes(sub.url, timeoutSeconds: 300);
        if (bytes == null || bytes.isEmpty) continue;
        final safeLang = _safeName(sub.language ?? 'und');
        final ext = _safeName(sub.format);
        final fileName = '$i-$safeLang.$ext';
        await OfflineDisk.writeBytesAtomic(
          File('${unitDir.path}/subs/$fileName'),
          bytes,
        );
        localSubs.add(
          OfflineLocalSubtitle(
            ref: 'external:$fileName',
            fileName: fileName,
            kind: (ext == 'ass' || ext == 'ssa') ? 'ass' : 'vtt',
            language: sub.language,
            title: sub.title,
            isDefault: sub.isDefault,
            isForced: sub.isForced,
            isAi: sub.isAi,
            sourceRef: sub.trackRef,
          ),
        );
      } catch (_) {
        // 单条字幕失败不阻断其余字幕与视频下载。
      }
    }

    // 5. 若存在 ASS 字幕且清单提供了 fonts_url，拉取内嵌字体文件
    final fonts = <String>[];
    final hasAss = localSubs.any((s) => s.kind == 'ass');
    if (hasAss && manifest.fontsUrl != null && manifest.fontsUrl!.isNotEmpty) {
      try {
        final rawBytes =
            await _fetchBytes(manifest.fontsUrl!, timeoutSeconds: 300);
        if (rawBytes != null && rawBytes.isNotEmpty) {
          final decoded = jsonDecode(utf8.decode(rawBytes));
          final data = (decoded is Map && decoded['data'] is Map)
              ? (decoded['data'] as Map)
              : (decoded is Map ? decoded : null);
          final fontUrls = (data?['fonts'] as List?) ?? const [];
          for (final rawFontUrl in fontUrls) {
            final fontUrl = rawFontUrl.toString();
            if (fontUrl.isEmpty) continue;
            final uri = Uri.tryParse(fontUrl);
            final baseName = uri != null && uri.pathSegments.isNotEmpty
                ? Uri.decodeComponent(uri.pathSegments.last)
                : 'font.ttf';
            final safeFont = _safeName(baseName);
            final fontBytes = await _fetchBytes(fontUrl, timeoutSeconds: 300);
            if (fontBytes != null && fontBytes.isNotEmpty) {
              await OfflineDisk.writeBytesAtomic(
                File('${unitDir.path}/fonts/$safeFont'),
                fontBytes,
              );
              fonts.add(safeFont);
            }
          }
        }
      } catch (_) {}
    }

    // 6. 写入播放规格 playback.json
    Map<String, dynamic>? sourceFile;
    final files = manifest.itemJson?['files'];
    if (files is List) {
      for (final f in files.whereType<Map>()) {
        if ((f['id'] as num?)?.toInt() == fileId) {
          sourceFile = f.cast<String, dynamic>();
          break;
        }
      }
    }
    final audioTracks = original
        ? manifest.audioTracksJson
        : manifest.audioTracksJson
            .where((a) => a['ref']?.toString() == manifest.defaultAudio)
            .toList();
    final spec = OfflinePlaybackSpec(
      durationMs: manifest.durationMs,
      chapters: manifest.chaptersJson,
      segments: manifest.segmentsJson,
      audioTracks: audioTracks,
      defaultAudio: manifest.defaultAudio,
      subtitles: localSubs,
      fonts: fonts,
      resolution: original ? (sourceFile?['resolution']?.toString()) : profile,
      videoCodec:
          original ? (sourceFile?['video_codec']?.toString()) : 'h264',
      container: original ? manifest.container : 'mp4',
    );
    await OfflineDisk.writeJson(
      OfflineDisk.playbackFile(ownerDir, itemId, fileId),
      spec.toJson(),
    );

    // 7. 后台下载去重后的海报/背景/剧照/演职员头像（图片缺失不阻断下载完成）
    await _saveImages();
    return spec;
  }

  Future<void> _saveImages() async {
    final itemId = manifest.mediaItemId;
    final item = manifest.itemJson;
    if (item == null || itemId <= 0) return;

    final wanted = <({String raw, int width})>[];
    void add(Object? raw, int width) {
      final s = raw?.toString().trim() ?? '';
      if (s.isNotEmpty) wanted.add((raw: s, width: width));
    }

    add(item['poster_url'] ?? item['posterUrl'], 720);
    add(item['backdrop_url'] ?? item['backdropUrl'], 1920);
    add(item['logo_url'] ?? item['logoUrl'], 720);

    final localMeta = item['local_meta'] ?? item['localMeta'];
    if (localMeta is Map) {
      final actors = (localMeta['actors'] as List?) ?? const [];
      for (final a in actors.whereType<Map>().take(20)) {
        add(a['thumb_url'] ?? a['thumbUrl'], 360);
      }
      final directors =
          (localMeta['director_credits'] ?? localMeta['directorCredits'])
                  as List? ??
              const [];
      for (final d in directors.whereType<Map>().take(5)) {
        add(d['thumb_url'] ?? d['thumbUrl'], 360);
      }
    }

    final seasonEpisodes = manifest.seasonJson?['episodes'];
    if (seasonEpisodes is List) {
      for (final ep in seasonEpisodes.whereType<Map>().take(80)) {
        add(ep['still_url'] ?? ep['stillUrl'], 720);
      }
    }

    final dir = OfflineDisk.imagesDir(ownerDir, itemId);
    final indexFile = File('${dir.path}/index.json');
    final existing = await OfflineDisk.readJsonMap(indexFile);
    final index = <String, String>{
      if (existing != null)
        for (final e in existing.entries) e.key: e.value.toString(),
    };
    var changed = false;

    for (final entry in wanted) {
      final fullUrl = McImageUrls.build(
        entry.raw,
        widthPx: entry.width,
        baseUrl: client.baseUrl,
      );
      if (fullUrl == null) continue;
      final key = OfflineImages.keyForUrl(fullUrl);
      if (key == null) continue;
      if (index.containsKey(key)) {
        final f = File('${dir.path}/${index[key]}');
        if (await f.exists()) {
          OfflineImages.shared.register(key, f, itemId);
          continue;
        }
      }
      try {
        final fetched = await _fetchBytesWithMime(fullUrl, timeoutSeconds: 25);
        if (fetched == null || fetched.bytes.isEmpty) continue;
        final mime = fetched.mime.toLowerCase();
        final ext = mime.contains('png')
            ? 'png'
            : mime.contains('webp')
                ? 'webp'
                : 'jpg';
        final fileName = OfflineImages.fileNameForKey(key, ext);
        final target = File('${dir.path}/$fileName');
        await OfflineDisk.writeBytesAtomic(target, fetched.bytes);
        index[key] = fileName;
        OfflineImages.shared.register(key, target, itemId);
        changed = true;
      } catch (_) {}
    }

    if (changed) {
      try {
        await OfflineDisk.writeJson(indexFile, index);
      } catch (_) {}
    }
  }

  String _resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final origin = ServerRoutes.instance.currentOrigin(client.baseUrl);
    if (path.startsWith('/')) return '$origin$path';
    return '$origin/$path';
  }

  Future<List<int>?> _fetchBytes(
    String path, {
    int timeoutSeconds = 30,
  }) async {
    final res = await _fetchBytesWithMime(path, timeoutSeconds: timeoutSeconds);
    return res?.bytes;
  }

  Future<({List<int> bytes, String mime})?> _fetchBytesWithMime(
    String path, {
    int timeoutSeconds = 30,
  }) async {
    final url = _resolveUrl(path);
    final http = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = Duration(seconds: timeoutSeconds);
    try {
      final req = await http
          .getUrl(Uri.parse(url))
          .timeout(Duration(seconds: timeoutSeconds));
      mcImageHeaders().forEach(req.headers.set);
      req.headers.set(HttpHeaders.userAgentHeader, McClient.defaultUserAgent);
      final res = await req.close().timeout(Duration(seconds: timeoutSeconds));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        await res.drain<void>();
        return null;
      }
      final chunks = <int>[];
      await for (final chunk in res) {
        chunks.addAll(chunk);
      }
      final mime = res.headers.contentType?.mimeType ?? '';
      return (bytes: chunks, mime: mime);
    } finally {
      http.close(force: true);
    }
  }

  static String _safeName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (cleaned.isEmpty) return 'file';
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }
}
