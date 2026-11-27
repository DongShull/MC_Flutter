import '../models/search_models.dart';

/// 促销角标类型。
enum TorrentPromoKind { free, discount, upload, hitAndRun }

class TorrentPromo {
  const TorrentPromo(this.kind, this.label);

  final TorrentPromoKind kind;
  final String label;
}

/// 属性徽标色阶。
enum TorrentAttrTone {
  plain,
  season,
  content,
  remux,
  hdr,
  subtitle,
  audio,
  group,
  platform,
}

class TorrentAttrChip {
  const TorrentAttrChip(this.text, this.tone);

  final String text;
  final TorrentAttrTone tone;
}

/// 站点资源搜索结果的纯前端规则（1:1 移植自 iOS `TorrentSearchLogic.swift`）：
/// 7 维双向排序、12 维自排除分面计数、作品聚合分组、结构化属性徽标、字幕 BCP-47 语义。
abstract final class TorrentSearchLogic {
  static const unparsedKey = '__unparsed__';

  // ── 排序 ──

  static double completenessTier(TorrentAttrs? a) {
    if (a == null) return 0;
    if (a.complete == true) return 4;
    if (a.seasons.isNotEmpty && a.episodes.isEmpty) return 3;
    if (a.episodes.length > 1) return 2;
    if (a.episodes.length == 1) return 1;
    return 0;
  }

  static const sourceRank = <String, double>{
    'UHD Blu-ray': 7,
    'Blu-ray': 6,
    'WEB-DL': 5,
    'BDRip': 4,
    'WEBRip': 3,
    'HD-DVD': 3,
    'HDTV': 2,
    'HDTVRip': 2,
    'HDRip': 2,
    'TVRip': 1,
    'DVDRip': 1,
    'DVD': 1,
  };

  static double uploadTimestamp(TorrentHit hit) {
    final raw = hit.uploadTime;
    if (raw == null || raw.isEmpty) return double.negativeInfinity;
    final parsed = DateTime.tryParse(raw) ?? DateTime.tryParse('${raw}Z');
    if (parsed == null) return double.negativeInfinity;
    return parsed.millisecondsSinceEpoch / 1000.0;
  }

  static int _leadingInt(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    final m = RegExp(r'^\d+').firstMatch(raw);
    return m == null ? 0 : (int.tryParse(m.group(0)!) ?? 0);
  }

  static List<double> sortVector(TorrentHit hit, TorrentSortKey key) {
    final a = hit.attrs;
    switch (key) {
      case TorrentSortKey.time:
        return [uploadTimestamp(hit)];
      case TorrentSortKey.size:
        return [hit.sizeBytes.toDouble()];
      case TorrentSortKey.snatched:
        return [hit.snatched.toDouble()];
      case TorrentSortKey.complete:
        return [
          completenessTier(a),
          (a?.seasons.length ?? 0).toDouble(),
          hit.seeders.toDouble(),
        ];
      case TorrentSortKey.quality:
        final res = _leadingInt(a?.resolution).toDouble();
        final src = (sourceRank[a?.mediaSource ?? ''] ?? 0) +
            (a?.remux == true ? 0.5 : 0);
        return [res, src, hit.seeders.toDouble()];
      case TorrentSortKey.free:
        final promo = (hit.free || hit.downloadVolumeFactor == 0)
            ? 2.0
            : (hit.downloadVolumeFactor < 1 ? 1.0 : 0.0);
        return [promo, hit.hitAndRun == false ? 1.0 : 0.0, hit.seeders.toDouble()];
      case TorrentSortKey.seeders:
        return [hit.seeders.toDouble()];
    }
  }

  static List<TorrentHit> sorted(List<TorrentHit> hits, TorrentSort sort) {
    final decorated = [
      for (var i = 0; i < hits.length; i++)
        (index: i, hit: hits[i], vec: sortVector(hits[i], sort.key)),
    ];
    decorated.sort((x, y) {
      final len = x.vec.length < y.vec.length ? x.vec.length : y.vec.length;
      for (var i = 0; i < len; i++) {
        final a = x.vec[i];
        final b = y.vec[i];
        if (a == b) continue;
        if (a == double.negativeInfinity) return 1;
        if (b == double.negativeInfinity) return -1;
        return sort.descending ? b.compareTo(a) : a.compareTo(b);
      }
      return x.index.compareTo(y.index);
    });
    return [for (final e in decorated) e.hit];
  }

