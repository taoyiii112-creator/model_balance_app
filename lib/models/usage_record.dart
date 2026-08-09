/// Token 用量记录，与桌面版 models.UsageRecord 对应。
class UsageRecord {
  UsageRecord({
    this.id,
    required this.account,
    required this.model,
    this.promptCacheHitTokens = 0,
    this.promptCacheMissTokens = 0,
    this.completionTokens = 0,
    this.cost,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final int? id;
  final String account;
  final String model;

  /// 输入 Token：命中缓存。
  final int promptCacheHitTokens;

  /// 输入 Token：未命中缓存。
  final int promptCacheMissTokens;

  /// 输出 Token。
  final int completionTokens;
  final double? cost;
  final String note;
  final DateTime createdAt;

  /// 输入 Token 合计（兼容旧字段）。
  int get promptTokens => promptCacheHitTokens + promptCacheMissTokens;

  int get totalTokens =>
      promptCacheHitTokens + promptCacheMissTokens + completionTokens;

  Map<String, Object?> toDbMap() => <String, Object?>{
        'account': account,
        'model': model,
        'created_at': createdAt.toIso8601String(),
        'prompt_tokens': promptTokens,
        'prompt_cache_hit_tokens': promptCacheHitTokens,
        'prompt_cache_miss_tokens': promptCacheMissTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
        'cost': cost,
        'note': note,
      };

  factory UsageRecord.fromDbMap(Map<String, Object?> map) {
    return UsageRecord(
      id: map['id'] as int?,
      account: map['account'] as String,
      model: map['model'] as String,
      promptCacheHitTokens: (map['prompt_cache_hit_tokens'] as int?) ?? 0,
      promptCacheMissTokens: (map['prompt_cache_miss_tokens'] as int?) ?? 0,
      completionTokens: (map['completion_tokens'] as int?) ?? 0,
      cost: (map['cost'] as num?)?.toDouble(),
      note: (map['note'] as String?) ?? '',
      // 历史数据可能存过 UTC（带 Z），读取时统一转本地时间。
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}

/// 用量汇总统计。
class UsageTotals {
  const UsageTotals({
    this.records = 0,
    this.promptCacheHitTokens = 0,
    this.promptCacheMissTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.cost = 0,
  });

  final int records;
  final int promptCacheHitTokens;
  final int promptCacheMissTokens;
  final int completionTokens;
  final int totalTokens;
  final double cost;

  /// 输入 Token 合计。
  int get promptTokens => promptCacheHitTokens + promptCacheMissTokens;

  factory UsageTotals.sum(List<UsageRecord> records) {
    var cacheHit = 0;
    var cacheMiss = 0;
    var completion = 0;
    var total = 0;
    var cost = 0.0;
    for (final r in records) {
      cacheHit += r.promptCacheHitTokens;
      cacheMiss += r.promptCacheMissTokens;
      completion += r.completionTokens;
      total += r.totalTokens;
      cost += r.cost ?? 0;
    }
    return UsageTotals(
      records: records.length,
      promptCacheHitTokens: cacheHit,
      promptCacheMissTokens: cacheMiss,
      completionTokens: completion,
      totalTokens: total,
      cost: cost,
    );
  }
}
