import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/account.dart';

/// 账户配置（含 API Key）存放到系统安全存储，与桌面版 .env 对应。
class SecureConfigStore {
  SecureConfigStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _accountsKey = 'accounts';

  final FlutterSecureStorage _storage;

  Future<List<Account>> loadAccounts() async {
    final raw = await _storage.read(key: _accountsKey);
    if (raw == null || raw.isEmpty) {
      return <Account>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <Account>[];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Account.fromJson)
        .toList();
  }

  Future<void> saveAccounts(List<Account> accounts) async {
    final raw = jsonEncode(
      accounts.map((a) => a.toJson()).toList(),
    );
    await _storage.write(key: _accountsKey, value: raw);
  }
}
