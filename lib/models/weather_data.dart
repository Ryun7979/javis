/// 気圧の推移（釣果指数の気圧トレンド判定に使う）。
class PressurePoint {
  const PressurePoint({required this.time, required this.hPa});

  final DateTime time;
  final double hPa;

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'hPa': hPa,
      };

  factory PressurePoint.fromJson(Map<String, dynamic> json) => PressurePoint(
        time: DateTime.parse(json['time'] as String),
        hPa: (json['hPa'] as num).toDouble(),
      );
}

class WeatherData {
  const WeatherData({
    required this.fetchedAt,
    required this.temperatureC,
    required this.weatherCode,
    required this.windSpeedMs,
    required this.windDirectionDeg,
    required this.pressureHpa,
    required this.pressureHistory,
    required this.precipitationProbabilityPercent,
  });

  final DateTime fetchedAt;
  final double temperatureC;

  /// WMO weather code（Open-Meteoの天気コード）。
  final int weatherCode;
  final double windSpeedMs;
  final double windDirectionDeg;
  final double pressureHpa;

  /// 直近24時間分の気圧推移（新しい順ではなく時系列順）。
  final List<PressurePoint> pressureHistory;
  final int precipitationProbabilityPercent;

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'temperatureC': temperatureC,
        'weatherCode': weatherCode,
        'windSpeedMs': windSpeedMs,
        'windDirectionDeg': windDirectionDeg,
        'pressureHpa': pressureHpa,
        'pressureHistory': pressureHistory.map((e) => e.toJson()).toList(),
        'precipitationProbabilityPercent': precipitationProbabilityPercent,
      };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        temperatureC: (json['temperatureC'] as num).toDouble(),
        weatherCode: json['weatherCode'] as int,
        windSpeedMs: (json['windSpeedMs'] as num).toDouble(),
        windDirectionDeg: (json['windDirectionDeg'] as num).toDouble(),
        pressureHpa: (json['pressureHpa'] as num).toDouble(),
        pressureHistory: (json['pressureHistory'] as List)
            .map((e) => PressurePoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        precipitationProbabilityPercent:
            json['precipitationProbabilityPercent'] as int,
      );
}
