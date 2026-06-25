import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;

    await _requestPermission();
  }

  static Future<void> _requestPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.notification.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  static Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'aip_messages',
      '私信通知',
      channelDescription: '收到新私信时通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  static Future<void> showGenericNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'aip_notifications',
      '应用通知',
      channelDescription: '点赞、关注、回复等通知',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
