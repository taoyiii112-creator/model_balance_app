import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_notification.dart';
import '../models/balance.dart';
import '../models/usage_record.dart';

/// 本地 SQLite 存储：Token 用量记录 + 余额快照，表结构与桌面版一致。
class StorageService {
  static const String _dbName = 'model_balance.db';
  static const int _dbVersion = 3;

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) {
      return _db!;
    }
    final path = join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usage_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account TEXT NOT NULL,
        model TEXT NOT NULL,
        created_at TEXT NOT NULL,
        prompt_tokens INTEGER NOT NULL DEFAULT 0,
        prompt_cache_hit_tokens INTEGER NOT NULL DEFAULT 0,
        prompt_cache_miss_tokens INTEGER NOT NULL DEFAULT 0,
        completion_tokens INTEGER NOT NULL DEFAULT 0,
        total_tokens INTEGER NOT NULL DEFAULT 0,
        cost REAL,
        note TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE balance_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account TEXT NOT NULL,
        provider TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'CNY',
        available REAL,
        total REAL,
        used REAL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        dedupe_key TEXT UNIQUE,
        read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE usage_records '
        'ADD COLUMN prompt_cache_hit_tokens INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE usage_records '
        'ADD COLUMN prompt_cache_miss_tokens INTEGER NOT NULL DEFAULT 0',
      );
      // 旧记录无缓存拆分：把原 prompt_tokens 视为未命中缓存。
      await db.execute(
        'UPDATE usage_records SET prompt_cache_miss_tokens = prompt_tokens '
        'WHERE prompt_tokens > 0 AND prompt_cache_miss_tokens = 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE notifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          dedupe_key TEXT UNIQUE,
          read INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  // ---------- 消息中心 ----------

  /// 写入一条消息；[dedupeKey] 重复时忽略并返回 0。
  Future<int> addNotification(AppNotification notification) async {
    final db = await _database;
    return db.insert(
      'notifications',
      notification.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 指定去重键是否已存在。
  Future<bool> notificationExists(String dedupeKey) async {
    final db = await _database;
    final rows = await db.query(
      'notifications',
      columns: <String>['id'],
      where: 'dedupe_key = ?',
      whereArgs: <Object?>[dedupeKey],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 按时间倒序返回最近 [limit] 条消息。
  Future<List<AppNotification>> listNotifications({int limit = 200}) async {
    final db = await _database;
    final rows = await db.query(
      'notifications',
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(AppNotification.fromDbMap).toList();
  }

  Future<int> unreadNotificationCount() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notifications WHERE read = 0',
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<int> markNotificationRead(int id) async {
    final db = await _database;
    return db.update(
      'notifications',
      <String, Object?>{'read': 1},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> markAllNotificationsRead() async {
    final db = await _database;
    return db.update('notifications', <String, Object?>{'read': 1});
  }

  Future<int> deleteNotification(int id) async {
    final db = await _database;
    return db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 清理超过 [keepDays] 的旧消息，避免消息中心无限增长。
  Future<int> pruneNotifications({int keepDays = 90}) async {
    final db = await _database;
    final cutoff =
        DateTime.now().subtract(Duration(days: keepDays)).toIso8601String();
    return db.delete(
      'notifications',
      where: 'created_at < ?',
      whereArgs: <Object?>[cutoff],
    );
  }

  Future<int> addUsageRecord(UsageRecord record) async {
    final db = await _database;
    return db.insert('usage_records', record.toDbMap());
  }

  Future<int> updateUsageRecord(UsageRecord record) async {
    final id = record.id;
    if (id == null) {
      throw ArgumentError('更新用量记录需要 id');
    }
    final db = await _database;
    return db.update(
      'usage_records',
      record.toDbMap(),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> deleteUsageRecord(int id) async {
    final db = await _database;
    return db.delete(
      'usage_records',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 返回已入库的 codex 记录 note（用于导入去重）。
  Future<Set<String>> listCodexKeys() async {
    final db = await _database;
    final rows = await db.query(
      'usage_records',
      columns: <String>['note'],
      where: "note LIKE 'codex:%'",
    );
    return rows
        .map((r) => (r['note'] as String?) ?? '')
        .where((n) => n.isNotEmpty)
        .toSet();
  }

  Future<List<UsageRecord>> listUsageRecords({
    String? account,
    DateTime? since,
  }) async {
    final db = await _database;
    final where = <String>[];
    final args = <Object?>[];
    if (account != null && account.isNotEmpty) {
      where.add('account = ?');
      args.add(account);
    }
    if (since != null) {
      where.add('created_at >= ?');
      args.add(since.toIso8601String());
    }
    final rows = await db.query(
      'usage_records',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(UsageRecord.fromDbMap).toList();
  }

  Future<int> addSnapshot(Balance balance) async {
    final db = await _database;
    return db.insert('balance_snapshots', <String, Object?>{
      'account': balance.account,
      'provider': balance.provider,
      'currency': balance.currency,
      'available': balance.available,
      'total': balance.total,
      'used': balance.used,
      'created_at': balance.fetchedAt.toIso8601String(),
    });
  }

  /// 查询余额快照（按时间升序，便于画趋势线）。
  Future<List<BalanceSnapshot>> listSnapshots({
    String? account,
    DateTime? since,
    int? limit,
  }) async {
    final db = await _database;
    final where = <String>[];
    final args = <Object?>[];
    if (account != null && account.isNotEmpty) {
      where.add('account = ?');
      args.add(account);
    }
    if (since != null) {
      where.add('created_at >= ?');
      args.add(since.toIso8601String());
    }
    final rows = await db.query(
      'balance_snapshots',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(BalanceSnapshot.fromDbMap).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
