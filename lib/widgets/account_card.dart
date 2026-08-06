import 'package:flutter/material.dart';

import '../models/balance.dart';
import '../utils/formats.dart';

/// 单个账户余额卡片：成功显示金额明细，失败显示错误原因。
class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.result});

  final AccountResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = result.balance;
    final ok = result.ok;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ok && balance != null
            ? _buildSuccess(theme, balance)
            : _buildError(theme),
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme, Balance balance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              radius: 16,
              child: Text(
                balance.provider.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(balance.account, style: theme.textTheme.titleMedium),
                  Text(
                    providerLabel(balance.provider),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${formatMoney(balance.available)} ${balance.currency}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('可用金额', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: <Widget>[
            _detail('总额', balance.total, balance.currency),
            _detail('已用', balance.used, balance.currency),
            if (balance.granted != null)
              _detail('赠送', balance.granted, balance.currency),
            if (balance.toppedUp != null)
              _detail('充值', balance.toppedUp, balance.currency),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '更新于 ${formatDateTime(balance.fetchedAt)}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }

  Widget _detail(String label, double? value, String currency) {
    return Text('$label: ${formatMoney(value)} $currency');
  }

  Widget _buildError(ThemeData theme) {
    final error = result.error;
    return Row(
      children: <Widget>[
        Icon(Icons.error_outline, color: theme.colorScheme.error),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(result.account.name, style: theme.textTheme.titleMedium),
              Text(
                error ?? '尚未查询',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
