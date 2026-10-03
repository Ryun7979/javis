import 'dart:math' as math;

import '../data/prefectures.dart';
import '../util/geo.dart';

/// 中心と半径（メートル）で表す円（強風域・予報円など）。
class TyphoonCircle {
  const TyphoonCircle(this.center, this.radiusM);

  final GeoPoint center;
  final double radiusM;
}

/// 円弧。角度は北を0として時計回り（度）。
class TyphoonArc {
  const TyphoonArc(this.center, this.radiusM, this.startDeg, this.endDeg);

  final GeoPoint center;
  final double radiusM;
  final double startDeg;
  final double endDeg;
}

/// 暴風域・強風域・暴風警戒域の形。気象庁のデータは「中心と半径の円」か
/// 「円弧と、円弧どうしをつなぐ線分の集まり」のどちらかで届く。
class TyphoonArea {
  const TyphoonArea({
    this.circles = const [],
    this.arcs = const [],
    this.lines = const [],
  });

  final List<TyphoonCircle> circles;
  final List<TyphoonArc> arcs;
  final List<(GeoPoint, GeoPoint)> lines;

  static const empty = TyphoonArea();

  bool get isEmpty => circles.isEmpty && arcs.isEmpty && lines.isEmpty;

  static TyphoonArea parse(dynamic json) {
    if (json is! Map) return empty;
    final circles = <TyphoonCircle>[];
    final arcs = <TyphoonArc>[];
    final lines = <(GeoPoint, GeoPoint)>[];
    final center = GeoPoint.fromList(json['center']);
    final radius = json['radius'];
    if (center != null && radius is num) {
      circles.add(TyphoonCircle(center, radius.toDouble()));
    }
    for (final a in json['arc'] as List? ?? const []) {
      if (a is! List || a.length < 3) continue;
      final c = GeoPoint.fromList(a[0]);
      final r = a[1], range = a[2];
      if (c == null || r is! num || range is! List || range.length < 2) {
        continue;
      }
      arcs.add(
        TyphoonArc(
          c,
          r.toDouble(),
          (range[0] as num).toDouble(),
          (range[1] as num).toDouble(),
        ),
      );
    }
    lines.addAll(_parseLines(json['line']));
    return TyphoonArea(circles: circles, arcs: arcs, lines: lines);
  }
}

List<(GeoPoint, GeoPoint)> _parseLines(dynamic json) {
  final lines = <(GeoPoint, GeoPoint)>[];
  for (final l in json as List? ?? const []) {
    if (l is! List || l.length < 2) continue;
    final a = GeoPoint.fromList(l[0]), b = GeoPoint.fromList(l[1]);
    if (a != null && b != null) lines.add((a, b));
  }
  return lines;
}

/// ある時刻の予報（予報円の中心と大きさ、そのときの勢力）。
class TyphoonForecast {
  const TyphoonForecast({
    required this.advancedHours,
    required this.validTimeUtc,
    required this.center,
    required this.probabilityRadiusM,
    required this.tangents,
    required this.categoryJp,
    required this.pressureHpa,
    required this.maxWindMs,
  });

  /// 何時間後の予報か。
  final int advancedHours;
  final DateTime validTimeUtc;
  final GeoPoint center;

  /// 予報円の半径（メートル）。
  final double probabilityRadiusM;

  /// 1つ前の円（または現在位置）と予報円をつなぐ線。
  final List<(GeoPoint, GeoPoint)> tangents;

  /// その時点の種別（台風・熱帯低気圧・温帯低気圧）。
  final String? categoryJp;
  final int? pressureHpa;
  final int? maxWindMs;
}

/// 気象庁の台風情報（実況と進路予報）1つ分。
class Typhoon {
  const Typhoon({
    required this.id,
    required this.number,
    required this.name,
    required this.categoryJp,
    required this.categoryEn,
    required this.issuedAtUtc,
    required this.validTimeUtc,
    required this.center,
    required this.scale,
    required this.intensity,
    required this.location,
    required this.course,
    required this.speed,
    required this.pressureHpa,
    required this.maxWindMs,
    required this.maxGustMs,
    required this.track,
    required this.galeArea,
    required this.stormArea,
    required this.stormWarningArea,
    required this.forecasts,
  });

