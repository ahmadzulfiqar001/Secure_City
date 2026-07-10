import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Real OS-level notification banners for newly arrived alerts — not just
/// an in-app badge. Uses the device's own notification center, no Firebase
/// project needed since this only fires while the WebSocket connection is
/// alive (a true push service would additionally need FCM/APNs to wake the
/// app up when it's fully closed).
class LocalNotificationService {
  LocalNotificationService._();
  static final instance = LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationChannel(
    'securecity_alerts',
    'Safety Alerts',
    description: 'Live alerts from the SecureCity monitoring system',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_ready) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit, macOS: iosInit),
    );
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);
    await androidImpl?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> showAlert({required String title, required String body}) async {
    try {
      await init();
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      // Notifications are a nice-to-have here — never let a plugin/platform
      // hiccup (e.g. unsupported on this target) take down the alert feed.
      debugPrint('LocalNotificationService.showAlert failed: $e');
    }
  }
}
