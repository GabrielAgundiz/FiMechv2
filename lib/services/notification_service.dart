import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Utility for showing immediate (non-scheduled) local notifications.
/// Relies on the plugin being already initialized by [ReminderService.init()].
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Start at 500 to avoid conflicts with reminder IDs used by ReminderService.
  static int _idCounter = 500;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'updates_channel',
    'Actualizaciones',
    channelDescription: 'Notificaciones de cambios en citas y vehículos',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> showNow(String title, String body) async {
    try {
      await _plugin.show(
        _idCounter++,
        title,
        body,
        const NotificationDetails(android: _androidDetails),
      );
    } catch (_) {
      // Non-critical; fail silently.
    }
  }
}