  /// 気象庁の識別子（例: TC2633）。
  final String id;

  /// 台風番号（例: 27）。熱帯低気圧にはない。
  final int? number;

  /// 名前（例: チョーイワン）。
  final String? name;
  final String? categoryJp;
  final String? categoryEn;
  final DateTime issuedAtUtc;

  /// 実況の時刻。
  final DateTime validTimeUtc;
  final GeoPoint center;

  /// 大きさ（大型・超大型）と強さ（強い・非常に強い・猛烈な）。該当しなければnull。
  final String? scale;
  final String? intensity;

  /// 存在地域（例: 小笠原近海）。
  final String? location;

  /// 進行方向（例: 北北東）と速さ（例: 15km/h、ゆっくり）。
  final String? course;
  final String? speed;
  final int? pressureHpa;
  final int? maxWindMs;
  final int? maxGustMs;

  /// これまでの経路（古い順。最後が現在位置）。
  final List<GeoPoint> track;

  /// 強風域（風速15m/s以上）・暴風域（風速25m/s以上）の実況。
  final TyphoonArea galeArea;
  final TyphoonArea stormArea;

  /// 暴風警戒域（予報の期間中に暴風域に入るおそれのある範囲）。
  final TyphoonArea stormWarningArea;
  final List<TyphoonForecast> forecasts;

  /// 台風か（熱帯低気圧は含めない）。知っている種別だけを台風とみなす。
  bool get isTyphoon =>
      categoryJp == '台風' || const {'TS', 'STS', 'TY'}.contains(categoryEn);

  /// 表示名（例: 台風27号）。
  String get label =>
      number != null ? '台風$number号' : (categoryJp ?? '熱帯低気圧');

  /// 日本（県庁所在地と主な離島）に最も近づくときの距離（km）。予報円の半径ぶんは近いほうに見積もる。
  double get closestApproachKm {
    var best = _distanceToJapanKm(center);
    for (final f in forecasts) {
      best = math.min(
        best,
        _distanceToJapanKm(f.center) - f.probabilityRadiusM / 1000,
      );
    }
    return best;
  }

  /// この距離（km）以内まで近づく台風を「日本付近の台風」とする（強風域のおおよその広さ）。
  static const approachThresholdKm = 500.0;

  /// 現在位置または予報円が日本付近に入るか。
  bool get approachesJapan => closestApproachKm <= approachThresholdKm;

