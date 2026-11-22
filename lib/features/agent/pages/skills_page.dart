// Agent 技能页（对应 parity 清单 #24 的技能部分）：
// 服务端注册的技能列表（GET /api/v1/skills）：名称、说明、作用域。
// 技能由服务端定义，app 内只读展示；对话里模型按需调用。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../state/agent_state.dart';

class SkillsPage extends ConsumerStatefulWidget {
  const SkillsPage({super.key});

  @override
  ConsumerState<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends ConsumerState<SkillsPage> {
  late Future<List<core.SkillView>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(agentApiProvider).skills();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Agent 技能')),
        body: FutureBuilder<List<core.SkillView>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('加载失败：${snapshot.error}'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(
                          () => _future = ref.read(agentApiProvider).skills()),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }
            final skills = snapshot.data ?? const <core.SkillView>[];
            if (skills.isEmpty) {
              return const Center(child: Text('当前没有注册的技能'));
            }
            return ListView(
              children: [
                for (final s in skills)
                  ListTile(
                    leading: const Icon(Icons.psychology),
                    title: Text(s.name),
                    subtitle: Text(
                      [
                        if ((s.description ?? '').isNotEmpty)
                          s.description!,
                        if ((s.scope ?? '').isNotEmpty) '作用域：${s.scope}',
                      ].join('\n'),
                    ),
                  ),
              ],
            );
          },
        ),
      );
}
