import 'package:flutter_test/flutter_test.dart';
import 'package:model_balance_app/models/app_notification.dart';

void main() {
  test('AppNotification 落库字段往返一致', () {
    final notification = AppNotification(
      id: 7,
      type: 'low_balance',
      title: '低余额提醒',
      body: 'deepseek-main 可用余额 0.3000 CNY，低于阈值 5.00。',
      createdAt: DateTime(2026, 8, 9, 10, 30),
      dedupeKey: 'low_balance:deepseek-main:2026-08-09',
    );
    final restored = AppNotification.fromDbMap(notification.toDbMap());
    expect(restored.id, 7);
    expect(restored.type, 'low_balance');
    expect(restored.title, '低余额提醒');
    expect(restored.dedupeKey, notification.dedupeKey);
    expect(restored.createdAt, DateTime(2026, 8, 9, 10, 30));
    expect(restored.read, isFalse);
  });

  test('copyWith 仅修改已读状态', () {
    final notification = AppNotification(
      type: 'update_available',
      title: '发现新版本 v0.3.0',
      body: '更新内容',
    );
    final read = notification.copyWith(read: true);
    expect(read.read, isTrue);
    expect(read.title, '发现新版本 v0.3.0');
    expect(read.id, isNull);
  });
}
