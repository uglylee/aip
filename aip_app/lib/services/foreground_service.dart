import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class AipForegroundTaskHandler extends TaskHandler {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _connect();
  }

  void _connect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final baseUrl = prefs.getString('api_base_url') ?? 'http://192.168.0.108:8005';
      final wsUrl = baseUrl.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/ws?token=$token');

      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data.toString());
            if (decoded is Map<String, dynamic>) {
              final event = decoded['event'] as String?;
              final eventData = decoded['data'];
              if (event == 'message' && eventData is Map) {
                final sender = eventData['senderName'] ?? '新消息';
                final content = eventData['content'] ?? '';
                NotificationService.showMessageNotification(title: sender, body: content);
              } else if (event == 'notification' && eventData is Map) {
                final type = eventData['type'] ?? '';
                String text;
                switch (type) {
                  case 'like': text = '赞了你的帖子'; break;
                  case 'retweet': text = '转发了你的帖子'; break;
                  case 'follow': text = '关注了你'; break;
                  case 'reply': text = '回复了你的帖子'; break;
                  case 'friend_request': text = '发送了好友请求'; break;
                  default: text = '与你互动';
                }
                NotificationService.showGenericNotification(title: '新通知', body: text);
              }
            }
          } catch (_) {}
        },
        onDone: () {
          _channel = null;
          Future.delayed(const Duration(seconds: 3), _connect);
        },
        onError: (err) {
          _channel = null;
          Future.delayed(const Duration(seconds: 3), _connect);
        },
      );
    } catch (_) {
      Future.delayed(const Duration(seconds: 5), _connect);
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    if (_channel == null) _connect();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _sub?.cancel();
    _channel?.sink.close();
  }
}

class ForegroundServiceHelper {
  static bool _started = false;

  static Future<void> start() async {
    if (_started) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'aip_foreground',
        channelName: 'AIP 后台服务',
        channelDescription: '保持消息实时推送',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        allowWakeLock: true,
      ),
    );

    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    await FlutterForegroundTask.startService(
      notificationTitle: 'AIP',
      notificationText: '正在运行，接收消息中...',
      callback: startCallback,
    );
    _started = true;
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    _started = false;
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(AipForegroundTaskHandler());
}
