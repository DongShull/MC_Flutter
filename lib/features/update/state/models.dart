/// 客户端发布模型（对齐原 ClientReleaseView，字段 snake_case 兼容 camelCase）。

library;

class ClientReleaseView {
  const ClientReleaseView({
    this.product = '',
    this.version = '',
    this.build = 0,
    this.size = 0,
    this.sha256 = '',
    this.certificateSha256,
    this.minimumSdk,
    this.changelog = '',
    this.publishedAt,
    this.releaseUrl = '',
  });

  /// android / androidtv
  final String product;
  /// versionName，如 0.4.0
  final String version;
  /// versionCode：App 比这个数决定有没有新版
  final int build;
  /// 安装包字节数
  final int size;
  /// sha256（小写十六进制）
  final String sha256;
  final String? certificateSha256;
  final int? minimumSdk;
  final String changelog;
  final String? publishedAt;
  final String releaseUrl;

  factory ClientReleaseView.fromJson(Map<String, dynamic> j) {
    int? numAt(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v is num) return v.toInt();
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    String? strAt(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return null;
    }

    return ClientReleaseView(
      product: strAt(['product']) ?? '',
      version: strAt(['version']) ?? '',
      build: numAt(['build']) ?? 0,
      size: numAt(['size']) ?? 0,
      sha256: (strAt(['sha256']) ?? '').toLowerCase(),
      certificateSha256: strAt(['certificateSha256', 'certificate_sha256']),
      minimumSdk: numAt(['minimumSdk', 'minimum_sdk']),
      changelog: strAt(['changelog']) ?? '',
      publishedAt: strAt(['publishedAt', 'published_at']),
      releaseUrl: strAt(['releaseUrl', 'release_url']) ?? '',
    );
  }
}

/// 更新策略（对齐原 core/update UpdatePolicy 的纯函数部分）。
abstract final class UpdatePolicy {
  /// Flutter 端当前 build 号（对应 Kotlin BuildInfo.BUILD_NUMBER）。
  /// 构建时经 --dart-define 注入，未注入时回退 1（本地 debug 基线）：
  /// ```sh
  /// flutter build apk --dart-define=MC_BUILD_NUMBER=42
  /// ```
  static const int currentBuild =
      int.fromEnvironment('MC_BUILD_NUMBER', defaultValue: 1);
  static const String currentDisplayVersion = '0.1.0';
  static const String product = 'android';

  /// 一天最多自动检查一次。
  static const autoCheckInterval = Duration(hours: 24);

  static bool isNewer(ClientReleaseView release, int currentBuild) =>
      release.build > currentBuild;

  /// 自动检查只在「比本机新、而且不是用户说过跳过的那一版」时弹；手动检查不看跳过。
  static bool shouldPrompt(ClientReleaseView release, int currentBuild, int? skippedBuild) =>
      isNewer(release, currentBuild) && release.build != skippedBuild;

  /// changelog 摘要：优先取「## 简体中文」小节，最多 4 行 / 200 字（对齐 UpdatePolicy.summary）。
  static String summary(String changelog, {int maxLines = 4, int maxChars = 200}) {
    final fenceMarker = String.fromCharCodes([96, 96, 96]);
    final lines = changelog.split(String.fromCharCode(10));
    final zh = lines.indexWhere((l) => l.trim() == '## 简体中文');
    final section = zh < 0
        ? lines
        : lines.skip(zh + 1).takeWhile((l) => l.trim() != '---').toList();
    final buffer = StringBuffer();
    var used = 0;
    var count = 0;
    for (final raw in section) {
      var line = raw.trim();
      while (line.startsWith('#') || line.startsWith('>')) {
        line = line.substring(1).trim();
      }
      if (line.isEmpty || line.startsWith(fenceMarker)) continue;
      if (count >= maxLines) break;
      var piece = line;
      if (used + piece.length > maxChars) {
        final room = (maxChars - used).clamp(0, piece.length);
        piece = '${piece.substring(0, room).trimRight()}…';
      }
      if (buffer.isNotEmpty) buffer.write(String.fromCharCode(10));
      buffer.write(piece);
      used += piece.length;
      count++;
      if (used >= maxChars) break;
    }
    return buffer.toString();
  }
}
