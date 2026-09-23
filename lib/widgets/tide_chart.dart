import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/tide_data.dart';

/// 潮汐グラフ（毎時潮位の折れ線＋満潮/干潮のマーカー）。
class TideChart extends StatelessWidget {
  const TideChart({super.key, required this.tide});

  final TideDayData tide;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var hour = 0; hour < tide.hourlyLevelsCm.length; hour++) {
      final level = tide.hourlyLevelsCm[hour];
      if (level != null) spots.add(FlSpot(hour.toDouble(), level.toDouble()));
    }
    if (spots.isEmpty) {
      return const Center(child: Text('潮汐グラフのデータがありません'));
    }

    final levels = spots.map((s) => s.y).toList();
    final minY = levels.reduce((a, b) => a < b ? a : b) - 10;
    final maxY = levels.reduce((a, b) => a > b ? a : b) + 10;

    final color = Theme.of(context).colorScheme.primary;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 23,
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 50,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 3,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}時',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.15)),
          ),
        ],
        extraLinesData: ExtraLinesData(
          verticalLines: [
            for (final e in tide.extremes)
              VerticalLine(
                x: e.time.hour + e.time.minute / 60,
                color: (e.isHigh ? Colors.orangeAccent : Colors.lightBlueAccent)
                    .withValues(alpha: 0.7),
                strokeWidth: 1,
                dashArray: [4, 4],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topCenter,
                  style: const TextStyle(fontSize: 10),
                  labelResolver: (line) =>
                      '${e.isHigh ? '満' : '干'} ${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
