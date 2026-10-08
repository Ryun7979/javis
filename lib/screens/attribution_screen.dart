import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

/// アプリが利用している外部データの出典・利用条件の一覧。
///
/// 気象庁（政府標準利用規約）・国土地理院（地理院タイル）・Open-Meteo（CC BY 4.0）・
/// Wikipedia（CC BY-SA 4.0）は
/// いずれも出典の表示を利用条件としているため、設定画面からいつでも確認できるようにしている。
/// NASAの宇宙写真（APOD）は、著作者付きの写真があるため併せて載せている。
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
              '台風情報（台風の実況・経路・進路予報、暴風域・強風域・暴風警戒域）',
            ],
            notes: [
              '雨雲レーダーは、気象庁の降水ナウキャスト画像と雷の観測位置を、'
                  '地理院タイルの地図上に重ね合わせて表示しています。',
              '台風情報は、気象庁の発表した位置・予報円などを、地震情報と同じ地図上に'
                  '描き直して表示しています。防災の判断には気象庁の発表を確認してください。',
              '気象庁ホームページのコンテンツは「政府標準利用規約（第2.0版）」に準拠して'
                  '利用しています。',
            ],
            links: [
              'https://www.jma.go.jp/jma/kishou/info/coment.html',
              'https://www.jma.go.jp/bosai/nowc/',
              'https://www.jma.go.jp/bosai/typhoon/',
              'https://www.data.jma.go.jp/kaiyou/db/tide/suisan/',
            ],
          ),
          const _Section(
            title: '国土地理院',
            credit: '出典：国土地理院（地理院タイル）',
            usages: [
              '雨雲レーダーの背景地図（淡色地図）',
              '雨雲レーダーの海岸線・都道府県境（白地図）',
              '地震・台風情報の日本地図（淡色地図・白地図）',
            ],
            notes: [
              '地理院タイルを加工して作成（ダークテーマに合わせて色を反転・減光、'
                  '白地図は線だけを明るい灰色にして重ね合わせ）。',
            ],
            links: ['https://maps.gsi.go.jp/development/ichiran.html'],
          ),
          const _Section(
            title: 'P2P地震情報',
            credit: 'P2P地震情報 JSON API v2（気象庁の地震情報を配信）',
            usages: ['地震情報（震源・マグニチュード・最大震度・各地の震度・津波の有無）'],
            notes: [
              '商用・非商用を問わず無償で利用できるAPIです（二次利用の条件に従い、'
                  '元の情報が気象庁の地震情報であることを表示しています）。',
              '情報の正確性は保証されません。防災の判断には気象庁などの公式の発表を確認してください。',
            ],
            links: [
              'https://www.p2pquake.net/develop/json_api_v2/',
              'https://www.p2pquake.net/secondary_use/',
            ],
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
          const _Section(
            title: 'Wikipedia',
            credit: '出典：フリー百科事典『ウィキペディア（Wikipedia）』',
            usages: [
              '時計の下の「今日は何の日」（Wikipedia:今日は何の日）',
              '時計の下の「秀逸な記事」（その日の秀逸な記事の冒頭1文）',
            ],
            notes: [
              'テキストは CC BY-SA 4.0 ライセンスで提供されています。',
              '1行表示のため、リンクや脚注などの記法を取り除いて表示しています。',
            ],
            links: [
              'https://ja.wikipedia.org/',
              'https://creativecommons.org/licenses/by-sa/4.0/deed.ja',
            ],
          ),
          const _Section(
            title: 'NASA',
            credit: 'Astronomy Picture of the Day（NASA）',
            usages: ['時計の背景と全画面表示の宇宙写真（NASA Scienceのサイトの記事一覧）'],
            notes: [
              '公開された正式なAPIではないため、予告なく取得できなくなる場合があります。',
              '著作者の記載がない写真はNASAによるもので、パブリックドメインです。',
              '著作者の記載がある写真の著作権は各著作者に帰属します。全画面表示の下端に'
                  '著作者名を表示しています。',
            ],
            links: [
              'https://science.nasa.gov/apod/',
              'https://science.nasa.gov/apod/apod-about/',
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
          const _Section(
            title: 'はてなブックマーク',
            credit: 'はてなブックマーク件数取得API（株式会社はてな）',
            usages: ['ニュース「総合」の注目度順（各記事のブックマーク数）'],
            notes: [
              'ブックマーク数と配信からの経過時間をもとに端末内で並べ替えています。',
            ],
            links: ['https://developer.hatena.ne.jp/ja/documents/bookmark/apis/getcount'],
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
