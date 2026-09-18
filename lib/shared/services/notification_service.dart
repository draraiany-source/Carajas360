import '../models/models.dart';
import 'firestore_facade.dart';

abstract final class NotificationService {
  static Future<void> pushNotif(
          String userId, String title, String body, String type) =>
      FS.pushNotif(userId, title, body, type);
  static Stream<List<NotifModel>> notifStream() => FS.notifStream();
  static Future<void> markNotifRead(String id) => FS.markNotifRead(id);
}
