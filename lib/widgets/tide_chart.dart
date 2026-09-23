import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/tide_data.dart';
import '../theme/cyberpunk_colors.dart';

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

    final color = CyberpunkColors.neonCyan;

    // 折れ線の山・谷（満潮/干潮に近い極値）を発光マーカーで示す。
    final peakIndices = <int>{};
    for (var i = 1; i < spots.length - 1; i++) {
      final prev = spots[i - 1].y;
      final curr = spots[i].y;
      final next = spots[i + 1].y;
      if ((curr > prev && curr > next) || (curr < prev && curr < next)) {
        peakIndices.add(i);
      }
    }

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
            shadow: Shadow(color: color.withValues(alpha: 0.7), blurRadius: 10),
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) {
                final index = spots.indexOf(spot);
                return peakIndices.contains(index);
              },
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: CyberpunkColors.neonMagenta,
                strokeWidth: 4,
                strokeColor: CyberpunkColors.neonMagenta.withValues(alpha: 0.3),
              ),
            ),
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
      // データ更新（潮汐の再取得）のたびに折れ線がなめらかに描き直される。
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
    );
  }
}
