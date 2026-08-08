import 'package:flutter_test/flutter_test.dart';
import 'package:model_balance_app/models/balance.dart';
import 'package:model_balance_app/models/usage_record.dart';
import 'package:model_balance_app/services/storage_service.dart';
import 'package:model_balance_app/services/usage_import_service.dart';

class _FakeStorage extends StorageService {
  _FakeStorage(this.existing);

  final Set<String> existing;
  final List<UsageRecord> added = <UsageRecord>[];
  int _id = 100;

  @override
  Future<Set<String>> listCodexKeys() async => existing;

  @override
  Future<int> addUsageRecord(UsageRecord record) async {
    added.add(record);
    return _id++;
  }

  @override
  Future<List<UsageRecord>> listUsageRecords({
    String? account,
    DateTime? since,
  }) async {
    return List<UsageRecord>.of(added);
  }

  @override
  Future<int> addSnapshot(Balance balance) async => 1;
}

const sampleJson = '''
{"source":"codex","generated_at":"2026-08-08T20:00:00+08:00","records":[
 {"key":"s1:2026-08-02T12:51:19+08:00","session":"s1","thread":"游戏制作","created_at":"2026-08-02T12:51:19.535000+08:00","input_tokens":13167,"cached_input_tokens":0,"cache_miss_tokens":13167,"output_tokens":119,"total_tokens":13286},
 {"key":"s1:2026-08-02T12:55:23+08:00","session":"s1","thread":"游戏制作","created_at":"2026-08-02T12:55:23.046000+08:00","input_tokens":13293,"cached_input_tokens":13184,"cache_miss_tokens":109,"output_tokens":334,"total_tokens":13627}
]}
''';

void main() {
  test('parseCodexJson 解析字段与缓存拆分', () {
    final records = UsageImportService.parseCodexJson(sampleJson);
    expect(records.length, 2);

    final first = records.first;
    expect(first.account, 'codex');
    expect(first.model, '游戏制作');
    expect(first.promptCacheHitTokens, 0);
    expect(first.promptCacheMissTokens, 13167);
    expect(first.completionTokens, 119);
    expect(first.totalTokens, 13286);
    expect(first.note, startsWith('codex:s1:'));

    final second = records[1];
    expect(second.promptCacheHitTokens, 13184);
    expect(second.promptCacheMissTokens, 109);
    expect(second.completionTokens, 334);
    expect(second.totalTokens, 13627);
  });

  test('importCodex 增量去重', () async {
    final storage = _FakeStorage(<String>{
      'codex:s1:2026-08-02T12:51:19+08:00',
    });
    final result =
        await UsageImportService(storage: storage).importCodex(sampleJson);
    expect(result.imported, 1);
    expect(result.skipped, 1);
    expect(storage.added.single.note, 'codex:s1:2026-08-02T12:55:23+08:00');
  });

  test('非法 JSON 抛异常', () {
    expect(
      () => UsageImportService.parseCodexJson('not json'),
      throwsFormatException,
    );
    expect(
      () => UsageImportService.parseCodexJson('{"source":"x"}'),
      throwsA(isA<FormatException>()),
    );
  });
}
