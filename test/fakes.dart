import 'package:model_balance_app/models/app_notification.dart';
import 'package:model_balance_app/models/balance.dart';
import 'package:model_balance_app/models/usage_record.dart';
import 'package:model_balance_app/services/storage_service.dart';

/// 内存版 [StorageService]，供 widget / state 单元测试使用，
/// 避免触发 sqflite 平台通道。
class MemoryStorage extends StorageService {
  final List<UsageRecord> usage = <UsageRecord>[];
  final List<BalanceSnapshot> snapshots = <BalanceSnapshot>[];
  final List<AppNotification> notifications = <AppNotification>[];
  final Set<String> dedupeKeys = <String>{};
  int _nextNotificationId = 1;

  @override
  Future<List<UsageRecord>> listUsageRecords({
    String? account,
    DateTime? since,
  }) async {
    var list = usage;
    if (account != null && account.isNotEmpty) {
      list = list.where((r) => r.account == account).toList();
    }
    if (since != null) {
      list = list.where((r) => !r.createdAt.isBefore(since)).toList();
    }
    return list;
  }

  @override
  Future<int> addUsageRecord(UsageRecord record) async {
    usage.insert(0, record);
    return 1;
  }

  @override
  Future<int> addSnapshot(Balance balance) async {
    snapshots.add(
      BalanceSnapshot(
        account: balance.account,
        provider: balance.provider,
        currency: balance.currency,
        available: balance.available,
        total: balance.total,
        used: balance.used,
        createdAt: balance.fetchedAt,
      ),
    );
    return 1;
  }

  @override
  Future<List<BalanceSnapshot>> listSnapshots({
    String? account,
    DateTime? since,
    int? limit,
  }) async {
    var list = snapshots;
    if (account != null && account.isNotEmpty) {
      list = list.where((s) => s.account == account).toList();
    }
    if (since != null) {
      list = list.where((s) => !s.createdAt.isBefore(since)).toList();
    }
    final sorted = List<BalanceSnapshot>.of(list)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (limit != null && limit > 0 && sorted.length > limit) {
      return sorted.sublist(sorted.length - limit);
    }
    return sorted;
  }

  @override
  Future<int> addNotification(AppNotification notification) async {
    final key = notification.dedupeKey;
    if (key != null && dedupeKeys.contains(key)) {
      return 0;
    }
    if (key != null) {
      dedupeKeys.add(key);
    }
    final copy = AppNotification(
      id: _nextNotificationId++,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      createdAt: notification.createdAt,
      read: notification.read,
      dedupeKey: notification.dedupeKey,
    );
    notifications.insert(0, copy);
    return copy.id!;
  }

  @override
  Future<bool> notificationExists(String dedupeKey) async =>
      dedupeKeys.contains(dedupeKey);

  @override
  Future<List<AppNotification>> listNotifications({int limit = 200}) async {
    final sorted = List<AppNotification>.of(notifications)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<int> unreadNotificationCount() async =>
      notifications.where((n) => !n.read).length;

  @override
  Future<int> markNotificationRead(int id) async {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index < 0) {
      return 0;
    }
    notifications[index] = notifications[index].copyWith(read: true);
    return 1;
  }

  @override
  Future<int> markAllNotificationsRead() async {
    var count = 0;
    for (var i = 0; i < notifications.length; i++) {
      if (!notifications[i].read) {
        notifications[i] = notifications[i].copyWith(read: true);
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> deleteNotification(int id) async {
    final before = notifications.length;
    notifications.removeWhere((n) => n.id == id);
    return before - notifications.length;
  }

  @override
  Future<int> pruneNotifications({int keepDays = 90}) async {
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));
    final before = notifications.length;
    notifications.removeWhere((n) => n.createdAt.isBefore(cutoff));
    return before - notifications.length;
  }
}