  /// 台風一覧（targetTc.json）の1件と、その詳細（specifications.json / forecast.json）から作る。
  /// 実況の位置が読めなければnull。
  static Typhoon? parse(
    Map<String, dynamic> target,
    List<dynamic> specifications,
    List<dynamic> forecast,
  ) {
    Map<String, dynamic>? title;
    final specByHours = <int, Map<String, dynamic>>{};
    for (final p in specifications) {
      if (p is! Map<String, dynamic>) continue;
      if (p['part'] == 'title') {
        title = p;
      } else if (p['advancedHours'] is int) {
        specByHours[p['advancedHours'] as int] = p;
      }
    }
    final fcByHours = <int, Map<String, dynamic>>{};
    for (final p in forecast) {
      if (p is Map<String, dynamic> && p['advancedHours'] is int) {
        fcByHours[p['advancedHours'] as int] = p;
      }
    }

    final spec = specByHours[0];
    final fc = fcByHours[0];
    final center =
        GeoPoint.fromList(fc?['center']) ??
        GeoPoint.fromList((spec?['position'] as Map?)?['deg']);
    if (center == null) return null;

    final issued =
        _time(title?['issue']) ??
        DateTime.tryParse(target['issue'] as String? ?? '')?.toUtc();
    final valid = _time(spec?['validtime']) ?? _time(fc?['validtime']);
    if (issued == null) return null;

    final trackJson = fc?['track'] as Map?;
    final track = <GeoPoint>[
      for (final key in const ['preTyphoon', 'typhoon'])
        for (final p in trackJson?[key] as List? ?? const [])
          ?GeoPoint.fromList(p),
    ];

    final forecasts = <TyphoonForecast>[];
    var stormWarning = TyphoonArea.empty;
    for (final hours in fcByHours.keys.toList()..sort()) {
      if (hours == 0) continue;
      final f = fcByHours[hours]!;
      final s = specByHours[hours];
      final c = GeoPoint.fromList(f['center']);
      final validTime = _time(f['validtime']);
      final circle = f['probabilityCircle'] as Map?;
      // 暴風警戒域は後の予報ほど手前の分も含んだ形で届くので、最後のものを使う。
      final area = TyphoonArea.parse(f['stormWarningArea']);
      if (!area.isEmpty) stormWarning = area;
      if (c == null || validTime == null) continue;
      forecasts.add(
        TyphoonForecast(
          advancedHours: hours,
          validTimeUtc: validTime,
          center: c,
          probabilityRadiusM: (circle?['radius'] as num?)?.toDouble() ?? 0,
          tangents: _parseLines(circle?['tangent']),
          categoryJp: _jp(s?['category']),
          pressureHpa: _int(s?['pressure']),
          maxWindMs: _int(_wind(s, 'sustained')),
        ),
      );
    }

    final number = (title?['typhoonNumber'] ?? target['typhoonNumber'])
        ?.toString();
    final speed = (spec?['speed'] as Map?)?['km/h']?.toString();
    return Typhoon(
      id: target['tropicalCyclone']?.toString() ?? '',
      // 「2627」（年の下2桁＋番号）の番号だけを取り出す。
      number: number != null && number.length == 4
          ? int.tryParse(number.substring(2))
          : null,
      name: _jp(title?['name']),
      categoryJp: _jp(spec?['category']) ?? _jp(title?['category']),
      categoryEn:
          _en(spec?['category']) ??
          _en(title?['category']) ??
          target['category']?.toString(),
      issuedAtUtc: issued,
      validTimeUtc: valid ?? issued,
      center: center,
      scale: _label(spec?['scale']),
      intensity: _label(spec?['intensity']),
      location: _label(spec?['location']),
      course: _label(spec?['course']),
      speed: speed == null || speed.isEmpty
          ? null
          : (int.tryParse(speed) != null ? '${speed}km/h' : speed),
      pressureHpa: _int(spec?['pressure']),
      maxWindMs: _int(_wind(spec, 'sustained')),
      maxGustMs: _int(_wind(spec, 'gust')),
      track: track,
      galeArea: TyphoonArea.parse(fc?['galeWarningArea']),
      stormArea: TyphoonArea.parse(fc?['stormWarningArea']),
      stormWarningArea: stormWarning,
      forecasts: forecasts,
    );
  }
}

/// 日本付近かどうかの判定に使う地点（県庁所在地のほかに、本土から離れた主な島）。
const _remoteIslands = [
  GeoPoint(27.09, 142.19), // 父島
  GeoPoint(33.11, 139.79), // 八丈島
  GeoPoint(28.38, 129.49), // 奄美大島
  GeoPoint(25.83, 131.23), // 南大東島
  GeoPoint(24.80, 125.28), // 宮古島
  GeoPoint(24.34, 124.16), // 石垣島
  GeoPoint(24.47, 123.00), // 与那国島
];

double _distanceToJapanKm(GeoPoint p) {
  var best = double.infinity;
  for (final pref in prefectures) {
    best = math.min(
      best,
      distanceKm(p, GeoPoint(pref.latitude, pref.longitude)),
    );
  }
  for (final island in _remoteIslands) {
    best = math.min(best, distanceKm(p, island));
  }
  return best;
}

DateTime? _time(dynamic json) => json is Map
    ? DateTime.tryParse(json['UTC'] as String? ?? '')?.toUtc()
    : null;

String? _jp(dynamic v) => _label(v is Map ? v['jp'] : v);

String? _en(dynamic v) => _label(v is Map ? v['en'] : null);

/// 空文字や「-」（該当なし）はnullにする。
String? _label(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty || s == '-' ? null : s;
}

int? _int(dynamic v) => int.tryParse(v?.toString() ?? '');

dynamic _wind(Map<String, dynamic>? spec, String kind) =>
    ((spec?['maximumWind'] as Map?)?[kind] as Map?)?['m/s'];
