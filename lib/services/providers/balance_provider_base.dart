import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/account.dart';
import '../../models/balance.dart';

/// 提供商查询失败时抛出，message 可直接展示给用户。
class ProviderException implements Exception {
  const ProviderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 把字符串或数字安全转换为 double。
double? parseDouble(Object? value) {
  if (value == null) {
    return null;
  }
  return double.tryParse(value.toString());
}

/// 余额查询适配器抽象基类，与桌面版 providers/base.py 对应。
abstract class BalanceProvider {
  BalanceProvider(this.account);

  final Account account;

  Future<Balance> fetchBalance();

  /// 带 Bearer 鉴权的 GET 请求，15 秒超时，失败抛 [ProviderException]。
  Future<Map<String, dynamic>> getJson(String url) async {
    final uri = Uri.parse(url);
    final http.Response resp;
    try {
      resp = await http.get(uri, headers: <String, String>{
        'Authorization': 'Bearer ${account.apiKey}',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
    } on Exception catch (e) {
      throw ProviderException('请求失败: $e');
    }
    if (resp.statusCode != 200) {
      throw ProviderException('请求失败 HTTP ${resp.statusCode}: ${resp.body}');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    } on FormatException {
      throw const ProviderException('响应不是合法 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ProviderException('响应格式不是 JSON 对象');
    }
    return decoded;
  }
}
