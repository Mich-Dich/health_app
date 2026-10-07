import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/weight_entry.dart';

class WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  final double? goalWeight;
  final bool showMovingAverage;

  const WeightChart({
    super.key,
    required this.entries,
    this.goalWeight,
    this.showMovingAverage = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) return const SizedBox.shrink();

    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    final firstDay = DateUtils.dateOnly(sorted.first.date);

    double xOf(DateTime d) =>
        DateUtils.dateOnly(d).difference(firstDay).inDays.toDouble();

    final spots = sorted.map((e) => FlSpot(xOf(e.date), e.weight)).toList();

    // Centered ±3-day moving average. Handles sparse data gracefully.
    final maSpots = showMovingAverage
        ? sorted.map((e) {
            final window = sorted
                .where((o) => o.date.difference(e.date).inDays.abs() <= 3);
            final avg = window.map((o) => o.weight).reduce((a, b) => a + b) /
                window.length;
            return FlSpot(xOf(e.date), avg);
          }).toList()
        : <FlSpot>[];

    final weights = sorted.map((e) => e.weight).toList();
    var minV = weights.reduce(math.min);
    var maxV = weights.reduce(math.max);
    if (goalWeight != null) {
      minV = math.min(minV, goalWeight!);
      maxV = math.max(maxV, goalWeight!);
    }
    final range = maxV - minV;
    final pad = range < 0.5 ? 1.0 : range * 0.2;
    final minY = math.max(0.0, minV - pad);
    final maxY = maxV + pad;

    final lastX = spots.last.x;
    final maxX = lastX < 1 ? 1.0 : lastX;
    final xInterval = math.max(1.0, (maxX / 4).ceilToDouble());
    final yInterval = _niceInterval(maxY - minY);

    final lineColor = theme.colorScheme.primary;
    final maColor = theme.colorScheme.tertiary;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant.withAlpha(120),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: goalWeight == null
            ? const ExtraLinesData()
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: goalWeight!,
                    color: Colors.orange.withAlpha(200),
                    strokeWidth: 2,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      labelResolver: (_) =>
                          'Goal ${goalWeight!.toStringAsFixed(1)}',
                    ),
                  ),
                ],
              ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: yInterval,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  value.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > lastX + 0.001) {
                  return const SizedBox.shrink();
                }
                final date = firstDay.add(Duration(days: value.round()));
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('d/M').format(date),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((spot) {
              final date = firstDay.add(Duration(days: spot.x.round()));
              final isMA = spot.barIndex == 1;
              return LineTooltipItem(
                '${DateFormat('d MMM yyyy').format(date)}\n'
                '${isMA ? 'avg ' : ''}${spot.y.toStringAsFixed(1)} kg',
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            barWidth: 3,
            color: lineColor,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: theme.colorScheme.surface,
                strokeWidth: 2.5,
                strokeColor: lineColor,
              ),
            ),
            belowBarData: BarAreaData(show: true, color: lineColor.withAlpha(38)),
          ),
          if (showMovingAverage && maSpots.length > 1)
            LineChartBarData(
              spots: maSpots,
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              barWidth: 2,
              color: maColor,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
        ],
      ),
    );
  }

  static double _niceInterval(double range) {
    if (range <= 0) return 1;
    final raw = range / 4;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalized = raw / magnitude;
    double nice;
    if (normalized <= 1) {
      nice = 1;
    } else if (normalized <= 2) {
      nice = 2;
    } else if (normalized <= 5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * magnitude;
  }
}