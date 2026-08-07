import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/usage_record.dart';
import '../state/balance_state.dart';

/// 添加 / 编辑一条 Token 用量记录的对话框。
class UsageRecordDialog extends StatefulWidget {
  const UsageRecordDialog({super.key, required this.accounts, this.record});

  final List<Account> accounts;

  /// 传入则为编辑模式，否则为新增。
  final UsageRecord? record;

  @override
  State<UsageRecordDialog> createState() => _UsageRecordDialogState();
}

class _UsageRecordDialogState extends State<UsageRecordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final List<String> _accountNames =
      widget.accounts.map((a) => a.name).toList();
  late String _account = widget.record?.account ?? _accountNames.first;
  late final TextEditingController _modelController =
      TextEditingController(text: widget.record?.model ?? '');
  late final TextEditingController _cacheHitController = TextEditingController(
    text: widget.record == null ? '' : '${widget.record!.promptCacheHitTokens}',
  );
  late final TextEditingController _cacheMissController = TextEditingController(
    text:
        widget.record == null ? '' : '${widget.record!.promptCacheMissTokens}',
  );
  late final TextEditingController _completionController =
      TextEditingController(
    text: widget.record == null ? '' : '${widget.record!.completionTokens}',
  );
  late final TextEditingController _costController = TextEditingController(
    text: widget.record?.cost == null ? '' : '${widget.record!.cost}',
  );
  late final TextEditingController _noteController =
      TextEditingController(text: widget.record?.note ?? '');
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
      id: widget.record?.id,
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
      final state = context.read<BalanceState>();
      if (widget.record == null) {
        await state.addUsageRecord(record);
      } else {
        await state.updateUsageRecord(record);
      }
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
