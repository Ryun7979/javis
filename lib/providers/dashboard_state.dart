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
  final DateTime? lastUpdated;

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
      );
}
