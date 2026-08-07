import '../models/usage_record.dart';

/// 某一天的用量汇总。
class DailyUsage {
  const DailyUsage({
    required this.day,
    required this.tokens,
    required this.cost,
  });

  final DateTime day;
  final int tokens;
  final double cost;
}

/// 按天汇总用量（返回按日期升序）。
List<DailyUsage> aggregateDaily(List<UsageRecord> records) {
  final byDay = <DateTime, List<UsageRecord>>{};
  for (final r in records) {
    final local = r.createdAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    byDay.putIfAbsent(day, () => <UsageRecord>[]).add(r);
  }
  final days = byDay.keys.toList()..sort();
  return days
      .map(
        (d) => DailyUsage(
          day: d,
          tokens: byDay[d]!.fold(0, (sum, r) => sum + r.totalTokens),
          cost: byDay[d]!.fold(0.0, (sum, r) => sum + (r.cost ?? 0)),
        ),
      )
      .toList();
}

/// Token 构成（输入命中缓存 / 输入未命中缓存 / 输出）。
class TokenBreakdown {
  const TokenBreakdown({
    this.cacheHit = 0,
    this.cacheMiss = 0,
    this.completion = 0,
  });

  final int cacheHit;
  final int cacheMiss;
  final int completion;

  int get total => cacheHit + cacheMiss + completion;

  double ratio(int value) => total == 0 ? 0 : value / total;

  factory TokenBreakdown.sum(List<UsageRecord> records) {
    var cacheHit = 0;
    var cacheMiss = 0;
    var completion = 0;
    for (final r in records) {
      cacheHit += r.promptCacheHitTokens;
      cacheMiss += r.promptCacheMissTokens;
      completion += r.completionTokens;
    }
    return TokenBreakdown(
      cacheHit: cacheHit,
      cacheMiss: cacheMiss,
      completion: completion,
    );
  }
}