  /// 智能排序键按结果集构成动态出现：剧集为主给「全集优先」，电影为主给「画质优先」，「免费优先」常驻。
  static List<TorrentSortKey> smartSortKeys(List<TorrentHit> hits) {
    var tv = 0;
    var movie = 0;
    for (final h in hits) {
      if (h.attrs?.mediaType == 'tv') {
        tv++;
      } else if (h.attrs?.mediaType == 'movie') {
        movie++;
      }
    }
    final typed = tv + movie;
    final keys = <TorrentSortKey>[];
    if (typed > 0 && tv >= typed / 2.0) keys.add(TorrentSortKey.complete);
    if (typed > 0 && movie > typed / 2.0) keys.add(TorrentSortKey.quality);
    keys.add(TorrentSortKey.free);
    return keys;
  }

  // ── 12 维自排除筛选 ──

  static bool passes(
    TorrentFilterDim dim,
    TorrentHit hit,
    TorrentFilters filters,
  ) {
    final sel = filters.values(dim);
    if (sel.isEmpty) return true;
    final a = hit.attrs;
    switch (dim) {
      case TorrentFilterDim.resolution:
        return a?.resolution != null && sel.contains(a!.resolution);
      case TorrentFilterDim.site:
        return sel.contains(hit.siteId);
      case TorrentFilterDim.year:
        return a?.year != null && sel.contains('${a!.year}');
      case TorrentFilterDim.season:
        return (a?.seasons ?? const []).any((s) => sel.contains('$s'));
      case TorrentFilterDim.episode:
        return (a?.episodes ?? const []).any((e) => sel.contains('$e')) ||
            a?.complete == true;
      case TorrentFilterDim.source:
        final bySrc = a?.mediaSource != null && sel.contains(a!.mediaSource);
        return bySrc || (sel.contains('Remux') && a?.remux == true);
      case TorrentFilterDim.platform:
        return (a?.platforms ?? const []).any(sel.contains);
      case TorrentFilterDim.codec:
        return a?.videoCodec != null && sel.contains(a!.videoCodec);
      case TorrentFilterDim.hdr:
        return (a?.hdr ?? const []).any(sel.contains);
      case TorrentFilterDim.audio:
        return (a?.audio ?? const []).any(sel.contains);
      case TorrentFilterDim.subtitle:
        return (a?.subtitleLanguages ?? const []).any(
          (lang) =>
              sel.contains(lang) || sel.any((s) => lang.startsWith('$s-')),
        );
      case TorrentFilterDim.group:
        return a?.releaseGroup != null && sel.contains(a!.releaseGroup);
    }
  }

  static bool matches(TorrentHit hit, TorrentFilters filters) =>
      TorrentFilterDim.values.every((d) => passes(d, hit, filters));

