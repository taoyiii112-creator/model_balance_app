import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/balance.dart';
import '../models/usage_record.dart';

/// 本地 SQLite 存储：Token 用量记录 + 余额快照，表结构与桌面版一致。
class StorageService {
  static const String _dbName = 'model_balance.db';
  static const int _dbVersion = 1;

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
  }

  Future<int> addUsageRecord(UsageRecord record) async {
    final db = await _database;
    return db.insert('usage_records', record.toDbMap());
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

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
