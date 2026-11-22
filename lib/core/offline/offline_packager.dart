/// 离线打包（P3 纯 Dart 移植）。
///
/// 来源：安卓 `apps/android/app/src/main/java/io/movieclaw/android/core/offline/OfflinePackager.kt`
/// （设计见 `docs/design/offline-download.md` §5.4「准备中」；iOS 同名
/// `OfflinePackager`）。打包一个单元视频之外的东西：展示数据
/// （详情、库、这一季的分集）、播放数据（片段、章节、轨道）、字幕、图片。
///
/// 与 Kotlin 的差别（诚实记录）：
/// - 布局：Kotlin 是 `offline/<owner>/items/<条目>/units/<文件>/`
///   的归档目录（见 `OfflineArchive.OfflineDisk`）；Flutter 现状是
///   平铺文件 `<dir>/<id>.mp4`，打包产物以 sidecar 形式落在媒体文件旁：
///   `<savePath>.playback.json` / `.detail.json` / `.library.json` /
///   `.season.json` / `.subs/<名>` / `.images/<名>`。归档目录本身
///   （owner.json / summary.json / progress.json / viewings）未移植，
///   见小结未完成项。
/// - 不下 ASS 的内嵌字体（与 Kotlin 相同取舍：安卓播放器在线时也不取
///   服务端的字体，下了也用不上）。
/// - 图片缺了不影响完成，其余失败整次准备失败（调用方捕获后记日志，
///   不影响已下完的视频本身；对账时重来 = 下次打开离线页时
///   `OfflineController` 不会自动重跑，需后续接“准备态”对账）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../features/offline/state/models.dart';

/// 打包失败（字幕/展示数据/播放规格取不到时抛；图片失败不抛）。
class OfflinePackageException implements Exception {
  OfflinePackageException(this.message);
  final String message;
  @override
  String toString() => 'OfflinePackageException: $message';
}

/// 打包结果（供调用方记录/展示；`resumePositionMs` 是服务端续播点，
/// 本机离线进度存储未移植前调用方只记日志，见文件头注释）。
class OfflinePackageResult {
  const OfflinePackageResult({
    required this.specPath,
    required this.subtitleCount,
    required this.imageCount,
    this.resumePositionMs,
  });

  final String specPath;
  final int subtitleCount;
  final int imageCount;
  final int? resumePositionMs;
}

/// playback.json 里的一条字幕（对照安卓 `OfflinePlaybackSpec.Subtitle`）。
class OfflinePackagedSubtitle {
  const OfflinePackagedSubtitle({
    required this.ref,
    required this.fileName,
    required this.kind,
    this.language,
    this.title,
    this.isDefault = false,
    this.isForced = false,
    this.isAi = false,
    required this.sourceRef,
  });

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'fileName': fileName,
        'kind': kind,
        if (language != null) 'language': language,
        if (title != null) 'title': title,
        'isDefault': isDefault,
        'isForced': isForced,
        'isAi': isAi,
        'sourceRef': sourceRef,
      };

  /// 播放器里的轨引用：一律 `external:<存盘文件名>`
  /// （原画档的内封轨由引擎自己读）。
  final String ref;
  final String fileName;

  /// vtt（文本）/ ass。
  final String kind;
  final String? language;
  final String? title;
  final bool isDefault;
  final bool isForced;
  final bool isAi;

  /// 服务端的原轨引用。
  final String sourceRef;
}

/// 取字节回调：入参是绝对 URL 或 `/api/...` 路径；调用方负责拼
/// baseUrl 与鉴权（字幕 URL 带签名 token；图片是公开 CDN 地址时
/// 可直接拉）。生产环境由 `OfflineController` 传入
/// （`/api/...` 走 `McClient.getBytes`，绝对地址走 `HttpClient`）。
typedef OfflineFetchBytes = Future<List<int>> Function(String url);

class OfflinePackager {
  OfflinePackager({
    required this.manifest,
    required this.savePath,
    required this.profile,
    required this.baseUrl,
    required this.fetchBytes,
  });

  /// 清单（`OfflineController.manifest()` 的返回值）。
  final OfflineManifest manifest;

  /// 已下完的媒体文件路径；sidecar 落在它旁边。
  final String savePath;

  /// 档位 id：`original` = 原画，其余为转码档。
  final String profile;
  final String baseUrl;
  final OfflineFetchBytes fetchBytes;

