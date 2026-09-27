import '../models/fishing_score.dart';
import '../models/news_models.dart';
import '../models/tide_data.dart';
import '../models/weather_data.dart';
import '../util/news_ranking.dart';

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
    this.newsBookmarkCounts = const {},
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
  /// 記事数の多い配信元（ゲーム系など）で埋まらないよう、配信元ごとに新着
  /// [allNewsPerSourceLimit] 件までに絞る。
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
    final perSource = <String, int>{};
    return all.where((a) {
      if (!seenTitles.add(a.title)) return false;
      final n = perSource[a.sourceName] ?? 0;
      if (n >= allNewsPerSourceLimit) return false;
      perSource[a.sourceName] = n + 1;
      return true;
    }).toList();
  }

  static const allNewsPerSourceLimit = 15;

  /// 記事URLごとのはてなブックマーク数（「総合」の注目度順に使う）。
  final Map<String, int> newsBookmarkCounts;

  /// 「総合」を注目度の高い順に並べたもの（対象の記事は [allNewsSorted] と同じ）。
  List<NewsArticle> allNewsByPopularity(DateTime now) =>
      sortByPopularity(allNewsSorted, newsBookmarkCounts, now);

  DashboardState copyWith({
    bool? isLoading,
    TideDayData? tide,
    WeatherData? weather,
    FishingScore? fishingScore,
    String? tideError,
    String? weatherError,
    Map<NewsCategory, List<NewsArticle>>? newsByCategory,
    Map<NewsCategory, String?>? newsErrors,
    Map<String, int>? newsBookmarkCounts,
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
        newsBookmarkCounts: newsBookmarkCounts ?? this.newsBookmarkCounts,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        newsLastUpdated: newsLastUpdated ?? this.newsLastUpdated,
      );
}
