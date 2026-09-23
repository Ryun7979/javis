import 'package:flutter_test/flutter_test.dart';
import 'package:wall_jarvis/models/tide_data.dart';
import 'package:wall_jarvis/models/weather_data.dart';
import 'package:wall_jarvis/services/fishing_score_service.dart';

void main() {
  final service = FishingScoreService();

  TideDayData tideWith(String phase) => TideDayData(
        date: DateTime(2026, 1, 1),
        hourlyLevelsCm: List.filled(24, 100),
        extremes: const [],
        moonAge: 0,
        tidePhaseName: phase,
      );

  WeatherData weatherWith({
    required int weatherCode,
    required double windSpeedMs,
    required List<double> pressures,
  }) {
    final now = DateTime.now();
    return WeatherData(
      fetchedAt: now,
      temperatureC: 20,
      weatherCode: weatherCode,
      windSpeedMs: windSpeedMs,
      windDirectionDeg: 0,
      pressureHpa: pressures.last,
      pressureHistory: [
        for (var i = 0; i < pressures.length; i++)
          PressurePoint(
            time: now.subtract(Duration(hours: pressures.length - i)),
            hPa: pressures[i],
          ),
      ],
      precipitationProbabilityPercent: 10,
    );
  }

  test('good conditions yield a high star rating', () {
    final score = service.calculate(
      tide: tideWith('大潮'),
      weather: weatherWith(
        weatherCode: 0,
        windSpeedMs: 1.5,
        pressures: [1015, 1014, 1013],
      ),
      latitude: 35.45,
      longitude: 139.65,
    );
    expect(score.stars, inInclusiveRange(1, 5));
    expect(score.breakdown.length, 5);
  });

  test('harsh conditions yield a low star rating', () {
    final score = service.calculate(
      tide: tideWith('小潮'),
      weather: weatherWith(
        weatherCode: 96,
        windSpeedMs: 15,
        pressures: [1000, 1005, 1010],
      ),
      latitude: 35.45,
      longitude: 139.65,
    );
    expect(score.stars, lessThanOrEqualTo(2));
  });
}
