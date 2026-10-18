import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const morningId = 1, nightId = 2;

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
      }
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// اندروید ۱۳ به بالا: مجوز POST_NOTIFICATIONS در زمان اجرا پرسیده می‌شود.
  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    return await _android?.requestNotificationsPermission() ?? true;
  }

  static Future<bool> areEnabled() async {
    if (!_ready) return false;
    return await _android?.areNotificationsEnabled() ?? true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reminders',
      'یادآوری‌های روزانه',
      channelDescription: 'یادآوری برنامه صبح و برنامه‌ریزی شبانه',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// اعلان روزانه تکرارشونده. از حالت «غیردقیق» استفاده می‌شود تا مجوز Exact Alarm لازم نباشد؛
  /// ممکن است اعلان چند دقیقه دیرتر نمایش داده شود.
  static Future<void> scheduleDaily(int id, int hour, int minute, String title, String body) async {
    if (!_ready) return;
    await _plugin.zonedSchedule(
      id, title, body, _nextInstance(hour, minute), _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel(int id) async {
    if (_ready) await _plugin.cancel(id);
  }

  static Future<void> showNow(String title, String body) async {
    if (_ready) await _plugin.show(99, title, body, _details);
  }
}
