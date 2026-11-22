import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../tasks/data/models/task_model.dart';

/// Manages offline local deadline alarms via `flutter_local_notifications`.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _exactAlarmAllowed = false;

  static const _channelId = 'pocket_span_deadlines_alarm';
  static const _channelName = '事项到期闹钟';

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      _configureLocalTimeZone();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(initSettings);

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();
      _exactAlarmAllowed =
          await androidImpl?.canScheduleExactNotifications() ?? false;
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init skipped: $e');
    }
  }

  void _configureLocalTimeZone() {
    final targetOffsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (location.currentTimeZone.offset == targetOffsetMs) {
        tz.setLocalLocation(location);
        return;
      }
    }
  }

  /// Synchronizes all pending reminders for [tasks] with the OS scheduler.
  Future<void> syncTaskReminders(List<TaskWithDetails> tasks) async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
      final now = DateTime.now();
      for (final item in tasks) {
        if (item.task.status != TaskStatus.active) continue;
        for (final r in item.reminders) {
          if (r.triggerAt.isAfter(now)) {
            await _scheduleOne(item.task.title, r);
          }
        }
      }
    } catch (e) {
      debugPrint('NotificationService sync skipped: $e');
    }
  }

  String _formatOffsetLabel(int offsetMinutes) {
    if (offsetMinutes < 0) return '每周固定提醒';
    if (offsetMinutes == 0) return '已到期';
    if (offsetMinutes < 60) return '距离截止还有 $offsetMinutes 分钟';
    if (offsetMinutes < 1440) {
      final hours = (offsetMinutes / 60).round();
      return '距离截止还有 $hours 小时';
    }
    final days = (offsetMinutes / 1440).round();
    return '距离截止还有 $days 天';
  }

  Future<void> _scheduleOne(String taskTitle, ReminderModel reminder) async {
    final scheduled = tz.TZDateTime.from(reminder.triggerAt, tz.local);
    final offsetLabel = _formatOffsetLabel(reminder.offsetMinutes);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    final mode = _exactAlarmAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _plugin.zonedSchedule(
        reminder.notificationId,
        'PocketSpan 提醒：$taskTitle',
        offsetLabel,
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        reminder.notificationId,
        'PocketSpan 提醒：$taskTitle',
        offsetLabel,
        scheduled,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
