import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../models/balance.dart';
import '../services/update_flow.dart';
import '../services/update_service.dart';
import '../state/balance_state.dart';
import '../utils/formats.dart';
import '../widgets/account_card.dart';

/// 余额首页：汇总 + 账户余额列表 + 30 秒自动刷新。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = context.read<BalanceState>();
    state.load();
    state.startAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!UpdateService.instance.checkedThisSession) {
        UpdateService.instance.markChecked();
        _autoCheckUpdate();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App 进入后台暂停自动刷新，回到前台立即刷新一次。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final balanceState = context.read<BalanceState>();
    if (state == AppLifecycleState.resumed) {
      balanceState.resumeAutoRefresh();
      balanceState.refresh();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      balanceState.pauseAutoRefresh();
    }
  }

  /// 启动时静默检查一次更新，发现新版本才提示。
  Future<void> _autoCheckUpdate() async {
    if (!mounted) {
      return;
    }
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    await promptForUpdate(
      context,
      currentVersion: info.version,
      manual: false,
    );
  }

  Future<void> _refresh() {
    return context.read<BalanceState>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BalanceState>();
    final resultsByAccount = <String, AccountResult>{
      for (final r in state.results) r.account.name: r,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('模型余额'),
        actions: <Widget>[
          IconButton(
            onPressed: state.loading ? null : _refresh,
            tooltip: '立即刷新',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            _buildSummary(state),
            const SizedBox(height: 12),
            if (state.loading) const LinearProgressIndicator(),
            if (state.lastError != null) _buildErrorBanner(state.lastError!),
            if (state.accounts.isEmpty)
              _buildEmpty()
            else
              for (final account in state.accounts)
                AccountCard(
                  result: resultsByAccount[account.name] ??
                      AccountResult(account: account),
                ),
            const SizedBox(height: 8),
            _buildUsageSummary(state),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BalanceState state) {
    final theme = Theme.of(context);
    final byCurrency = state.totalByCurrency;
    final refreshed = state.lastRefreshed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('可用余额合计', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  if (byCurrency.isEmpty)
                    Text(
                      '-',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    for (final entry in byCurrency.entries)
                      Text(
                        '${entry.key}: ${entry.value.toStringAsFixed(4)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  refreshed == null
                      ? '尚未刷新'
                      : '更新于 ${formatDateTime(refreshed)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                FilledButton.tonalIcon(
                  onPressed: state.loading ? null : _refresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(state.loading ? '刷新中…' : '立即刷新'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 48,
              color: theme.hintColor,
            ),
            const SizedBox(height: 12),
            Text('还没有账户', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '请到下方「设置」添加 API 账户和 Key，然后回来刷新余额',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageSummary(BalanceState state) {
    final totals = state.usageTotals;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.data_usage),
        title: const Text('Token 用量'),
        subtitle: Text(
          '记录 ${totals.records} 条 · 共 ${totals.totalTokens} Token · '
          '费用 ${formatMoney(totals.cost)}',
        ),
      ),
    );
  }
}