  static Map<TorrentFilterDim, Map<String, int>> facetCounts(
    List<TorrentHit> hits, {
    TorrentFilters? filters,
  }) {
    final maps = <TorrentFilterDim, Map<String, int>>{};
    void bump(TorrentFilterDim dim, String val) {
      final m = maps.putIfAbsent(dim, () => <String, int>{});
      m[val] = (m[val] ?? 0) + 1;
    }

    for (final hit in hits) {
      TorrentFilterDim? only;
      if (filters != null) {
        var failed = 0;
        for (final dim in TorrentFilterDim.values) {
          if (!passes(dim, hit, filters)) {
            failed++;
            only = dim;
            if (failed > 1) break;
          }
        }
        if (failed > 1) continue;
        if (failed == 0) only = null;
      }
      bool want(TorrentFilterDim d) => only == null || only == d;

      if (want(TorrentFilterDim.site)) bump(TorrentFilterDim.site, hit.siteId);
      final a = hit.attrs;
      if (a == null) continue;
      if (want(TorrentFilterDim.year) && a.year != null) {
        bump(TorrentFilterDim.year, '${a.year}');
      }
      if (want(TorrentFilterDim.season)) {
        for (final s in a.seasons) {
          bump(TorrentFilterDim.season, '$s');
        }
      }
      if (want(TorrentFilterDim.episode)) {
        for (final e in a.episodes) {
          bump(TorrentFilterDim.episode, '$e');
        }
      }
      if (want(TorrentFilterDim.resolution) && a.resolution != null) {
        bump(TorrentFilterDim.resolution, a.resolution!);
      }
      if (want(TorrentFilterDim.source)) {
        if (a.mediaSource != null) bump(TorrentFilterDim.source, a.mediaSource!);
        if (a.remux) bump(TorrentFilterDim.source, 'Remux');
      }
      if (want(TorrentFilterDim.platform)) {
        for (final v in a.platforms) {
          bump(TorrentFilterDim.platform, v);
        }
      }
      if (want(TorrentFilterDim.codec) && a.videoCodec != null) {
        bump(TorrentFilterDim.codec, a.videoCodec!);
      }
      if (want(TorrentFilterDim.hdr)) {
        for (final v in a.hdr) {
          bump(TorrentFilterDim.hdr, v);
        }
      }
      if (want(TorrentFilterDim.audio)) {
        for (final v in a.audio) {
          bump(TorrentFilterDim.audio, v);
        }
      }
      if (want(TorrentFilterDim.subtitle)) {
        final keys = Set<String>.from(a.subtitleLanguages);
        if (a.subtitleLanguages.any((l) => l.startsWith('zh-'))) {
          keys.add('zh');
        }
        for (final v in keys) {
          bump(TorrentFilterDim.subtitle, v);
        }
      }
      if (want(TorrentFilterDim.group) && a.releaseGroup != null) {
        bump(TorrentFilterDim.group, a.releaseGroup!);
      }
    }
    return maps;
  }

  static TorrentFacets facets(List<TorrentHit> hits, TorrentFilters filters) {
    final full = facetCounts(hits);
    final counts = filters.isActive ? facetCounts(hits, filters: filters) : full;
    final byDim = <TorrentFilterDim, List<TorrentFacetValue>>{};

    for (final dim in TorrentFilterDim.values) {
      final entries = full[dim] ?? const <String, int>{};
      List<String> ordered;
      switch (dim) {
        case TorrentFilterDim.year:
          ordered = entries.keys.toList()
            ..sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
        case TorrentFilterDim.season:
        case TorrentFilterDim.episode:
          ordered = entries.keys.toList()
            ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
        case TorrentFilterDim.site:
          ordered = entries.keys.toList();
        default:
          final cap = dim == TorrentFilterDim.resolution ? 8 : 50;
          final list = entries.entries.toList()
            ..sort((a, b) {
              final c = b.value.compareTo(a.value);
              return c != 0 ? c : a.key.compareTo(b.key);
            });
          ordered = list.take(cap).map((e) => e.key).toList();
      }
      byDim[dim] = [
        for (final v in ordered)
          TorrentFacetValue(value: v, count: counts[dim]?[v] ?? 0),
      ];
    }
    return TorrentFacets(byDim: byDim);
  }

  // ── 作品分组 ──

  static String entityKey(TorrentHit hit) {
    final a = hit.attrs;
    final title = (a != null && a.titlesZh.isNotEmpty)
        ? a.titlesZh.first
        : (a != null && a.titlesEn.isNotEmpty ? a.titlesEn.first : null);
    if (title == null || title.isEmpty) return unparsedKey;
    final type = a?.mediaType ?? '?';
    if (type == 'tv') return 'tv|$title';
    return '$type|$title|${a?.year?.toString() ?? '?'}';
  }

