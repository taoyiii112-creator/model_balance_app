import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/account.dart';

/// 账户配置（含 API Key）存放到系统安全存储，与桌面版 .env 对应。
class SecureConfigStore {
  SecureConfigStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _accountsKey = 'accounts';
  static const String _lanSyncTokenKey = 'lan_sync_token';
  static const String _lanSyncIpKey = 'lan_sync_ip';

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

  Future<String?> loadLanSyncToken() async {
    return _storage.read(key: _lanSyncTokenKey);
  }

  Future<void> saveLanSyncToken(String token) async {
    await _storage.write(key: _lanSyncTokenKey, value: token);
  }

  Future<String?> loadLanSyncIp() async {
    return _storage.read(key: _lanSyncIpKey);
  }

  Future<void> saveLanSyncIp(String ip) async {
    await _storage.write(key: _lanSyncIpKey, value: ip);
  }
}
