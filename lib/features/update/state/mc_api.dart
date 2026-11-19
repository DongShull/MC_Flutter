import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/session/session_store.dart';
import 'models.dart';

/// 更新检查 API 单例。
final updateApiProvider = Provider<UpdateApi>((ref) => UpdateApi(
      ref.watch(sessionStoreProvider),
      product: UpdatePolicy.product,
    ));

/// 本次结果来源（对齐 AppUpdater.Source）。
enum UpdateSource { official, server }

extension UpdateSourceText on UpdateSource {
  String get label => switch (this) {
        UpdateSource.official => '官网',
        UpdateSource.server => '你的服务器',
      };
}

/// 客户端自身新版检查（对齐原 core/update AppUpdater.check）：
/// 先查官网 GitHub Release（tag 过滤 + release.json 附件），连不上（国内网络）再改问
/// 自己的服务器 GET /app/clients/{product}/latest（服务器沿用它的 GitHub 出口代查）。
class UpdateApi {
  UpdateApi(this._session, {this.product = 'android'});

  final SessionStore _session;
  final String product;
  McClient? _client;
  Dio? _officialDio;

  static const _githubApi = 'https://api.github.com/repos/movieclaw/movieclaw';
  static const _prefix = '/api/v1';

  /// 查最新版：来源标记 official / server；两边都失败时抛出说明两边原因的错误。
  Future<(ClientReleaseView, UpdateSource)> latest({bool force = false}) async {
    Object? officialError;
    try {
      return (await officialLatest(), UpdateSource.official);
    } catch (e) {
      officialError = e;
    }
    try {
      return (await serverLatest(refresh: force), UpdateSource.server);
    } catch (e) {
      throw Exception('官网检查失败（${_brief(officialError)}），服务器兜底也失败（${_brief(e)}）');
    }
  }

  /// 官网：GET /git/matching-refs/tags/<prefix> → 取最新正式 release 的 release.json 附件。
  Future<ClientReleaseView> officialLatest() async {
    final prefix = product == 'androidtv' ? 'androidtv-v' : 'android-v';
    final refs = await _getJson('$_githubApi/git/matching-refs/tags/$prefix');
    final list = (refs['refs'] as List?) ?? const [];
    final tags = list
        .whereType<Map>()
        .map((e) => (e['ref'] ?? '').toString().replaceFirst('refs/tags/', ''))
        .where((t) => t.startsWith(prefix) && RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(t))
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final infoAsset = product == 'androidtv' ? 'androidtv-release.json' : 'android-release.json';
    for (final tag in tags.take(5)) {
      final release = await _getJson('$_githubApi/releases/tags/$tag');
      if (release['draft'] == true || release['prerelease'] == true) continue;
      final assets = (release['assets'] as List?) ?? const [];
      String? assetUrl(String name) {
        for (final a in assets.whereType<Map>()) {
          if ((a['name'] ?? '').toString() == name) {
            return (a['browser_download_url'] ?? '').toString();
          }
        }
        return null;
      }

      final infoUrl = assetUrl(infoAsset);
      if (infoUrl == null) continue;
      final info = await _getJson(infoUrl);
      final version = (info['version'] ?? '').toString();
      final build = int.tryParse((info['build'] ?? '').toString());
      final sha = (info['sha256'] ?? '').toString().toLowerCase();
      if (version.isEmpty || build == null || sha.isEmpty) continue;
      return ClientReleaseView(
        product: product,
        version: version,
        build: build,
        size: int.tryParse((info['size'] ?? '').toString()) ?? 0,
        sha256: sha,
        certificateSha256: (info['certificateSha256'] ?? '').toString(),
        changelog: (release['body'] ?? '').toString(),
        publishedAt: (release['published_at'] ?? '').toString(),
        releaseUrl: (release['html_url'] ?? '').toString(),
      );
    }
    throw const ApiException('update.official', '官网没有这个客户端的正式发布');
  }

  /// 服务器兜底：GET /app/clients/{product}/latest（统一走 McClient，Channel.general）。
  Future<ClientReleaseView> serverLatest({bool refresh = false}) async {
    await _session.restore();
    final client = _client ??= McClient(session: _session);
    final body = await client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_prefix/app/clients/$product/latest',
      query: refresh ? const {'refresh': '1'} : null,
    );
    return ClientReleaseView.fromJson(body);
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final dio = _officialDio ??= Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (_) => true,
    ));
    final res = await dio.get<dynamic>(url);
    if (res.statusCode != 200 || res.data == null) {
      throw ApiException('update.official', '官网请求失败 HTTP ${res.statusCode}');
    }
    final data = res.data;
    if (data is Map) return data.cast<String, dynamic>();
    throw const ApiException('update.official', '官网返回格式不对');
  }

  static String _brief(Object e) => switch (e) {
        ApiException api => api.message,
        _ => e.toString(),
      };
}