import '../../models/balance.dart';
import 'balance_provider_base.dart';

/// DeepSeek 官方余额查询。
/// 接口：GET https://api.deepseek.com/user/balance
class DeepSeekProvider extends BalanceProvider {
  DeepSeekProvider(super.account);

  static const String balanceUrl = 'https://api.deepseek.com/user/balance';

  @override
  Future<Balance> fetchBalance() async {
    final data = await getJson(balanceUrl);
    return parseBalance(account.name, data);
  }

  static Balance parseBalance(String accountName, Map<String, dynamic> data) {
    if (data['is_available'] != true) {
      throw ProviderException('DeepSeek 账户不可用: $data');
    }
    final infos = data['balance_infos'];
    double? total;
    double? granted;
    double? toppedUp;
    var currency = 'CNY';
    if (infos is List &&
        infos.isNotEmpty &&
        infos.first is Map<String, dynamic>) {
      final info = infos.first as Map<String, dynamic>;
      total = parseDouble(info['total_balance']);
      granted = parseDouble(info['granted_balance']);
      toppedUp = parseDouble(info['topped_up_balance']);
      currency = (info['currency'] as String?) ?? currency;
    }
    return Balance(
      account: accountName,
      provider: 'deepseek',
      currency: currency,
      available: total,
      total: total,
      granted: granted,
      toppedUp: toppedUp,
    );
  }
}
