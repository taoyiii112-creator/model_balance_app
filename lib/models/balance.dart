import 'account.dart';

/// 单账户余额结果，与桌面版 models.Balance 对应。
class Balance {
  Balance({
    required this.account,
    required this.provider,
    this.currency = 'CNY',
    this.available,
    this.total,
    this.used,
    this.granted,
    this.toppedUp,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  final String account;
  final String provider;
  final String currency;

  /// 可用金额。
  final double? available;

  /// 总额。
  final double? total;

  /// 已使用金额。
  final double? used;

  /// 赠送金额（DeepSeek）。
  final double? granted;

  /// 充值金额（DeepSeek）。
  final double? toppedUp;

  final DateTime fetchedAt;

  bool get ok => available != null || total != null;
}

/// 单个账户的查询结果：成功返回 [balance]，失败返回 [error]。
class AccountResult {
  const AccountResult({required this.account, this.balance, this.error});

  final Account account;
  final Balance? balance;
  final String? error;

  bool get ok => error == null && balance != null;
}

/// 余额快照（每次成功查询自动写入本地库），用于趋势图。
class BalanceSnapshot {
  const BalanceSnapshot({
    required this.account,
    required this.provider,
    required this.currency,
    this.available,
    this.total,
    this.used,
    required this.createdAt,
  });

  final String account;
  final String provider;
  final String currency;
  final double? available;
  final double? total;
  final double? used;
  final DateTime createdAt;

  factory BalanceSnapshot.fromDbMap(Map<String, Object?> map) {
    return BalanceSnapshot(
      account: map['account'] as String,
      provider: map['provider'] as String,
      currency: (map['currency'] as String?) ?? 'CNY',
      available: (map['available'] as num?)?.toDouble(),
      total: (map['total'] as num?)?.toDouble(),
      used: (map['used'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
