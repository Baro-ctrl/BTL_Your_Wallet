import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const NotificationDetails _budgetDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'budget_alerts',
      'Cảnh báo ngân sách',
      channelDescription: 'Cảnh báo khi chi tiêu gần hoặc vượt ngân sách',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );
  static const NotificationDetails _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reminder',
      'Nhắc ghi giao dịch',
      channelDescription: 'Nhắc bạn ghi lại thu chi mỗi ngày',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  static const int _dailyReminderId = 2001;

  static Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(settings: settings);
    tz_data.initializeTimeZones();

    final localTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));
  }

  static Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return false;

    return await androidPlugin.requestNotificationsPermission() ?? false;
  }

  static Future<void> showBudgetWarning({
    required int id,
    required String title,
    required String message,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: message,
      notificationDetails: _budgetDetails,
    );
  }

  static Future<void> scheduleDailyReminder({
    int hour = 20,
    int minute = 0,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Nếu giờ nhắc hôm nay đã qua, đặt lịch từ ngày mai.
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: 'Đừng quên ghi giao dịch',
      body: 'Dành chút thời gian cập nhật thu chi hôm nay nhé.',
      scheduledDate: scheduledDate,
      notificationDetails: _reminderDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(id: _dailyReminderId);
  }
}
