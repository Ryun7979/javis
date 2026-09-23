import '../models/fishing_score.dart';
import '../models/news_models.dart';
import '../models/tide_data.dart';
import '../models/weather_data.dart';

class DashboardState {
  const DashboardState({
    required this.isLoading,
    this.tide,
    this.weather,
    this.fishingScore,
    this.tideError,
    this.weatherError,
    this.newsByCategory = const {},
    this.newsErrors = const {},
    this.lastUpdated,
    this.newsLastUpdated,
  });

  factory DashboardState.initial() => const DashboardState(isLoading: true);

  final bool isLoading;
  final TideDayData? tide;
  final WeatherData? weather;
  final FishingScore? fishingScore;
  final String? tideError;
  final String? weatherError;
  final Map<NewsCategory, List<NewsArticle>> newsByCategory;
  final Map<NewsCategory, String?> newsErrors;

  /// 潮汐・天気の最終更新時刻。
  final DateTime? lastUpdated;

  /// ニュースの最終更新時刻（潮汐・天気とは別間隔で更新されるため分けて保持する）。
  final DateTime? newsLastUpdated;

  /// 全ジャンルのニュースを新着順にまとめたもの（「総合」タブ用）。
  /// 同じ記事が複数の配信元（例: ITmedia NEWSとITmedia AI+）に重複掲載される
  /// ことがあるため、タイトルが同じものは1件にまとめる。
  List<NewsArticle> get allNewsSorted {
    final all = newsByCategory.values.expand((e) => e).toList();
    all.sort((a, b) {
      final ad = a.publishedAt;
      final bd = b.publishedAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    final seenTitles = <String>{};
    return all.where((a) => seenTitles.add(a.title)).toList();
  }

  DashboardState copyWith({
    bool? isLoading,
    TideDayData? tide,
    WeatherData? weather,
    FishingScore? fishingScore,
    String? tideError,
    String? weatherError,
    Map<NewsCategory, List<NewsArticle>>? newsByCategory,
    Map<NewsCategory, String?>? newsErrors,
    DateTime? lastUpdated,
    DateTime? newsLastUpdated,
  }) =>
      DashboardState(
        isLoading: isLoading ?? this.isLoading,
        tide: tide ?? this.tide,
        weather: weather ?? this.weather,
        fishingScore: fishingScore ?? this.fishingScore,
        tideError: tideError,
        weatherError: weatherError,
        newsByCategory: newsByCategory ?? this.newsByCategory,
        newsErrors: newsErrors ?? this.newsErrors,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        newsLastUpdated: newsLastUpdated ?? this.newsLastUpdated,
      );
}
