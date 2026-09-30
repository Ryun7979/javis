import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/earthquake.dart';

/// P2P地震情報 JSON API (v2) から、気象庁の地震情報（code 551）を取得する。
///
/// キー不要・商用非商用問わず無償。レート制限は /history が 60リクエスト/分（IPごと）。
/// 大きな地震の「各地の震度」は観測点が数百件になり1件で数百KBになるため、
/// 定期確認では件数を絞り（[fetchLatest]）、履歴の取り直しはまれにする（[fetchHistory]）。
class EarthquakeService {
  EarthquakeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoint = 'https://api.p2pquake.net/v2/history';

  /// 直近の発表を少しだけ取る（毎分の確認用）。
  Future<List<dynamic>> fetchLatest() => _fetch(limit: 3);

  /// 一覧表示用に、ある程度さかのぼって取る。
  Future<List<dynamic>> fetchHistory() => _fetch(limit: 60);

  Future<List<dynamic>> _fetch({required int limit}) async {
    final uri = Uri.parse('$_endpoint?codes=551&limit=$limit');
    final res = await _client.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
  }

  /// 取得済みの地震一覧[current]に、新しく取った発表[reports]を反映する。
  /// 同じ地震は新しい発表でまとめ直した内容に置き換える。
  static List<Earthquake> apply(
    List<Earthquake> current,
    List<dynamic> reports, {
    int keep = 40,
  }) {
    final fresh = Earthquake.mergeReports(reports);
    final byKey = {for (final q in current) q.key: q};
    for (final q in fresh) {
      final old = byKey[q.key];
      // 件数を絞った取得では同じ地震の古い発表が欠けることがあるので、
      // 取れた発表のほうが新しいときだけ置き換える。欠けた項目は前の内容で補う。
      if (old == null || !q.issuedAtUtc.isBefore(old.issuedAtUtc)) {
        byKey[q.key] = old == null ? q : _fillMissing(q, old);
      }
    }
    final list = byKey.values.toList()
      ..sort((a, b) => b.timeUtc.compareTo(a.timeUtc));
    return list.take(keep).toList();
  }

  static Earthquake _fillMissing(Earthquake q, Earthquake old) => Earthquake(
    key: q.key,
    timeUtc: q.timeUtc,
    issuedAtUtc: q.issuedAtUtc,
    issueType: q.issueType,
    hypocenterName: q.hypocenterName ?? old.hypocenterName,
    latitude: q.latitude ?? old.latitude,
    longitude: q.longitude ?? old.longitude,
    depthKm: q.hasHypocenter ? q.depthKm : old.depthKm,
    magnitude: q.magnitude ?? old.magnitude,
    maxScale: q.maxScale > 0 ? q.maxScale : old.maxScale,
    domesticTsunami: q.domesticTsunami,
    prefScales: q.prefScales.isNotEmpty ? q.prefScales : old.prefScales,
    topPoints: q.topPoints.isNotEmpty ? q.topPoints : old.topPoints,
  );
}
