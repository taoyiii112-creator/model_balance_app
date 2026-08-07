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

  /// 暂停自动刷新（App 进入后台时调用）。
  void pauseAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// 恢复自动刷新。
  void resumeAutoRefresh() {
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

  Future<void> updateUsageRecord(UsageRecord record) async {
    await storage.updateUsageRecord(record);
    usageRecords = await storage.listUsageRecords();
    usageTotals = UsageTotals.sum(usageRecords);
    notifyListeners();
  }

  Future<void> deleteUsageRecord(int id) async {
    await storage.deleteUsageRecord(id);
    usageRecords = await storage.listUsageRecords();
    usageTotals = UsageTotals.sum(usageRecords);
    notifyListeners();
  }

  /// 按币种汇总可用余额（不跨币种混算）。
  Map<String, double> get totalByCurrency {
    final map = <String, double>{};
    for (final r in results) {
      final balance = r.balance;
      final available = balance?.available;
      if (balance != null && available != null) {
        map[balance.currency] = (map[balance.currency] ?? 0) + available;
      }
    }
    return map;
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
