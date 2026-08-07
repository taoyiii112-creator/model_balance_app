import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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
    this.sha256,
  });

  final String version;
  final String downloadUrl;
  final String notes;

  /// 更新包大小（字节），未知为 0。
  final int sizeBytes;

  /// 更新包 SHA256（十六进制），无校验源时为 null。
  final String? sha256;

  AppUpdateInfo copyWith({String? sha256}) {
    return AppUpdateInfo(
      version: version,
      downloadUrl: downloadUrl,
      notes: notes,
      sizeBytes: sizeBytes,
      sha256: sha256 ?? this.sha256,
    );
  }
}

/// 应用内更新：检查 GitHub Release → 下载 APK → 唤起系统安装器。
class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  /// 默认更新源：GitHub Releases API。返回 JSON 含 tag_name / body / assets[].apk。
  static const String defaultUpdateSourceUrl =
      'https://api.github.com/repos/taoyiii112-creator/model_balance_app/releases/latest';

  String _updateSourceUrl = defaultUpdateSourceUrl;

  /// 当前生效的更新源地址（可在设置中修改，持久化到应用私有目录）。
  String get updateSourceUrl => _updateSourceUrl;

  /// 读取自定义更新源；不存在时用默认 GitHub。
  Future<void> loadUpdateSource() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}update_source.json',
      );
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        final url = data is Map ? data['url'] : null;
        if (url is String && url.trim().isNotEmpty) {
          _updateSourceUrl = url.trim();
        }
      }
    } catch (_) {
      // 读取失败时保留当前地址
    }
  }

  /// 设置更新源地址；传空字符串恢复默认 GitHub Releases。
  Future<void> setUpdateSource(String url) async {
    final trimmed = url.trim();
    _updateSourceUrl = trimmed.isEmpty ? defaultUpdateSourceUrl : trimmed;
    final dir = await getApplicationSupportDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}update_source.json',
    );
    await file.writeAsString(
      jsonEncode(<String, String>{'url': _updateSourceUrl}),
    );
  }

  /// 清理残留的临时 APK（上次安装可能因进程被杀未执行延迟清理）。
  Future<void> cleanupStaleDownload() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}model_balance_update.apk',
      );
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 清理失败不影响使用
    }
  }

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

  /// 兼容两种更新源格式：
  /// - GitHub Releases API（tag_name / assets）
  /// - 简单 version.json（version / url / size / notes / sha256）
  static AppUpdateInfo? parseUpdateInfo(Map<String, dynamic> json) {
    if (json.containsKey('tag_name') || json.containsKey('assets')) {
      return parseReleaseJson(json);
    }
    final version = json['version'] as String?;
    final url = json['url'] as String?;
    if (version == null || version.isEmpty || url == null || url.isEmpty) {
      return null;
    }
    return AppUpdateInfo(
      version: version.startsWith('v') ? version.substring(1) : version,
      downloadUrl: url,
      notes: (json['notes'] as String?) ?? '',
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String?,
    );
  }

  /// 从 Release 资产里找指定后缀的下载地址（如 .sha256）。
  static String? findAssetUrl(Map<String, dynamic> json, String suffix) {
    final assets = json['assets'];
    if (assets is! List) {
      return null;
    }
    for (final a in assets) {
      if (a is Map<String, dynamic>) {
        final name = ((a['name'] as String?) ?? '').toLowerCase();
        if (name.endsWith(suffix)) {
          return a['browser_download_url'] as String?;
        }
      }
    }
    return null;
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
    await loadUpdateSource();
    final http.Response resp;
    try {
      resp = await http.get(
        Uri.parse(_updateSourceUrl),
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
    if (resp.statusCode == 403) {
      throw const UpdateException('更新检查过于频繁，请稍后再试');
    }
    if (resp.statusCode != 200) {
      throw UpdateException('检查更新失败: HTTP ${resp.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    var info = parseUpdateInfo(decoded);
    if (info == null) {
      return null;
    }
    // 若 Release 附带 <apk>.sha256 资产，拉取摘要用于下载后校验。
    final shaAssetUrl = findAssetUrl(decoded, '.sha256');
    if (shaAssetUrl != null) {
      final expected = await _fetchSha256(shaAssetUrl);
      if (expected != null && expected.isNotEmpty) {
        info = info.copyWith(sha256: expected);
      }
    }
    return info;
  }

  /// 下载 APK 到应用私有目录，返回本地路径；onProgress 回调 0~1。
  Future<String> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
    String? expectedSha256,
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
    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      final actual = await sha256OfFile(file.path);
      if (actual.toLowerCase() != expectedSha256.toLowerCase()) {
        try {
          await file.delete();
        } catch (_) {}
        throw const UpdateException(
          'APK 校验失败（SHA256 不匹配），文件已删除，请重试',
        );
      }
    }
    return file.path;
  }

  /// 计算文件 SHA256。
  static Future<String> sha256OfFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return sha256.convert(bytes).toString();
  }

  static Future<String?> _fetchSha256(String url) async {
    final http.Response resp;
    try {
      resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    } on Exception {
      return null;
    }
    if (resp.statusCode != 200) {
      return null;
    }
    final match = RegExp(r'[0-9a-fA-F]{64}').firstMatch(resp.body);
    return match?.group(0);
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
