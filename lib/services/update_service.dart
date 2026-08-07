import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 可用的新版本信息。
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.notes = '',
    this.sizeBytes = 0,
  });

  final String version;
  final String downloadUrl;
  final String notes;

  /// 更新包大小（字节），未知为 0。
  final int sizeBytes;
}

/// 应用内更新：检查 GitHub Release → 下载 APK → 唤起系统安装器。
class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  /// 更新源：GitHub Releases API。返回 JSON 含 tag_name / body / assets[].apk。
  /// 如需自建更新源，可改成任意返回相同结构的地址。
  static const String updateSourceUrl =
      'https://api.github.com/repos/taoyiii112-creator/model_balance_app/releases/latest';

  static const MethodChannel _installChannel =
      MethodChannel('model_balance/install');

  bool _checkedThisSession = false;

  /// 本次启动是否已检查过更新（避免重复弹窗）。
  bool get checkedThisSession => _checkedThisSession;

  void markChecked() => _checkedThisSession = true;

  /// 解析 GitHub releases/latest 响应；无 APK 资产或字段缺失返回 null。
  static AppUpdateInfo? parseReleaseJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String?;
    if (tag == null || tag.isEmpty) {
      return null;
    }
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    String? apkUrl;
    var sizeBytes = 0;
    final assets = json['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is Map<String, dynamic>) {
          final name = ((a['name'] as String?) ?? '').toLowerCase();
          if (name.endsWith('.apk')) {
            apkUrl = a['browser_download_url'] as String?;
            sizeBytes = (a['size'] as num?)?.toInt() ?? 0;
            break;
          }
        }
      }
    }
    if (apkUrl == null || apkUrl.isEmpty) {
      return null;
    }
    return AppUpdateInfo(
      version: version,
      downloadUrl: apkUrl,
      notes: (json['body'] as String?) ?? '',
      sizeBytes: sizeBytes,
    );
  }

  /// 版本号比较（主.次.补丁）：返回 a < b ? -1 : a > b ? 1 : 0。
  static int compareVersions(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    for (var i = 0; i < pa.length; i++) {
      if (pa[i] != pb[i]) {
        return pa[i] < pb[i] ? -1 : 1;
      }
    }
    return 0;
  }

  static List<int> _parts(String version) {
    final nums =
        version.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
    while (nums.length < 3) {
      nums.add(0);
    }
    return nums.take(3).toList();
  }

  /// 查询最新版本；仓库还没有 Release 时返回 null。
  Future<AppUpdateInfo?> checkForUpdate() async {
    final http.Response resp;
    try {
      resp = await http.get(
        Uri.parse(updateSourceUrl),
        headers: const <String, String>{
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(const Duration(seconds: 15));
    } on Exception catch (e) {
      throw UpdateException('检查更新失败: $e');
    }
    if (resp.statusCode == 404) {
      return null;
    }
    if (resp.statusCode != 200) {
      throw UpdateException('检查更新失败: HTTP ${resp.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return parseReleaseJson(decoded);
  }

  /// 下载 APK 到应用私有目录，返回本地路径；onProgress 回调 0~1。
  Future<String> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}model_balance_update.apk',
    );
    final http.StreamedResponse response;
    try {
      response = await http.Client()
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 20));
    } on Exception catch (e) {
      throw UpdateException('下载失败: $e');
    }
    if (response.statusCode != 200) {
      throw UpdateException('下载失败: HTTP ${response.statusCode}');
    }
    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
    } finally {
      await sink.close();
    }
    return file.path;
  }

  /// 唤起系统安装器安装 APK。
  Future<void> installApk(String path) async {
    await _installChannel.invokeMethod<void>('installApk', path);
  }
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
