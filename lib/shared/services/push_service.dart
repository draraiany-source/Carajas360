import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'firestore_facade.dart';
import 'local_notifications.dart';

class PushSvc {
  static Future<void> init() async {
    try {
      await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('FCM permission: $e');
    }

    if (!kIsWeb) {
      try {
        await initLocalNotificationsPlugin((_, __) {});
        FirebaseMessaging.onMessage.listen((msg) {
          if (msg.notification != null) {
            _show(msg.notification!.title ?? 'Carajás 360',
                msg.notification!.body ?? '');
          }
        });
      } catch (e) {
        debugPrint('FCM/local notifications: $e');
      }
    }
  }

  static Future<void> saveToken(String uid) async {
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) await FS.updateFcmToken(t);
    } catch (e) {
      debugPrint('FCM token: $e');
    }
  }

  static Future<void> _show(String title, String body) async {
    if (kIsWeb) return;
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
    );
  }
}
