// 网络页（对应 web settings network 分区）：
// 代理模式与地址、按服务指定代理、上游 API 地址（TMDB/豆瓣镜像）、
// 服务连通性测试。安卓 NetworkSettingsValidationTest 对应的校验在服务端做。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class NetworkPage extends ConsumerStatefulWidget {
  const NetworkPage({super.key});

  @override
  ConsumerState<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends ConsumerState<NetworkPage> {
  late Future<core.NetworkConfig> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<core.NetworkConfig> _load() =>
      ref.read(settingsApiProvider).networkConfig();

  void _reload() => setState(() => _future = _load());

  Future<void> _save(core.NetworkConfig next) async {
    try {
      await ref.read(settingsApiProvider).saveNetworkConfig(next);
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
        title: '网络',
        body: AdminAsyncBody<core.NetworkConfig>(
          future: _future,
          onRetry: _reload,
          builder: (context, config) => ListView(
            children: [
              const SettingsGroupLabel('代理'),
              AdminSelectTile<String>(
                title: '代理模式',
                value: config.proxyMode,
                options: const [
                  (value: 'off', label: '关闭'),
                  (value: 'system', label: '跟随系统'),
                  (value: 'manual', label: '手动'),
                ],
                onSelected: (v) =>
                    _save(config.copyWith(proxyMode: v)),
              ),
              AdminTextTile(
                title: '代理地址',
                value: config.proxyUrl,
                subtitle: config.proxyUrl.isEmpty
                    ? '手动模式下填写，如 http://127.0.0.1:7890'
                    : config.proxyUrl,
                hint: 'http://127.0.0.1:7890',
                onSaved: (v) => _save(config.copyWith(proxyUrl: v)),
              ),
              if (config.envProxyDetected.isNotEmpty)
                SettingsRow(
                  icon: Icons.info_outline,
                  title: '检测到环境代理',
                  subtitle: config.envProxyDetected,
                ),
              const SettingsGroupLabel('上游地址'),
              AdminTextTile(
                title: 'TMDB API 地址',
                value: config.tmdbApiBaseUrl,
                subtitle: config.tmdbApiBaseUrl.isEmpty
                    ? '默认'
                    : config.tmdbApiBaseUrl,
                onSaved: (v) =>
                    _save(config.copyWith(tmdbApiBaseUrl: v)),
              ),
              AdminTextTile(
                title: 'TMDB 图片地址',
                value: config.tmdbImageBaseUrl,
                subtitle: config.tmdbImageBaseUrl.isEmpty
                    ? '默认'
                    : config.tmdbImageBaseUrl,
                onSaved: (v) =>
                    _save(config.copyWith(tmdbImageBaseUrl: v)),
              ),
              AdminTextTile(
                title: '豆瓣 API 地址',
                value: config.doubanApiBaseUrl,
                subtitle: config.doubanApiBaseUrl.isEmpty
                    ? '默认'
                    : config.doubanApiBaseUrl,
                onSaved: (v) =>
                    _save(config.copyWith(doubanApiBaseUrl: v)),
              ),
              const SettingsGroupLabel('连通性测试'),
              if (config.services.isEmpty)
                const SettingsInfoCard(text: '服务端未返回可测试的服务。'),
              for (final s in config.services)
                SettingsRow(
                  icon: Icons.lan,
                  title: s.label.isEmpty ? s.id : s.label,
                  subtitle: s.description,
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        final result = await ref
                            .read(settingsApiProvider)
                            .testNetwork(s.id);
                        if (!context.mounted) return;
                        showSettingsToast(
                          context,
                          result.ok
                              ? '连通正常${result.latencyMs == null ? '' : '（${result.latencyMs}ms）'}'
                              : '不通：${result.message}',
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        showSettingsToast(context, '测试失败：$e');
                      }
                    },
                    child: const Text('测试'),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
}
