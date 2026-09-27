import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/observation_points.dart';
import '../models/news_models.dart';
import '../providers/brightness_controller.dart';
import '../providers/settings_provider.dart';
import 'attribution_screen.dart';

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
          Text('ニュース一覧の自動ページ送り', style: Theme.of(context).textTheme.titleMedium),
          _IntervalDropdown(
            value: settings.newsPageScrollMinutes,
            options: const [1, 2, 3, 5, 10, 0],
            label: (m) => m == 0
                ? '自動で送らない'
                : '$m分ごとに1ページ送る',
            onChanged: (v) => notifier.update(
              settings.copyWith(newsPageScrollMinutes: v),
            ),
          ),
          const Text(
            '最後まで送ると先頭に戻ります。「総合」は戻るたびに新着順⇔注目度順'
            '（はてなブックマーク数）を切り替えます。',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 24),
          Text('釣り情報と雨雲レーダーの切り替え間隔', style: Theme.of(context).textTheme.titleMedium),
          _IntervalDropdown(
            value: settings.panelSwitchIntervalMinutes,
            options: const [1, 3, 5, 10, 15, 30, 60, 0],
            label: (m) => m == 0 ? '自動で切り替えない（ボタンのみ）' : '$m分ごと',
            onChanged: (v) => notifier.update(
              settings.copyWith(panelSwitchIntervalMinutes: v),
            ),
          ),
          const SizedBox(height: 24),
          Text('時計の背景（NASAの宇宙写真）', style: Theme.of(context).textTheme.titleMedium),
          _IntervalDropdown(
            value: settings.apodSwitchIntervalMinutes,
            options: const [1, 5, 10, 15, 30, 60, 0],
            label: (m) => m == 0
                ? '切り替えない（グリッドのまま・全画面ボタンのみ）'
                : '$m分ごとにグリッドと写真を切り替える',
            onChanged: (v) => notifier.update(
              settings.copyWith(apodSwitchIntervalMinutes: v),
            ),
          ),
          _PercentSlider(
            label: '写真の不透明度',
            value: settings.apodBackgroundOpacity,
            min: 0.1,
            max: 0.8,
            onChangeEnd: (v) =>
                notifier.update(settings.copyWith(apodBackgroundOpacity: v)),
          ),
          _IntervalDropdown(
            value: settings.apodFullscreenAutoCloseMinutes,
            options: const [1, 3, 5, 10, 30],
            label: (m) => '全画面表示は$m分で自動的に戻る',
            onChanged: (v) => notifier.update(
              settings.copyWith(apodFullscreenAutoCloseMinutes: v),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.key),
            title: const Text('NASA APIキー（任意）'),
            subtitle: Text(
              settings.nasaApiKey.isEmpty
                  ? '未設定（共用のDEMO_KEYを使用）'
                  : '設定済み（末尾 ${_keyTail(settings.nasaApiKey)}）',
            ),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final key = await _showApiKeyDialog(context, settings.nasaApiKey);
              if (key != null) {
                notifier.update(settings.copyWith(nasaApiKey: key));
              }
            },
          ),
          const SizedBox(height: 24),
          Text('ニュース記事を自動で閉じるまでの時間', style: Theme.of(context).textTheme.titleMedium),
          _IntervalDropdown(
            value: settings.articleAutoCloseMinutes,
            options: const [1, 3, 5, 10, 30],
            label: (m) => '無操作のまま$m分で閉じる',
            onChanged: (v) => notifier.update(
              settings.copyWith(articleAutoCloseMinutes: v),
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
          Text('画面の明るさ（電源接続時）', style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'バッテリー駆動中は本体の明るさ設定に従います',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          _PercentSlider(
            label: '暗い状態（2:00〜19:00）',
            value: settings.dimBrightness,
            onPreview: (v) => ref
                .read(brightnessControllerProvider.notifier)
                .preview(forDim: true, value: v),
            onChangeEnd: (v) =>
                notifier.update(settings.copyWith(dimBrightness: v)),
          ),
          _PercentSlider(
            label: '明るい状態（19:00〜翌2:00）',
            value: settings.brightBrightness,
            onPreview: (v) => ref
                .read(brightnessControllerProvider.notifier)
                .preview(forDim: false, value: v),
            onChangeEnd: (v) =>
                notifier.update(settings.copyWith(brightBrightness: v)),
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
          const SizedBox(height: 24),
          Text('このアプリについて', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('データの出典・利用規約'),
            subtitle: const Text('気象庁・国土地理院・Open-Meteo・Wikipedia・NASA・ニュース配信元'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AttributionScreen()),
            ),
          ),
        ],
      ),
    );
  }

  static String _keyTail(String key) =>
      key.length <= 4 ? key : key.substring(key.length - 4);

  /// APIキーの入力ダイアログ。空にして保存すると DEMO_KEY に戻る。キャンセル時は null。
  Future<String?> _showApiKeyDialog(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NASA APIキー'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'api.nasa.gov で無料発行できます。空欄なら共用のDEMO_KEYを使います。',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            TextField(
              controller: controller,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'APIキー'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
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
    this.label = _everyMinutes,
  });

  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;
  final String Function(int minutes) label;

  static String _everyMinutes(int m) => '$m分ごと';

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: options.contains(value) ? value : options.first,
      items: [
        for (final m in options)
          DropdownMenuItem(value: m, child: Text(label(m))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// 割合（既定は輝度用の5%〜100%、5%刻み）を指定するスライダー。
/// ドラッグ中は[onPreview]で画面へ即時反映し、指を離した時点で[onChangeEnd]により保存する。
class _PercentSlider extends StatefulWidget {
  const _PercentSlider({
    required this.label,
    required this.value,
    this.onPreview,
    required this.onChangeEnd,
    this.min = 0.05,
    this.max = 1.0,
  });

  final String label;
  final double value;
  final ValueChanged<double>? onPreview;
  final ValueChanged<double> onChangeEnd;
  final double min;
  final double max;

  @override
  State<_PercentSlider> createState() => _PercentSliderState();
}

class _PercentSliderState extends State<_PercentSlider> {
  double get _min => widget.min;
  double get _max => widget.max;

  late double _value = widget.value.clamp(_min, _max);

  @override
  void didUpdateWidget(_PercentSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value.clamp(_min, _max);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 200, child: Text(widget.label)),
        Expanded(
          child: Slider(
            value: _value,
            min: _min,
            max: _max,
            // 5%刻み（輝度の0.05〜1.0なら19分割）。
            divisions: ((_max - _min) / 0.05).round(),
            label: '${(_value * 100).round()}%',
            onChanged: (v) {
              setState(() => _value = v);
              widget.onPreview?.call(v);
            },
            onChangeEnd: widget.onChangeEnd,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text('${(_value * 100).round()}%', textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
