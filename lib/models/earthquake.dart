/// 地震情報（P2P地震情報 API v2 の code 551「地震情報」）。
///
/// 気象庁は1つの地震について「震度速報（震源なし）→震源に関する情報（震度なし）→
/// 各地の震度に関する情報」と複数回発表する。発生時刻が同じ発表を1件の[Earthquake]に
/// まとめ、各項目は「その項目が有効な値を持つ最新の発表」から取る（[Earthquake.mergeReports]）。
library;

/// 震度。P2P地震情報の数値（10=震度1 … 45=5弱 … 70=震度7）をそのまま持つ。
class SeismicScale {
  SeismicScale._();

  static const none = -1;
  static const s1 = 10;
  static const s3 = 30;

  /// 「3」「5弱」のような表示用の文字列。震度情報がなければ「-」。
  static String label(int scale) => switch (scale) {
    10 => '1',
    20 => '2',
    30 => '3',
    40 => '4',
    45 => '5弱',
    50 => '5強',
    55 => '6弱',
    60 => '6強',
    70 => '7',
    _ => '-',
  };

  /// 震度の段階（震度1=1 … 5弱=5, 5強=6, 6弱=7, 6強=8, 7=9）。震度情報がなければ0。
  static int level(int scale) => switch (scale) {
    10 => 1,
    20 => 2,
    30 => 3,
    40 => 4,
    45 => 5,
    50 => 6,
    55 => 7,
    60 => 8,
    70 => 9,
    _ => 0,
  };
}

/// 震源から広がる同心円の演出の大きさ。震度が大きいほど遠くまで・多重に広がる。
class QuakeRippleSpec {
  const QuakeRippleSpec({
    required this.maxRadiusRatio,
    required this.rings,
    required this.period,
  });

  /// 同心円が広がりきったときの半径（地図の短辺に対する割合）。
  final double maxRadiusRatio;

  /// 同時に広がる円の数。
  final int rings;

  /// 1つの円が広がりきるまでの時間。
  final Duration period;

  static QuakeRippleSpec forScale(int scale) {
    final level = SeismicScale.level(scale);
    // 震度情報がない（震源の情報だけ届いた）間は、震度1と同じ控えめな大きさにする。
    final l = level == 0 ? 1 : level;
    return QuakeRippleSpec(
      maxRadiusRatio: 0.05 + 0.05 * l,
      rings: 1 + (l - 1) ~/ 2,
      period: Duration(milliseconds: 1600 + 250 * l),
    );
  }
}

/// 震度を観測した地点（表示用に絞ったもの）。
class QuakePoint {
  const QuakePoint({
    required this.pref,
    required this.addr,
    required this.scale,
  });

  final String pref;
  final String addr;
  final int scale;
}

class Earthquake {
  const Earthquake({
    required this.key,
    required this.timeUtc,
    required this.issuedAtUtc,
    required this.issueType,
    required this.hypocenterName,
    required this.latitude,
    required this.longitude,
    required this.depthKm,
    required this.magnitude,
    required this.maxScale,
    required this.domesticTsunami,
    required this.prefScales,
    required this.topPoints,
  });

  /// 同じ地震の発表をまとめるためのキー（発生時刻の文字列）。
  final String key;
  final DateTime timeUtc;

  /// まとめた発表のうち最新のものの発表時刻。
  final DateTime issuedAtUtc;

  /// 最新の発表の種類（ScalePrompt / Destination / ScaleAndDestination / DetailScale）。
  final String issueType;

  /// 震源の名称。震源がまだ発表されていなければnull。
  final String? hypocenterName;
  final double? latitude;
  final double? longitude;

  /// 深さ(km)。0は「ごく浅い」。不明ならnull。
  final int? depthKm;
  final double? magnitude;

  /// 最大震度（[SeismicScale]の数値）。震度情報がなければ -1。
  final int maxScale;

  /// 国内への津波の有無（None / Unknown / Checking / NonEffective / Watch / Warning）。
  final String domesticTsunami;

  /// 都道府県ごとの最大震度。
  final Map<String, int> prefScales;

  /// 震度の大きい順に並べた観測地点（上位のみ）。
  final List<QuakePoint> topPoints;

  bool get hasHypocenter => latitude != null && longitude != null;

  static const _topPointsLimit = 8;

