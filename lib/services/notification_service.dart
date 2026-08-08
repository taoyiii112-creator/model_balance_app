import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 系统通知封装：初始化、申请权限、展示通知。
///
/// 点击通知后的跳转由 App 通过 [onNotificationTap] 注入；
/// 平台通道不可用（例如单元测试环境）时静默降级，不影响业务。
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> Function()? onNotificationTap;
  bool _ready = false;

  /// 初始化并申请权限；返回 App 是否由点击通知拉起（冷启动场景）。
  Future<bool> init({Future<void> Function()? onTap}) async {
    onNotificationTap = onTap;
    var launchedFromNotification = false;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const settings =
          InitializationSettings(android: androidInit, iOS: iosInit);
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          onNotificationTap?.call();
        },
      );
      _ready = true;
      await requestPermissions();
      launchedFromNotification =
          launchDetails?.didNotificationLaunchApp ?? false;
    } catch (_) {
      // 平台通道不可用时保持未初始化，show 直接跳过。
    }
    return launchedFromNotification;
  }

  /// 申请通知权限（Android 13+ 需运行时授权；iOS 首次弹窗）。
  Future<void> requestPermissions() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {
      // 权限申请失败不阻塞主流程。
    }
  }

  /// 展示一条系统通知；失败时静默忽略（不影响消息中心落库）。
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_ready) {
      return;
    }
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'balance_alerts',
          '余额与消息提醒',
          channelDescription: '低余额、新版本等消息提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {
      // 展示失败不影响消息中心。
    }
  }
}
