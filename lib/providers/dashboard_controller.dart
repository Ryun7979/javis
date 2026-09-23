import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/app_settings.dart';
import '../models/news_models.dart';
import 'core_providers.dart';
import 'dashboard_state.dart';
import 'settings_provider.dart';

/// 潮汐・天気・釣果指数・ニュースをまとめて保持し、設定された間隔で自動更新する。
class DashboardController extends StateNotifier<DashboardState> {
  DashboardController(this._ref) : super(DashboardState.initial()) {
    _init();
  }

  final Ref _ref;
  Timer? _tideWeatherTimer;
  Timer? _newsTimer;

  void _init() {
    unawaited(refreshTideWeather());
    unawaited(refreshNews());
    _scheduleTimers();

    _ref.listen<AppSettings>(settingsProvider, (previous, next) {
      if (previous == null) return;
      if (previous.location.id != next.location.id) {
        unawaited(refreshTideWeather());
      }
      if (previous.tideWeatherUpdateIntervalMinutes !=
              next.tideWeatherUpdateIntervalMinutes ||
          previous.newsUpdateIntervalMinutes !=
              next.newsUpdateIntervalMinutes) {
        _scheduleTimers();
      }
      if (!_sameNewsSources(previous.newsSources, next.newsSources)) {
        unawaited(refreshNews());
      }
    });
  }

  bool _sameNewsSources(List<NewsSource> a, List<NewsSource> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].rssUrl != b[i].rssUrl) return false;
    }
    return true;
  }

  void _scheduleTimers() {
    _tideWeatherTimer?.cancel();
    _newsTimer?.cancel();
    final settings = _ref.read(settingsProvider);
    _tideWeatherTimer = Timer.periodic(
      Duration(minutes: settings.tideWeatherUpdateIntervalMinutes),
      (_) => unawaited(refreshTideWeather()),
    );
    _newsTimer = Timer.periodic(
      Duration(minutes: settings.newsUpdateIntervalMinutes),
      (_) => unawaited(refreshNews()),
    );
  }

  Future<void> refreshTideWeather() async {
    final settings = _ref.read(settingsProvider);
    final tideService = _ref.read(tideServiceProvider);
    final weatherService = _ref.read(weatherServiceProvider);

    var tide = state.tide;
    String? tideError;
    try {
      final fetched = await tideService.getTideForDate(
        settings.location.jmaStationCode,
        DateTime.now(),
      );
      if (fetched == null) {
        tideError = 'この地点・日付の潮汐データが見つかりませんでした';
      } else {
        tide = fetched;
      }
    } catch (e) {
      tideError = e.toString();
    }

    var weather = state.weather;
    String? weatherError;
    try {
      weather = await weatherService.getWeather(
        settings.location.latitude,
        settings.location.longitude,
      );
    } catch (e) {
      weatherError = e.toString();
    }

    var fishingScore = state.fishingScore;
    if (tide != null && weather != null) {
      fishingScore = _ref.read(fishingScoreServiceProvider).calculate(
            tide: tide,
            weather: weather,
            latitude: settings.location.latitude,
            longitude: settings.location.longitude,
          );
    }

    if (!mounted) return;
    state = state.copyWith(
      isLoading: false,
      tide: tide,
      weather: weather,
      fishingScore: fishingScore,
      tideError: tideError,
      weatherError: weatherError,
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> refreshNews() async {
    final settings = _ref.read(settingsProvider);
    final newsService = _ref.read(newsServiceProvider);

    final byCategory = <NewsCategory, List<NewsArticle>>{};
    final errors = <NewsCategory, String?>{};

    for (final category in NewsCategory.values) {
      final sources =
          settings.newsSources.where((s) => s.category == category).toList();
      final articles = <NewsArticle>[];
      String? lastError;
      for (final source in sources) {
        try {
          articles.addAll(await newsService.fetchArticles(source));
        } catch (e) {
          lastError = e.toString();
        }
      }
      articles.sort((a, b) {
        final ad = a.publishedAt;
        final bd = b.publishedAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
      byCategory[category] = articles.take(30).toList();
      errors[category] = articles.isEmpty ? lastError : null;
    }

    if (!mounted) return;
    state = state.copyWith(
      newsByCategory: byCategory,
      newsErrors: errors,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _tideWeatherTimer?.cancel();
    _newsTimer?.cancel();
    super.dispose();
  }
}

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>(
  (ref) => DashboardController(ref),
);
