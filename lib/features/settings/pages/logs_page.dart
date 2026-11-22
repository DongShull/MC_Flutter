// 系统日志页（对应 web settings logs 分区）：
// 按天浏览服务端日志（GET /logs/days、GET /logs/{day}），
// 支持按关键字过滤。日志内容可能很大，服务端会截断（truncated 标记）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' as core;
import '../../../core/models/format.dart';
import '../state/mc_api.dart';
import '../widgets/admin_widgets.dart';

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  late Future<core.LogDayList> _future;
  String? _selectedDay;
  Future<core.LogContent>? _contentFuture;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<core.LogDayList> _load() =>
      ref.read(settingsApiProvider).logDays();

  void _reload() => setState(() {
        _future = _load();
        _selectedDay = null;
        _contentFuture = null;
      });

  void _selectDay(String day) {
    setState(() {
      _selectedDay = day;
      _contentFuture = ref.read(settingsApiProvider).logContent(day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedDay;
    return SettingsScaffold(
      title: '系统日志',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: '过滤关键字',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Expanded(
            child: AdminAsyncBody<core.LogDayList>(
              future: _future,
              onRetry: _reload,
              builder: (context, days) {
                if (days.days.isEmpty) {
                  return const Center(child: Text('暂无日志'));
                }
                final contentFuture = _contentFuture;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      child: ListView(
                        children: [
                          for (final d in days.days)
                            ListTile(
                              selected: d.day == selected,
                              title: Text(d.day),
                              subtitle: Text(mcFormatBytes(d.sizeBytes)),
                              onTap: () => _selectDay(d.day),
                            ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: selected == null || contentFuture == null
                          ? const Center(child: Text('请在左侧选择一天'))
                          : AdminAsyncBody<core.LogContent>(
                              future: contentFuture,
                              onRetry: () => _selectDay(selected),
                              builder: (context, content) {
                                final lines = _filter.isEmpty
                                    ? content.lines
                                    : content.lines
                                        .where((l) => l
                                            .toLowerCase()
                                            .contains(
                                                _filter.toLowerCase()))
                                        .toList();
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        '${content.day} · 共 ${content.totalLines} 行'
                                        '${content.truncated ? '（已截断）' : ''}'
                                        '${_filter.isEmpty ? '' : ' · 过滤后 ${lines.length} 行'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium,
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: lines.length,
                                        itemBuilder: (context, i) => Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 2),
                                          child: SelectableText(
                                            lines[i],
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
