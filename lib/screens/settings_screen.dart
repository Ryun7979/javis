import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/observation_points.dart';
import '../models/news_models.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('観測地点', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField(
            initialValue: settings.location.id,
            items: [
              for (final p in observationPoints)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (id) {
              if (id == null) return;
              notifier.update(
                settings.copyWith(location: findObservationPoint(id)),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('潮汐・天気の自動更新間隔', style: Theme.of(context).textTheme.titleMedium),
          _IntervalDropdown(
            value: settings.tideWeatherUpdateIntervalMinutes,
            options: const [15, 30, 45, 60],
            onChanged: (v) => notifier.update(
              settings.copyWith(tideWeatherUpdateIntervalMinutes: v),
            ),
          ),
          const SizedBox(height: 24),
          Text('ニュースの自動更新間隔', style: Theme.of(context).textTheme.titleMedium),
          _IntervalDropdown(
            value: settings.newsUpdateIntervalMinutes,
            options: const [10, 15, 30, 60],
            onChanged: (v) => notifier.update(
              settings.copyWith(newsUpdateIntervalMinutes: v),
            ),
          ),
          const SizedBox(height: 24),
          Text('タイムゾーン', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('常に日本標準時(JST)を使う'),
            subtitle: const Text('端末のタイムゾーン設定によらず、時計・更新時刻・潮汐の日付判定を日本時間に固定します'),
            value: settings.useFixedJst,
            onChanged: (v) => notifier.update(settings.copyWith(useFixedJst: v)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('ニュース配信元', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final newSource = await _showSourceDialog(context);
                  if (newSource != null) {
                    notifier.update(
                      settings.copyWith(
                        newsSources: [...settings.newsSources, newSource],
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          for (final source in settings.newsSources)
            ListTile(
              title: Text(source.name),
              subtitle: Text('${source.category.label} ・ ${source.rssUrl}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => notifier.update(
                  settings.copyWith(
                    newsSources: settings.newsSources
                        .where((s) => s.rssUrl != source.rssUrl)
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<NewsSource?> _showSourceDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    var category = NewsCategory.game;

    return showDialog<NewsSource>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('ニュース配信元を追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名前'),
              ),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'RSS URL'),
              ),
              DropdownButtonFormField(
                initialValue: category,
                items: [
                  for (final c in NewsCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (v) => setState(() => category = v ?? category),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    urlController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(
                  NewsSource(
                    name: nameController.text.trim(),
                    category: category,
                    rssUrl: urlController.text.trim(),
                  ),
                );
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntervalDropdown extends StatelessWidget {
  const _IntervalDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: options.contains(value) ? value : options.first,
      items: [
        for (final m in options)
          DropdownMenuItem(value: m, child: Text('$m分ごと')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
