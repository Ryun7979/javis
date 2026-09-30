// 地震情報（P2P地震情報 code 551）の解析・まとめ方・自動切り替えの判定のテスト。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wall_jarvis/models/earthquake.dart';
import 'package:wall_jarvis/providers/core_providers.dart';
import 'package:wall_jarvis/providers/earthquake_controller.dart';
import 'package:wall_jarvis/services/earthquake_service.dart';
import 'package:wall_jarvis/widgets/news_quake_panel.dart';

/// 実データ（2026-09-29 04:45 茨城県南部、最大震度4）と同じ形の発表。新しい順。
Map<String, dynamic> report({
  required String type,
  required String issued,
  String time = '2026/09/29 04:45:00',
  double lat = 36.1,
  double lon = 139.9,
  int depth = 50,
  double mag = 4.9,
  String name = '茨城県南部',
  int maxScale = 40,
  String tsunami = 'None',
  List<Map<String, dynamic>> points = const [],
}) => {
  'code': 551,
  'issue': {'source': '気象庁', 'time': issued, 'type': type},
  'earthquake': {
    'time': time,
    'hypocenter': {
      'name': name,
      'latitude': lat,
      'longitude': lon,
      'depth': depth,
      'magnitude': mag,
    },
    'maxScale': maxScale,
    'domesticTsunami': tsunami,
  },
  'points': points,
};

Map<String, dynamic> scalePrompt({
  String time = '2026/09/29 04:45:00',
  String issued = '2026/09/29 04:46:43',
  int maxScale = 40,
}) => report(
  type: 'ScalePrompt',
  issued: issued,
  time: time,
  lat: -200,
  lon: -200,
  depth: -1,
  mag: -1,
  name: '',
  maxScale: maxScale,
  tsunami: 'Checking',
  points: [
    {'pref': '茨城県', 'addr': '茨城県南部', 'isArea': true, 'scale': maxScale},
  ],
);

final ibarakiSequence = [
  report(
    type: 'DetailScale',
    issued: '2026/09/29 04:49:17',
    points: [
      {'pref': '栃木県', 'addr': '宇都宮市', 'isArea': false, 'scale': 20},
      {'pref': '茨城県', 'addr': 'つくば市', 'isArea': false, 'scale': 40},
      {'pref': '茨城県', 'addr': '水戸市', 'isArea': false, 'scale': 30},
    ],
  ),
  report(type: 'Destination', issued: '2026/09/29 04:47:52', maxScale: -1),
  scalePrompt(),
];

