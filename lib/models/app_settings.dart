import '../data/default_news_sources.dart';
import '../data/observation_points.dart';
import '../util/brightness_schedule.dart';
import 'location_point.dart';
import 'news_models.dart';

class AppSettings {
  const AppSettings({
    required this.location,
    required this.tideWeatherUpdateIntervalMinutes,
    required this.newsUpdateIntervalMinutes,
    required this.newsSources,
    required this.useFixedJst,
    required this.dimBrightness,
    required this.brightBrightness,
    required this.articleAutoCloseMinutes,
    required this.panelSwitchIntervalMinutes,
    required this.apodSwitchIntervalMinutes,
    required this.apodBackgroundOpacity,
    required this.apodFullscreenAutoCloseMinutes,
    required this.nasaApiKey,
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

  /// 電源接続時、暗くする時間帯（2:00〜19:00）の画面輝度（0.0〜1.0）。
  final double dimBrightness;

  /// 電源接続時、明るくする時間帯（19:00〜翌2:00）の画面輝度（0.0〜1.0）。
  final double brightBrightness;

  /// ニュース記事のアプリ内表示を、無操作のまま自動で閉じるまでの時間（分）。
  /// キオスクで記事を開きっぱなしのまま放置されるのを防ぐ。
  final int articleAutoCloseMinutes;

  static const defaultArticleAutoCloseMinutes = 3;

  /// 釣り情報と雨雲レーダーを自動で切り替える間隔（分）。0 のときは自動で切り替えない。
  final int panelSwitchIntervalMinutes;

  static const defaultPanelSwitchIntervalMinutes = 10;

  /// 時計の背景を「グリッド⇔NASAの宇宙写真」で切り替える間隔（分）。0 のときは切り替えずグリッドのまま。
  final int apodSwitchIntervalMinutes;

  static const defaultApodSwitchIntervalMinutes = 15;

  /// 時計の背景に写真を出すときの写真の不透明度（0.0〜1.0）。時計が読みにくくならないよう低めにする。
  final double apodBackgroundOpacity;

  static const defaultApodBackgroundOpacity = 0.35;

  /// 写真の全画面表示を、タッチされなくても自動で閉じるまでの時間（分）。静止画の焼き付き対策。
  final int apodFullscreenAutoCloseMinutes;

  static const defaultApodFullscreenAutoCloseMinutes = 10;

  /// NASA APIキー。空のときは共用の DEMO_KEY を使う（端末内のHiveにだけ保存される）。
  final String nasaApiKey;

  static AppSettings defaults() => AppSettings(
        location: observationPoints.first,
        tideWeatherUpdateIntervalMinutes: 30,
        newsUpdateIntervalMinutes: 30,
        newsSources: defaultNewsSources,
        useFixedJst: true,
        dimBrightness: defaultDimBrightness,
        brightBrightness: defaultBrightBrightness,
        articleAutoCloseMinutes: defaultArticleAutoCloseMinutes,
        panelSwitchIntervalMinutes: defaultPanelSwitchIntervalMinutes,
        apodSwitchIntervalMinutes: defaultApodSwitchIntervalMinutes,
        apodBackgroundOpacity: defaultApodBackgroundOpacity,
        apodFullscreenAutoCloseMinutes: defaultApodFullscreenAutoCloseMinutes,
        nasaApiKey: '',
      );

  AppSettings copyWith({
    LocationPoint? location,
    int? tideWeatherUpdateIntervalMinutes,
    int? newsUpdateIntervalMinutes,
    List<NewsSource>? newsSources,
    bool? useFixedJst,
    double? dimBrightness,
    double? brightBrightness,
    int? articleAutoCloseMinutes,
    int? panelSwitchIntervalMinutes,
    int? apodSwitchIntervalMinutes,
    double? apodBackgroundOpacity,
    int? apodFullscreenAutoCloseMinutes,
    String? nasaApiKey,
  }) =>
      AppSettings(
        location: location ?? this.location,
        tideWeatherUpdateIntervalMinutes: tideWeatherUpdateIntervalMinutes ??
            this.tideWeatherUpdateIntervalMinutes,
        newsUpdateIntervalMinutes:
            newsUpdateIntervalMinutes ?? this.newsUpdateIntervalMinutes,
        newsSources: newsSources ?? this.newsSources,
        useFixedJst: useFixedJst ?? this.useFixedJst,
        dimBrightness: dimBrightness ?? this.dimBrightness,
        brightBrightness: brightBrightness ?? this.brightBrightness,
        articleAutoCloseMinutes:
            articleAutoCloseMinutes ?? this.articleAutoCloseMinutes,
        panelSwitchIntervalMinutes:
            panelSwitchIntervalMinutes ?? this.panelSwitchIntervalMinutes,
        apodSwitchIntervalMinutes:
            apodSwitchIntervalMinutes ?? this.apodSwitchIntervalMinutes,
        apodBackgroundOpacity:
            apodBackgroundOpacity ?? this.apodBackgroundOpacity,
        apodFullscreenAutoCloseMinutes: apodFullscreenAutoCloseMinutes ??
            this.apodFullscreenAutoCloseMinutes,
        nasaApiKey: nasaApiKey ?? this.nasaApiKey,
      );

  Map<String, dynamic> toJson() => {
        'location': location.toJson(),
        'tideWeatherUpdateIntervalMinutes': tideWeatherUpdateIntervalMinutes,
        'newsUpdateIntervalMinutes': newsUpdateIntervalMinutes,
        'newsSources': newsSources.map((e) => e.toJson()).toList(),
        'useFixedJst': useFixedJst,
        'dimBrightness': dimBrightness,
        'brightBrightness': brightBrightness,
        'articleAutoCloseMinutes': articleAutoCloseMinutes,
        'panelSwitchIntervalMinutes': panelSwitchIntervalMinutes,
        'apodSwitchIntervalMinutes': apodSwitchIntervalMinutes,
        'apodBackgroundOpacity': apodBackgroundOpacity,
        'apodFullscreenAutoCloseMinutes': apodFullscreenAutoCloseMinutes,
        'nasaApiKey': nasaApiKey,
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
        // 輝度設定の追加前に保存された設定では既定値を使う。
        dimBrightness: (json['dimBrightness'] as num?)?.toDouble() ??
            defaultDimBrightness,
        brightBrightness: (json['brightBrightness'] as num?)?.toDouble() ??
            defaultBrightBrightness,
        // 記事の自動クローズ設定の追加前に保存された設定では既定値を使う。
        articleAutoCloseMinutes: json['articleAutoCloseMinutes'] as int? ??
            defaultArticleAutoCloseMinutes,
        // 釣り情報/雨雲レーダー切り替えの追加前に保存された設定では既定値を使う。
        panelSwitchIntervalMinutes: json['panelSwitchIntervalMinutes'] as int? ??
            defaultPanelSwitchIntervalMinutes,
        // NASAの宇宙写真の追加前に保存された設定では既定値を使う。
        apodSwitchIntervalMinutes: json['apodSwitchIntervalMinutes'] as int? ??
            defaultApodSwitchIntervalMinutes,
        apodBackgroundOpacity:
            (json['apodBackgroundOpacity'] as num?)?.toDouble() ??
                defaultApodBackgroundOpacity,
        apodFullscreenAutoCloseMinutes:
            json['apodFullscreenAutoCloseMinutes'] as int? ??
                defaultApodFullscreenAutoCloseMinutes,
        nasaApiKey: json['nasaApiKey'] as String? ?? '',
      );
}
