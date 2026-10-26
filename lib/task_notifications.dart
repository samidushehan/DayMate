import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'task.dart';

abstract interface class TaskReminderService {
  Future<bool> initialize();

  Future<bool> schedule(Task task);

  Future<void> cancel(int id);
}

class LocalTaskReminderService implements TaskReminderService {
  LocalTaskReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _permissionGranted = false;

  @override
  Future<bool> initialize() async {
    if (_initialized) return _permissionGranted;
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      _initialized = true;
      return false;
    }

    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));

    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    if (initialized != true) {
      throw StateError('Local notifications could not be initialized.');
    }

    if (platform == TargetPlatform.android) {
      _permissionGranted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    } else {
      _permissionGranted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    _initialized = true;
    return _permissionGranted;
  }

  @override
  Future<bool> schedule(Task task) async {
    if (!_initialized) {
      throw StateError('Reminder service has not been initialized.');
    }
    await cancel(task.id);
    if (!task.hasTime || task.isCompleted || !_permissionGranted) return false;
    if (!task.dueAt.isAfter(DateTime.now())) return true;

    await _plugin.zonedSchedule(
      id: task.id,
      title: task.title,
      body: 'Your DayMate task is due now.',
      scheduledDate: timezone.TZDateTime.from(task.dueAt, timezone.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daymate_task_reminders',
          'Task reminders',
          channelDescription: 'Reminders for scheduled DayMate tasks.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: task.id.toString(),
    );
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    if (!_initialized) {
      throw StateError('Reminder service has not been initialized.');
    }
    await _plugin.cancel(id: id);
  }
}
