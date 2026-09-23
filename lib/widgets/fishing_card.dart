import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/tide_data.dart';
import '../models/weather_data.dart';
import '../providers/dashboard_controller.dart';
import '../providers/settings_provider.dart';
import '../util/weather_code.dart';
import 'fishing_score_badge.dart';
import 'tide_chart.dart';

/// 釣り情報カード（潮汐グラフ、満潮/干潮時刻、天気、気温、風速、釣りやすさの目安）。
class FishingCard extends ConsumerWidget {
  const FishingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final location = ref.watch(settingsProvider).location;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, size: 18, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  location.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (state.fishingScore != null)
                  FishingScoreBadge(score: state.fishingScore!),
              ],
            ),
            const Divider(),
            if (state.weather != null) _WeatherRow(weather: state.weather!),
            if (state.weatherError != null && state.weather == null)
              _ErrorLine(message: '天気: ${state.weatherError}'),
            const SizedBox(height: 8),
            Expanded(
              child: state.tide != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '潮汐グラフ（${state.tide!.tidePhaseName}）',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Expanded(child: TideChart(tide: state.tide!)),
                        _TideExtremesRow(tide: state.tide!),
                      ],
                    )
                  : state.tideError != null
                      ? _ErrorLine(message: '潮汐: ${state.tideError}')
                      : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherRow extends StatelessWidget {
  const _WeatherRow({required this.weather});
  final WeatherData weather;

  @override
  Widget build(BuildContext context) {
    final info = describeWeatherCode(weather.weatherCode);
    return Row(
      children: [
        Icon(info.icon, size: 28),
        const SizedBox(width: 8),
        Text(info.label, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 16),
        Text('${weather.temperatureC.toStringAsFixed(1)}℃'),
        const SizedBox(width: 16),
        Text('降水確率 ${weather.precipitationProbabilityPercent}%'),
        const SizedBox(width: 16),
        Text('風 ${weather.windSpeedMs.toStringAsFixed(1)}m/s'),
        const SizedBox(width: 16),
        Text('気圧 ${weather.pressureHpa.toStringAsFixed(0)}hPa'),
      ],
    );
  }
}

class _TideExtremesRow extends StatelessWidget {
  const _TideExtremesRow({required this.tide});
  final TideDayData tide;

  @override
  Widget build(BuildContext context) {
    if (tide.extremes.isEmpty) {
      return const Text('満潮/干潮データなし', style: TextStyle(fontSize: 12));
    }
    final formatter = DateFormat('HH:mm');
    return Wrap(
      spacing: 12,
      children: [
        for (final e in tide.extremes)
          Text(
            '${e.isHigh ? '満潮' : '干潮'} ${formatter.format(e.time)} (${e.levelCm}cm)',
            style: TextStyle(
              fontSize: 12,
              color: e.isHigh ? Colors.orangeAccent : Colors.lightBlueAccent,
            ),
          ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(fontSize: 12, color: Colors.redAccent),
    );
  }
}
