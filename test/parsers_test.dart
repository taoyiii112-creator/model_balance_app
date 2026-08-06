import 'package:flutter_test/flutter_test.dart';
import 'package:model_balance_app/services/providers/balance_provider_base.dart';
import 'package:model_balance_app/services/providers/deepseek_provider.dart';
import 'package:model_balance_app/services/providers/openai_compat_provider.dart';
import 'package:model_balance_app/services/providers/openai_provider.dart';

void main() {
  group('DeepSeekProvider', () {
    test('解析官方余额响应', () {
      final balance = DeepSeekProvider.parseBalance(
        'deepseek-main',
        <String, dynamic>{
          'is_available': true,
          'balance_infos': <Map<String, dynamic>>[
            <String, dynamic>{
              'currency': 'CNY',
              'total_balance': '110.00',
              'granted_balance': '10.00',
              'topped_up_balance': '100.00',
            },
          ],
        },
      );
      expect(balance.available, 110.0);
      expect(balance.granted, 10.0);
      expect(balance.toppedUp, 100.0);
      expect(balance.currency, 'CNY');
    });

    test('账户不可用时抛出异常', () {
      expect(
        () => DeepSeekProvider.parseBalance(
          'deepseek-main',
          <String, dynamic>{'is_available': false},
        ),
        throwsA(isA<ProviderException>()),
      );
    });
  });

  group('OpenAIProvider', () {
    test('解析 credit_grants 响应', () {
      final balance = OpenAIProvider.parseBalance(
        'openai-main',
        <String, dynamic>{
          'total_granted': 100.0,
          'total_used': 30.0,
          'total_available': 70.0,
        },
      );
      expect(balance.available, 70.0);
      expect(balance.total, 100.0);
      expect(balance.used, 30.0);
      expect(balance.currency, 'USD');
    });

    test('缺少金额字段时抛出异常', () {
      expect(
        () => OpenAIProvider.parseBalance(
          'openai-main',
          <String, dynamic>{'foo': 1},
        ),
        throwsA(isA<ProviderException>()),
      );
    });
  });

  group('OpenAICompatProvider', () {
    test('quota 按分母换算', () {
      final balance = OpenAICompatProvider.parseBalance(
        'relay-openai',
        <String, dynamic>{
          'data': <String, dynamic>{'quota': 8000000, 'used_quota': 2000000},
        },
        500000,
        'CNY',
      );
      expect(balance.available, 16.0);
      expect(balance.used, 4.0);
      expect(balance.currency, 'CNY');
    });
  });
}
