import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/usage_record.dart';
import '../state/balance_state.dart';
import '../utils/formats.dart';
import '../utils/usage_stats.dart';
import '../widgets/daily_usage_chart.dart';
import '../widgets/token_breakdown_chart.dart';
import '../widgets/usage_record_dialog.dart';
import '../widgets/usage_record_tile.dart';

/// Token 用量页：汇总 + 记录列表 + 手动添加。
class UsageScreen extends StatelessWidget {
  const UsageScreen({super.key});

  Future<void> _showAddDialog(BuildContext context) async {
    final state = context.read<BalanceState>();
    if (state.accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在「设置」中添加账户')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => UsageRecordDialog(accounts: state.accounts),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BalanceState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Token 用量')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('记录用量'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          _TotalsCard(totals: state.usageTotals),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Token 构成',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TokenBreakdownChart(
                    breakdown: TokenBreakdown.sum(state.usageRecords),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: DailyUsageChart(
                daily: aggregateDaily(state.usageRecords),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (state.usageRecords.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('暂无用量记录，点击右下角添加')),
              ),
            )
          else
            for (final record in state.usageRecords)
              UsageRecordTile(
                record: record,
                onEdit: () => _editRecord(context, record),
                onDelete: () => _deleteRecord(context, record),
              ),
        ],
      ),
    );
  }

  Future<void> _editRecord(BuildContext context, UsageRecord record) async {
    final state = context.read<BalanceState>();
    await showDialog<void>(
      context: context,
      builder: (_) => UsageRecordDialog(
        accounts: state.accounts,
        record: record,
      ),
    );
  }

  Future<void> _deleteRecord(BuildContext context, UsageRecord record) async {
    final id = record.id;
    if (id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定删除「${record.model}」这条用量记录？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<BalanceState>().deleteUsageRecord(id);
    }
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});

  final UsageTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('汇总', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 20,
              runSpacing: 6,
              children: <Widget>[
                _item('记录', '${totals.records} 条'),
                _item('输入·命中缓存', '${totals.promptCacheHitTokens}'),
                _item('输入·未命中缓存', '${totals.promptCacheMissTokens}'),
                _item('输出', '${totals.completionTokens}'),
                _item('总 Token', '${totals.totalTokens}'),
                _item('费用', formatMoney(totals.cost)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(String label, String value) {
    return Text('$label: $value');
  }
}