void main() {
  group('Earthquake.parseJst', () {
    test('日本時間をUTCに直す', () {
      expect(
        Earthquake.parseJst('2026/09/30 08:05:00'),
        DateTime.utc(2026, 9, 29, 23, 5),
      );
      expect(Earthquake.parseJst('bad'), isNull);
    });
  });

  group('Earthquake.mergeReports', () {
    test('震度速報・震源情報・各地の震度を1件にまとめる', () {
      final quakes = Earthquake.mergeReports(ibarakiSequence);
      expect(quakes, hasLength(1));
      final q = quakes.single;
      expect(q.hypocenterName, '茨城県南部');
      expect(q.latitude, 36.1);
      expect(q.longitude, 139.9);
      expect(q.depthKm, 50);
      expect(q.magnitude, 4.9);
      // 震源情報（Destination）の maxScale=-1 ではなく、震度のある最新の発表から取る。
      expect(q.maxScale, 40);
      expect(q.domesticTsunami, 'None');
      expect(q.issueType, 'DetailScale');
      expect(q.prefScales, {'栃木県': 20, '茨城県': 40});
      expect(q.topPoints.first.addr, 'つくば市');
    });

    test('震度速報だけの間は震源なし・最大震度あり', () {
      final q = Earthquake.mergeReports([scalePrompt(maxScale: 30)]).single;
      expect(q.hasHypocenter, isFalse);
      expect(q.hypocenterName, isNull);
      expect(q.magnitude, isNull);
      expect(q.maxScale, 30);
      expect(q.prefScales, {'茨城県': 30});
    });

    test('海外の地震は除き、発生時刻の新しい順に並べる', () {
      final quakes = Earthquake.mergeReports([
        report(
          type: 'Foreign',
          issued: '2026/09/30 06:48:40',
          time: '2026/09/30 06:23:00',
          maxScale: -1,
        ),
        ...ibarakiSequence,
        report(
          type: 'DetailScale',
          issued: '2026/09/30 21:31:24',
          time: '2026/09/30 21:28:00',
          name: 'トカラ列島近海',
          maxScale: 10,
        ),
      ]);
      expect(quakes.map((q) => q.hypocenterName), ['トカラ列島近海', '茨城県南部']);
    });
  });

  group('EarthquakeService.apply', () {
    test('件数を絞った取得で欠けた項目は前の内容で補う', () {
      final before = Earthquake.mergeReports(ibarakiSequence);
      // 震度の訂正だけが届いた（震源は -200、観測点なし）場合。
      final after = EarthquakeService.apply(before, [
        report(
          type: 'ScalePrompt',
          issued: '2026/09/29 04:54:14',
          lat: -200,
          lon: -200,
          depth: -1,
          mag: -1,
          name: '',
          maxScale: 45,
        ),
      ]);
      final q = after.single;
      expect(q.maxScale, 45);
      expect(q.hypocenterName, '茨城県南部');
      expect(q.latitude, 36.1);
      expect(q.magnitude, 4.9);
      expect(q.prefScales, {'栃木県': 20, '茨城県': 40});
    });

    test('古い発表では置き換えない', () {
      final before = Earthquake.mergeReports(ibarakiSequence);
      final after = EarthquakeService.apply(before, [scalePrompt()]);
      expect(after.single.issueType, 'DetailScale');
    });
  });

  group('QuakeRippleSpec', () {
    test('震度が大きいほど遠くまで・多重に広がる', () {
      const scales = [10, 20, 30, 40, 45, 50, 55, 60, 70];
      final specs = scales.map(QuakeRippleSpec.forScale).toList();
      for (var i = 1; i < specs.length; i++) {
        expect(
          specs[i].maxRadiusRatio,
          greaterThan(specs[i - 1].maxRadiusRatio),
        );
        expect(specs[i].rings, greaterThanOrEqualTo(specs[i - 1].rings));
      }
      expect(specs.first.rings, 1);
      expect(specs.last.rings, 5);
    });

    test('震度の表示', () {
      expect(SeismicScale.label(45), '5弱');
      expect(SeismicScale.label(60), '6強');
      expect(SeismicScale.label(-1), '-');
    });
  });

  group('EarthquakeController の自動切り替えの判定', () {
    Future<EarthquakeController> run(
      List<dynamic> reports,
      DateTime now,
    ) async {
      final c = EarthquakeController(_FakeService(reports), now: () => now);
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    // 04:45 JST = 前日 19:45 UTC。
    final occurred = DateTime.utc(2026, 9, 28, 19, 45);

    test('震度3以上・発生30分以内なら切り替える（同じ地震では1回だけ）', () async {
      final c = await run(
        ibarakiSequence,
        occurred.add(const Duration(minutes: 5)),
      );
      expect(c.state.alertSeq, 1);
      expect(c.state.alertKey, '2026/09/29 04:45:00');
      await c.refresh();
      expect(c.state.alertSeq, 1);
      c.dispose();
    });

    test('震度2以下では切り替えないが、一覧には出す', () async {
      final c = await run([
        report(
          type: 'DetailScale',
          issued: '2026/09/29 04:49:17',
          maxScale: 20,
        ),
      ], occurred.add(const Duration(minutes: 5)));
      expect(c.state.alertSeq, 0);
      expect(c.state.felt, hasLength(1));
      c.dispose();
    });

    test('発生から30分を過ぎた地震では切り替えない', () async {
      final c = await run(
        ibarakiSequence,
        occurred.add(const Duration(minutes: 31)),
      );
      expect(c.state.alertSeq, 0);
      c.dispose();
    });
  });

  group('NewsQuakePanel', () {
    testWidgets('地震で自動的に切り替わり、30分後にニュースへ戻る', (tester) async {
      final service = _FakeService(const []);
      final container = ProviderContainer(
        overrides: [earthquakeServiceProvider.overrideWithValue(service)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: NewsQuakePanel(
                newsBuilder: (b) => Row(children: [const Text('NEWS'), b]),
                quakeBuilder: (b) => Row(children: [const Text('QUAKE'), b]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NEWS'), findsOneWidget);

      // 手動で切り替え・戻す。
      await tester.tap(find.byTooltip('地震情報に切り替え'));
      await tester.pumpAndSettle();
      expect(find.text('QUAKE'), findsOneWidget);
      await tester.tap(find.byTooltip('ニュースに切り替え'));
      await tester.pumpAndSettle();
      expect(find.text('NEWS'), findsOneWidget);

      // 今起きた震度4の地震が届く。
      final jst = DateTime.now().toUtc().add(const Duration(hours: 9));
      String two(int v) => v.toString().padLeft(2, '0');
      final now =
          '${jst.year}/${two(jst.month)}/${two(jst.day)} '
          '${two(jst.hour)}:${two(jst.minute)}:00';
      service.reports = [report(type: 'DetailScale', issued: now, time: now)];
      await container.read(earthquakeControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(container.read(earthquakeControllerProvider).alertSeq, 1);
      expect(find.text('QUAKE'), findsOneWidget);

      await tester.pump(const Duration(minutes: 29));
      await tester.pumpAndSettle();
      expect(find.text('QUAKE'), findsOneWidget);
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('NEWS'), findsOneWidget);

      // 毎分の確認タイマーを止める。
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  });
}

class _FakeService extends EarthquakeService {
  _FakeService(this.reports);

  List<dynamic> reports;

  @override
  Future<List<dynamic>> fetchHistory() async => reports;

  @override
  Future<List<dynamic>> fetchLatest() async => reports;
}