  bool get _original => profile == 'original';

  Future<OfflinePackageResult> run() async {
    await _writeJsonIfPresent(
        File('$savePath.detail.json'), manifest.item);
    await _writeJsonIfPresent(
        File('$savePath.library.json'), manifest.library);
    await _writeJsonIfPresent(
        File('$savePath.season.json'), manifest.season);

    // 字幕：原画档的内封轨在文件里，引擎自己读；外挂轨、转码档的
    // 全部文字轨存成旁挂文件。文本轨请服务端转成 VTT 存
    // （播放器与调时间轴的叠层都认 VTT），ASS 原样存（保留定位与样式）。
    final subtitles = <OfflinePackagedSubtitle>[];
    final subsDir = Directory('$savePath.subs');
    await subsDir.create(recursive: true);
    for (var i = 0; i < manifest.subtitles.length; i++) {
      final sub = manifest.subtitles[i];
      if (_original && sub.embedded) continue;
      final url = sub.url;
      if (url == null || url.isEmpty) continue;
      final ass = sub.format == 'ass' || sub.format == 'ssa';
      final ext = ass ? 'ass' : 'vtt';
      final name = '$i-${_safeName(sub.language ?? 'und')}.$ext';
      final fetchUrl = ass ? url : _vttUrl(url);
      late final List<int> bytes;
      try {
        bytes = await fetchBytes(fetchUrl);
      } catch (e) {
        throw OfflinePackageException('字幕下载失败（$name）：$e');
      }
      if (bytes.isEmpty) {
        throw OfflinePackageException('字幕下载为空（$name）');
      }
      await File('${subsDir.path}/$name').writeAsBytes(bytes);
      subtitles.add(OfflinePackagedSubtitle(
        ref: 'external:$name',
        fileName: name,
        kind: ass ? 'ass' : 'vtt',
        language: sub.language,
        title: sub.title,
        isDefault: sub.isDefault,
        isForced: sub.isForced,
        isAi: sub.isAi,
        sourceRef: sub.trackRef,
      ));
    }

    final detail = manifest.item;
    final files = detail?['files'];
    Map<String, dynamic>? firstFile;
    if (files is List) {
      for (final f in files) {
        if (f is Map<String, dynamic>) {
          final id = f['id'];
          if (id != null && id.toString() == manifest.fileId) {
            firstFile = f;
            break;
          }
        }
      }
      firstFile ??= files.isNotEmpty && files.first is Map<String, dynamic>
          ? files.first as Map<String, dynamic>
          : null;
    }
    // 转码档只留默认音轨（与 Kotlin 一致：按 ref == defaultAudio 过滤）。
    dynamic audioTracks = manifest.audioTracks;
    if (!_original && audioTracks is List && manifest.defaultAudio != null) {
      audioTracks = [
        for (final t in audioTracks)
          if (t is Map && t['ref']?.toString() == manifest.defaultAudio) t,
      ];
    }
    // 注意：`firstFile?['resolution']` 不能直接写在三元表达式里——
    // 解析器会把第二个 `?` 当成嵌套条件的开头（实测报错），先取局部变量。
    final fileResolution = firstFile?['resolution'];
    final fileVideoCodec = firstFile?['videoCodec'];
    final spec = <String, dynamic>{
      'format': 1,
      if (manifest.durationMs != null) 'durationMs': manifest.durationMs,
      if (manifest.chapters != null) 'chapters': manifest.chapters,
      if (manifest.segments != null) 'segments': manifest.segments,
      if (audioTracks != null) 'audioTracks': audioTracks,
      if (manifest.defaultAudio != null)
        'defaultAudio': manifest.defaultAudio,
      'subtitles': [for (final s in subtitles) s.toJson()],
      'resolution': _original ? fileResolution : profile,
      if (_original && fileVideoCodec != null) 'videoCodec': fileVideoCodec,
      'container': _original ? manifest.container : 'mp4',
    };
    final specFile = File('$savePath.playback.json');
    await specFile.writeAsString(jsonEncode(spec));

    final images = await _saveImages(detail);
    return OfflinePackageResult(
      specPath: specFile.path,
      subtitleCount: subtitles.length,
      imageCount: images,
      resumePositionMs: manifest.resumePositionMs,
    );
  }

