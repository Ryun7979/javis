import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/typhoon.dart';

/// 気象庁ホームページの台風情報（`jma.go.jp/bosai/typhoon/data/`）を取得する。
///
/// キー不要。雨雲レーダーと同じく公式に仕様が公開されたAPIではないので、形が変わっても
/// 落ちないよう読めない項目は飛ばす。発表は1〜3時間ごとなので、確認は10分ごとで足りる。
class TyphoonService {
  TyphoonService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://www.jma.go.jp/bosai/typhoon/data';

  /// 発表中の台風・熱帯低気圧をすべて取得する。発表がなければ空。
  Future<List<Typhoon>> fetchAll() async {
    final targets = await _getJson('$_base/targetTc.json') as List<dynamic>;
    final result = <Typhoon>[];
    Object? lastError;
    for (final t in targets) {
      if (t is! Map<String, dynamic>) continue;
      final id = t['tropicalCyclone'];
      if (id is! String || id.isEmpty) continue;
      try {
        final details = await Future.wait([
          _getJson('$_base/$id/specifications.json'),
          _getJson('$_base/$id/forecast.json'),
        ]);
        final typhoon = Typhoon.parse(
          t,
          details[0] as List<dynamic>,
          details[1] as List<dynamic>,
        );
        if (typhoon != null) result.add(typhoon);
      } catch (e) {
        // 1つ読めなくても、ほかの台風は表示する。
        lastError = e;
      }
    }
    if (result.isEmpty && lastError != null) throw lastError;
    return result;
  }

  Future<dynamic> _getJson(String url) async {
    final res = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }
}
