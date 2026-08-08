import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../state/balance_state.dart';
import '../utils/formats.dart';

/// 消息中心：展示系统通知生成的消息，支持已读、查看详情与删除。
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BalanceState>();
    final items = state.notifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: <Widget>[
          IconButton(
            onPressed: state.unreadNotificationCount == 0
                ? null
                : () =>
                    context.read<BalanceState>().markAllNotificationsRead(),
            tooltip: '全部已读',
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              onRefresh: () => context.read<BalanceState>().load(),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _NotificationTile(notification: items[index]),
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.notifications_none,
            size: 56,
            color: theme.hintColor,
          ),
          const SizedBox(height: 12),
          Text('暂无消息', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '低余额、新版本等提醒会显示在这里',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  Future<void> _showDetail(BuildContext context) async {
    final state = context.read<BalanceState>();
    if (!notification.read) {
      await state.markNotificationRead(notification.id!);
    }
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(notification.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(notification.body),
              const SizedBox(height: 10),
              Text(
                formatDateTime(notification.createdAt),
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(dialogContext).hintColor,
                    ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.read;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: unread ? FontWeight.bold : FontWeight.normal,
    );
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _colorFor(notification.type).withValues(alpha: 0.15),
        child: Icon(
          _iconFor(notification.type),
          color: _colorFor(notification.type),
          size: 20,
        ),
      ),
      title: Row(
        children: <Widget>[
          if (unread)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(child: Text(notification.title, style: titleStyle)),
        ],
      ),
      subtitle: Text(
        notification.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: unread ? theme.colorScheme.onSurface : theme.hintColor,
        ),
      ),
      isThreeLine: false,
      onTap: () => _showDetail(context),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            formatTime(notification.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          IconButton(
            onPressed: () =>
                context.read<BalanceState>().deleteNotification(notification.id!),
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'low_balance':
        return Icons.warning_amber_rounded;
      case 'update_available':
        return Icons.system_update_alt;
      default:
        return Icons.notifications_outlined;
    }
  }

  static Color _colorFor(String type) {
    switch (type) {
      case 'low_balance':
        return Colors.orange;
      case 'update_available':
        return Colors.blue;
      default:
        return Colors.indigo;
    }
  }
}