  static Map<String, TorrentEntity> entities(List<TorrentHit> hits) {
    final groups = <String, TorrentEntity>{};
    for (final hit in hits) {
      final key = entityKey(hit);
      if (key == unparsedKey) continue;
      final a = hit.attrs;
      final zh = (a != null && a.titlesZh.isNotEmpty) ? a.titlesZh.first : null;
      final en = (a != null && a.titlesEn.isNotEmpty) ? a.titlesEn.first : null;
      final prev = groups[key];
      if (prev != null) {
        groups[key] = TorrentEntity(
          key: key,
          nameZh: prev.nameZh ?? zh,
          nameEn: prev.nameEn ?? en,
          year: prev.year ?? a?.year,
          mediaType: prev.mediaType ?? a?.mediaType,
          contentType: prev.contentType ?? a?.contentType,
        );
      } else {
        groups[key] = TorrentEntity(
          key: key,
          nameZh: zh,
          nameEn: en,
          year: a?.year,
          mediaType: a?.mediaType,
          contentType: a?.contentType,
        );
      }
    }
    return groups;
  }

  static List<({String key, List<TorrentHit> rows})> buckets(
    List<TorrentHit> sortedHits,
  ) {
    final list = <({String key, List<TorrentHit> rows})>[];
    final index = <String, int>{};
    for (final hit in sortedHits) {
      final key = entityKey(hit);
      final idx = index[key];
      if (idx != null) {
        list[idx].rows.add(hit);
      } else {
        index[key] = list.length;
        list.add((key: key, rows: [hit]));
      }
    }
    final unparsedIdx = index[unparsedKey];
    if (unparsedIdx != null && unparsedIdx != list.length - 1) {
      list.add(list.removeAt(unparsedIdx));
    }
    return list;
  }

  static String? maxResolution(List<TorrentHit> rows) {
    String? best;
    var bestNum = -1;
    for (final r in rows) {
      final res = r.attrs?.resolution;
      if (res == null) continue;
      final n = _leadingInt(res);
      if (n > bestNum) {
        bestNum = n;
        best = res;
      }
    }
    return best;
  }

  // ── 展示标签 ──

  static const mediaTypeLabels = <String, String>{
    'movie': '电影',
    'tv': '剧集',
  };

  static const contentTypeLabels = <String, String>{
    'anime': '动漫',
    'documentary': '纪录片',
    'variety': '综艺',
    'music': '音乐',
  };

  static const subtitleLanguageLabels = <String, String>{
    'zh': '中文',
    'zh-Hans': '简体中文',
    'zh-Hant': '繁体中文',
    'en': '英语',
    'ja': '日语',
    'ko': '韩语',
    'yue': '粤语',
  };

  static String subtitleLanguageLabel(String value) =>
      subtitleLanguageLabels[value] ?? value;

  static const platformLabels = <String, String>{
    'netflix': 'Netflix',
    'amazon': 'Prime Video',
    'disney_plus': 'Disney+',
    'hbo_max': 'HBO Max',
    'hulu': 'Hulu',
    'apple_tv_plus': 'Apple TV+',
    'paramount_plus': 'Paramount+',
    'peacock': 'Peacock',
    'showtime': 'Showtime',
    'starz': 'Starz',
    'discovery_plus': 'Discovery+',
    'crave': 'Crave',
    'stan': 'Stan',
    'roku': 'Roku',
    'google_tv': 'Google TV',
    'itunes': 'iTunes',
    'sony_core': 'Sony Pictures Core',
    'criterion': 'Criterion',
    'iqiyi': '爱奇艺',
    'wetv': '腾讯视频',
    'youku': '优酷',
    'mangotv': '芒果TV',
    'bilibili': 'B站',
    'viu': 'Viu',
    'nowplayer': 'Now player',
    'mytv_super': 'myTV SUPER',
    'hami_video': 'Hami Video',
    'line_tv': 'LINE TV',
    'kktv': 'KKTV',
    'tving': 'TVING',
    'wavve': 'Wavve',
    'coupang_play': 'Coupang Play',
    'kocowa': 'KOCOWA',
    'viki': 'Viki',
    'unext': 'U-NEXT',
    'tver': 'TVer',
    'fod': 'FOD',
    'dmm_tv': 'DMM TV',
    'hotstar': 'Hotstar',
    'crunchyroll': 'Crunchyroll',
    'hidive': 'HIDIVE',
    'abema': 'ABEMA',
    'adn': 'ADN',
    'funimation': 'Funimation',
    'vrv': 'VRV',
    'wakanim': 'Wakanim',
    'b_global': 'B-Global',
  };

