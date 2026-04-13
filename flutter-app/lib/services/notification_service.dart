import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Android 알림 채널
    const channel = AndroidNotificationChannel(
      'chat_channel',
      'Pulsar Chat 알림',
      description: '새 채팅 메시지 알림',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// 새 메시지 로컬 알림 표시
  static Future<void> showMessageNotification({
    required String senderName,
    required String roomName,
    required String content,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Pulsar Chat 알림',
      channelDescription: '새 채팅 메시지',
      importance: Importance.high,
      priority: Priority.high,
      ticker: '새 메시지',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      id,
      '$senderName — $roomName',
      content,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }

  /// 파일 공유 알림
  static Future<void> showFileNotification({
    required String senderName,
    required String fileName,
  }) async {
    await showMessageNotification(
      senderName: senderName,
      roomName: '파일 공유',
      content: '📎 $fileName',
    );
  }
}
