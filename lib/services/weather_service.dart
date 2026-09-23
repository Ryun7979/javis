import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_data.dart';
import 'cache_service.dart';

/// Open-Meteo（APIキー不要・非商用個人利用無料）から天気を取得するサービス。
/// https://open-meteo.com/en/docs
class WeatherService {
  WeatherService(this._cache, {http.Client? client})
      : _client = client ?? http.Client();

  final CacheService _cache;
  final http.Client _client;

  static const Duration _cacheTtl = Duration(minutes: 15);

  String _cacheKey(double lat, double lon) =>
      'weather_${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';

  Future<WeatherData> getWeather(double latitude, double longitude) async {
    final key = _cacheKey(latitude, longitude);
    final cached = _cache.read(key);
    if (cached != null) {
      final (savedAt, data) = cached;
      if (DateTime.now().difference(savedAt) < _cacheTtl) {
        return WeatherData.fromJson(data as Map<String, dynamic>);
      }
    }
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,surface_pressure'
        '&hourly=precipitation_probability,surface_pressure'
        '&forecast_days=2&timezone=Asia%2FTokyo',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw WeatherServiceException('天気APIエラー: HTTP ${res.statusCode}');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final weather = _parse(json);
      await _cache.writeJson(key, weather.toJson());
      return weather;
    } catch (e) {
      if (cached != null) {
        return WeatherData.fromJson(cached.$2 as Map<String, dynamic>);
      }
      throw WeatherServiceException('天気データを取得できませんでした: $e');
    }
  }

  WeatherData _parse(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final pressures = (hourly['surface_pressure'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final precipProbs =
        (hourly['precipitation_probability'] as List).cast<num>();

    final now = DateTime.now();
    final pressureHistory = <PressurePoint>[];
    for (var i = 0; i < times.length && i < pressures.length; i++) {
      pressureHistory.add(
        PressurePoint(time: DateTime.parse(times[i]), hPa: pressures[i]),
      );
    }

    // 現在時刻にもっとも近い時間帯の降水確率を使う。
    var nearestIndex = 0;
    var nearestDiff = const Duration(days: 999);
    for (var i = 0; i < times.length; i++) {
      final t = DateTime.parse(times[i]);
      final diff = t.difference(now).abs();
      if (diff < nearestDiff) {
        nearestDiff = diff;
        nearestIndex = i;
      }
    }
    final precipProb = nearestIndex < precipProbs.length
        ? precipProbs[nearestIndex].toInt()
        : 0;

    return WeatherData(
      fetchedAt: DateTime.now(),
      temperatureC: (current['temperature_2m'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
      windSpeedMs: (current['wind_speed_10m'] as num).toDouble() / 3.6,
      windDirectionDeg: (current['wind_direction_10m'] as num).toDouble(),
      pressureHpa: (current['surface_pressure'] as num).toDouble(),
      pressureHistory: pressureHistory,
      precipitationProbabilityPercent: precipProb,
    );
  }
}

class WeatherServiceException implements Exception {
  WeatherServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
