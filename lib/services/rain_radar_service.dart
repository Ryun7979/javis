import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/rain_radar.dart';
import '../util/web_mercator.dart';

/// 気象庁ナウキャスト（雨雲レーダー・雷）の取得サービス。
///
/// 気象庁ホームページの「雨雲の動き」画面が内部で使っているデータ
/// （https://www.jma.go.jp/bosai/nowc/ ）を利用する。正式公開APIではないため
/// 仕様が予告なく変わる可能性がある。利用条件は政府標準利用規約（出典表示が必要）で、
/// 出典は設定画面の「データの出典」ページと、レーダー画面の隅に表示している。
class RainRadarService {
  RainRadarService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://www.jma.go.jp/bosai/jmatile/data/nowc';

  /// アニメーションに含める範囲（実況は過去1時間、予報は1時間先まで）。
  static const pastRange = Duration(hours: 1);
  static const forecastRange = Duration(hours: 1);

  /// 過去コマの雷データは確定後に変わらないため、validtime単位でメモリに保持する。
  final Map<String, List<LightningStrike>> _strikeCache = {};

  /// 降水強度タイルのURL。
  static String radarTileUrl(RadarFrame frame, TileIndex t) =>
      '$_base/${frame.basetime}/none/${frame.validtime}/surf/hrpns/'
      '${t.z}/${t.x}/${t.y}.png';

  /// 実況・予報をまとめ、時刻の古い順に並べたコマ一覧を取得する。
  Future<List<RadarFrame>> fetchFrames() async {
    final responses = await Future.wait([
      _getJson('$_base/targetTimes_N1.json'),
      _getJson('$_base/targetTimes_N2.json'),
      _getJson('$_base/targetTimes_N3.json'),
    ]);
    final frames = buildFrames(
      n1: responses[0] as List,
      n2: responses[1] as List,
    );
    final lidenTimes = lightningTimes(responses[2] as List);

    return Future.wait([
      for (final f in frames)
        if (!f.isForecast && lidenTimes.contains(f.validtime))
          _fetchStrikes(f.validtime).then(f.withStrikes)
        else
          Future.value(f),
    ]);
  }

  /// targetTimes_N1（実況）/N2（予報）のJSONから、アニメーション用のコマ一覧を作る。
  ///
  /// 予報は最新のbasetimeのものだけを使い、実況と時刻が重ならないよう
  /// 最新実況より後のvalidtimeに限定する。
  static List<RadarFrame> buildFrames({
    required List<dynamic> n1,
    required List<dynamic> n2,
  }) {
    final past = <RadarFrame>[];
    for (final e in n1.cast<Map<String, dynamic>>()) {
      if (!_hasElement(e, 'hrpns')) continue;
      final basetime = e['basetime'] as String;
      final validtime = e['validtime'] as String;
      past.add(RadarFrame(
        basetime: basetime,
        validtime: validtime,
        validTimeUtc: parseJmaTime(validtime),
        isForecast: false,
      ));
    }
    if (past.isEmpty) return const [];
    past.sort((a, b) => a.validTimeUtc.compareTo(b.validTimeUtc));
    final latest = past.last;
    final oldestPast = latest.validTimeUtc.subtract(pastRange);
    final latestForecast = latest.validTimeUtc.add(forecastRange);

    // 予報（N2）は実況（N1）より数十秒遅れて更新されることがあるため、
    // 実況と同じbasetimeに限定せず、予報側の最新basetimeを使う。
    final n2Entries = n2
        .cast<Map<String, dynamic>>()
        .where((e) => _hasElement(e, 'hrpns'))
        .toList();
    final forecastBase = n2Entries.isEmpty
        ? null
        : n2Entries
            .map((e) => e['basetime'] as String)
            .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    final forecast = <RadarFrame>[];
    for (final e in n2Entries) {
      if (e['basetime'] != forecastBase) continue;
      final validtime = e['validtime'] as String;
      final t = parseJmaTime(validtime);
      if (!t.isAfter(latest.validTimeUtc) || t.isAfter(latestForecast)) {
        continue;
      }
      forecast.add(RadarFrame(
        basetime: forecastBase!,
        validtime: validtime,
        validTimeUtc: t,
        isForecast: true,
      ));
    }
    forecast.sort((a, b) => a.validTimeUtc.compareTo(b.validTimeUtc));

    return [
      ...past.where((f) => !f.validTimeUtc.isBefore(oldestPast)),
      ...forecast,
    ];
  }

  /// targetTimes_N3のうち、雷（liden）データがある実況時刻の一覧。
  static Set<String> lightningTimes(List<dynamic> n3) => {
        for (final e in n3.cast<Map<String, dynamic>>())
          if (_hasElement(e, 'liden') && e['basetime'] == e['validtime'])
            e['validtime'] as String,
      };

  /// 雷のGeoJSON（Point の FeatureCollection）を読み取る。
  static List<LightningStrike> parseStrikes(Map<String, dynamic> geojson) {
    final features = geojson['features'] as List? ?? const [];
    return [
      for (final f in features.cast<Map<String, dynamic>>())
        if ((f['geometry'] as Map?)?['type'] == 'Point')
          LightningStrike(
            longitude:
                ((f['geometry'] as Map)['coordinates'] as List)[0].toDouble(),
            latitude:
                ((f['geometry'] as Map)['coordinates'] as List)[1].toDouble(),
          ),
    ];
  }

  /// 気象庁の時刻文字列（UTC、`yyyyMMddHHmmss`）をUTCのDateTimeにする。
  static DateTime parseJmaTime(String s) => DateTime.utc(
        int.parse(s.substring(0, 4)),
        int.parse(s.substring(4, 6)),
        int.parse(s.substring(6, 8)),
        int.parse(s.substring(8, 10)),
        int.parse(s.substring(10, 12)),
        int.parse(s.substring(12, 14)),
      );

  static bool _hasElement(Map<String, dynamic> e, String element) =>
      (e['elements'] as List? ?? const []).contains(element);

  Future<List<LightningStrike>> _fetchStrikes(String validtime) async {
    final cached = _strikeCache[validtime];
    if (cached != null) return cached;
    try {
      final json = await _getJson(
        '$_base/$validtime/none/$validtime/surf/liden/data.geojson',
      );
      final strikes = parseStrikes(json as Map<String, dynamic>);
      _strikeCache[validtime] = strikes;
      // 1時間半より古いコマはアニメーションに出てこないので捨てる。
      if (_strikeCache.length > 30) {
        final keys = _strikeCache.keys.toList()..sort();
        for (final k in keys.take(_strikeCache.length - 30)) {
          _strikeCache.remove(k);
        }
      }
      return strikes;
    } catch (_) {
      // 雷は補助情報のため、取得失敗でもレーダー表示自体は続ける。
      return const [];
    }
  }

  Future<dynamic> _getJson(String url) async {
    final res = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw RainRadarServiceException('HTTP ${res.statusCode}: $url');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }
}

class RainRadarServiceException implements Exception {
  RainRadarServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
