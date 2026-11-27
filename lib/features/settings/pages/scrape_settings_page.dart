import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/api/session_providers.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';
import '../widgets/settings_ui.dart';

// ── 刮削静态目录与命名模板渲染引擎（1:1 镜像 iOS SettingsBScrapeModel.swift）──

class _ChipOpt {
  const _ChipOpt(this.id, this.name, {this.tip});

  final String id;
  final String name;
  final String? tip;
}

const _commonMetaLangs = <_ChipOpt>[
  _ChipOpt('zh-CN', '简体中文'),
  _ChipOpt('zh-TW', '繁體中文'),
  _ChipOpt('en-US', 'English'),
  _ChipOpt('ja-JP', '日本語'),
  _ChipOpt('ko-KR', '한국어'),
  _ChipOpt('fr-FR', 'Français'),
];

const _commonImageLangs = <_ChipOpt>[
  _ChipOpt('meta', '跟随元数据主语言', tip: '自动匹配本片刮削到的首选语言'),
  _ChipOpt('orig', '影片原语种', tip: '优先选影片原始发行语言的图片'),
  _ChipOpt('en', 'English'),
  _ChipOpt('null', '无文字纯图', tip: '适合背景图与洁癖海报'),
  _ChipOpt('ja', '日本語'),
];

const _commonCertCountries = <_ChipOpt>[
  _ChipOpt('CN', '中国'),
  _ChipOpt('US', '美国'),
  _ChipOpt('JP', '日本'),
  _ChipOpt('GB', '英国'),
];

const _posterSizes = ['w342', 'w500', 'w780', 'original'];
const _backdropSizes = ['w780', 'w1280', 'original'];
const _stillSizes = ['w185', 'w300', 'original'];
const _profileSizes = ['w185', 'h632', 'original'];

const _imageQualities = <({String id, String title, String desc})>[
  (
    id: 'original',
    title: '原图（默认）',
    desc: '保留 TMDB/Fanart 最高清晰度，4K 大屏与 Apple TV 效果最佳',
  ),
  (
    id: 'standard',
    title: '标准画质',
    desc: '均衡清晰度与磁盘占用，手机、平板与 1080p 电视足够清晰',
  ),
  (
    id: 'compact',
    title: '轻量省空间',
    desc: '大幅降低元数据图片体积，适合小容量 SSD 或大库',
  ),
  (
    id: 'custom',
    title: '自定义各尺寸档位',
    desc: '分别指定海报、背景图、剧照与演职员头像的 TMDB 档位',
  ),
];

class _NamingFieldSpec {
  const _NamingFieldSpec({
    required this.key,
    required this.label,
    required this.fallback,
    required this.tokens,
    this.note = '',
  });

  final String key;
  final String label;
  final String fallback;
  final List<String> tokens;
  final String note;
}

const _commonTokens = [
  'title',
  'original_title',
  'english_title',
  'year',
  'tmdb_id',
  'imdb_id',
  'douban_id',
];
const _fileAttrTokens = [
  'resolution',
  'video_codec',
  'hdr',
  'bit_depth',
  'audio',
  'media_source',
  'release_group',
  'site',
  'release_name',
];

const _namingFields = <_NamingFieldSpec>[
  _NamingFieldSpec(
    key: 'naming_entry_dir',
    label: '影片 / 剧集根目录',
    note: '电影和剧集共用此目录模板',
    fallback: '{title} ({year})',
    tokens: _commonTokens,
  ),
  _NamingFieldSpec(
    key: 'naming_movie_file',
    label: '电影文件名',
    fallback: '{title} ({year})',
    tokens: [..._commonTokens, ..._fileAttrTokens],
  ),
  _NamingFieldSpec(
    key: 'naming_season_dir',
    label: '季目录',
    fallback: 'Season {season:02d}',
    tokens: [..._commonTokens, 'season', 'season_name'],
  ),
  _NamingFieldSpec(
    key: 'naming_episode_file',
    label: '剧集文件名',
    fallback: '{title} ({year}) - S{season:02d}E{episode:02d}',
    tokens: [
      ..._commonTokens,
      ..._fileAttrTokens,
      'season',
      'season_name',
      'episode',
      'episode_title',
    ],
  ),
];

const _tokenGroups = <({String label, List<(String, String)> tokens})>[
  (
    label: '片名与编号',
    tokens: [
      ('title', '片名'),
      ('original_title', '原名'),
      ('english_title', '英文名'),
      ('year', '年份'),
      ('tmdb_id', 'TMDB ID'),
      ('imdb_id', 'IMDb ID'),
      ('douban_id', '豆瓣 ID'),
    ],
  ),
  (
    label: '季与集',
    tokens: [
      ('season', '季号'),
      ('season_name', '季名'),
      ('episode', '集号'),
      ('episode_title', '分集标题'),
    ],
  ),
  (
    label: '视频规格',
    tokens: [
      ('resolution', '分辨率'),
      ('video_codec', '视频编码'),
      ('hdr', 'HDR'),
      ('bit_depth', '色深'),
      ('audio', '音轨'),
    ],
  ),
  (
    label: '来源与压制组',
    tokens: [
      ('media_source', '媒介来源'),
      ('release_group', '制作组'),
      ('site', '站点'),
      ('release_name', '原始发布名'),
    ],
  ),
];

const _sampleMovie = <String, String>{
  'title': '沙丘2',
  'original_title': 'Dune: Part Two',
  'english_title': 'Dune: Part Two',
  'year': '2024',
  'tmdb_id': '693134',
  'imdb_id': 'tt15239678',
  'douban_id': '35575567',
  'resolution': '2160p',
  'video_codec': 'HEVC',
  'hdr': 'DV',
  'bit_depth': '10bit',
  'audio': 'TrueHD Atmos 7.1',
  'media_source': 'BluRay',
  'release_group': 'FRDS',
  'site': 'hdsky',
  'release_name': 'Dune.Part.Two.2024.2160p.BluRay.DV.HEVC.TrueHD.7.1.Atmos-FRDS',
};

