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
}
