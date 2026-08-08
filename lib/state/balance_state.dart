import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/account.dart';
import '../models/balance.dart';
import '../models/usage_record.dart';
import '../services/balance_service.dart';
import '../services/secure_config_store.dart';
import '../services/storage_service.dart';
import '../services/usage_import_service.dart';

/// 全局业务状态：账户、余额结果、用量记录。
class BalanceState extends ChangeNotifier {
  BalanceState({SecureConfigStore? configStore, StorageService? storage})
      : configStore = configStore ?? SecureConfigStore(),
        storage = storage ?? StorageService();

  final SecureConfigStore configStore;
  final StorageService storage;

  List<Account> accounts = <Account>[];
  List<AccountResult> results = <AccountResult>[];
  List<UsageRecord> usageRecords = <UsageRecord>[];
  Map<String, List<BalanceSnapshot>> snapshotsByAccount =
      <String, List<BalanceSnapshot>>{};
  UsageTotals usageTotals = const UsageTotals();
  bool loading = false;
  String? lastError;
  DateTime? lastRefreshed;

  Timer? _autoRefreshTimer;
  int _refreshSeconds = 30;

  /// 自动刷新间隔（秒），默认 30。
  int get refreshSeconds => _refreshSeconds;

  Duration get refreshInterval => Duration(seconds: _refreshSeconds);

  Future<void> load() async {
    await _loadSettings();
    accounts = await configStore.loadAccounts();
    usageRecords = await storage.listUsageRecords();
    usageTotals = UsageTotals.sum(usageRecords);
    await _loadSnapshots();
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}settings.json',
      );
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        final seconds = data is Map ? data['refresh_seconds'] : null;
        if (seconds is num && seconds >= 5) {
          _refreshSeconds = seconds.toInt();
        }
      }
    } catch (_) {
      // 读取失败用默认值
    }
  }

  /// 设置自动刷新间隔并持久化。
  Future<void> setRefreshInterval(int seconds) async {
    _refreshSeconds = seconds < 5 ? 5 : seconds;
    _restartAutoRefresh();
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}settings.json',
      );
      await file.writeAsString(
        jsonEncode(<String, dynamic>{'refresh_seconds': _refreshSeconds}),
      );
    } catch (_) {
      // 持久化失败不影响本次设置
    }
    notifyListeners();
  }

  Future<void> _loadSnapshots() async {
    final since = DateTime.now().subtract(const Duration(days: 30));
    final map = <String, List<BalanceSnapshot>>{};
    for (final account in accounts) {
      map[account.name] = await storage.listSnapshots(
        account: account.name,
        since: since,
        limit: 500,
      );
    }
    snapshotsByAccount = map;
  }

  /// 开始每 30 秒自动刷新（幂等）。
  void startAutoRefresh() {
    _autoRefreshTimer ??= Timer.periodic(
      refreshInterval,
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
      refreshInterval,
      (_) => refresh(),
    );
  }

  void _restartAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      refreshInterval,
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
      await _loadSnapshots();
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

  /// 导入桌面端导出的 Codex 用量 JSON（增量去重）。
  Future<CodexImportResult> importCodexUsage(String content) async {
    final result =
        await UsageImportService(storage: storage).importCodex(content);
    usageRecords = await storage.listUsageRecords();
    usageTotals = UsageTotals.sum(usageRecords);
    notifyListeners();
    return result;
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
