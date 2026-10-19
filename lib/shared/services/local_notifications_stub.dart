/// Stub Web: notificações locais não usam o plugin nativo.
Future<void> initLocalNotificationsPlugin(
  void Function(String title, String body) onMessage, {
  void Function(String? payload)? onTap,
}) async {}

Future<void> showLocalNotification({
  required int id,
  required String title,
  required String body,
  String? payload,
}) async {}
