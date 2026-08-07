import 'package:flutter_test/flutter_test.dart';
import 'package:model_balance_app/models/account.dart';
import 'package:model_balance_app/models/balance.dart';
import 'package:model_balance_app/models/usage_record.dart';
import 'package:model_balance_app/services/secure_config_store.dart';
import 'package:model_balance_app/services/storage_service.dart';
import 'package:model_balance_app/state/balance_state.dart';

class _FakeConfigStore extends SecureConfigStore {
  @override
  Future<List<Account>> loadAccounts() async => <Account>[];

  @override
  Future<void> saveAccounts(List<Account> accounts) async {}
}

class _FakeStorage extends StorageService {
  @override
  Future<List<UsageRecord>> listUsageRecords({
    String? account,
    DateTime? since,
  }) async {
    return <UsageRecord>[];
  }

  @override
  Future<int> addUsageRecord(UsageRecord record) async => 1;

  @override
  Future<int> updateUsageRecord(UsageRecord record) async => 1;

  @override
  Future<int> deleteUsageRecord(int id) async => 1;

  @override
  Future<int> addSnapshot(Balance balance) async => 1;
}

void main() {
  test('totalByCurrency 按币种分组汇总', () {
    final state = BalanceState(
      configStore: _FakeConfigStore(),
      storage: _FakeStorage(),
    );
    state.results = <AccountResult>[
      AccountResult(
        account: const Account(
          name: 'deepseek-main',
          provider: 'deepseek',
          apiKey: 'k',
        ),
        balance: Balance(
          account: 'deepseek-main',
          provider: 'deepseek',
          currency: 'CNY',
          available: 1.5,
        ),
      ),
      AccountResult(
        account: const Account(
          name: 'openai-main',
          provider: 'openai',
          apiKey: 'k',
        ),
        balance: Balance(
          account: 'openai-main',
          provider: 'openai',
          currency: 'USD',
          available: 2.0,
        ),
      ),
      AccountResult(
        account: const Account(
          name: 'deepseek-2',
          provider: 'deepseek',
          apiKey: 'k',
        ),
        balance: Balance(
          account: 'deepseek-2',
          provider: 'deepseek',
          currency: 'CNY',
          available: 0.5,
        ),
      ),
    ];
    final byCurrency = state.totalByCurrency;
    expect(byCurrency['CNY'], 2.0);
    expect(byCurrency['USD'], 2.0);
  });
}