const _sampleEpisode = <String, String>{
  'title': '风筝',
  'original_title': '风筝',
  'english_title': 'Kite',
  'year': '2017',
  'tmdb_id': '68035',
  'imdb_id': 'tt6952510',
  'douban_id': '26340419',
  'season': '1',
  'season_name': '第 1 季',
  'episode': '3',
  'episode_title': '山城暗流',
  'resolution': '1080p',
  'video_codec': 'H.264',
  'bit_depth': '8bit',
  'audio': 'AAC 2.0',
  'media_source': 'WEB-DL',
  'release_group': 'CHDWEB',
  'site': 'chdbits',
  'release_name': 'Kite.2017.S01E03.1080p.WEB-DL.H264.AAC-CHDWEB',
};

final _tokenRe = RegExp(r'\{([A-Za-z0-9_]+)(?::0(\d)d)?\}');
final _bracketGroupRe = RegExp(r'[(\[【][^()\[\]【】]*[)\]】]');
final _forbiddenRe = RegExp(r'[\\/:*?"<>|]');

String? _validateNamingTemplate(_NamingFieldSpec field, String tpl) {
  final t = tpl.trim();
  if (t.isEmpty) return null;
  if (t.contains('/') || t.contains('\\')) return '模板中不能包含路径分隔符 / 或 \\';
  final unknown = <String>[];
  for (final m in _tokenRe.allMatches(t)) {
    final name = m.group(1) ?? '';
    if (!field.tokens.contains(name) && !unknown.contains(name)) {
      unknown.add(name);
    }
  }
  if (unknown.isNotEmpty) {
    return '包含不支持的占位符：${unknown.map((e) => '{$e}').join('、')}';
  }
  return null;
}

String _sanitizeSegment(String value) {
  var v = value.replaceAll(_forbiddenRe, ' ');
  v = v.replaceAll(RegExp(r'\s+'), ' ');
  return v.replaceAll(RegExp(r'^[\s.]+|[\s.]+$'), '');
}

String _tokenVal(Map<String, String> ctx, String name, String? pad) {
  final raw = ctx[name];
  if (raw == null || raw.isEmpty) return '';
  var text = _sanitizeSegment(raw);
  final width = int.tryParse(pad ?? '');
  if (width != null &&
      text.isNotEmpty &&
      RegExp(r'^\d+$').hasMatch(text) &&
      text.length < width) {
    text = text.padLeft(width, '0');
  }
  return text;
}

String _cutUtf8Bytes(String text, int limit) {
  final buf = StringBuffer();
  var used = 0;
  for (final ch in text.characters) {
    final b = utf8.encode(ch).length;
    if (used + b > limit) break;
    used += b;
    buf.write(ch);
  }
  return buf.toString();
}

String _renderOnce(String template, Map<String, String> ctx) {
  // ① 占位符全空的括号组丢弃
  final dropped = template.replaceAllMapped(_bracketGroupRe, (m) {
    final group = m.group(0) ?? '';
    final found = _tokenRe.allMatches(group).toList();
    if (found.isEmpty) return group;
    final allEmpty = found.every(
      (tm) => _tokenVal(ctx, tm.group(1) ?? '', tm.group(2)).isEmpty,
    );
    return allEmpty ? '' : group;
  });
  // ② 替换占位符
  final filled = dropped.replaceAllMapped(
    _tokenRe,
    (m) => _tokenVal(ctx, m.group(1) ?? '', m.group(2)),
  );
  // ③ 收缩清理
  var s = filled;
  s = s.replaceAllMapped(RegExp(r'([(\[【])[\s\-–]+'), (m) => m.group(1)!);
  s = s.replaceAllMapped(RegExp(r'[\s\-–]+([)\]】])'), (m) => m.group(1)!);
  s = s.replaceAll(RegExp(r'(?:\s*-\s*){2,}'), ' - ');
  s = s.replaceAll(RegExp(r'\s{2,}'), ' ');
  s = s.replaceAll(RegExp(r'^[\s\-–.]+|[\s\-–.]+$'), '');
  final res = _sanitizeSegment(s);
  return res.isEmpty ? '未命名' : res;
}

String _renderNaming(String template, Map<String, String> baseCtx) {
  final ctx = Map<String, String>.from(baseCtx);
  final seenTitles = <String>{};
  const titleKeys = {'title', 'original_title', 'english_title'};
  for (final m in _tokenRe.allMatches(template)) {
    final k = m.group(1) ?? '';
    if (!titleKeys.contains(k)) continue;
    final v = _tokenVal(ctx, k, null).toLowerCase();
    if (v.isEmpty) continue;
    if (!seenTitles.add(v)) ctx.remove(k);
  }
  var text = _renderOnce(template, ctx);
  const shrinkables = [
    'title',
    'original_title',
    'english_title',
    'episode_title',
    'season_name',
    'release_name',
  ];
  for (var i = 0; i < shrinkables.length * 2; i++) {
    final over = utf8.encode(text).length - 200;
    if (over <= 0) return text;
    String? longestKey;
    var longestLen = 0;
    for (final k in shrinkables) {
      final len = utf8.encode(_tokenVal(ctx, k, null)).length;
      if (len > longestLen) {
        longestLen = len;
        longestKey = k;
      }
    }
    if (longestKey == null || longestLen <= 30) break;
    final cut = _cutUtf8Bytes(
      _tokenVal(ctx, longestKey, null),
      (longestLen - over).clamp(30, longestLen),
    );
    ctx[longestKey] = cut.replaceAll(RegExp(r'^[ .-]+|[ .-]+$'), '');
    text = _renderOnce(template, ctx);
  }
  final res = _sanitizeSegment(_cutUtf8Bytes(text, 200));
  return res.isEmpty ? '未命名' : res;
}

String _fmtGbMb(int bytes) {
  final gb = bytes / 1073741824.0;
  if (gb >= 1.0) return '${gb.toStringAsFixed(1)} GB';
  final mb = (bytes / 1048576.0).round();
  return '${mb < 1 ? 1 : mb} MB';
}

// ── 刮削与网盘主页（保留类名 ScrapeDrivesAdminPage 兼容已有路由）──────────────

/// 6) 刮削与整理（完整 9 张卡片 + 真后端 schema）& 网盘账号管理页。
class ScrapeDrivesAdminPage extends ConsumerStatefulWidget {
  const ScrapeDrivesAdminPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<ScrapeDrivesAdminPage> createState() =>
      _ScrapeDrivesAdminPageState();
}

