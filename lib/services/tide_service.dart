import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/tide_data.dart';
import '../util/moon_phase.dart';
import 'cache_service.dart';

/// 気象庁の潮位表テキストデータを取得・解析するサービス。
///
/// データ形式（1行=1日、固定長）:
///  - 1〜72桁: 0時〜23時の毎時潮位（cm）、3桁×24
///  - 73〜74桁: 年（下2桁）
///  - 75〜76桁: 月
///  - 77〜78桁: 日
///  - 79〜80桁: 観測地点コード
///  - 81〜108桁: 満潮（最大4件、各7桁=時2+分2+潮位cm3）
///  - 109〜136桁: 干潮（最大4件、同上）
/// 未使用の枠は "9999999"。
/// 参照: https://www.data.jma.go.jp/kaiyou/db/tide/suisan/ （地点別テキストデータ）
class TideService {
  TideService(this._cache, {http.Client? client})
      : _client = client ?? http.Client();

  final CacheService _cache;
  final http.Client _client;

  static const Duration _rawCacheTtl = Duration(hours: 20);

  String _rawCacheKey(String stationCode, int year) =>
      'tide_raw_${stationCode}_$year';

  Future<String> _fetchYearText(String stationCode, int year) async {
    final cached = _cache.read(_rawCacheKey(stationCode, year));
    if (cached != null) {
      final (savedAt, data) = cached;
      if (DateTime.now().difference(savedAt) < _rawCacheTtl) {
        return data as String;
      }
    }
    try {
      final uri = Uri.parse(
        'https://www.data.jma.go.jp/kaiyou/data/db/tide/suisan/txt/$year/$stationCode.txt',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        final text = res.body;
        await _cache.writeRaw(_rawCacheKey(stationCode, year), text);
        return text;
      }
    } catch (_) {
      // 通信エラー時はキャッシュにフォールバック
    }
    if (cached != null) {
      return cached.$2 as String;
    }
    throw TideServiceException('潮汐データを取得できませんでした（$stationCode/$year）');
  }

  /// 指定日の潮汐データを取得する。取得できない場合は null。
  Future<TideDayData?> getTideForDate(
    String stationCode,
    DateTime date,
  ) async {
    final text = await _fetchYearText(stationCode, date.year);
    final targetDate = DateTime(date.year, date.month, date.day);
    for (final line in const LineSplitter().convert(text)) {
      final record = _parseLine(line);
      if (record == null) continue;
      if (record.date == targetDate) {
        final moonAge = moonAgeForDate(targetDate);
        return TideDayData(
          date: record.date,
          hourlyLevelsCm: record.hourly,
          extremes: record.extremes,
          moonAge: moonAge,
          tidePhaseName: tidePhaseNameForMoonAge(moonAge),
        );
      }
    }
    return null;
  }

  _TideLineRecord? _parseLine(String rawLine) {
    if (rawLine.length < 80) return null;
    try {
      final hourly = <int?>[];
      for (var i = 0; i < 24; i++) {
        final chunk = rawLine.substring(i * 3, i * 3 + 3);
        hourly.add(int.tryParse(chunk.trim()));
      }
      final yy = int.parse(rawLine.substring(72, 74).trim());
      final mm = int.parse(rawLine.substring(74, 76).trim());
      final dd = int.parse(rawLine.substring(76, 78).trim());
      final date = DateTime(2000 + yy, mm, dd);

      final extremes = <TideExtreme>[];
      if (rawLine.length >= 136) {
        extremes.addAll(
          _parseExtremes(rawLine.substring(80, 108), date, isHigh: true),
        );
        extremes.addAll(
          _parseExtremes(rawLine.substring(108, 136), date, isHigh: false),
        );
      }
      extremes.sort((a, b) => a.time.compareTo(b.time));
      return _TideLineRecord(date: date, hourly: hourly, extremes: extremes);
    } catch (_) {
      return null;
    }
  }

  List<TideExtreme> _parseExtremes(
    String part,
    DateTime date, {
    required bool isHigh,
  }) {
    final list = <TideExtreme>[];
    for (var i = 0; i < 4; i++) {
      final occ = part.substring(i * 7, i * 7 + 7);
      final hh = occ.substring(0, 2).trim();
      final mi = occ.substring(2, 4).trim();
      final levelStr = occ.substring(4, 7).trim();
      if (hh == '99' || mi == '99' || levelStr == '999') continue;
      final h = int.tryParse(hh);
      final m = int.tryParse(mi);
      final level = int.tryParse(levelStr);
      if (h == null || m == null || level == null) continue;
      if (h > 23 || m > 59) continue;
      list.add(
        TideExtreme(
          time: DateTime(date.year, date.month, date.day, h, m),
          levelCm: level,
          isHigh: isHigh,
        ),
      );
    }
    return list;
  }
}

class _TideLineRecord {
  _TideLineRecord({
    required this.date,
    required this.hourly,
    required this.extremes,
  });

  final DateTime date;
  final List<int?> hourly;
  final List<TideExtreme> extremes;
}

class TideServiceException implements Exception {
  TideServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
