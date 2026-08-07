import 'package:flutter/material.dart';

import '../models/usage_record.dart';
import '../utils/formats.dart';

class UsageRecordTile extends StatelessWidget {
  const UsageRecordTile({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final UsageRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = record.note.isEmpty
        ? '${record.account} · ${formatDateTime(record.createdAt)}'
        : '${record.account} · ${formatDateTime(record.createdAt)}\n'
            '${record.note}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(record.model),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${record.totalTokens} Token',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  '费用 ${formatMoney(record.cost)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            PopupMenuButton<String>(
              tooltip: '更多操作',
              onSelected: (v) {
                if (v == 'edit') {
                  onEdit();
                } else if (v == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'edit', child: Text('编辑')),
                PopupMenuItem<String>(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
