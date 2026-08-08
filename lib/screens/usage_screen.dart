import 'dart:io';

import 'package:file_picker/file_picker.dart';
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

  Future<void> _showImportSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.content_paste_go),
              title: const Text('粘贴 JSON'),
              subtitle: const Text('从电脑复制的 codex_usage.json 内容'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pasteJson(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('选择文件'),
              subtitle: const Text('从手机文件中选择 codex_usage.json'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickFile(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pasteJson(BuildContext context) async {
    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('粘贴 Codex 用量 JSON'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: '粘贴 codex_usage.json 的完整内容',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (content != null && content.isNotEmpty) {
      if (!context.mounted) {
        return;
      }
      await _runImport(context, content);
    }
  }

  Future<void> _pickFile(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = picked?.files.single.path;
    if (path == null) {
      return;
    }
    try {
      final content = await File(path).readAsString();
      if (!context.mounted) {
        return;
      }
      await _runImport(context, content);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('读取文件失败：$e')),
        );
      }
    }
  }

  Future<void> _runImport(BuildContext context, String content) async {
    try {
      final result =
          await context.read<BalanceState>().importCodexUsage(content);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '导入完成：新增 ${result.imported} 条，跳过重复 ${result.skipped} 条',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BalanceState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Token 用量'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _showImportSheet(context),
            tooltip: '导入用量',
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
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
