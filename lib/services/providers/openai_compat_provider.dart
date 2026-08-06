import '../../models/balance.dart';
import 'balance_provider_base.dart';

/// OpenAI 兼容中转渠道（one-api / new-api 类）余额查询。
/// 接口：GET {base_url}/api/user/status
/// one-api 的 quota 单位：1 quota = 1/500000（默认）元，可通过账户配置调整。
class OpenAICompatProvider extends BalanceProvider {
  OpenAICompatProvider(super.account);

  @override
  Future<Balance> fetchBalance() async {
    final baseUrl = account.baseUrl;
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      throw const ProviderException('openai_compat 需要配置 base_url');
    }
    final url = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/user/status';
    final payload = await getJson(url);
    return parseBalance(
      account.name,
      payload,
      account.quotaDenominator,
      account.quotaCurrency,
    );
  }

  static Balance parseBalance(
    String accountName,
    Map<String, dynamic> payload,
    double denominator,
    String currency,
  ) {
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw ProviderException('中转渠道响应缺少 data 字段: $payload');
    }
    final quota = parseDouble(data['quota']);
    final usedQuota = parseDouble(data['used_quota']);
    return Balance(
      account: accountName,
      provider: 'openai_compat',
      currency: currency,
      available: quota == null ? null : quota / denominator,
      used: usedQuota == null ? null : usedQuota / denominator,
    );
  }
}
