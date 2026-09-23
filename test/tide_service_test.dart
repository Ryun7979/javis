// 気象庁の潮位表テキストフォーマットのパース検証。
// 実データ（横浜/QS, 2026-01-01）で手動検証した満潮・干潮の時刻/潮位と一致することを確認する。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wall_jarvis/services/cache_service.dart';
import 'package:wall_jarvis/services/tide_service.dart';

const _sampleLine =
    ' 86116140156163159149137127123127138152164169165150123 89 53 22  4  3 2026 1 1QS 4 816314 816999999999999999 8581232132  199999999999999';

void main() {
  late Box<String> box;

  setUp(() async {
    Hive.init('${Directory.systemTemp.path}/wall_jarvis_test_${DateTime.now().microsecondsSinceEpoch}');
    box = await Hive.openBox<String>('test_cache');
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  test('parses hourly levels, high/low tide times and moon phase', () async {
    final client = MockClient((request) async {
      return http.Response(_sampleLine, 200);
    });
    final service = TideService(CacheService.withBox(box), client: client);

    final result = await service.getTideForDate('QS', DateTime(2026, 1, 1));

    expect(result, isNotNull);
    expect(result!.hourlyLevelsCm.length, 24);
    expect(result.hourlyLevelsCm[0], 86);
    expect(result.hourlyLevelsCm[4], 163);
    expect(result.hourlyLevelsCm[23], 20);

    final highs = result.extremes.where((e) => e.isHigh).toList();
    final lows = result.extremes.where((e) => !e.isHigh).toList();

    expect(highs.length, 2);
    expect(highs[0].time.hour, 4);
    expect(highs[0].time.minute, 8);
    expect(highs[0].levelCm, 163);
    expect(highs[1].time.hour, 14);
    expect(highs[1].time.minute, 8);
    expect(highs[1].levelCm, 169);

    expect(lows.length, 2);
    expect(lows[0].time.hour, 8);
    expect(lows[0].time.minute, 58);
    expect(lows[0].levelCm, 123);
    expect(lows[1].time.hour, 21);
    expect(lows[1].time.minute, 32);
    expect(lows[1].levelCm, 1);

    expect(result.tidePhaseName, isNotEmpty);
  });
}
