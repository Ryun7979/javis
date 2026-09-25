import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cache_service.dart';
import '../services/fishing_score_service.dart';
import '../services/news_service.dart';
import '../services/rain_radar_service.dart';
import '../services/tide_service.dart';
import '../services/weather_service.dart';

/// main() で CacheService.open() の結果を override して差し込む。
final cacheServiceProvider = Provider<CacheService>(
  (ref) => throw UnimplementedError('cacheServiceProvider is not overridden'),
);

final tideServiceProvider = Provider<TideService>(
  (ref) => TideService(ref.watch(cacheServiceProvider)),
);

final weatherServiceProvider = Provider<WeatherService>(
  (ref) => WeatherService(ref.watch(cacheServiceProvider)),
);

final newsServiceProvider = Provider<NewsService>(
  (ref) => NewsService(ref.watch(cacheServiceProvider)),
);

final rainRadarServiceProvider = Provider<RainRadarService>(
  (ref) => RainRadarService(),
);

final fishingScoreServiceProvider = Provider<FishingScoreService>(
  (ref) => FishingScoreService(),
);
