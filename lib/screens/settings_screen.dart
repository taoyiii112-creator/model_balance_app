import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../services/update_flow.dart';
import '../services/update_service.dart';
import '../state/balance_state.dart';
import '../utils/formats.dart';
import 'account_edit_screen.dart';

/// 设置页：账户、API Key 与版本更新管理。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentVersion = '0.0.0';
  String _updateSource = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadUpdateSource();
  }

  Future<void> _loadUpdateSource() async {
    await UpdateService.instance.loadUpdateSource();
    if (mounted) {
      setState(() => _updateSource = UpdateService.instance.updateSourceUrl);
    }
  }

  Future<void> _editUpdateSource() async {
    final controller = TextEditingController(
      text: UpdateService.instance.updateSourceUrl,
    );
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('更新源地址'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '留空恢复默认 GitHub Releases',
            ),
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.isNotEmpty &&
                  !text.startsWith('http://') &&
                  !text.startsWith('https://')) {
                return '请输入以 http(s):// 开头的地址';
              }
              return null;
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      try {
        await UpdateService.instance.setUpdateSource(result);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存更新源失败，请重试')),
          );
          return;
        }
      }
      setState(() => _updateSource = UpdateService.instance.updateSourceUrl);
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _currentVersion = info.version);
    }
  }

  Future<void> _editAlertThreshold() async {
    final controller = TextEditingController(
      text: context
          .read<BalanceState>()
          .alertThreshold
          .toStringAsFixed(2),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('低余额提醒阈值'),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '例如 5 表示余额低于 5 时提醒',
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
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    final value = double.tryParse(result);
    if (value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入大于等于 0 的数字')),
      );
      return;
    }
    await context.read<BalanceState>().setAlertThreshold(value);
  }

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
    final refreshOptions = <int>{15, 30, 60, 120, state.refreshSeconds}.toList()
      ..sort();
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update_alt_outlined),
              title: const Text('版本更新'),
              subtitle: Text('当前版本 v$_currentVersion'),
              trailing: FilledButton.tonal(
                onPressed: () => promptForUpdate(
                  context,
                  currentVersion: _currentVersion,
                  manual: true,
                ),
                child: const Text('检查更新'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.link),
              title: const Text('更新源地址'),
              subtitle: Text(
                _updateSource.isEmpty ? '加载中…' : _updateSource,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _editUpdateSource,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('余额自动刷新间隔'),
              trailing: DropdownButton<int>(
                value: state.refreshSeconds,
                items: refreshOptions
                    .map(
                      (s) => DropdownMenuItem<int>(
                        value: s,
                        child: Text('$s 秒'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    context.read<BalanceState>().setRefreshInterval(v);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('低余额提醒阈值'),
              subtitle: Text(
                '余额低于 ${state.alertThreshold.toStringAsFixed(2)} '
                '时发消息并弹系统通知',
              ),
              trailing: FilledButton.tonal(
                onPressed: _editAlertThreshold,
                child: const Text('修改'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于'),
              subtitle: Text(
                '模型余额手机版 v$_currentVersion\n'
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
