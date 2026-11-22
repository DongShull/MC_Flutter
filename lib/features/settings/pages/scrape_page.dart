// 刮削页（对应 web settings scrape 分区 / 安卓 ScrapeSettingsPage）：
// 全局刮削偏好：语言优先级、海报模式与尺寸、Fanart 密钥、存储预估。
// 每库级覆盖在「编辑库 → 刮削设置」里，不在本页。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../../../core/models/format.dart';
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class _ScrapeData {
  const _ScrapeData({
    required this.config,
    required this.fanart,
    required this.estimate,
  });

  final core.ScrapeConfigView config;
  final core.ScrapeFanartView fanart;
  final core.ScrapeStorageEstimate estimate;
}

class ScrapePage extends ConsumerStatefulWidget {
  const ScrapePage({super.key});

  @override
  ConsumerState<ScrapePage> createState() => _ScrapePageState();
}

class _ScrapePageState extends ConsumerState<ScrapePage> {
  late Future<_ScrapeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ScrapeData> _load() async {
    final api = ref.read(settingsApiProvider);
    final results = await Future.wait([
      api.scrapeShow(),
      api.scrapeFanartShow(),
      api.scrapeStorageEstimate(),
    ]);
    return _ScrapeData(
      config: results[0] as core.ScrapeConfigView,
      fanart: results[1] as core.ScrapeFanartView,
      estimate: results[2] as core.ScrapeStorageEstimate,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _save(core.ScrapeSetting next) async {
    try {
      await ref.read(settingsApiProvider).scrapeSet(next);
      if (!mounted) return;
      showSettingsToast(context, '已保存');
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '保存失败：$e');
    }
  }

  Future<void> _saveFanartKey() async {
    final key = await textInputDialog(context,
        title: 'Fanart API Key', hint: 'fanart.tv 的 API Key');
    if (key == null) return;
    try {
      await ref.read(settingsApiProvider).scrapeFanartSetKey(key);
      if (!mounted) return;
      showSettingsToast(context, '已保存');
      _reload();
    } catch (e) {
      if (!mounted) return;
      showSettingsToast(context, '保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: '刮削',
        body: AdminAsyncBody<_ScrapeData>(
          future: _future,
          onRetry: _reload,
          builder: (context, data) {
            final s = data.config.setting;
            final eff = data.config.effective;
            return ListView(
              children: [
                const SettingsGroupLabel('语言优先级'),
                AdminTextTile(
                  title: '语言优先级',
                  value: formatCommaList(s.languagePriority),
                  subtitle: '逗号分隔，如 zh-CN, zh-TW, en',
                  hint: 'zh-CN, en',
                  onSaved: (v) => _save(s.copyWith(
                      languagePriority: parseCommaList(v))),
                ),
                AdminTextTile(
                  title: '认证地区优先级',
                  value: formatCommaList(s.certCountryPriority),
                  subtitle: '逗号分隔，如 CN, US',
                  hint: 'CN, US',
                  onSaved: (v) => _save(s.copyWith(
                      certCountryPriority: parseCommaList(v))),
                ),
                const SettingsGroupLabel('海报'),
                AdminSelectTile<String>(
                  title: '海报模式',
                  value: s.posterMode,
                  options: const [
                    (value: 'language', label: '按语言优先'),
                    (value: 'default', label: '默认顺序'),
                  ],
                  onSelected: (v) =>
                      _save(s.copyWith(posterMode: v)),
                ),
                AdminTextTile(
                  title: '海报语言优先级',
                  value: formatCommaList(s.posterLanguagePriority),
                  subtitle: '逗号分隔，如 zh-CN, en',
                  onSaved: (v) => _save(s.copyWith(
                      posterLanguagePriority: parseCommaList(v))),
                ),
                AdminTextTile(
                  title: '背景语言优先级',
                  value: formatCommaList(s.backdropLanguagePriority),
                  subtitle: '逗号分隔，如 zh-CN, en',
                  onSaved: (v) => _save(s.copyWith(
                      backdropLanguagePriority: parseCommaList(v))),
                ),
                AdminTextTile(
                  title: '海报最小宽度',
                  value: s.posterMinWidth.toString(),
                  subtitle: '像素，0 = 不限',
                  keyboardType: TextInputType.number,
                  onSaved: (v) {
                    final n = int.tryParse(v);
                    if (n == null) {
                      showSettingsToast(context, '请输入数字');
                      return;
                    }
                    _save(s.copyWith(posterMinWidth: n));
                  },
                ),
                AdminTextTile(
                  title: '背景最小宽度',
                  value: s.backdropMinWidth.toString(),
                  subtitle: '像素，0 = 不限',
                  keyboardType: TextInputType.number,
                  onSaved: (v) {
                    final n = int.tryParse(v);
                    if (n == null) {
                      showSettingsToast(context, '请输入数字');
                      return;
                    }
                    _save(s.copyWith(backdropMinWidth: n));
                  },
                ),
                const SettingsGroupLabel('当前生效'),
                SettingsRow(
                  icon: Icons.photo,
                  title: '海报 ${eff.posterSize} · 背景 ${eff.backdropSize}',
                  subtitle:
                      '剧照 ${eff.stillSize} · 人物 ${eff.profileSize} · 质量 ${eff.imageQuality}',
                ),
                const SettingsGroupLabel('Fanart'),
                SettingsRow(
                  icon: Icons.key,
                  title: data.fanart.configured
                      ? 'Fanart Key 已配置${data.fanart.keyInvalid ? '（无效）' : ''}'
                      : 'Fanart Key 未配置',
                  subtitle: data.fanart.keyHint.isEmpty
                      ? '用于补充高清背景与 Logo'
                      : data.fanart.keyHint,
                  onTap: _saveFanartKey,
                ),
                const SettingsGroupLabel('存储预估'),
                SettingsRow(
                  icon: Icons.storage,
                  title:
                      '当前画质 ${data.estimate.currentQuality} · 约 ${mcFormatBytes(data.estimate.currentBytes)}',
                  subtitle: '切换画质后的预估见服务端返回',
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      );
}
