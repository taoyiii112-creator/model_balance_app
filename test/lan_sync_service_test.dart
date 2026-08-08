import 'package:flutter_test/flutter_test.dart';
import 'package:model_balance_app/services/lan_sync_service.dart';

void main() {
  test('buildUrl 拼接局域网地址', () {
    expect(
      LanSyncService.buildUrl('192.168.1.100', 8002),
      'http://192.168.1.100:8002/api/codex-usage',
    );
    expect(
      LanSyncService.buildUrl('192.168.1.100', LanSyncService.defaultPort),
      'http://192.168.1.100:8002/api/codex-usage',
    );
  });

  group('validateInput', () {
    const token = '0123456789abcdef0123456789abcdef';

    test('合法 IP + 32 位十六进制令牌通过', () {
      expect(LanSyncService.validateInput('192.168.1.100', token), isNull);
      expect(LanSyncService.validateInput(' 192.168.1.100 ', token), isNull);
    });

    test('IP 为空或格式错误时拒绝', () {
      expect(LanSyncService.validateInput('', token), isNotNull);
      expect(LanSyncService.validateInput('abc', token), isNotNull);
      expect(LanSyncService.validateInput('999.1.1.1', token), isNotNull);
      expect(LanSyncService.validateInput('localhost', token), isNotNull);
    });

    test('令牌为空或格式错误时拒绝', () {
      expect(LanSyncService.validateInput('192.168.1.100', ''), isNotNull);
      expect(
        LanSyncService.validateInput('192.168.1.100', 'short-token'),
        isNotNull,
      );
      expect(
        LanSyncService.validateInput(
          '192.168.1.100',
          'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
        ),
        isNotNull,
      );
    });
  });
}
