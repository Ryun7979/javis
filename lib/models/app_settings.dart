import '../data/default_news_sources.dart';
import '../data/observation_points.dart';
import 'location_point.dart';
import 'news_models.dart';

class AppSettings {
  const AppSettings({
    required this.location,
    required this.tideWeatherUpdateIntervalMinutes,
    required this.newsUpdateIntervalMinutes,
    required this.newsSources,
  });

  final LocationPoint location;

  /// 潮汐・天気の自動更新間隔（分）。仕様書の「数十分〜1時間に1回」に合わせる。
  final int tideWeatherUpdateIntervalMinutes;

  /// ニュースの自動更新間隔（分）。仕様書の例（30分ごと）に合わせる。
  final int newsUpdateIntervalMinutes;

  final List<NewsSource> newsSources;

  static AppSettings defaults() => AppSettings(
        location: observationPoints.first,
        tideWeatherUpdateIntervalMinutes: 30,
        newsUpdateIntervalMinutes: 30,
        newsSources: defaultNewsSources,
      );

  AppSettings copyWith({
    LocationPoint? location,
    int? tideWeatherUpdateIntervalMinutes,
    int? newsUpdateIntervalMinutes,
    List<NewsSource>? newsSources,
  }) =>
      AppSettings(
        location: location ?? this.location,
        tideWeatherUpdateIntervalMinutes: tideWeatherUpdateIntervalMinutes ??
            this.tideWeatherUpdateIntervalMinutes,
        newsUpdateIntervalMinutes:
            newsUpdateIntervalMinutes ?? this.newsUpdateIntervalMinutes,
        newsSources: newsSources ?? this.newsSources,
      );

  Map<String, dynamic> toJson() => {
        'location': location.toJson(),
        'tideWeatherUpdateIntervalMinutes': tideWeatherUpdateIntervalMinutes,
        'newsUpdateIntervalMinutes': newsUpdateIntervalMinutes,
        'newsSources': newsSources.map((e) => e.toJson()).toList(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        location: LocationPoint.fromJson(
            json['location'] as Map<String, dynamic>),
        tideWeatherUpdateIntervalMinutes:
            json['tideWeatherUpdateIntervalMinutes'] as int,
        newsUpdateIntervalMinutes: json['newsUpdateIntervalMinutes'] as int,
        newsSources: (json['newsSources'] as List)
            .map((e) => NewsSource.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
