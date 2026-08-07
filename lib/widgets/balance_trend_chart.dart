import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/balance.dart';
import '../utils/formats.dart';

/// 余额趋势折线图：展示某账户近 30 天可用余额变化。
class BalanceTrendChart extends StatelessWidget {
  const BalanceTrendChart({super.key, required this.snapshots});

  final List<BalanceSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = <double>[];
    var currency = 'CNY';
    for (final s in snapshots) {
      final v = s.available;
      if (v != null) {
        points.add(v);
        currency = s.currency;
      }
    }
    if (points.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('暂无趋势数据（刷新余额后生成）')),
      );
    }
    final minV = points.reduce((a, b) => a < b ? a : b);
    final maxV = points.reduce((a, b) => a > b ? a : b);
    final minY = minV <= 0 ? 0.0 : minV * 0.9;
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.1;
    final labelInterval =
        (snapshots.length / 5).ceil().clamp(1, snapshots.length);

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (snapshots.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(2),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 ||
                      index >= snapshots.length ||
                      index % labelInterval != 0) {
                    return const SizedBox.shrink();
                  }
                  final day = snapshots[index].createdAt.toLocal();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${day.month}/${day.day}',
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => <LineTooltipItem>[
                for (final spot in touchedSpots)
                  LineTooltipItem(
                    '${formatDateTime(snapshots[spot.spotIndex].createdAt.toLocal())}\n'
                    '${formatMoney(spot.y)} $currency',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: <FlSpot>[
                for (var i = 0; i < snapshots.length; i++)
                  FlSpot(i.toDouble(), snapshots[i].available ?? 0),
              ],
              isCurved: true,
              color: theme.colorScheme.primary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
