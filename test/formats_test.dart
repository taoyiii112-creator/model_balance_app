import 'package:flutter_test/flutter_test.dart';
import 'package:model_balance_app/utils/formats.dart';

void main() {
  group('formatBytes', () {
    test('MB 显示', () {
      expect(formatBytes(49 * 1024 * 1024), '49.0 MB');
    });

    test('KB / B / 未知', () {
      expect(formatBytes(512 * 1024), '512.0 KB');
      expect(formatBytes(100), '100 B');
      expect(formatBytes(0), '未知大小');
    });
  });
}
