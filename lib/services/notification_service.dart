import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/alarm.dart';
import '../models/habit.dart';
import 'alarm_buzz.dart';
import 'alarm_store.dart';

class NotificationService implements AlarmScheduler {
  NotificationService({this.onAlarmTap});

  static const _habitIdBase = 1000000;

  final _plugin = FlutterLocalNotificationsPlugin();
  final void Function(int alarmId)? onAlarmTap;
  bool _ready = false;

  List<Alarm> _alarms = const [];
  List<Habit> _habits = const [];
  bool _habitRemindersEnabled = true;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {}

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_alarm'),
          iOS: DarwinInitializationSettings(),
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
        onDidReceiveNotificationResponse: _handleTap,
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);

      _ready = true;
    } catch (e) {
      debugPrint('notifications unavailable: $e');
    }
  }

  Future<int?> launchedByAlarm() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        final payload = details?.notificationResponse?.payload ?? '';
        if (payload.startsWith('alarm:')) {
          return int.tryParse(payload.substring(6));
        }
      }
    } catch (_) {}
    return null;
  }

  void _handleTap(NotificationResponse response) {
    final payload = response.payload ?? '';
    if (payload.startsWith('alarm:')) {
      final id = int.tryParse(payload.substring(6));
      if (id != null) onAlarmTap?.call(id);
    }
  }

  NotificationDetails get _alarmDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      'alarms_loud',
      'Alarms',
      channelDescription: 'NAVI alarms',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      autoCancel: false,
      ongoing: true,
      enableVibration: true,
      vibrationPattern: notificationVibrationPattern,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  NotificationDetails get _habitDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      'habit_reminders',
      'Habit reminders',
      channelDescription: 'Daily habit check-in reminders',
      importance: Importance.high,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  @override
  Future<void> syncAll(List<Alarm> alarms) async {
    _alarms = List.of(alarms);
    await _resync();
  }

  Future<void> syncHabits(List<Habit> habits, {required bool enabled}) async {
    _habits = List.of(habits);
    _habitRemindersEnabled = enabled;
    await _resync();
  }

  Future<void> _resync() async {
    if (!_ready) return;
    try {
      // simplest correct approach, wipe everything and rebuild from scratch
      await _plugin.cancelAll();
      await AlarmBuzz.cancelAllScheduled();
      for (final alarm in _alarms) {
        await _scheduleAlarm(alarm);
      }
      if (_habitRemindersEnabled) {
        for (final habit in _habits) {
          await _scheduleHabit(habit);
        }
      }
    } catch (e) {
      debugPrint('notification sync failed: $e');
    }
  }

  Future<void> _scheduleAlarm(Alarm alarm) async {
    if (!alarm.enabled) return;

    final now = DateTime.now();
    final snooze = alarm.snoozedUntil;
    // snooze fires as its own notification, once alarms skip the regular schedule
    if (snooze != null && snooze.isAfter(now)) {
      await _zonedAlarm(
        id: alarm.id * 100 + 99,
        alarm: alarm,
        at: snooze,
        title: 'ALARM (SNOOZED) — ${alarm.timeLabel24}',
      );
      if (alarm.repeat == AlarmRepeat.once) return;
    }

    switch (alarm.repeat) {
      case AlarmRepeat.once:
        final at = alarm.nextFire(now);
        if (at == null) return;
        await _zonedAlarm(id: alarm.id * 100, alarm: alarm, at: at);
      case AlarmRepeat.daily:
        final at = _nextWallClock(now, alarm.hour, alarm.minute);
        await _zonedAlarm(
          id: alarm.id * 100,
          alarm: alarm,
          at: at,
          match: DateTimeComponents.time,
        );
      case AlarmRepeat.weekdays:
        for (var day = DateTime.monday; day <= DateTime.friday; day++) {
          await _zonedAlarm(
            id: alarm.id * 100 + day,
            alarm: alarm,
            at: _nextWallClockOnWeekday(now, alarm.hour, alarm.minute, day),
            match: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      case AlarmRepeat.custom:
        for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
          if ((alarm.dayBits >> (day - 1)) & 1 == 0) continue;
          await _zonedAlarm(
            id: alarm.id * 100 + day,
            alarm: alarm,
            at: _nextWallClockOnWeekday(now, alarm.hour, alarm.minute, day),
            match: DateTimeComponents.dayOfWeekAndTime,
          );
        }
    }
  }

  Future<void> _scheduleHabit(Habit habit) async {
    final minutes = habit.reminderMinutes;
    if (!habit.enabled || minutes == null) return;
    final now = DateTime.now();
    for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
      if ((habit.dayBits >> (day - 1)) & 1 == 0) continue;
      final at = _nextWallClockOnWeekday(
        now,
        minutes ~/ 60,
        minutes % 60,
        day,
      );
      try {
        await _plugin.zonedSchedule(
          id: _habitIdBase + habit.id * 100 + day,
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          notificationDetails: _habitDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          title: habit.name.toUpperCase(),
          body: 'Check in. Present day, present time.',
          payload: 'habit:${habit.id}',
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        debugPrint('habit reminder failed: $e');
      }
    }
  }

  DateTime _nextWallClock(DateTime now, int hour, int minute) {
    var at = DateTime(now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  DateTime _nextWallClockOnWeekday(
    DateTime now,
    int hour,
    int minute,
    int weekday,
  ) {
    var at = _nextWallClock(now, hour, minute);
    while (at.weekday != weekday) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  Future<void> _zonedAlarm({
    required int id,
    required Alarm alarm,
    required DateTime at,
    String? title,
    DateTimeComponents? match,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _alarmDetails,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      title: title ?? 'ALARM — ${alarm.timeLabel24}',
      body: '${alarm.label} • WAKE UP, LAIN.',
      payload: 'alarm:${alarm.id}',
      matchDateTimeComponents: match,
    );

    await AlarmBuzz.scheduleAt(id: id, alarmId: alarm.id, at: at);
  }
}
