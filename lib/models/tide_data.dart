/// 満潮・干潮の1件分（気象庁の潮位表テキストから直接読み取った値）。
class TideExtreme {
  const TideExtreme({
    required this.time,
    required this.levelCm,
    required this.isHigh,
  });

  final DateTime time;
  final int levelCm;
  final bool isHigh;

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'levelCm': levelCm,
        'isHigh': isHigh,
      };

  factory TideExtreme.fromJson(Map<String, dynamic> json) => TideExtreme(
        time: DateTime.parse(json['time'] as String),
        levelCm: json['levelCm'] as int,
        isHigh: json['isHigh'] as bool,
      );
}

/// 1日分の潮汐データ。
class TideDayData {
  const TideDayData({
    required this.date,
    required this.hourlyLevelsCm,
    required this.extremes,
    required this.moonAge,
    required this.tidePhaseName,
  });

  /// その日の日付（時刻情報は00:00に丸めたローカル日付）。
  final DateTime date;

  /// 0時〜23時、1時間ごとの潮位（cm）。取得できなかった時は null。
  final List<int?> hourlyLevelsCm;

  /// 満潮・干潮（気象庁データに含まれるもの、最大4件ずつ）。
  final List<TideExtreme> extremes;

  /// 月齢（0〜29.5程度）。
  final double moonAge;

  /// 大潮・中潮・小潮・長潮・若潮（月齢からの概算、目安表示）。
  final String tidePhaseName;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'hourlyLevelsCm': hourlyLevelsCm,
        'extremes': extremes.map((e) => e.toJson()).toList(),
        'moonAge': moonAge,
        'tidePhaseName': tidePhaseName,
      };

  factory TideDayData.fromJson(Map<String, dynamic> json) => TideDayData(
        date: DateTime.parse(json['date'] as String),
        hourlyLevelsCm: (json['hourlyLevelsCm'] as List)
            .map((e) => e == null ? null : e as int)
            .toList(),
        extremes: (json['extremes'] as List)
            .map((e) => TideExtreme.fromJson(e as Map<String, dynamic>))
            .toList(),
        moonAge: (json['moonAge'] as num).toDouble(),
        tidePhaseName: json['tidePhaseName'] as String,
      );
}
