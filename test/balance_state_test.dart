import 'package:flutter_test/flutter_test.dart';
import 'package:model_balance_app/models/account.dart';
import 'package:model_balance_app/models/balance.dart';
import 'package:model_balance_app/services/secure_config_store.dart';
import 'package:model_balance_app/state/balance_state.dart';

import 'fakes.dart';

class _FakeConfigStore extends SecureConfigStore {
  @override
  Future<List<Account>> loadAccounts() async => <Account>[];

  @override
  Future<void> saveAccounts(List<Account> accounts) async {}
}

class _FakeStorage extends MemoryStorage {}

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

  test('setRefreshInterval 设置并限制最小值', () async {
    final state = BalanceState(
      configStore: _FakeConfigStore(),
      storage: _FakeStorage(),
    );
    await state.setRefreshInterval(60);
    expect(state.refreshSeconds, 60);
    await state.setRefreshInterval(2);
    expect(state.refreshSeconds, 5);
  });

  test('setAlertThreshold 设置并限制最小值', () async {
    final state = BalanceState(
      configStore: _FakeConfigStore(),
      storage: _FakeStorage(),
    );
    await state.setAlertThreshold(2.5);
    expect(state.alertThreshold, 2.5);
    await state.setAlertThreshold(-1);
    expect(state.alertThreshold, 0);
  });

  test('低余额触发消息并同日去重', () async {
    final storage = _FakeStorage();
    final state = BalanceState(
      configStore: _FakeConfigStore(),
      storage: storage,
    );
    state.alertThreshold = 5;
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
          available: 0.3,
        ),
      ),
    ];

    await state.checkLowBalanceAlerts();
    expect(storage.notifications.length, 1);
    expect(state.notifications.single.title, '低余额提醒');
    expect(state.notifications.single.body, contains('deepseek-main'));
    expect(state.unreadNotificationCount, 1);

    // 同一天重复检查不再新增。
    await state.checkLowBalanceAlerts();
    expect(storage.notifications.length, 1);

    await state.markAllNotificationsRead();
    expect(state.unreadNotificationCount, 0);
  });

  test('余额高于阈值不生成消息', () async {
    final storage = _FakeStorage();
    final state = BalanceState(
      configStore: _FakeConfigStore(),
      storage: storage,
    );
    state.alertThreshold = 5;
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
          available: 50,
        ),
      ),
    ];

    await state.checkLowBalanceAlerts();
    expect(storage.notifications, isEmpty);
  });
}
