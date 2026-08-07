import 'package:flutter_test/flutter_test.dart';
import 'package:model_balance_app/models/usage_record.dart';
import 'package:model_balance_app/utils/usage_stats.dart';

void main() {
  group('UsageRecord', () {
    test('totalTokens 汇总三类 Token', () {
      final record = UsageRecord(
        account: 'deepseek-main',
        model: 'deepseek-chat',
        promptCacheHitTokens: 100,
        promptCacheMissTokens: 300,
        completionTokens: 200,
      );
      expect(record.promptTokens, 400);
      expect(record.totalTokens, 600);
    });
  });

  group('aggregateDaily', () {
    test('按天汇总并升序返回', () {
      final records = <UsageRecord>[
        UsageRecord(
          account: 'a',
          model: 'm',
          promptCacheMissTokens: 100,
          completionTokens: 50,
          cost: 0.1,
          createdAt: DateTime(2026, 8, 7, 10, 0),
        ),
        UsageRecord(
          account: 'a',
          model: 'm',
          promptCacheHitTokens: 30,
          completionTokens: 20,
          cost: 0.05,
          createdAt: DateTime(2026, 8, 7, 18, 30),
        ),
        UsageRecord(
          account: 'a',
          model: 'm',
          promptCacheMissTokens: 500,
          completionTokens: 100,
          cost: 0.2,
          createdAt: DateTime(2026, 8, 6, 9, 0),
        ),
      ];
      final daily = aggregateDaily(records);
      expect(daily.length, 2);
      expect(daily[0].day, DateTime(2026, 8, 6));
      expect(daily[0].tokens, 600);
      expect(daily[0].cost, 0.2);
      expect(daily[1].day, DateTime(2026, 8, 7));
      expect(daily[1].tokens, 200);
      expect(daily[1].cost, closeTo(0.15, 0.0001));
    });
  });

  group('TokenBreakdown', () {
    test('汇总命中缓存/未命中缓存/输出', () {
      final breakdown = TokenBreakdown.sum(<UsageRecord>[
        UsageRecord(
          account: 'a',
          model: 'm',
          promptCacheHitTokens: 100,
          promptCacheMissTokens: 200,
          completionTokens: 300,
        ),
        UsageRecord(
          account: 'a',
          model: 'm',
          promptCacheHitTokens: 50,
          promptCacheMissTokens: 50,
          completionTokens: 100,
        ),
      ]);
      expect(breakdown.cacheHit, 150);
      expect(breakdown.cacheMiss, 250);
      expect(breakdown.completion, 400);
      expect(breakdown.total, 800);
      expect(breakdown.ratio(200), closeTo(0.25, 0.0001));
    });

    test('空数据时比例为 0', () {
      const breakdown = TokenBreakdown();
      expect(breakdown.total, 0);
      expect(breakdown.ratio(10), 0);
    });
  });
}
