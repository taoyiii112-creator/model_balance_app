import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_balance_app/app.dart';
import 'package:model_balance_app/models/account.dart';
import 'package:model_balance_app/models/balance.dart';
import 'package:model_balance_app/services/secure_config_store.dart';
import 'package:model_balance_app/state/balance_state.dart';

import 'fakes.dart';

class _FakeConfigStore extends SecureConfigStore {
  _FakeConfigStore(this.accounts);

  final List<Account> accounts;

  @override
  Future<List<Account>> loadAccounts() async => accounts;

  @override
  Future<void> saveAccounts(List<Account> accounts) async {}
}

class _FakeStorage extends MemoryStorage {}

void main() {
  testWidgets('首页显示账户与余额', (WidgetTester tester) async {
    const account = Account(
      name: 'deepseek-main',
      provider: 'deepseek',
      apiKey: 'sk-test',
    );
    final state = BalanceState(
      configStore: _FakeConfigStore(<Account>[account]),
      storage: _FakeStorage(),
    );
    state.accounts = <Account>[account];
    state.results = <AccountResult>[
      AccountResult(
        account: account,
        balance: Balance(
          account: 'deepseek-main',
          provider: 'deepseek',
          currency: 'CNY',
          available: 0.3,
        ),
      ),
    ];

    await tester.pumpWidget(ModelBalanceApp(state: state));
    await tester.pump();
    await tester.pump();

    expect(find.text('模型余额'), findsOneWidget);
    expect(find.text('deepseek-main'), findsOneWidget);
    expect(find.text('0.3000 CNY'), findsOneWidget);

    // 卸载 App，释放自动刷新定时器。
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('无账户时显示引导提示', (WidgetTester tester) async {
    final state = BalanceState(
      configStore: _FakeConfigStore(<Account>[]),
      storage: _FakeStorage(),
    );

    await tester.pumpWidget(ModelBalanceApp(state: state));
    await tester.pump();
    await tester.pump();

    expect(find.text('还没有账户'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