class _ScrapeDrivesAdminPageState extends ConsumerState<ScrapeDrivesAdminPage> {
  late int _tab = widget.initialTab.clamp(0, 1); // 0=刮削与整理, 1=网盘账号
  Map<String, dynamic> _setting = {};
  Map<String, dynamic> _effective = {};
  Map<String, List<String>> _overridesByField = {};
  List<_ChipOpt> _extraMetaLangs = const [];
  List<_ChipOpt> _extraImageLangs = const [];
  List<_ChipOpt> _extraCountries = const [];
  Map<String, dynamic>? _estimate;
  Map<String, dynamic>? _fanartStatus;
  List<Map<String, dynamic>> _drives = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  McClient get _mc => ref.read(mcClientProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = _setting.isEmpty;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _mc.unwrap<Map<String, dynamic>>(
          Channel.general,
          'GET',
          '/api/v1/scrape/config',
        ),
        _mc
            .unwrap<dynamic>(
              Channel.general,
              'GET',
              '/api/v1/scrape/language-options',
            )
            .catchError((_) => const <dynamic>[]),
        _mc
            .unwrap<dynamic>(
              Channel.general,
              'GET',
              '/api/v1/scrape/country-options',
            )
            .catchError((_) => const <dynamic>[]),
        _mc
            .unwrap<Map<String, dynamic>>(
              Channel.general,
              'GET',
              '/api/v1/scrape/storage-estimate',
            )
            .catchError((_) => <String, dynamic>{}),
        _mc
            .unwrap<Map<String, dynamic>>(
              Channel.general,
              'GET',
              '/api/v1/scrape/fanart',
            )
            .catchError((_) => <String, dynamic>{}),
        _mc
            .unwrap<dynamic>(
              Channel.general,
              'GET',
              '/api/v1/drives/accounts',
            )
            .catchError((_) => const <dynamic>[]),
      ]);

      final cfg = results[0] as Map<String, dynamic>;
      _acceptScrapeConfig(cfg);

      // 解析全量语言/地区选项
      final langList = (results[1] is List ? results[1] as List : const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      final countryList = (results[2] is List ? results[2] as List : const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();

      String langName(Map<String, dynamic> l) {
        final n = (l['name'] ?? '').toString();
        if (n.isNotEmpty) return n;
        final en = (l['english_name'] ?? l['englishName'] ?? '').toString();
        if (en.isNotEmpty) return en;
        return (l['code'] ?? '').toString();
      }

      final est = results[3] as Map<String, dynamic>;
      final fanart = results[4] as Map<String, dynamic>;
      final drRaw = results[5];
      final drList = drRaw is List
          ? drRaw
          : (drRaw is Map
              ? (drRaw['items'] ?? drRaw['accounts'] ?? const [])
                  as List<dynamic>
              : const <dynamic>[]);

      if (!mounted) return;
      setState(() {
        _extraMetaLangs = langList
            .where((l) {
              final code = (l['code'] ?? '').toString();
              return code.isNotEmpty &&
                  !_commonMetaLangs.any((c) => c.id.startsWith('$code-'));
            })
            .map((l) => _ChipOpt((l['code'] ?? '').toString(), langName(l)))
            .toList();
        _extraImageLangs = langList
            .where((l) {
              final code = (l['code'] ?? '').toString();
              return code.isNotEmpty &&
                  !_commonImageLangs.any((c) => c.id == code);
            })
            .map((l) => _ChipOpt((l['code'] ?? '').toString(), langName(l)))
            .toList();
        _extraCountries = countryList
            .where((c) {
              final code = (c['code'] ?? '').toString();
              return code.isNotEmpty &&
                  !_commonCertCountries.any((x) => x.id == code);
            })
            .map(
              (c) => _ChipOpt(
                (c['code'] ?? '').toString(),
                (c['name'] ?? c['code'] ?? '').toString(),
              ),
            )
            .toList();
        _estimate = est.isNotEmpty ? est : null;
        _fanartStatus = fanart.isNotEmpty ? fanart : null;
        _drives =
            drList.whereType<Map>().map(Map<String, dynamic>.from).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = settingsErrorText(e);
        });
      }
    }
  }

  void _acceptScrapeConfig(Map<String, dynamic> cfg) {
    final settingRaw = cfg['setting'];
    final effectiveRaw = cfg['effective'];
    _setting = settingRaw is Map
        ? Map<String, dynamic>.from(settingRaw)
        : Map<String, dynamic>.from(cfg);
    _effective = effectiveRaw is Map
        ? Map<String, dynamic>.from(effectiveRaw)
        : <String, dynamic>{};

    final map = <String, List<String>>{};
    final rawOv = cfg['library_overrides'] ?? cfg['overrides'];
    if (rawOv is List) {
      for (final item in rawOv) {
        if (item is! Map) continue;
        final libName = (item['library_name'] ?? item['name'] ?? '').toString();
        final keys = (item['fields'] ?? item['overridden_fields'] ?? item['keys']);
        if (libName.isNotEmpty && keys is List) {
          for (final k in keys) {
            map.putIfAbsent(k.toString(), () => []).add(libName);
          }
        }
      }
    } else if (rawOv is Map) {
      for (final e in rawOv.entries) {
        if (e.value is List) {
          map[e.key.toString()] =
              (e.value as List).map((x) => x.toString()).toList();
        }
      }
    }
    _overridesByField = map;
  }

  List<String> _overriddenLibsFor(List<String> keys) {
    final set = <String>{};
    for (final k in keys) {
      final libs = _overridesByField[k];
      if (libs != null) set.addAll(libs);
    }
    return set.toList();
  }

  Future<bool> _savePatch(Map<String, dynamic> patch) async {
    setState(() => _saving = true);
    try {
      final updated = await _mc.unwrap<Map<String, dynamic>>(
        Channel.general,
        'PUT',
        '/api/v1/scrape/config',
        body: patch,
      );
      if (mounted) {
        setState(() => _acceptScrapeConfig(updated));
        McToast.success('刮削配置已保存');
      }
      // 刷新估算
      _mc
          .unwrap<Map<String, dynamic>>(
            Channel.general,
            'GET',
            '/api/v1/scrape/storage-estimate',
          )
          .then((est) {
        if (mounted && est.isNotEmpty) setState(() => _estimate = est);
      }).catchError((_) {});
      return true;
    } catch (e) {
      if (mounted) McToast.error(settingsErrorText(e));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _strList(String key, List<String> fallback) {
    final raw = _setting[key];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return fallback;
  }

  String _labelFor(List<_ChipOpt> base, List<_ChipOpt> extra, String id) {
    for (final o in base) {
      if (o.id == id) return o.name;
    }
    for (final o in extra) {
      if (o.id == id) return o.name;
    }
    return id;
  }

  String _joinLabels(
    List<_ChipOpt> base,
    List<_ChipOpt> extra,
    List<String> vals,
  ) =>
      vals.map((v) => _labelFor(base, extra, v)).join(' → ');

  // ── 9 张刮削卡片编辑器 ───────────────────────────────────────────────────

  Future<void> _openOrderEditor({
    required String title,
    required String desc,
    required String fieldKey,
    required List<_ChipOpt> common,
    required List<_ChipOpt> extra,
    required List<String> initial,
    required int maxItems,
    List<String> overriddenLibs = const [],
  }) async {
    final list = List<String>.from(initial);
    var search = '';
    final ok = await showMcSheet<bool>(
      context: context,
      maxWidth: 580,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final kw = search.trim().toLowerCase();
          final allExtra = extra.where((o) {
            if (list.contains(o.id)) return false;
            if (kw.isEmpty) return true;
            return o.name.toLowerCase().contains(kw) ||
                o.id.toLowerCase().contains(kw);
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: McText.titleSm),
                const SizedBox(height: 4),
                Text(desc, style: McText.caption.muted),
                if (overriddenLibs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SettingsNoticeBanner(
                    text: '以下媒体库已单独覆盖此项：${overriddenLibs.join('、')}',
                    tone: SettingsTone.info,
                    margin: EdgeInsets.zero,
                  ),
                ],
                const SizedBox(height: 12),
                Text('当前优先级（可拖动或点箭头调整顺序，最多 $maxItems 项）',
                    style: McText.caption.semibold),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  Text('尚未选择', style: McText.caption.faint)
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    onReorder: (oldIdx, newIdx) => setSheet(() {
                      if (newIdx > oldIdx) newIdx--;
                      final item = list.removeAt(oldIdx);
                      list.insert(newIdx, item);
                    }),
                    itemBuilder: (_, idx) {
                      final id = list[idx];
                      return ListTile(
                        key: ValueKey('ord-$id'),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Text(
                          '${idx + 1}',
                          style: McText.caption.tabular.semibold,
                        ),
                        title: Text(
                          _labelFor(common, extra, id),
                          style: McText.sub.copyWith(color: McTokens.text),
                        ),
                        subtitle: Text(
                          idx == 0 ? '首选 · $id' : id,
                          style: McText.micro.faint,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (list.length > 1)
                              IconButton(
                                icon: const Icon(McIcons.close, size: 16),
                                onPressed: () =>
                                    setSheet(() => list.removeAt(idx)),
                              ),
                            const Icon(
                              McIcons.draggableS,
                              size: 16,
                              color: McTokens.textFaint,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                Text('常用快捷添加', style: McText.caption.muted),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final o in common)
                      McChip(
                        label: o.name,
                        compact: true,
                        selected: list.contains(o.id),
                        onTap: () => setSheet(() {
                          if (list.contains(o.id)) {
                            if (list.length > 1) list.remove(o.id);
                          } else if (list.length < maxItems) {
                            list.add(o.id);
                          } else {
                            McToast.info('最多选择 $maxItems 项');
                          }
                        }),
                      ),
                  ],
                ),
                if (extra.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(McIcons.search, size: 17),
                      hintText: '搜索更多语言 / 地区…',
                    ),
                    onChanged: (v) => setSheet(() => search = v),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: allExtra.length.clamp(0, 40),
                      itemBuilder: (_, idx) {
                        final o = allExtra[idx];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${o.name} (${o.id})', style: McText.sub),
                          trailing: const Icon(McIcons.addS, size: 16),
                          onTap: () => setSheet(() {
                            if (list.length < maxItems) {
                              list.add(o.id);
                            } else {
                              McToast.info('最多选择 $maxItems 项');
                            }
                          }),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                McActionPill(
                  label: '保存顺序',
                  primary: true,
                  expanded: true,
                  onTap: list.isEmpty ? null : () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok == true) {
      await _savePatch({fieldKey: list});
    }
  }

  Future<void> _openImageSourcesSheet() async {
    var fanartEnabled = _setting['fanart_enabled'] == true;
    var posterOrder = _strList('poster_source_order', ['tmdb', 'fanart']);
    var backdropOrder = _strList('backdrop_source_order', ['tmdb', 'fanart']);
    var logoOrder = _strList('logo_source_order', ['fanart', 'tmdb']);
    var seasonOrder =
        _strList('season_poster_source_order', ['fanart', 'tmdb']);
    var fanart = _fanartStatus ?? <String, dynamic>{};

    await showMcSheet<void>(
      context: context,
      maxWidth: 580,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final configured = fanart['configured'] == true;
          final keyInvalid = fanart['key_invalid'] == true;
          final keyHint = (fanart['key_hint'] ?? '').toString();
          final usable = configured && !keyInvalid;

          Future<void> editKey() async {
            final key = await textInputDialog(
              ctx,
              title: configured ? '更换 Fanart.tv API Key' : '配置 Fanart.tv API Key',
              hint: '粘贴 Personal API Key（提交时自动校验）',
              obscureText: true,
            );
            if (key == null || key.trim().isEmpty) return;
            try {
              final res = await _mc.unwrap<Map<String, dynamic>>(
                Channel.general,
                'PUT',
                '/api/v1/scrape/fanart',
                body: {'api_key': key.trim()},
              );
              setSheet(() {
                fanart = res;
                _fanartStatus = res;
                fanartEnabled = true;
              });
              await _savePatch({'fanart_enabled': true});
              McToast.success('Fanart.tv 密钥已验证并启用');
            } catch (e) {
              McToast.error(settingsErrorText(e));
            }
          }

          Widget orderRow(
            String label,
            String fieldKey,
            List<String> order,
            void Function(List<String>) setOrder,
          ) {
            final text = order
                .map((s) => s == 'fanart' ? 'Fanart.tv' : 'TMDB')
                .join(' → ');
            return McInsetRow(
              title: label,
              subtitle: text,
              trailing: McChip(
                label: '对调顺序',
                compact: true,
                onTap: !fanartEnabled
                    ? null
                    : () async {
                        final next = order.reversed.toList();
                        setSheet(() => setOrder(next));
                        await _savePatch({fieldKey: next});
                      },
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('图片来源与 Fanart.tv', style: McText.titleSm),
                const SizedBox(height: 12),
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  header: '图源服务',
                  children: [
                    const McInsetRow(title: 'TMDB', valueText: '始终启用'),
                    McInsetRow(
                      title: 'Fanart.tv 高清图源',
                      subtitle: keyInvalid
                          ? '密钥已失效，请重新验证'
                          : (configured
                              ? '已配置密钥 ••••$keyHint'
                              : '需配置免费 Personal API Key 启用'),
                      trailing: Switch(
                        value: fanartEnabled,
                        onChanged: (v) async {
                          if (v && !usable) {
                            await editKey();
                            return;
                          }
                          setSheet(() => fanartEnabled = v);
                          await _savePatch({'fanart_enabled': v});
                        },
                      ),
                    ),
                    McInsetRow(
                      icon: McIcons.key,
                      title: configured ? '更换 Fanart.tv 密钥' : '配置 Fanart.tv 密钥',
                      onTap: editKey,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  header: '四类图片优先来源（启用 Fanart.tv 后生效）',
                  children: [
                    orderRow('海报', 'poster_source_order', posterOrder,
                        (v) => posterOrder = v),
                    orderRow('背景图', 'backdrop_source_order', backdropOrder,
                        (v) => backdropOrder = v),
                    orderRow('标题 Logo', 'logo_source_order', logoOrder,
                        (v) => logoOrder = v),
                    orderRow('季海报', 'season_poster_source_order', seasonOrder,
                        (v) => seasonOrder = v),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPosterSheet() async {
    var mode = (_setting['poster_mode'] ?? 'default').toString();
    final langs = _strList('poster_language_priority', ['meta', 'en', 'orig', 'null']);
    final ok = await showMcSheet<bool>(
      context: context,
      maxWidth: 580,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('海报策略', style: McText.titleSm),
              const SizedBox(height: 12),
              McInsetGroup(
                margin: EdgeInsets.zero,
                children: [
                  McInsetRow(
                    title: 'TMDB 默认海报',
                    subtitle: '采用 TMDB 官方主海报（投票最高）',
                    trailing: mode == 'default'
                        ? const Icon(McIcons.checkCircleFill,
                            color: McTokens.ok, size: 19)
                        : null,
                    onTap: () => setSheet(() => mode = 'default'),
                  ),
                  McInsetRow(
                    title: '按语言优先级选图',
                    subtitle: '按下方语言顺序挑选带对应文字或无字海报',
                    trailing: mode == 'language'
                        ? const Icon(McIcons.checkCircleFill,
                            color: McTokens.ok, size: 19)
                        : null,
                    onTap: () => setSheet(() => mode = 'language'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (mode == 'language' || _setting['fanart_enabled'] == true) ...[
                Text('海报语言优先级（点击增删）', style: McText.caption.muted),
                const SizedBox(height: 6),
                Text(
                  _joinLabels(_commonImageLangs, _extraImageLangs, langs),
                  style: McText.sub.copyWith(color: McTokens.accentStrong),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final o in _commonImageLangs)
                      McChip(
                        label: o.name,
                        compact: true,
                        selected: langs.contains(o.id),
                        onTap: () => setSheet(() {
                          if (langs.contains(o.id)) {
                            if (langs.length > 1) langs.remove(o.id);
                          } else if (langs.length < 4) {
                            langs.add(o.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              McActionPill(
                label: '保存海报设置',
                primary: true,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await _savePatch({
        'poster_mode': mode,
        'poster_language_priority': langs,
      });
    }
  }

  Future<void> _openQualitySheet() async {
    var quality = (_setting['image_quality'] ?? '').toString();
    if (quality.isEmpty) {
      quality = (_effective['image_quality'] ?? 'original').toString();
    }
    var posterSize = (_setting['poster_size'] ?? '').toString();
    var backdropSize = (_setting['backdrop_size'] ?? '').toString();
    var stillSize = (_setting['still_size'] ?? '').toString();
    var profileSize = (_setting['profile_size'] ?? '').toString();
    final pMinCtrl = TextEditingController(
      text: '${(_setting['poster_min_width'] as num?)?.toInt() ?? 0}',
    );
    final bMinCtrl = TextEditingController(
      text: '${(_setting['backdrop_min_width'] as num?)?.toInt() ?? 0}',
    );

    final presetsEst = _estimate?['presets'] is Map
        ? Map<String, dynamic>.from(_estimate!['presets'] as Map)
        : const <String, dynamic>{};

    final ok = await showMcSheet<bool>(
      context: context,
      maxWidth: 580,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          String? estLabel(String qId) {
            final v = presetsEst[qId];
            if (v is num) return '预计占用 ${_fmtGbMb(v.toInt())}';
            if (qId == 'custom' &&
                _estimate?['current_quality'] == 'custom' &&
                _estimate?['current_bytes'] is num) {
              return '当前占用 ${_fmtGbMb((_estimate!['current_bytes'] as num).toInt())}';
            }
            return null;
          }

          Widget sizeDrop(
            String label,
            String val,
            List<String> opts,
            ValueChanged<String> onChanged,
          ) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<String>(
                  value: opts.contains(val) ? val : '',
                  decoration: InputDecoration(labelText: label),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('跟随默认')),
                    for (final o in opts)
                      DropdownMenuItem(value: o, child: Text(o)),
                  ],
                  onChanged: (v) => setSheet(() => onChanged(v ?? '')),
                ),
              );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('图片画质与最低分辨率门槛', style: McText.titleSm),
                const SizedBox(height: 12),
                McInsetGroup(
                  margin: EdgeInsets.zero,
                  header: '本地图片画质预设',
                  children: [
                    for (final q in _imageQualities)
                      McInsetRow(
                        title: q.title,
                        subtitle: [
                          if (estLabel(q.id) != null) estLabel(q.id)!,
                          q.desc,
                        ].join(' · '),
                        trailing: quality == q.id
                            ? const Icon(
                                McIcons.checkCircleFill,
                                color: McTokens.ok,
                                size: 19,
                              )
                            : null,
                        onTap: () => setSheet(() {
                          quality = q.id;
                          if (q.id == 'custom') {
                            if (posterSize.isEmpty) {
                              posterSize =
                                  (_effective['poster_size'] ?? '').toString();
                            }
                            if (backdropSize.isEmpty) {
                              backdropSize =
                                  (_effective['backdrop_size'] ?? '').toString();
                            }
                            if (stillSize.isEmpty) {
                              stillSize =
                                  (_effective['still_size'] ?? '').toString();
                            }
                            if (profileSize.isEmpty) {
                              profileSize =
                                  (_effective['profile_size'] ?? '').toString();
                            }
                          }
                        }),
                      ),
                  ],
                ),
                if (quality == 'custom') ...[
                  const SizedBox(height: 12),
                  sizeDrop('海报档位', posterSize, _posterSizes,
                      (v) => posterSize = v),
                  sizeDrop('背景图档位', backdropSize, _backdropSizes,
                      (v) => backdropSize = v),
                  sizeDrop('分集剧照档位', stillSize, _stillSizes,
                      (v) => stillSize = v),
                  sizeDrop('演职员头像档位', profileSize, _profileSizes,
                      (v) => profileSize = v),
                ],
                const SizedBox(height: 12),
                Text('最低分辨率门槛（像素宽度，0 表示不限）',
                    style: McText.caption.muted),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pMinCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: '海报最小宽度 (px)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: bMinCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: '背景图最小宽度 (px)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                McActionPill(
                  label: '保存画质与门槛',
                  primary: true,
                  expanded: true,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok == true) {
      await _savePatch({
        'image_quality': quality,
        'poster_size': posterSize,
        'backdrop_size': backdropSize,
        'still_size': stillSize,
        'profile_size': profileSize,
        'poster_min_width': int.tryParse(pMinCtrl.text.trim()) ?? 0,
        'backdrop_min_width': int.tryParse(bMinCtrl.text.trim()) ?? 0,
      });
    }
  }

  Future<void> _openNamingSheet() async {
    final ctrls = <String, TextEditingController>{
      for (final f in _namingFields)
        f.key: TextEditingController(text: (_setting[f.key] ?? '').toString()),
    };
    var focusedKey = 'naming_episode_file';

    final ok = await showMcSheet<bool>(
      context: context,
      maxWidth: 640,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          String effectiveTpl(String key) {
            final f = _namingFields.firstWhere((e) => e.key == key);
            final raw = ctrls[key]!.text.trim();
            return raw.isEmpty ? f.fallback : raw;
          }

          final errs = <String, String?>{
            for (final f in _namingFields)
              f.key: _validateNamingTemplate(f, ctrls[f.key]!.text),
          };
          final allValid = errs.values.every((e) => e == null);
          final focusedField =
              _namingFields.firstWhere((e) => e.key == focusedKey);

          void insertToken(String tok) {
            final ctrl = ctrls[focusedField.key]!;
            final raw = ctrl.text;
            final base = raw.isEmpty ? focusedField.fallback : raw;
            final sel = ctrl.selection;
            final start = (raw.isNotEmpty && sel.isValid)
                ? sel.start.clamp(0, base.length)
                : base.length;
            final end = (raw.isNotEmpty && sel.isValid)
                ? sel.end.clamp(start, base.length)
                : base.length;
            final inserted = '{$tok}';
            final next = base.replaceRange(start, end, inserted);
            ctrl.value = TextEditingValue(
              text: next,
              selection: TextSelection.collapsed(offset: start + inserted.length),
            );
            setSheet(() {});
          }

          final moviePreview =
              '电影/${_renderNaming(effectiveTpl('naming_entry_dir'), _sampleMovie)}/'
              '${_renderNaming(effectiveTpl('naming_movie_file'), _sampleMovie)}.mkv';
          final tvPreview =
              '剧集/${_renderNaming(effectiveTpl('naming_entry_dir'), _sampleEpisode)}/'
              '${_renderNaming(effectiveTpl('naming_season_dir'), _sampleEpisode)}/'
              '${_renderNaming(effectiveTpl('naming_episode_file'), _sampleEpisode)}.mkv';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('入库命名模板', style: McText.titleSm),
                    ),
                    McChip(
                      label: '恢复默认',
                      compact: true,
                      onTap: () => setSheet(() {
                        for (final c in ctrls.values) {
                          c.clear();
                        }
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final f in _namingFields) ...[
                  Focus(
                    onFocusChange: (hasFocus) {
                      if (hasFocus) setSheet(() => focusedKey = f.key);
                    },
                    child: TextField(
                      controller: ctrls[f.key],
                      style: McText.caption.copyWith(fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        labelText: f.label,
                        hintText: f.fallback,
                        helperText: f.note.isNotEmpty ? f.note : null,
                        errorText: errs[f.key],
                      ),
                      onChanged: (_) => setSheet(() {}),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  '点击插入占位符到「${focusedField.label}」',
                  style: McText.caption.semibold,
                ),
                const SizedBox(height: 6),
                for (final g in _tokenGroups) ...[
                  Builder(
                    builder: (context) {
                      final allowed = g.tokens
                          .where((t) => focusedField.tokens.contains(t.$1))
                          .toList();
                      if (allowed.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final (k, name) in allowed)
                              McChip(
                                label: '$name {$k}',
                                compact: true,
                                onTap: () => insertToken(k),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: McTokens.surfaceInset,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: McTokens.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('实时路径预览', style: McText.caption.semibold),
                          const Spacer(),
                          SettingsStatusBadge(
                            label: allValid ? '模板合法' : '模板有误',
                            tone: allValid
                                ? SettingsTone.ok
                                : SettingsTone.danger,
                          ),
                        ],
                      ),
                      if (allValid) ...[
                        const SizedBox(height: 8),
                        Text('电影示例', style: McText.micro.faint),
                        SelectableText(
                          moviePreview,
                          style: McText.caption.copyWith(
                            fontFamily: 'monospace',
                            color: McTokens.accentStrong,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('剧集示例', style: McText.micro.faint),
                        SelectableText(
                          tvPreview,
                          style: McText.caption.copyWith(
                            fontFamily: 'monospace',
                            color: McTokens.accentStrong,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                McActionPill(
                  label: '保存命名模板',
                  primary: true,
                  expanded: true,
                  onTap: allValid ? () => Navigator.of(ctx).pop(true) : null,
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok == true) {
      await _savePatch({
        for (final f in _namingFields) f.key: ctrls[f.key]!.text.trim(),
      });
    }
    for (final c in ctrls.values) {
      c.dispose();
    }
  }

  Future<void> _openMirrorSheet() async {
    var mirrorImages = _setting['mirror_images'] != false;
    var mirrorNfo = _setting['mirror_nfo'] != false;
    var mirrorThumbs = _setting['mirror_episode_thumbs'] != false;
    final ok = await showMcSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('媒体目录写入（NFO 与本地图片）', style: McText.titleSm),
              const SizedBox(height: 12),
              McInsetGroup(
                margin: EdgeInsets.zero,
                children: [
                  McInsetRow(
                    title: '写入海报、背景图与 Logo',
                    subtitle: '保存到影片目录，兼容 Infuse / Kodi / Jellyfin',
                    trailing: Switch(
                      value: mirrorImages,
                      onChanged: (v) => setSheet(() => mirrorImages = v),
                    ),
                  ),
                  McInsetRow(
                    title: '写入 NFO 元数据文件',
                    subtitle: '生成 movie.nfo / tvshow.nfo / 分集 NFO',
                    trailing: Switch(
                      value: mirrorNfo,
                      onChanged: (v) => setSheet(() => mirrorNfo = v),
                    ),
                  ),
                  McInsetRow(
                    title: '写入分集剧照缩略图',
                    subtitle: '在季目录写入每集缩略图（episode-thumb.jpg）',
                    trailing: Switch(
                      value: mirrorThumbs,
                      onChanged: (v) => setSheet(() => mirrorThumbs = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              McActionPill(
                label: '保存写入策略',
                primary: true,
                expanded: true,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await _savePatch({
        'mirror_images': mirrorImages,
        'mirror_nfo': mirrorNfo,
        'mirror_episode_thumbs': mirrorThumbs,
      });
    }
  }

  String _qualitySummary() {
    final q = (_setting['image_quality'] ?? _effective['image_quality'] ?? 'original')
        .toString();
    final qLabel = switch (q) {
      'original' => '原图',
      'standard' => '标准',
      'compact' => '轻量',
      _ => '自定义',
    };
    final pw = (_setting['poster_min_width'] as num?)?.toInt() ?? 0;
    final bw = (_setting['backdrop_min_width'] as num?)?.toInt() ?? 0;
    return '$qLabel · 海报${pw > 0 ? '≥${pw}px' : '不限'} · 背景${bw > 0 ? '≥${bw}px' : '不限'}';
  }

  String _namingSummary() {
    final changed = _namingFields
        .where((f) => (_setting[f.key] ?? '').toString().trim().isNotEmpty)
        .map((f) => f.label)
        .toList();
    return changed.isEmpty ? '全部使用默认模板' : '已自定义：${changed.join('、')}';
  }

  String _mirrorSummary() {
    final off = <String>[
      if (_setting['mirror_images'] == false) '图片',
      if (_setting['mirror_nfo'] == false) 'NFO',
      if (_setting['mirror_episode_thumbs'] == false) '分集剧照',
    ];
    return off.isEmpty ? '图片、NFO 与分集剧照全部写入' : '未写入：${off.join('、')}';
  }

  Widget _overrideBadge(List<String> keys) {
    final libs = _overriddenLibsFor(keys);
    if (libs.isEmpty) return const SizedBox.shrink();
    return SettingsStatusBadge(
      label: '${libs.length} 库已覆盖',
      tone: SettingsTone.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '刮削与云盘存储',
      actions: [
        McChip(label: '刷新', compact: true, onTap: _load),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              McTokens.pagePadding,
              4,
              McTokens.pagePadding,
              10,
            ),
            child: Row(
              children: [
                McChip(
                  icon: McIcons.imageEdit,
                  label: '刮削与整理 (9 项)',
                  compact: true,
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 8),
                McChip(
                  icon: McIcons.cloud,
                  label: '网盘账号 (${_drives.length})',
                  compact: true,
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: McTokens.line),
          Expanded(
            child: _loading
                ? const McLoadingView()
                : _error != null && _setting.isEmpty
                    ? McErrorView(text: _error!, onRetry: _load)
                    : _tab == 0
                        ? _buildScrapeList()
                        : _buildDrivesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScrapeList() {
    final metaLangs = _strList('language_priority', ['zh-CN', 'en-US']);
    final certCountries = _strList('cert_country_priority', ['CN', 'US']);
    final posterMode = (_setting['poster_mode'] ?? 'default').toString();
    final posterLangs =
        _strList('poster_language_priority', ['meta', 'en', 'orig', 'null']);
    final backdropLangs =
        _strList('backdrop_language_priority', ['null', 'meta', 'en']);
    final logoLangs =
        _strList('logo_language_priority', ['meta', 'en', 'orig', 'null']);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          McInsetGroup(
            header: '语言与分级',
            children: [
              McInsetRow(
                icon: McIcons.translate,
                title: '1. 元数据语言优先级',
                subtitle:
                    _joinLabels(_commonMetaLangs, _extraMetaLangs, metaLangs),
                trailing: _overrideBadge(const ['language_priority']),
                showChevron: true,
                onTap: _saving
                    ? null
                    : () => _openOrderEditor(
                          title: '元数据语言优先级',
                          desc: '刮削片名、简介和演职员时按此顺序回退匹配。',
                          fieldKey: 'language_priority',
                          common: _commonMetaLangs,
                          extra: _extraMetaLangs,
                          initial: metaLangs,
                          maxItems: 5,
                          overriddenLibs:
                              _overriddenLibsFor(const ['language_priority']),
                        ),
              ),
              McInsetRow(
                icon: McIcons.shieldCheck,
                title: '2. 内容分级地区优先级',
                subtitle: _joinLabels(
                  _commonCertCountries,
                  _extraCountries,
                  certCountries,
                ),
                trailing: _overrideBadge(const ['cert_country_priority']),
                showChevron: true,
                onTap: _saving
                    ? null
                    : () => _openOrderEditor(
                          title: '内容分级地区优先级',
                          desc: '决定成员年龄限制优先参考哪个国家/地区的分级标准。',
                          fieldKey: 'cert_country_priority',
                          common: _commonCertCountries,
                          extra: _extraCountries,
                          initial: certCountries,
                          maxItems: 4,
                          overriddenLibs: _overriddenLibsFor(
                            const ['cert_country_priority'],
                          ),
                        ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          McInsetGroup(
            header: '图片选图与画质',
            children: [
              McInsetRow(
                icon: McIcons.image,
                title: '3. 图片来源与 Fanart.tv',
                subtitle: _setting['fanart_enabled'] == true
                    ? 'TMDB + Fanart.tv 已启用'
                    : '仅使用 TMDB',
                trailing: _overrideBadge(const [
                  'fanart_enabled',
                  'poster_source_order',
                  'backdrop_source_order',
                  'logo_source_order',
                  'season_poster_source_order',
                ]),
                showChevron: true,
                onTap: _saving ? null : _openImageSourcesSheet,
              ),
              McInsetRow(
                icon: McIcons.gallery1,
                title: '4. 海报选图策略',
                subtitle: posterMode == 'default'
                    ? 'TMDB 默认主海报'
                    : '按语言：${_joinLabels(_commonImageLangs, _extraImageLangs, posterLangs)}',
                trailing: _overrideBadge(
                  const ['poster_mode', 'poster_language_priority'],
                ),
                showChevron: true,
                onTap: _saving ? null : _openPosterSheet,
              ),
              McInsetRow(
                icon: McIcons.screenHorizontal,
                title: '5. 背景图语言优先级',
                subtitle: _joinLabels(
                  _commonImageLangs,
                  _extraImageLangs,
                  backdropLangs,
                ),
                trailing: _overrideBadge(const ['backdrop_language_priority']),
                showChevron: true,
                onTap: _saving
                    ? null
                    : () => _openOrderEditor(
                          title: '背景图语言优先级',
                          desc: '横屏剧照/背景图默认优先选无文字纯图。',
                          fieldKey: 'backdrop_language_priority',
                          common: _commonImageLangs,
                          extra: _extraImageLangs,
                          initial: backdropLangs,
                          maxItems: 4,
                          overriddenLibs: _overriddenLibsFor(
                            const ['backdrop_language_priority'],
                          ),
                        ),
              ),
              McInsetRow(
                icon: McIcons.watermark,
                title: '6. 标题 Logo 语言优先级',
                subtitle: _joinLabels(
                  _commonImageLangs,
                  _extraImageLangs,
                  logoLangs,
                ),
                trailing: _overrideBadge(const ['logo_language_priority']),
                showChevron: true,
                onTap: _saving
                    ? null
                    : () => _openOrderEditor(
                          title: '标题 Logo 语言优先级',
                          desc: '详情页与沉浸播放页透明标题 Logo 的语言偏好序。',
                          fieldKey: 'logo_language_priority',
                          common: _commonImageLangs,
                          extra: _extraImageLangs,
                          initial: logoLangs,
                          maxItems: 4,
                          overriddenLibs: _overriddenLibsFor(
                            const ['logo_language_priority'],
                          ),
                        ),
              ),
              McInsetRow(
                icon: McIcons.hd2,
                title: '7. 图片画质与最低分辨率门槛',
                subtitle: _qualitySummary(),
                trailing: _overrideBadge(const [
                  'image_quality',
                  'poster_min_width',
                  'backdrop_min_width',
                ]),
                showChevron: true,
                onTap: _saving ? null : _openQualitySheet,
              ),
            ],
          ),
          const SizedBox(height: 16),
          McInsetGroup(
            header: '文件整理与目录落地',
            children: [
              McInsetRow(
                icon: McIcons.fileCode2,
                title: '8. 入库命名模板与实时预览',
                subtitle: _namingSummary(),
                trailing: _overrideBadge(
                  _namingFields.map((f) => f.key).toList(),
                ),
                showChevron: true,
                onTap: _saving ? null : _openNamingSheet,
              ),
              McInsetRow(
                icon: McIcons.folderOpen,
                title: '9. 媒体目录写入（NFO / 图片 / 分集剧照）',
                subtitle: _mirrorSummary(),
                trailing: _overrideBadge(const [
                  'mirror_images',
                  'mirror_nfo',
                  'mirror_episode_thumbs',
                ]),
                showChevron: true,
                onTap: _saving ? null : _openMirrorSheet,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrivesList() {
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 36),
      children: [
        McInsetGroup(
          header: '网盘直连账号 (${_drives.length})',
          children: _drives.isEmpty
              ? const [
                  McInsetRow(
                    icon: McIcons.cloud,
                    title: '暂未挂载网盘账号',
                    subtitle: '支持 115 / 阿里云盘 / WebDAV / OpenList 直连串流',
                  ),
                ]
              : [
                  for (final d in _drives)
                    McInsetRow(
                      icon: McIcons.cloudFill,
                      title: (d['name'] ?? d['backend'] ?? '网盘账号').toString(),
                      subtitle: (d['backend'] ?? '').toString(),
                      trailing: IconButton(
                        icon: const Icon(
                          McIcons.trash2,
                          size: 17,
                          color: McTokens.danger,
                        ),
                        onPressed: () async {
                          final ok = await confirmDialog(
                            context,
                            title: '移除网盘账号？',
                            message: '移除后关联媒体库将无法继续直连该网盘。',
                            confirmLabel: '移除',
                          );
                          if (!ok) return;
                          await _mc.unwrap<dynamic>(
                            Channel.general,
                            'DELETE',
                            '/api/v1/drives/accounts/${d['id']}',
                          );
                          await _load();
                        },
                      ),
                    ),
                ],
        ),
      ],
    );
  }
}
