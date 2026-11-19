/// 规则组 spec → 中文摘要（对齐 RuleSetSpec.kt 的 specSummary 口径）。
library;

/// 片源中文映射。
String _sourceLabel(String v) {
  switch (v.toLowerCase()) {
    case 'remux':
      return 'Remux';
    case 'blu-ray':
    case 'bluray':
      return '蓝光';
    case 'web-dl':
    case 'webdl':
      return 'WEB-DL';
    case 'hdtv':
      return 'HDTV';
    default:
      return v.toUpperCase();
  }
}

/// 编码族塌缩：H.265 族→H.265，H.264 族→H.264，AV1 族→AV1。
String _codecLabel(String v) {
  final s = v.toLowerCase();
  if (s.contains('265') || s.contains('hevc')) return 'H.265';
  if (s.contains('264') || s.contains('avc')) return 'H.264';
  if (s.contains('av1')) return 'AV1';
  return v;
}

/// 把规则组的 spec（服务端下发的 JsonObject）渲染成一句中文摘要；
/// 服务端没有给摘要字段时前端按口径拼（同网页）。
String specSummary(Map<String, dynamic>? spec) {
  if (spec == null || spec.isEmpty) return '系统默认规则';
  final parts = <String>[];

  final resolutions = spec['resolutions'];
  if (resolutions is List && resolutions.isNotEmpty) {
    parts.add('画质 ${resolutions.join(" > ")}');
  }

  final sources = spec['sources'];
  if (sources is List && sources.isNotEmpty) {
    parts.add('片源 ${sources.map((s) => _sourceLabel("$s")).join("、")}');
  }

  final codecs = spec['codecs'];
  if (codecs is List && codecs.isNotEmpty) {
    final seen = <String>{};
    final labels = <String>[];
    for (final c in codecs) {
      final l = _codecLabel('$c');
      if (seen.add(l)) labels.add(l);
    }
    parts.add('编码 ${labels.join("/")}');
  }

  if (spec['freeleech_only'] == true) parts.add('仅免费');
  final seeders = spec['min_seeders'];
  if (seeders is num && seeders > 0) parts.add('做种 ≥ ${seeders.toInt()}');
  final size = spec['max_episode_size_gb'];
  if (size is num && size > 0) parts.add('单集 ≤ ${size}GB');
  if (spec['exclude_hr'] == true) parts.add('排除 H&R');

  final groups = spec['release_groups'];
  if (groups is List && groups.isNotEmpty) parts.add('制作组白名单 ${groups.length} 个');
  final banned = spec['banned_groups'];
  if (banned is List && banned.isNotEmpty) parts.add('制作组黑名单 ${banned.length} 个');

  return parts.isEmpty ? '自定义规则' : parts.join(' · ');
}