  /// P2P地震情報の時刻（"2026/09/30 21:28:00"、日本時間）をUTCに変換する。
  static DateTime? parseJst(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2})')
        .firstMatch(s);
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i)!);
    return DateTime.utc(
      g(1),
      g(2),
      g(3),
      g(4),
      g(5),
      g(6),
    ).subtract(const Duration(hours: 9));
  }

  /// APIの応答（発表の一覧、新しい順）を地震ごとにまとめ、発生時刻の新しい順に返す。
  /// 海外の地震（Foreign）と、発生時刻を読めない発表は除く。
  static List<Earthquake> mergeReports(List<dynamic> reports) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in reports) {
      if (r is! Map<String, dynamic> || r['code'] != 551) continue;
      final issue = r['issue'] as Map<String, dynamic>?;
      if (issue?['type'] == 'Foreign') continue;
      final eq = r['earthquake'] as Map<String, dynamic>?;
      final time = eq?['time'] as String?;
      if (time == null || parseJst(time) == null) continue;
      groups.putIfAbsent(time, () => []).add(r);
    }
    final quakes = [for (final e in groups.entries) _merge(e.key, e.value)]
      ..sort((a, b) => b.timeUtc.compareTo(a.timeUtc));
    return quakes;
  }

  static Earthquake _merge(String key, List<Map<String, dynamic>> reports) {
    // 発表時刻の新しい順に並べ、各項目は有効な値を持つ最初（=最新）の発表から取る。
    DateTime issued(Map<String, dynamic> r) =>
        parseJst((r['issue'] as Map<String, dynamic>)['time'] as String?) ??
        DateTime.utc(0);
    final sorted = [...reports]..sort((a, b) => issued(b).compareTo(issued(a)));
    final latest = sorted.first;

    Map<String, dynamic> eqOf(Map<String, dynamic> r) =>
        r['earthquake'] as Map<String, dynamic>;
    Map<String, dynamic>? hypoOf(Map<String, dynamic> r) =>
        eqOf(r)['hypocenter'] as Map<String, dynamic>?;

    Map<String, dynamic>? hypo;
    for (final r in sorted) {
      final h = hypoOf(r);
      final lat = (h?['latitude'] as num?)?.toDouble();
      if (h != null && lat != null && lat > -200) {
        hypo = h;
        break;
      }
    }

    var maxScale = SeismicScale.none;
    for (final r in sorted) {
      final s = (eqOf(r)['maxScale'] as num?)?.toInt() ?? SeismicScale.none;
      if (s > 0) {
        maxScale = s;
        break;
      }
    }

    List<dynamic> points = const [];
    for (final r in sorted) {
      final p = r['points'] as List<dynamic>?;
      if (p != null && p.isNotEmpty) {
        points = p;
        break;
      }
    }
    final prefScales = <String, int>{};
    final parsedPoints = <QuakePoint>[];
    for (final p in points.whereType<Map<String, dynamic>>()) {
      final pref = p['pref'] as String? ?? '';
      final scale = (p['scale'] as num?)?.toInt() ?? SeismicScale.none;
      if (pref.isEmpty || scale <= 0) continue;
      if (scale > (prefScales[pref] ?? 0)) prefScales[pref] = scale;
      parsedPoints.add(
        QuakePoint(pref: pref, addr: p['addr'] as String? ?? '', scale: scale),
      );
    }
    parsedPoints.sort((a, b) => b.scale.compareTo(a.scale));

    final depth = (hypo?['depth'] as num?)?.toInt();
    final mag = (hypo?['magnitude'] as num?)?.toDouble();
    final name = hypo?['name'] as String?;
    return Earthquake(
      key: key,
      timeUtc: parseJst(key)!,
      issuedAtUtc: issued(latest),
      issueType:
          (latest['issue'] as Map<String, dynamic>)['type'] as String? ?? '',
      hypocenterName: name == null || name.isEmpty ? null : name,
      latitude: (hypo?['latitude'] as num?)?.toDouble(),
      longitude: (hypo?['longitude'] as num?)?.toDouble(),
      depthKm: depth == null || depth < 0 ? null : depth,
      magnitude: mag == null || mag < 0 ? null : mag,
      maxScale: maxScale,
      domesticTsunami: eqOf(latest)['domesticTsunami'] as String? ?? 'Unknown',
      prefScales: prefScales,
      topPoints: parsedPoints.take(_topPointsLimit).toList(),
    );
  }

  /// 津波の有無の表示用文字列。
  String get tsunamiLabel => switch (domesticTsunami) {
    'None' => 'この地震による津波の心配はありません',
    'NonEffective' => '若干の海面変動（被害の心配なし）',
    'Checking' => '津波の有無を調査中',
    'Watch' => '津波注意報 発表中',
    'Warning' => '津波予報 発表中',
    _ => '津波の情報なし',
  };

  /// 津波について注意が必要な発表か（表示を目立たせる）。
  bool get tsunamiAlert =>
      domesticTsunami == 'Watch' || domesticTsunami == 'Warning';
}