  static String platformLabel(String id) => platformLabels[id] ?? id;

  static String facetLabel(
    TorrentFilterDim dim,
    String value,
    String Function(String siteId) siteName,
  ) =>
      switch (dim) {
        TorrentFilterDim.site => siteName(value),
        TorrentFilterDim.season => '第 $value 季',
        TorrentFilterDim.episode => '第 $value 集',
        TorrentFilterDim.subtitle => subtitleLanguageLabel(value),
        TorrentFilterDim.platform => platformLabel(value),
        _ => value,
      };

  static const _subLangShort = <String, String>{
    'zh-Hans': '简',
    'zh-Hant': '繁',
    'zh': '中',
    'en': '英',
    'ja': '日',
    'ko': '韩',
    'yue': '粤',
  };

  static const _audioLangShort = <String, String>{
    'cmn': '国语',
    'yue': '粤语',
    'en': '英语',
    'ja': '日语',
    'ko': '韩语',
  };

  static String? compactSubtitleBadge(TorrentAttrs a) {
    final langs = List<String>.from(a.subtitleLanguages);
    if (langs.isEmpty) return null;
    if (langs.any((l) => l.startsWith('zh-'))) {
      langs.removeWhere((l) => l == 'zh');
    }
    final hard = a.subtitleCarriers.contains('hardcoded');
    if (langs.length == 1 && langs.first == 'zh') {
      return hard ? '硬中字' : '中字';
    }
    final list = langs.map((l) => _subLangShort[l] ?? l).join('·');
    return hard ? '字幕 $list·硬' : '字幕 $list';
  }

