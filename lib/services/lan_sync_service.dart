import 'dart:convert';

import 'package:http/http.dart' as http;

import 'storage_service.dart';
import 'usage_import_service.dart';

class LanSyncException implements Exception {
  const LanSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 局域网同步：从电脑端 lan-sync 服务拉取 Codex 用量并导入。
class LanSyncService {
  LanSyncService({StorageService? storage})
      : storage = storage ?? StorageService();

  final StorageService storage;

  static const int defaultPort = 8002;

  static String buildUrl(String host, int port) {
    return 'http://$host:$port/api/codex-usage';
  }

  Future<CodexImportResult> fetchAndImport(
    String host,
    int port,
    String token,
  ) async {
    final http.Response resp;
    try {
      resp = await http.get(
        Uri.parse(buildUrl(host, port)),
        headers: <String, String>{'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } on Exception catch (e) {
      throw LanSyncException('无法连接电脑：$e');
    }
    if (resp.statusCode == 401) {
      throw const LanSyncException('鉴权失败：同步令牌不正确，请核对电脑端显示/保存的令牌');
    }
    if (resp.statusCode != 200) {
      throw LanSyncException('同步失败：HTTP ${resp.statusCode}');
    }
    try {
      return await UsageImportService(storage: storage)
          .importCodex(utf8.decode(resp.bodyBytes));
    } on FormatException catch (e) {
      throw LanSyncException('响应格式错误：$e');
    }
  }
}
