/// Token 用量记录，与桌面版 models.UsageRecord 对应。
class UsageRecord {
  UsageRecord({
    this.id,
    required this.account,
    required this.model,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.cost,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final int? id;
  final String account;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final double? cost;
  final String note;
  final DateTime createdAt;

  int get totalTokens => promptTokens + completionTokens;

  Map<String, Object?> toDbMap() => <String, Object?>{
        'account': account,
        'model': model,
        'created_at': createdAt.toIso8601String(),
        'prompt_tokens': promptTokens,
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
      promptTokens: (map['prompt_tokens'] as int?) ?? 0,
      completionTokens: (map['completion_tokens'] as int?) ?? 0,
      cost: (map['cost'] as num?)?.toDouble(),
      note: (map['note'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// 用量汇总统计。
class UsageTotals {
  const UsageTotals({
    this.records = 0,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.cost = 0,
  });

  final int records;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double cost;

  factory UsageTotals.sum(List<UsageRecord> records) {
    var prompt = 0;
    var completion = 0;
    var total = 0;
    var cost = 0.0;
    for (final r in records) {
      prompt += r.promptTokens;
      completion += r.completionTokens;
      total += r.totalTokens;
      cost += r.cost ?? 0;
    }
    return UsageTotals(
      records: records.length,
      promptTokens: prompt,
      completionTokens: completion,
      totalTokens: total,
      cost: cost,
    );
  }
}
