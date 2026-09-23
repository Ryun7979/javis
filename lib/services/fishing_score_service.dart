import '../models/fishing_score.dart';
import '../models/tide_data.dart';
import '../models/weather_data.dart';
import '../util/sun_times.dart';

/// 天気・潮回り・気圧・風・時間帯から「釣りやすさ」の目安スコアを算出する。
///
/// 学術的に検証された手法ではなく、一般的に言われる経験則を点数化した
/// 独自のヒューリスティックであることに注意（画面上にも「目安」と明記する）。
class FishingScoreService {
  FishingScore calculate({
    required TideDayData tide,
    required WeatherData weather,
    required double latitude,
    required double longitude,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final breakdown = <FishingScoreBreakdownItem>[
      _tidePhaseScore(tide.tidePhaseName),
      _pressureTrendScore(weather),
      _windScore(weather.windSpeedMs),
      _mazumeScore(currentTime, latitude, longitude),
      _weatherScore(weather.weatherCode),
    ];

    final total = breakdown.fold<double>(0, (sum, item) => sum + item.points);
    final stars = _starsFromTotal(total);

    return FishingScore(stars: stars, breakdown: breakdown);
  }

  int _starsFromTotal(double total) {
    if (total >= 85) return 5;
    if (total >= 65) return 4;
    if (total >= 45) return 3;
    if (total >= 25) return 2;
    return 1;
  }

  FishingScoreBreakdownItem _tidePhaseScore(String phaseName) {
    final points = switch (phaseName) {
      '大潮' => 25.0,
      '中潮' => 18.0,
      '小潮' => 10.0,
      '長潮' => 8.0,
      '若潮' => 8.0,
      _ => 12.0,
    };
    return FishingScoreBreakdownItem(
      label: '潮回り',
      points: points,
      maxPoints: 25,
      reason: '$phaseNameは潮の動きの目安',
    );
  }

  FishingScoreBreakdownItem _pressureTrendScore(WeatherData weather) {
    final history = weather.pressureHistory;
    if (history.length < 2) {
      return const FishingScoreBreakdownItem(
        label: '気圧変化',
        points: 15,
        maxPoints: 25,
        reason: 'データ不足のため中間評価',
      );
    }
    final now = DateTime.now();
    // 現在に最も近い点と、その約6時間前に最も近い点を探す。
    PressurePoint nearest(DateTime target) {
      var best = history.first;
      var bestDiff = history.first.time.difference(target).abs();
      for (final p in history) {
        final diff = p.time.difference(target).abs();
        if (diff < bestDiff) {
          best = p;
          bestDiff = diff;
        }
      }
      return best;
    }

    final current = nearest(now);
    final past = nearest(now.subtract(const Duration(hours: 6)));
    final diff = current.hPa - past.hPa;

    double points;
    String reason;
    if (diff <= -0.5 && diff >= -3.0) {
      points = 25;
      reason = '緩やかな気圧下降（${diff.toStringAsFixed(1)}hPa/6h）で活性が上がりやすい目安';
    } else if (diff.abs() < 0.5) {
      points = 18;
      reason = '気圧はほぼ安定（${diff.toStringAsFixed(1)}hPa/6h）';
    } else if (diff > 0.5 && diff <= 2.0) {
      points = 12;
      reason = '気圧はやや上昇傾向（${diff.toStringAsFixed(1)}hPa/6h）';
    } else {
      points = 5;
      reason = '気圧が急変中（${diff.toStringAsFixed(1)}hPa/6h）、活性が下がりやすい目安';
    }
    return FishingScoreBreakdownItem(
      label: '気圧変化',
      points: points,
      maxPoints: 25,
      reason: reason,
    );
  }

  FishingScoreBreakdownItem _windScore(double windSpeedMs) {
    double points;
    if (windSpeedMs <= 3) {
      points = 20;
    } else if (windSpeedMs <= 6) {
      points = 15;
    } else if (windSpeedMs <= 9) {
      points = 8;
    } else {
      points = 2;
    }
    return FishingScoreBreakdownItem(
      label: '風速',
      points: points,
      maxPoints: 20,
      reason: '風速 ${windSpeedMs.toStringAsFixed(1)} m/s',
    );
  }

  FishingScoreBreakdownItem _mazumeScore(
    DateTime now,
    double latitude,
    double longitude,
  ) {
    final sun = calculateSunTimes(now, latitude, longitude);
    const window = Duration(hours: 1);
    final nearSunrise = now.difference(sun.sunrise).abs() <= window;
    final nearSunset = now.difference(sun.sunset).abs() <= window;
    final isMazume = nearSunrise || nearSunset;
    return FishingScoreBreakdownItem(
      label: '時間帯（マズメ）',
      points: isMazume ? 15 : 6,
      maxPoints: 15,
      reason: isMazume ? '朝夕マズメの時間帯（概算）' : 'マズメ時間帯外（概算）',
    );
  }

  FishingScoreBreakdownItem _weatherScore(int weatherCode) {
    double points;
    String reason;
    if (weatherCode <= 2) {
      points = 15;
      reason = '晴れ・快晴';
    } else if (weatherCode == 3) {
      points = 12;
      reason = '曇り';
    } else if (weatherCode >= 95) {
      points = 0;
      reason = '雷雨で釣行には厳しい状況';
    } else if ((weatherCode >= 61 && weatherCode <= 67) ||
        (weatherCode >= 80 && weatherCode <= 82)) {
      points = 5;
      reason = '雨で条件はやや厳しい';
    } else if (weatherCode >= 45 && weatherCode <= 57) {
      points = 8;
      reason = '霧・霧雨';
    } else {
      points = 6;
      reason = '雪など';
    }
    return FishingScoreBreakdownItem(
      label: '天気',
      points: points,
      maxPoints: 15,
      reason: reason,
    );
  }
}
