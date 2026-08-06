import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../state/balance_state.dart';
import '../utils/formats.dart';
import 'account_edit_screen.dart';

/// 设置页：账户与 API Key 管理。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openEditor(BuildContext context, {Account? account}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountEditScreen(account: account),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确定删除账户「${account.name}」？本地用量记录会保留。'),
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
      await context.read<BalanceState>().deleteAccount(account.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<BalanceState>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          Text('账户与 API Key', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Key 保存在手机系统安全存储中（Keychain/Keystore），不上传到服务器',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 8),
          if (state.accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('暂无账户'),
            )
          else
            for (final account in state.accounts)
              _AccountTile(
                account: account,
                onEdit: () => _openEditor(context, account: account),
                onDelete: () => _confirmDelete(context, account),
              ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('添加账户'),
          ),
          const SizedBox(height: 20),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('关于'),
              subtitle: Text(
                '模型余额手机版 v0.1.0\n'
                '与桌面版共享同一套余额查询逻辑：'
                'DeepSeek / OpenAI / 中转渠道',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.onEdit,
    required this.onDelete,
  });

  final Account account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maskedKey = account.apiKey.isEmpty
        ? '未填写 Key'
        : 'sk-***${account.apiKey.length > 8 ? account.apiKey.substring(account.apiKey.length - 4) : ''}';
    final subtitle = <String>[
      providerLabel(account.provider),
      maskedKey,
      if (account.baseUrl != null && account.baseUrl!.isNotEmpty)
        account.baseUrl!,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(account.name),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              onPressed: onEdit,
              tooltip: '编辑',
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
