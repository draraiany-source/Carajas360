import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _plugin = FlutterLocalNotificationsPlugin();

Future<void> initLocalNotificationsPlugin(
  void Function(String title, String body) onMessage, {
  void Function(String? payload)? onTap,
}) async {
  const a = AndroidInitializationSettings('@mipmap/ic_launcher');
  const i = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true);
  await _plugin.initialize(
      settings: const InitializationSettings(android: a, iOS: i),
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload));
}

Future<void> showLocalNotification({
  required int id,
  required String title,
  required String body,
  String? payload,
}) async {
  const a = AndroidNotificationDetails('sc_main', 'Carajás 360',
      channelDescription: 'Notificações',
      importance: Importance.high,
      priority: Priority.high);
  const i = DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true);
  await _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(android: a, iOS: i),
    payload: payload,
  );
}

/// Payload da notificação local que abriu o app (estava encerrado).
Future<String?> localNotificationLaunchPayload() async {
  final d = await _plugin.getNotificationAppLaunchDetails();
  if (d == null || !d.didNotificationLaunchApp) return null;
  return d.notificationResponse?.payload;
}