  /// 文本轨请服务端转成 VTT（与 Kotlin 相同 URL 改写）。
  static String _vttUrl(String url) {
    final replaced = url.replaceAll('format=srt', 'format=vtt');
    if (replaced.contains('format=')) return replaced;
    return url.contains('?') ? '$url&format=vtt' : '$url?format=vtt';
  }

  /// 详情页、海报格、分集卡、演职员要的图，每张存一份
  /// （按图片键，任何显示宽度都用它）。失败跳过，不影响完成。
  Future<int> _saveImages(Map<String, dynamic>? detail) async {
    if (detail == null) return 0;
    final wanted = <(String, int)>[];
    void add(dynamic raw, int width) {
      if (raw is String && raw.isNotEmpty) wanted.add((raw, width));
    }

    add(detail['posterUrl'], 780);
    add(detail['backdropUrl'], 1920);
    add(detail['logoUrl'], 780);
    final localMeta = detail['localMeta'];
    if (localMeta is Map) {
      final actors = localMeta['actors'];
      if (actors is List) {
        for (final a in actors.take(20)) {
          if (a is Map) add(a['thumbUrl'], 300);
        }
      }
      final directors = localMeta['directorCredits'];
      if (directors is List) {
        for (final d in directors.take(5)) {
          if (d is Map) add(d['thumbUrl'], 300);
        }
      }
    }
    final season = manifest.season;
    final episodes = season?['episodes'];
    if (episodes is List) {
      for (final e in episodes.take(80)) {
        if (e is Map) add(e['stillUrl'], 600);
      }
    }
    if (wanted.isEmpty) return 0;
    final dir = Directory('$savePath.images');
    await dir.create(recursive: true);
    var saved = 0;
    for (final (raw, width) in wanted) {
      final url = _resolveImageUrl(raw, width);
      if (url == null) continue;
      final key = _imageKey(url);
      if (await File('${dir.path}/$key.jpg').exists() ||
          await File('${dir.path}/$key.png').exists() ||
          await File('${dir.path}/$key.webp').exists()) {
        continue;
      }
      late final List<int> bytes;
      try {
        bytes = await fetchBytes(url);
      } catch (_) {
        continue;
      }
      if (bytes.isEmpty) continue;
      final ext = _sniffExt(bytes);
      final target = File('${dir.path}/$key.$ext');
      try {
        await target.writeAsBytes(bytes);
        saved += 1;
      } catch (_) {
        // 单张写盘失败跳过，不影响其余。
      }
    }
    return saved;
  }

  /// 图片地址可能是相对路径（`/images/...`）或带宽度的服务端地址；
  /// 相对地址拼 baseUrl。宽度参数沿用 Kotlin 的 resolveImageUrl 口径：
  /// 已有 width 参数的不改，没给的补 `?width=<w>`。
  String? _resolveImageUrl(String raw, int width) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    Uri absolute;
    if (uri.hasScheme) {
      absolute = uri;
    } else {
      if (baseUrl.isEmpty) return null;
      absolute = Uri.parse(baseUrl).resolve(raw);
    }
    if (absolute.queryParameters.containsKey('width')) return absolute.toString();
    final params = Map<String, String>.from(absolute.queryParameters)
      ..['width'] = width.toString();
    return absolute.replace(queryParameters: params).toString();
  }

  /// 图片键：与 Kotlin `OfflineImages.key` 同口径的 URL 摘要
  /// （SHA-256 前 16 字节 hex；Kotlin 取 16 字节拼文件名）。
  static String _imageKey(String url) =>
      sha256.convert(utf8.encode(url)).toString().substring(0, 32);

  /// 按文件头猜扩展名（只分 png/webp/其余 jpg，与 Kotlin 的
  /// Content-Type 分支等价口径的本地版；调用方不传 MIME 时用）。
  static String _sniffExt(List<int> bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return 'jpg';
  }

  static String _safeName(String raw) {
    final cleaned = raw
        .split('')
        .map((c) =>
            RegExp(r'[A-Za-z0-9._-]').hasMatch(c) ? c : '_')
        .join();
    final trimmed = cleaned.isEmpty ? 'file' : cleaned;
    return trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed;
  }

  static Future<void> _writeJsonIfPresent(
      File file, Map<String, dynamic>? json) async {
    if (json == null) return;
    await file.writeAsString(jsonEncode(json));
  }
}
