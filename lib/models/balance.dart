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
