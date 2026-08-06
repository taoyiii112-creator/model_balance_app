import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/usage_record.dart';
import '../state/balance_state.dart';
import '../utils/formats.dart';
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
      body: state.usageRecords.isEmpty
          ? const Center(child: Text('暂无用量记录，点击右下角添加'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                _TotalsCard(totals: state.usageTotals),
                const SizedBox(height: 12),
                for (final record in state.usageRecords)
                  UsageRecordTile(record: record),
              ],
            ),
    );
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
                _item('Prompt', '${totals.promptTokens}'),
                _item('Completion', '${totals.completionTokens}'),
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
