import 'package:flutter/material.dart';

import '../utils/formats.dart';
import 'update_service.dart';

/// 检查更新并引导下载安装。
///
/// [manual] 为 true 时由用户主动触发：无更新 / 失败都会提示；
/// 为 false 时启动静默检查：只在发现新版本时弹窗。
Future<void> promptForUpdate(
  BuildContext context, {
  required String currentVersion,
  required bool manual,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  AppUpdateInfo? info;
  try {
    info = await UpdateService.instance.checkForUpdate();
  } catch (_) {
    if (manual) {
      messenger.showSnackBar(
        const SnackBar(content: Text('检查更新失败，请检查网络')),
      );
    }
    return;
  }

  if (info == null ||
      UpdateService.compareVersions(info.version, currentVersion) <= 0) {
    if (manual) {
      messenger.showSnackBar(
        SnackBar(content: Text('当前已是最新版本 v$currentVersion')),
      );
    }
    return;
  }
  if (!context.mounted) {
    return;
  }

  final goDownload = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('发现新版本 v${info!.version}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              info.notes.isEmpty ? '有新版本可用，是否立即下载更新？' : info.notes,
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const Icon(Icons.sd_storage_outlined, size: 16),
                const SizedBox(width: 4),
                Text('更新包大小：${formatBytes(info.sizeBytes)}'),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('立即更新'),
        ),
      ],
    ),
  );
  if (goDownload != true || !context.mounted) {
    return;
  }

  final progress = ValueNotifier<double>(0);
  final status = ValueNotifier<String>('准备下载…');
  final canInstall = ValueNotifier<bool>(false);
  final failed = ValueNotifier<bool>(false);
  final totalBytes = info.sizeBytes;

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('下载更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, p, __) => LinearProgressIndicator(
              value: p <= 0 ? null : p.clamp(0.0, 1.0),
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (_, s, __) => Text(s),
          ),
        ],
      ),
      actions: <Widget>[
        ValueListenableBuilder<bool>(
          valueListenable: canInstall,
          builder: (_, ok, __) {
            if (ok) {
              return FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop('install'),
                child: const Text('安装'),
              );
            }
            return ValueListenableBuilder<bool>(
              valueListenable: failed,
              builder: (_, isFailed, __) => TextButton(
                onPressed: () => Navigator.of(dialogContext)
                    .pop(isFailed ? 'close' : 'cancel'),
                child: Text(isFailed ? '关闭' : '取消'),
              ),
            );
          },
        ),
      ],
    ),
  );

  String? path;
  try {
    path = await UpdateService.instance.downloadApk(
      info.downloadUrl,
      onProgress: (p) {
        progress.value = p;
        status.value = totalBytes > 0
            ? '已下载 ${formatBytes((totalBytes * p).round())} / '
                '${formatBytes(totalBytes)}（${(p * 100).toStringAsFixed(0)}%）'
            : '${(p * 100).toStringAsFixed(0)}%';
      },
    );
    status.value = '下载完成，请点击安装';
    canInstall.value = true;
  } catch (e) {
    status.value = '下载失败：$e';
    failed.value = true;
  }

  if (result == 'install' && path != null && context.mounted) {
    try {
      await UpdateService.instance.installApk(path);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('安装失败：$e')));
    }
  }
  progress.dispose();
  status.dispose();
  canInstall.dispose();
  failed.dispose();
}
