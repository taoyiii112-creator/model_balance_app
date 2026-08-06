import '../models/account.dart';
import '../models/balance.dart';
import 'providers/balance_provider_base.dart';
import 'providers/deepseek_provider.dart';
import 'providers/openai_compat_provider.dart';
import 'providers/openai_provider.dart';

/// 余额聚合查询，与桌面版 fetcher.py 对应。
class BalanceService {
  static BalanceProvider createProvider(Account account) {
    switch (account.provider) {
      case 'deepseek':
        return DeepSeekProvider(account);
      case 'openai':
        return OpenAIProvider(account);
      case 'openai_compat':
        return OpenAICompatProvider(account);
      default:
        throw ProviderException('未知提供商: ${account.provider}');
    }
  }

  /// 单个账户失败不阻断其他账户。
  static Future<AccountResult> fetchOne(Account account) async {
    try {
      final balance = await createProvider(account).fetchBalance();
      return AccountResult(account: account, balance: balance);
    } on ProviderException catch (e) {
      return AccountResult(account: account, error: e.message);
    } catch (e) {
      return AccountResult(account: account, error: '$e');
    }
  }

  static Future<List<AccountResult>> fetchAll(List<Account> accounts) {
    return Future.wait(accounts.map(fetchOne));
  }
}
