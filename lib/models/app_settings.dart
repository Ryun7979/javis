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
    required this.useFixedJst,
  });

  final LocationPoint location;

  /// 潮汐・天気の自動更新間隔（分）。仕様書の「数十分〜1時間に1回」に合わせる。
  final int tideWeatherUpdateIntervalMinutes;

  /// ニュースの自動更新間隔（分）。仕様書の例（30分ごと）に合わせる。
  final int newsUpdateIntervalMinutes;

  final List<NewsSource> newsSources;

  /// true の場合、端末のシステムタイムゾーン設定によらず常に日本標準時(UTC+9)を
  /// 基準に時計表示・日付境界判定を行う（キオスク端末のTZ誤設定対策）。
  final bool useFixedJst;

  static AppSettings defaults() => AppSettings(
        location: observationPoints.first,
        tideWeatherUpdateIntervalMinutes: 30,
        newsUpdateIntervalMinutes: 30,
        newsSources: defaultNewsSources,
        useFixedJst: true,
      );

  AppSettings copyWith({
    LocationPoint? location,
    int? tideWeatherUpdateIntervalMinutes,
    int? newsUpdateIntervalMinutes,
    List<NewsSource>? newsSources,
    bool? useFixedJst,
  }) =>
      AppSettings(
        location: location ?? this.location,
        tideWeatherUpdateIntervalMinutes: tideWeatherUpdateIntervalMinutes ??
            this.tideWeatherUpdateIntervalMinutes,
        newsUpdateIntervalMinutes:
            newsUpdateIntervalMinutes ?? this.newsUpdateIntervalMinutes,
        newsSources: newsSources ?? this.newsSources,
        useFixedJst: useFixedJst ?? this.useFixedJst,
      );

  Map<String, dynamic> toJson() => {
        'location': location.toJson(),
        'tideWeatherUpdateIntervalMinutes': tideWeatherUpdateIntervalMinutes,
        'newsUpdateIntervalMinutes': newsUpdateIntervalMinutes,
        'newsSources': newsSources.map((e) => e.toJson()).toList(),
        'useFixedJst': useFixedJst,
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
        // 既存キャッシュ（フィールド追加前）との後方互換のため未設定時はtrue扱い。
        useFixedJst: json['useFixedJst'] as bool? ?? true,
      );
}
