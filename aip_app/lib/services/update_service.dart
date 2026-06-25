import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

class UpdateService {
  static final Dio _dio = Dio();
  static const _channel = MethodChannel('com.aip.aip_app/install');

  static Future<void> checkAndPrompt(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final result = await ApiService.checkUpdate(info.version);
      if (result == null) return;

      final serverVersion = result['version'] as String?;
      if (serverVersion == null || serverVersion == info.version) return;

      final changelog = result['changelog'] as String? ?? 'New version';
      final forceUpdate = result['forceUpdate'] as bool? ?? false;

      if (!context.mounted) return;

      final shouldUpdate = await showDialog<bool>(
        context: context,
        barrierDismissible: !forceUpdate,
        builder: (ctx) => AlertDialog(
          title: const Text('发现新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前: ${info.version}  →  最新: $serverVersion'),
              const SizedBox(height: 8),
              Text(changelog, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          actions: forceUpdate
              ? [TextButton(onPressed: () {}, child: const Text('必须更新才能使用'))]
              : [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('稍后')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('立即更新')),
                ],
        ),
      );

      if (shouldUpdate == true && context.mounted) {
        _downloadAndInstall(context);
      }
    } catch (_) {}
  }

  static Future<void> _downloadAndInstall(BuildContext context) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DownloadingDialog(),
    );

    try {
      final dir = await getDownloadsDirectory();
      final publicDir = dir ?? await getTemporaryDirectory();

      // Clean old APK files
      try {
        final existing = publicDir.listSync().where((f) => f.path.endsWith('.apk')).toList();
        for (final f in existing) {
          try { await f.delete(); } catch (_) {}
        }
      } catch (_) {}

      final filePath = '${publicDir.path}/aip-update.apk';
      final apkUrl = '${ApiService.baseUrl}/uploads/aip-debug.apk';

      final response = await _dio.download(apkUrl, filePath,
        options: Options(headers: {'Cache-Control': 'no-cache'}),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            _DownloadDialogState.updateProgress(progress);
          }
        },
      );

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        final file = File(filePath);
        final size = await file.length();
        if (size > 1000000) {
          await _installApk(filePath);
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  static Future<void> _installApk(String filePath) async {
    try {
      await _channel.invokeMethod('install', {'path': filePath});
    } catch (_) {}
  }
}

class _DownloadingDialog extends StatefulWidget {
  const _DownloadingDialog();
  @override
  State<_DownloadingDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadingDialog> {
  static Function(double)? _updateProgress;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _updateProgress = (p) {
      if (mounted) setState(() => _progress = p);
    };
  }

  @override
  void dispose() {
    _updateProgress = null;
    super.dispose();
  }

  static void updateProgress(double p) {
    _updateProgress?.call(p);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('正在下载更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          const SizedBox(height: 12),
          Text(_progress > 0 ? '${(_progress * 100).toStringAsFixed(0)}%' : '准备中...'),
        ],
      ),
    );
  }
}
