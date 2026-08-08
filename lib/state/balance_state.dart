import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/account.dart';
import '../models/app_notification.dart';
import '../models/balance.dart';
import '../models/usage_record.dart';
import '../services/balance_service.dart';
import '../services/lan_sync_service.dart';
import '../services/notification_service.dart';
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
  List<AppNotification> notifications = <AppNotification>[];
  double alertThreshold = 5.0;

  Timer? _autoRefreshTimer;
  int _refreshSeconds = 30;
  int _notificationSeq = 0;

  /// 自动刷新间隔（秒），默认 30。
  int get refreshSeconds => _refreshSeconds;

  Duration get refreshInterval => Duration(seconds: _refreshSeconds);

  Future<void> load() async {
    await _loadSettings();
    accounts = await configStore.loadAccounts();
    usageRecords = await storage.listUsageRecords();
    usageTotals = UsageTotals.sum(usageRecords);
    await _loadSnapshots();
    await storage.pruneNotifications();
    notifications = await storage.listNotifications();
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
        final threshold = data is Map ? data['alert_threshold'] : null;
        if (threshold is num && threshold >= 0) {
          alertThreshold = threshold.toDouble();
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
    await _saveSettings();
    notifyListeners();
  }

  /// 设置低余额提醒阈值（币种金额单位），持久化到 settings.json。
  Future<void> setAlertThreshold(double value) async {
    alertThreshold = value < 0 ? 0 : value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}settings.json',
      );
      await file.writeAsString(
        jsonEncode(<String, dynamic>{
          'refresh_seconds': _refreshSeconds,
          'alert_threshold': alertThreshold,
        }),
      );
    } catch (_) {
      // 持久化失败不影响本次设置
    }
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
      await checkLowBalanceAlerts();
      lastRefreshed = DateTime.now();
    } catch (e) {
      lastError = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 检查各账户可用余额是否低于阈值；低于时生成消息并弹系统通知。
  ///
  /// 同一账户同一天只提醒一次（按去重键），余额恢复后次日重新提醒。
  Future<void> checkLowBalanceAlerts() async {
    final today = DateTime.now();
    for (final r in results) {
      final balance = r.balance;
      final available = balance?.available;
      if (!r.ok || balance == null || available == null) {
        continue;
      }
      if (available >= alertThreshold) {
        continue;
      }
      final dedupeKey =
          'low_balance:${balance.account}:${_dateKey(today)}';
      final created = await _createNotification(
        type: 'low_balance',
        title: '低余额提醒',
        body: '${balance.account} 可用余额 '
            '${available.toStringAsFixed(4)} ${balance.currency}，'
            '已低于提醒阈值 ${alertThreshold.toStringAsFixed(2)}。',
        dedupeKey: dedupeKey,
      );
      if (created) {
        await NotificationService.instance.show(
          id: _nextNotificationId(),
          title: '低余额提醒',
          body: '${balance.account} 可用余额低于 '
              '${alertThreshold.toStringAsFixed(2)} ${balance.currency}',
        );
      }
    }
  }

  /// 发现新版本时写入消息并弹系统通知。
  Future<void> notifyUpdateAvailable(String version, String notes) async {
    final created = await _createNotification(
      type: 'update_available',
      title: '发现新版本 v$version',
      body: notes.trim().isEmpty ? '有新版本可用，可在设置中查看并更新。' : notes.trim(),
      dedupeKey: 'update_available:$version',
    );
    if (created) {
      await NotificationService.instance.show(
        id: _nextNotificationId(),
        title: '发现新版本 v$version',
        body: '模型余额有新版本可用，点此查看更新内容。',
      );
    }
  }

  /// 写入一条消息（去重键已存在时返回 false）。
  Future<bool> _createNotification({
    required String type,
    required String title,
    required String body,
    String? dedupeKey,
  }) async {
    if (dedupeKey != null && await storage.notificationExists(dedupeKey)) {
      return false;
    }
    await storage.addNotification(
      AppNotification(
        type: type,
        title: title,
        body: body,
        dedupeKey: dedupeKey,
      ),
    );
    notifications = await storage.listNotifications();
    notifyListeners();
    return true;
  }

  Future<void> markNotificationRead(int id) async {
    await storage.markNotificationRead(id);
    notifications = await storage.listNotifications();
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    await storage.markAllNotificationsRead();
    notifications = await storage.listNotifications();
    notifyListeners();
  }

  Future<void> deleteNotification(int id) async {
    await storage.deleteNotification(id);
    notifications = await storage.listNotifications();
    notifyListeners();
  }

  int get unreadNotificationCount =>
      notifications.where((n) => !n.read).length;

  static String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 生成不重复的系统通知 id（Android 要求为正 int）。
  int _nextNotificationId() {
    _notificationSeq = (_notificationSeq + 1) & 0xff;
    final base = DateTime.now().millisecondsSinceEpoch % 0x7fffffff;
    return (base + _notificationSeq) % 0x7fffffff;
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

  /// 局域网同步：从电脑端拉取 Codex 用量并增量导入。
  Future<CodexImportResult> lanSyncCodex(
    String host,
    int port,
    String token,
  ) async {
    final result = await LanSyncService(storage: storage)
        .fetchAndImport(host, port, token);
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
