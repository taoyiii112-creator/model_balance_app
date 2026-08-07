import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/usage_stats.dart';

/// 扇形图：输入（命中缓存）/ 输入（未命中缓存）/ 输出 的 Token 构成。
class TokenBreakdownChart extends StatelessWidget {
  const TokenBreakdownChart({super.key, required this.breakdown});

  final TokenBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final total = breakdown.total;
    if (total == 0) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('暂无 Token 数据')),
      );
    }

    const hitColor = Color(0xFF4CAF50);
    const missColor = Color(0xFFFF9800);
    const outputColor = Color(0xFF7E57C2);

    return Row(
      children: <Widget>[
        SizedBox(
          width: 150,
          height: 150,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              startDegreeOffset: -90,
              sections: <PieChartSectionData>[
                PieChartSectionData(
                  value: breakdown.cacheHit.toDouble(),
                  color: hitColor,
                  radius: 50,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: breakdown.cacheMiss.toDouble(),
                  color: missColor,
                  radius: 50,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: breakdown.completion.toDouble(),
                  color: outputColor,
                  radius: 50,
                  showTitle: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _LegendItem(
                color: hitColor,
                label: '输入（命中缓存）',
                value: breakdown.cacheHit,
                total: total,
              ),
              const SizedBox(height: 8),
              _LegendItem(
                color: missColor,
                label: '输入（未命中缓存）',
                value: breakdown.cacheMiss,
                total: total,
              ),
              const SizedBox(height: 8),
              _LegendItem(
                color: outputColor,
                label: '输出',
                value: breakdown.completion,
                total: total,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.total,
  });

  final Color color;
  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = total == 0 ? 0 : (value / total * 100).toStringAsFixed(1);
    return Row(
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$value ($percent%)',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
