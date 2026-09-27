import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefectures.dart';
import '../providers/settings_provider.dart';

/// 雨雲レーダーに県庁所在地のマークを出す都道府県を選ぶ画面。
///
/// 47件のチェックボックスを設定画面に並べると長くなるため、別画面に分けている。
/// チェックを変えるたびにすぐ保存する（保存ボタンは置かない）。
class CapitalMarkerSettingsScreen extends ConsumerWidget {
  const CapitalMarkerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final selected = settings.capitalMarkerPrefectures;

    void save(Set<int> codes) =>
        notifier.update(settings.copyWith(capitalMarkerPrefectures: codes));

    return Scaffold(
      appBar: AppBar(
        title: Text('県庁所在地のマーク（${selected.length}/${prefectures.length}）'),
        actions: [
          TextButton(
            onPressed: () => save(allPrefectureCodes),
            child: const Text('全選択'),
          ),
          TextButton(
            onPressed: () => save(const {}),
            child: const Text('全解除'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '雨雲レーダーで、チェックした都道府県の県庁所在地にマゼンタのマークを表示します。'
            '観測地点のマーク（シアン）と重なる場所には表示しません。',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          for (final region in JapanRegion.values) ...[
            const SizedBox(height: 16),
            _RegionHeader(
              region: region,
              selected: selected,
              onChanged: save,
            ),
            Wrap(
              children: [
                for (final p in prefectures)
                  if (p.region == region)
                    SizedBox(
                      width: 200,
                      child: CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(p.name),
                        subtitle: Text(p.capital),
                        value: selected.contains(p.code),
                        onChanged: (v) => save(
                          v == true
                              ? {...selected, p.code}
                              : ({...selected}..remove(p.code)),
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 地方の見出しと、その地方をまとめて選択・解除するボタン。
class _RegionHeader extends StatelessWidget {
  const _RegionHeader({
    required this.region,
    required this.selected,
    required this.onChanged,
  });

  final JapanRegion region;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final codes = {
      for (final p in prefectures)
        if (p.region == region) p.code,
    };
    final count = codes.where(selected.contains).length;
    return Row(
      children: [
        Text(
          '${region.label}地方',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(width: 8),
        Text(
          '$count/${codes.length}',
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => onChanged({...selected, ...codes}),
          child: const Text('すべて選択'),
        ),
        TextButton(
          onPressed: () => onChanged(selected.difference(codes)),
          child: const Text('すべて解除'),
        ),
      ],
    );
  }
}
