import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/usage_record.dart';
import '../state/balance_state.dart';

/// 添加一条 Token 用量记录的对话框，与桌面版 add-usage 命令对应。
class UsageRecordDialog extends StatefulWidget {
  const UsageRecordDialog({super.key, required this.accounts});

  final List<Account> accounts;

  @override
  State<UsageRecordDialog> createState() => _UsageRecordDialogState();
}

class _UsageRecordDialogState extends State<UsageRecordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final List<String> _accountNames =
      widget.accounts.map((a) => a.name).toList();
  late String _account = _accountNames.first;
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _cacheHitController = TextEditingController();
  final TextEditingController _cacheMissController = TextEditingController();
  final TextEditingController _completionController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _modelController.dispose();
    _cacheHitController.dispose();
    _cacheMissController.dispose();
    _completionController.dispose();
    _costController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    final record = UsageRecord(
      account: _account,
      model: _modelController.text.trim(),
      promptCacheHitTokens: int.tryParse(_cacheHitController.text.trim()) ?? 0,
      promptCacheMissTokens:
          int.tryParse(_cacheMissController.text.trim()) ?? 0,
      completionTokens: int.tryParse(_completionController.text.trim()) ?? 0,
      cost: double.tryParse(_costController.text.trim()),
      note: _noteController.text.trim(),
    );
    try {
      await context.read<BalanceState>().addUsageRecord(record);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('记录用量'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: _account,
                decoration: const InputDecoration(labelText: '账户'),
                items: _accountNames
                    .map((n) =>
                        DropdownMenuItem<String>(value: n, child: Text(n)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _account = v);
                  }
                },
              ),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(labelText: '模型'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入模型名称' : null,
              ),
              TextFormField(
                controller: _cacheHitController,
                decoration: const InputDecoration(
                  labelText: '输入 Token（命中缓存）',
                ),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _cacheMissController,
                decoration: const InputDecoration(
                  labelText: '输入 Token（未命中缓存）',
                ),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _completionController,
                decoration: const InputDecoration(labelText: '输出 Token'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(labelText: '费用（可选）'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: '备注（可选）'),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
