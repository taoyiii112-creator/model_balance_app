import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/usage_stats.dart';

/// 柱状图：按天展示消费金额或 Token 用量（可切换）。
class DailyUsageChart extends StatefulWidget {
  const DailyUsageChart({super.key, required this.daily});

  final List<DailyUsage> daily;

  @override
  State<DailyUsageChart> createState() => _DailyUsageChartState();
}

class _DailyUsageChartState extends State<DailyUsageChart> {
  bool _showCost = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daily = widget.daily;
    if (daily.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('暂无每日用量数据')),
      );
    }

    final values =
        daily.map((d) => _showCost ? d.cost : d.tokens.toDouble()).toList();
    final maxValue = values.fold<double>(0, (a, b) => b > a ? b : a);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.25;
    final labelInterval = (daily.length / 7).ceil().clamp(1, daily.length);
    final color =
        _showCost ? theme.colorScheme.tertiary : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('每日用量', style: theme.textTheme.titleMedium),
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Token'),
                  icon: Icon(Icons.data_usage, size: 16),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('金额'),
                  icon: Icon(Icons.payments_outlined, size: 16),
                ),
              ],
              selected: <bool>{_showCost},
              onSelectionChanged: (s) => setState(() => _showCost = s.first),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
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
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) => Text(
                      _showCost
                          ? value.toStringAsFixed(1)
                          : _compactNumber(value),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 ||
                          index >= daily.length ||
                          index % labelInterval != 0) {
                        return const SizedBox.shrink();
                      }
                      final day = daily[index].day;
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
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final d = daily[group.x];
                    return BarTooltipItem(
                      '${d.day.month}/${d.day.day}\n'
                      '${_showCost ? '金额 ${d.cost.toStringAsFixed(4)} 元' : 'Token ${d.tokens}'}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              barGroups: <BarChartGroupData>[
                for (var i = 0; i < daily.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: values[i],
                        width: 18,
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _compactNumber(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}
