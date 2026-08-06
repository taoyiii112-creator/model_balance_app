import '../../models/balance.dart';
import 'balance_provider_base.dart';

/// OpenAI 官方余额查询。
/// 接口：GET https://api.openai.com/v1/dashboard/billing/credit_grants
/// 注意：该接口对部分 API Key 不稳定，若 401/404 可改用中转渠道接入。
class OpenAIProvider extends BalanceProvider {
  OpenAIProvider(super.account);

  static const String balanceUrl =
      'https://api.openai.com/v1/dashboard/billing/credit_grants';

  @override
  Future<Balance> fetchBalance() async {
    final payload = await getJson(balanceUrl);
    return parseBalance(account.name, payload);
  }

  static Balance parseBalance(
      String accountName, Map<String, dynamic> payload) {
    final totalGranted = parseDouble(payload['total_granted']);
    final totalUsed = parseDouble(payload['total_used']);
    final totalAvailable = parseDouble(payload['total_available']);
    if (totalAvailable == null && totalGranted == null) {
      throw ProviderException('OpenAI 余额响应缺少金额字段: $payload');
    }
    return Balance(
      account: accountName,
      provider: 'openai',
      currency: 'USD',
      available: totalAvailable,
      total: totalGranted,
      used: totalUsed,
    );
  }
}