  static String? compactAudioBadge(TorrentAttrs a) {
    if (a.audioLanguages.isEmpty) return null;
    final list = a.audioLanguages.map((l) => _audioLangShort[l] ?? l).join('·');
    return '音轨 $list';
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  static String? seasonEpLabel(TorrentAttrs a) {
    String range(List<int> nums, String prefix) => nums.length == 1
        ? '$prefix${_pad2(nums.first)}'
        : '$prefix${_pad2(nums.first)}-$prefix${_pad2(nums.last)}';

    final parts = <String>[];
    if (a.seasons.length == 1 && a.episodes.isNotEmpty) {
      parts.add('S${_pad2(a.seasons.first)}${range(a.episodes, 'E')}');
    } else {
      if (a.seasons.isNotEmpty) parts.add(range(a.seasons, 'S'));
      if (a.episodes.isNotEmpty && a.complete != true) {
        parts.add(range(a.episodes, 'E'));
      }
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  static String? completeLabel(TorrentAttrs? a) {
    if (a?.complete != true) return null;
    return a?.episodesTotal != null ? '全 ${a!.episodesTotal} 集' : '全集';
  }

  static String formatNumList(List<int> nums) {
    final s = List<int>.from(nums)..sort();
    var contiguous = true;
    for (var i = 1; i < s.length; i++) {
      if (s[i] != s[i - 1] + 1) {
        contiguous = false;
        break;
      }
    }
    if (s.length > 1 && contiguous) return '${s.first}-${s.last}';
    return s.join('、');
  }

  static ({String text, bool pack})? seasonEpisodeChip(TorrentAttrs? a) {
    if (a == null || a.mediaType == 'movie') return null;
    final season =
        a.seasons.isEmpty ? null : '第 ${formatNumList(a.seasons)} 季';
    final ep = completeLabel(a) ??
        (a.episodes.isEmpty ? null : '第 ${formatNumList(a.episodes)} 集');
    if (season == null && ep == null) return null;
    final pack = a.complete == true || (season != null && a.episodes.isEmpty);
    final text = [if (season != null) season, if (ep != null) ep].join(' · ');
    return (text: text, pack: pack);
  }

  static String? specSummary(TorrentAttrs a) {
    final parts = <String>[];
    final se = seasonEpLabel(a);
    if (se != null) parts.add(se);
    if (a.resolution != null) parts.add(a.resolution!);
    parts.addAll(a.platforms.map(platformLabel));
    if (a.mediaSource != null) parts.add(a.mediaSource!);
    if (a.remux) parts.add('Remux');
    if (a.videoCodec != null) parts.add(a.videoCodec!);
    parts.addAll(a.hdr);
    final sub = compactSubtitleBadge(a);
    if (sub != null) parts.add(sub);
    final aud = compactAudioBadge(a);
    if (aud != null) parts.add(aud);
    parts.addAll(a.audio.take(2));
    if (a.releaseGroup != null) parts.add(a.releaseGroup!);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static ({String primary, String? secondary})? parsedName(TorrentHit hit) {
    final a = hit.attrs;
    if (a == null) return null;
    if (a.titlesZh.isNotEmpty) {
      return (
        primary: a.titlesZh.first,
        secondary: a.titlesEn.isNotEmpty ? a.titlesEn.first : null,
      );
    }
    if (a.titlesEn.isNotEmpty) {
      return (primary: a.titlesEn.first, secondary: null);
    }
    return null;
  }

  static List<TorrentPromo> promos(TorrentHit hit) {
    final out = <TorrentPromo>[];
    if (hit.free || hit.downloadVolumeFactor == 0) {
      out.add(const TorrentPromo(TorrentPromoKind.free, 'FREE'));
    } else if (hit.downloadVolumeFactor < 1) {
      final pct = (hit.downloadVolumeFactor * 100).round();
      out.add(TorrentPromo(TorrentPromoKind.discount, '$pct%'));
    }
    if (hit.uploadVolumeFactor > 1) {
      final f = hit.uploadVolumeFactor == hit.uploadVolumeFactor.roundToDouble()
          ? hit.uploadVolumeFactor.round().toString()
          : hit.uploadVolumeFactor.toStringAsFixed(1);
      out.add(TorrentPromo(TorrentPromoKind.upload, '${f}x 上传'));
    }
    if (hit.hitAndRun == true) {
      out.add(const TorrentPromo(TorrentPromoKind.hitAndRun, 'H&R'));
    }
    return out;
  }

  static List<TorrentAttrChip> attrBadges(TorrentAttrs a) {
    final chips = <TorrentAttrChip>[];
    final se = seasonEpLabel(a);
    if (se != null) chips.add(TorrentAttrChip(se, TorrentAttrTone.season));
    if (a.contentType != null && contentTypeLabels.containsKey(a.contentType)) {
      chips.add(
        TorrentAttrChip(
          contentTypeLabels[a.contentType]!,
          TorrentAttrTone.content,
        ),
      );
    }
    if (a.resolution != null) {
      chips.add(TorrentAttrChip(a.resolution!, TorrentAttrTone.plain));
    }
    if (a.remux) {
      chips.add(const TorrentAttrChip('Remux', TorrentAttrTone.remux));
    }
    for (final v in a.hdr) {
      chips.add(TorrentAttrChip(v, TorrentAttrTone.hdr));
    }
    final sub = compactSubtitleBadge(a);
    if (sub != null) chips.add(TorrentAttrChip(sub, TorrentAttrTone.subtitle));
    final aud = compactAudioBadge(a);
    if (aud != null) chips.add(TorrentAttrChip(aud, TorrentAttrTone.audio));
    if (a.releaseGroup != null) {
      chips.add(TorrentAttrChip(a.releaseGroup!, TorrentAttrTone.group));
    }
    for (final v in a.platforms) {
      chips.add(TorrentAttrChip(platformLabel(v), TorrentAttrTone.platform));
    }
    if (a.mediaSource != null) {
      chips.add(TorrentAttrChip(a.mediaSource!, TorrentAttrTone.plain));
    }
    if (a.videoCodec != null) {
      chips.add(TorrentAttrChip(a.videoCodec!, TorrentAttrTone.plain));
    }
    for (final v in a.audio.take(2)) {
      chips.add(TorrentAttrChip(v, TorrentAttrTone.plain));
    }
    return chips;
  }

  static String sizeText(TorrentHit hit) {
    if (hit.size != null && hit.size!.isNotEmpty) return hit.size!;
    if (hit.sizeBytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var v = hit.sizeBytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
  }

  static String elapsedText(int ms) => '${(ms / 1000.0).toStringAsFixed(1)}s';
}
