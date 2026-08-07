import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:model_balance_app/services/update_service.dart';

void main() {
  group('UpdateService.compareVersions', () {
    test('比较主版本', () {
      expect(UpdateService.compareVersions('0.2.0', '0.1.0'), 1);
      expect(UpdateService.compareVersions('1.0.0', '2.0.0'), -1);
    });

    test('比较补丁版本', () {
      expect(UpdateService.compareVersions('1.2.10', '1.2.9'), 1);
      expect(UpdateService.compareVersions('1.2.9', '1.2.10'), -1);
    });

    test('相同版本', () {
      expect(UpdateService.compareVersions('0.2.0', '0.2.0'), 0);
      expect(UpdateService.compareVersions('0.2', '0.2.0'), 0);
    });
  });

  group('UpdateService.parseReleaseJson', () {
    test('解析带 APK 资产的 Release', () {
      final info = UpdateService.parseReleaseJson(<String, dynamic>{
        'tag_name': 'v0.2.0',
        'body': '修复若干问题',
        'assets': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'app-release.apk',
            'browser_download_url': 'https://example.com/app-release.apk',
            'size': 52200000,
          },
        ],
      });
      expect(info, isNotNull);
      expect(info!.version, '0.2.0');
      expect(info.downloadUrl, 'https://example.com/app-release.apk');
      expect(info.notes, '修复若干问题');
      expect(info.sizeBytes, 52200000);
    });

    test('没有 APK 资产时返回 null', () {
      final info = UpdateService.parseReleaseJson(<String, dynamic>{
        'tag_name': 'v0.2.0',
        'assets': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'source.zip'},
        ],
      });
      expect(info, isNull);
    });

    test('缺少 tag 时返回 null', () {
      expect(UpdateService.parseReleaseJson(<String, dynamic>{}), isNull);
    });
  });

  group('UpdateService.sha256OfFile', () {
    test('计算文件 SHA256', () async {
      final dir = await Directory.systemTemp.createTemp('mb_update_test');
      final file = File('${dir.path}${Platform.pathSeparator}a.txt');
      await file.writeAsString('hello');
      final digest = await UpdateService.sha256OfFile(file.path);
      expect(
        digest,
        '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
      );
      await dir.delete(recursive: true);
    });
  });
}
