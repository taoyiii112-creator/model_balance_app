import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../models/balance.dart';
import '../models/usage_record.dart';
import '../services/balance_service.dart';
import '../services/secure_config_store.dart';
import '../services/storage_service.dart';

/// 全局业务状态：账户、余额结果、用量记录。
class BalanceState extends ChangeNotifier {
  BalanceState({SecureConfigStore? configStore, StorageService? storage})
      : configStore = configStore ?? SecureConfigStore(),
        storage = storage ?? StorageService();

  static const Duration autoRefreshInterval = Duration(seconds: 30);

  final SecureConfigStore configStore;
  final StorageService storage;

  List<Account> accounts = <Account>[];
  List<AccountResult> results = <AccountResult>[];
  List<UsageRecord> usageRecords = <UsageRecord>[];
  UsageTotals usageTotals = const UsageTotals();
  bool loading = false;
  String? lastError;
  DateTime? lastRefreshed;

  Timer? _autoRefreshTimer;

  Future<void> load() async {
    accounts = await configStore.loadAccounts();
    usageRecords = await storage.listUsageRecords();
    usageTotals = UsageTotals.sum(usageRecords);
    notifyListeners();
  }

  /// 开始每 30 秒自动刷新（幂等）。
  void startAutoRefresh() {
    _autoRefreshTimer ??= Timer.periodic(
      autoRefreshInterval,
      (_) => refresh(),
    );
  }

  Future<void> refresh() async {
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      results = await BalanceService.fetchAll(accounts);
      for (final r in results) {
        if (r.ok) {
          await storage.addSnapshot(r.balance!);
        }
      }
      lastRefreshed = DateTime.now();
    } catch (e) {
      lastError = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> saveAccount(Account account) async {
    final index = accounts.indexWhere((a) => a.name == account.name);
    if (index >= 0) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }
    await configStore.saveAccounts(accounts);
    notifyListeners();
    await refresh();
  }

  Future<void> deleteAccount(String name) async {
    accounts.removeWhere((a) => a.name == name);
    results.removeWhere((r) => r.account.name == name);
    await configStore.saveAccounts(accounts);
    notifyListeners();
  }

  Future<void> addUsageRecord(UsageRecord record) async {
    await storage.addUsageRecord(record);
    usageRecords = await storage.listUsageRecords();
    usageTotals = UsageTotals.sum(usageRecords);
    notifyListeners();
  }

  /// 全部可用金额合计（跨币种简单求和，仅作参考）。
  double? get totalAvailable {
    var sum = 0.0;
    var count = 0;
    for (final r in results) {
      final available = r.balance?.available;
      if (available != null) {
        sum += available;
        count++;
      }
    }
    return count == 0 ? null : sum;
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
