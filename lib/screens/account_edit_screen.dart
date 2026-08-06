import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../state/balance_state.dart';

/// 添加 / 编辑账户表单。
class AccountEditScreen extends StatefulWidget {
  const AccountEditScreen({super.key, this.account});

  final Account? account;

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _denominatorController;
  late String _provider;
  late String _quotaCurrency;
  bool _obscureKey = true;
  bool _saving = false;

  bool get _editing => widget.account != null;
  bool get _isCompat => _provider == 'openai_compat';

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _apiKeyController = TextEditingController(text: account?.apiKey ?? '');
    _baseUrlController = TextEditingController(text: account?.baseUrl ?? '');
    _denominatorController =
        TextEditingController(text: '${account?.quotaDenominator ?? 500000}');
    _provider = account?.provider ?? 'deepseek';
    _quotaCurrency = account?.quotaCurrency ?? 'CNY';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _denominatorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    final account = Account(
      name: _nameController.text.trim(),
      provider: _provider,
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _isCompat ? _baseUrlController.text.trim() : null,
      quotaDenominator:
          double.tryParse(_denominatorController.text.trim()) ?? 500000,
      quotaCurrency: _quotaCurrency,
    );
    try {
      await context.read<BalanceState>().saveAccount(account);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('账户已保存')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? '编辑账户' : '添加账户')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              enabled: !_editing,
              decoration: const InputDecoration(
                labelText: '账户名称',
                hintText: '如 deepseek-main',
                helperText: '名称作为唯一标识，创建后不可修改',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入账户名称' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _provider,
              decoration: const InputDecoration(labelText: '提供商'),
              items: Account.providerOptions
                  .map(
                    (p) => DropdownMenuItem<String>(
                      value: p,
                      child: Text(p),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _provider = v);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  icon: Icon(
                    _obscureKey ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入 API Key' : null,
            ),
            if (_isCompat) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: '中转地址 base_url',
                  hintText: 'https://your-relay.example.com',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return '中转渠道必须填写 base_url';
                  }
                  if (!v.trim().startsWith('http')) {
                    return '请填写以 http(s):// 开头的地址';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _denominatorController,
                decoration: const InputDecoration(
                  labelText: 'quota 换算分母',
                  helperText: 'one-api 默认 500000',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final value = double.tryParse(v?.trim() ?? '');
                  if (value == null || value <= 0) {
                    return '请输入大于 0 的数字';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _quotaCurrency,
                decoration: const InputDecoration(labelText: '币种'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'CNY', child: Text('CNY')),
                  DropdownMenuItem<String>(value: 'USD', child: Text('USD')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _quotaCurrency = v);
                  }
                },
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
