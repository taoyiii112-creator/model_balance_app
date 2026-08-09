import 'dart:convert';

import '../models/usage_record.dart';
import 'storage_service.dart';

/// 导入结果统计。
class CodexImportResult {
  const CodexImportResult({required this.imported, required this.skipped});

  final int imported;
  final int skipped;
}

/// 导入桌面端导出的 Codex 用量 JSON。
class UsageImportService {
  UsageImportService({StorageService? storage})
      : storage = storage ?? StorageService();

  final StorageService storage;

  /// 解析桌面端 `codex-usage --export` 生成的 JSON。
  static List<UsageRecord> parseCodexJson(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON 格式不正确：顶层应为对象');
    }
    final records = decoded['records'];
    if (records is! List) {
      throw const FormatException('JSON 缺少 records 数组');
    }
    final result = <UsageRecord>[];
    for (final item in records) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final key = (item['key'] as String?) ?? '';
      final createdRaw = (item['created_at'] as String?) ?? '';
      final input = (item['input_tokens'] as num?)?.toInt() ?? 0;
      final cached = (item['cached_input_tokens'] as num?)?.toInt() ?? 0;
      final miss = (item['cache_miss_tokens'] as num?)?.toInt() ??
          (input - cached).clamp(0, input);
      final output = (item['output_tokens'] as num?)?.toInt() ?? 0;
      final thread = (item['thread'] as String?) ?? 'codex';
      if (key.isEmpty || createdRaw.isEmpty) {
        continue;
      }
      result.add(
        UsageRecord(
          account: 'codex',
          model: thread,
          promptCacheHitTokens: cached,
          promptCacheMissTokens: miss,
          completionTokens: output,
          note: 'codex:$key',
          // 桌面端导出带时区（+08:00 等），统一转本地时间，避免显示差 8 小时。
          createdAt: (DateTime.tryParse(createdRaw) ?? DateTime.now()).toLocal(),
        ),
      );
    }
    return result;
  }

  /// 导入并去重：note 为 codex:<key>，已存在则跳过。
  Future<CodexImportResult> importCodex(String content) async {
    final records = parseCodexJson(content);
    final existing = await storage.listCodexKeys();
    var imported = 0;
    var skipped = 0;
    for (final record in records) {
      if (existing.contains(record.note)) {
        skipped++;
        continue;
      }
      await storage.addUsageRecord(record);
      imported++;
    }
    return CodexImportResult(imported: imported, skipped: skipped);
  }
}
