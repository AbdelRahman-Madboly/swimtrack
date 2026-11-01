// SwolfChart widget - fl_chart line chart showing SWOLF score per lap.

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../models/session.dart';

/// Line chart displaying SWOLF score for each lap in a session.
/// Lower SWOLF = better performance (shown with gradient fill).
class SwolfChart extends StatelessWidget {
  /// The laps to chart.
  final List<Lap> laps;

  /// Height of the chart widget.
  final double height;

  const SwolfChart({
    super.key,
    required this.laps,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (laps.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No lap data', style: SwimTrackTextStyles.body()),
        ),
      );
    }

    final spots = laps
        .map((l) => FlSpot(l.lapNumber.toDouble(), l.swolf))
        .toList();

    final minY = (laps.map((l) => l.swolf).reduce((a, b) => a < b ? a : b) - 5)
        .clamp(0.0, double.infinity);
    final maxY =
        laps.map((l) => l.swolf).reduce((a, b) => a > b ? a : b) + 5;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: SwimTrackColors.divider,
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: SwimTrackTextStyles.tiny(),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final lap = value.toInt();
                  if (lap < 1 || lap > laps.length) return const SizedBox();
                  return Text(
                    lap.toString(),
                    style: SwimTrackTextStyles.tiny(),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: SwimTrackColors.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: SwimTrackColors.primary,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    SwimTrackColors.primary.withValues(alpha: 0.15),
                    SwimTrackColors.secondary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots
                  .map((s) => LineTooltipItem(
                        'Lap ${s.x.toInt()}\n${s.y.toStringAsFixed(1)}',
                        SwimTrackTextStyles.tiny(color: Colors.white),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}