import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

/// アプリが利用している外部データの出典・利用条件の一覧。
///
/// 気象庁（政府標準利用規約）・国土地理院（地理院タイル）・Open-Meteo（CC BY 4.0）は
/// いずれも出典の表示を利用条件としているため、設定画面からいつでも確認できるようにしている。
class AttributionScreen extends ConsumerWidget {
  const AttributionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsSources = ref.watch(settingsProvider).newsSources;

    return Scaffold(
      appBar: AppBar(title: const Text('データの出典・利用規約')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Section(
            title: '気象庁',
            credit: '出典：気象庁ホームページ',
            usages: [
              '潮位表（満潮・干潮時刻と毎時潮位）',
              '高解像度降水ナウキャスト（雨雲レーダーの実況・予報）',
              '雷監視（雷ナウキャストの雷の観測位置）',
            ],
            notes: [
              '雨雲レーダーは、気象庁の降水ナウキャスト画像と雷の観測位置を、'
                  '地理院タイルの地図上に重ね合わせて表示しています。',
              '気象庁ホームページのコンテンツは「政府標準利用規約（第2.0版）」に準拠して'
                  '利用しています。',
            ],
            links: [
              'https://www.jma.go.jp/jma/kishou/info/coment.html',
              'https://www.jma.go.jp/bosai/nowc/',
              'https://www.data.jma.go.jp/kaiyou/db/tide/suisan/',
            ],
          ),
          const _Section(
            title: '国土地理院',
            credit: '出典：国土地理院（地理院タイル）',
            usages: ['雨雲レーダーの背景地図（淡色地図）'],
            notes: [
              '地理院タイルを加工して作成（ダークテーマに合わせて色を反転・減光）。',
            ],
            links: ['https://maps.gsi.go.jp/development/ichiran.html'],
          ),
          const _Section(
            title: 'Open-Meteo',
            credit: 'Weather data by Open-Meteo.com',
            usages: [
              '天気・気温・風速・気圧・降水確率（Forecast API）',
              '海面水温（Marine API）',
            ],
            notes: [
              'データは CC BY 4.0 ライセンスで提供されています。',
              '海面水温は衛星・数値モデルによる推定値で、内湾や河口の実際の水温とは'
                  '異なる場合があります。',
            ],
            links: [
              'https://open-meteo.com/',
              'https://creativecommons.org/licenses/by/4.0/',
            ],
          ),
          _Section(
            title: 'ニュース（RSS）',
            credit: '各記事の著作権は配信元に帰属します',
            usages: [
              for (final s in newsSources) '${s.name}（${s.rssUrl}）',
            ],
            notes: const [
              '記事一覧にはタイトル・配信元・配信時刻のみを表示し、本文は配信元のページを'
                  'そのまま表示しています。',
            ],
            links: const [],
          ),
          const SizedBox(height: 8),
          const Text(
            '日の出・日の入り・月齢は、端末内で天文計算により求めています（外部データなし）。',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: const Text('オープンソースライセンス'),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Wall JARVIS',
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.credit,
    required this.usages,
    required this.notes,
    required this.links,
  });

  final String title;
  final String credit;
  final List<String> usages;
  final List<String> notes;
  final List<String> links;

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 13, color: Colors.white70);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(credit, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('利用しているデータ', style: small),
            for (final u in usages) Text('・$u'),
            for (final n in notes) ...[
              const SizedBox(height: 6),
              Text(n, style: small),
            ],
            if (links.isNotEmpty) const SizedBox(height: 6),
            // キオスク端末で外部ブラウザへ飛ばないよう、URLは選択可能なテキストとして表示するだけにする。
            for (final l in links)
              SelectableText(
                l,
                style: const TextStyle(fontSize: 12, color: Colors.lightBlueAccent),
              ),
          ],
        ),
      ),
    );
  }
}
