import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: settings,
    );
    _initialized = true;
  }

  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'faculty_class_channel',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming and current faculty classes',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  static Future<void> scheduleClassReminder({
    required int id,
    required String subjectName,
    required DateTime classTime,
  }) async {
    await init();

    final now = DateTime.now();

    // 1. Reminder 15 Minutes Before Class
    final time15MinBefore = classTime.subtract(const Duration(minutes: 15));
    if (time15MinBefore.isAfter(now)) {
      await _scheduleNotification(
        id: id * 10 + 1,
        title: "Upcoming Class Reminder ⏰",
        body: "Your $subjectName class starts in 15 minutes.",
        scheduledDate: time15MinBefore,
      );
    }

    // 2. Reminder At Class Time
    if (classTime.isAfter(now)) {
      await _scheduleNotification(
        id: id * 10 + 2,
        title: "Class Time 🔔",
        body: "You have a $subjectName class now.",
        scheduledDate: classTime,
      );
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'faculty_class_channel',
        'Class Reminders',
        channelDescription: 'Notifications for upcoming and current faculty classes',
        importance: Importance.high,
        priority: Priority.high,
      );

      const details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Fallback if exact alarms permission is not granted
    }
  }

  static Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id: id * 10 + 1);
    await _notificationsPlugin.cancel(id: id * 10 + 2);
  }
}
