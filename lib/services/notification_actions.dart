import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm.dart';
import '../models/habit.dart';

const habitCheckInActionId = 'habit_check_in';
const alarmSnoozeActionId = 'alarm_snooze';
const alarmDismissActionId = 'alarm_dismiss';

const _habitsKey = 'navi.habits.v1';
const _alarmsKey = 'navi.alarms.v1';

/// Applies a notification action straight to storage. Runs in the background
/// isolate, so it cannot touch the stores and has to go through prefs.
class NotificationActions {
  static Future<bool> checkInHabit(int habitId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_habitsKey);
    if (raw == null) return false;
    try {
      final data = (jsonDecode(raw) as Map).cast<String, Object?>();
      final logs = [
        for (final e in (data['logs'] as List? ?? []))
          HabitLog.fromJson((e as Map).cast<String, Object?>()),
      ];
      final key = dayKeyOf(DateTime.now());
      if (logs.any((l) => l.habitId == habitId && l.dayKey == key)) {
        return true;
      }
      var nextId = data['nextId'] as int? ?? 1;
      logs.add(
        HabitLog(
          id: nextId++,
          habitId: habitId,
          dayKey: key,
          at: DateTime.now(),
        ),
      );
      data['logs'] = [for (final l in logs) l.toJson()];
      data['nextId'] = nextId;
      await prefs.setString(_habitsKey, jsonEncode(data));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> snoozeAlarm(int alarmId) =>
      _mutateAlarm(alarmId, (alarm) {
        alarm.snoozedUntil = DateTime.now().add(
          Duration(minutes: alarm.snoozeMinutes),
        );
      });

  static Future<bool> dismissAlarm(int alarmId) =>
      _mutateAlarm(alarmId, (alarm) {
        alarm.snoozedUntil = null;
        if (alarm.repeat == AlarmRepeat.once) alarm.enabled = false;
      });

  static Future<bool> _mutateAlarm(int alarmId, void Function(Alarm) apply) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_alarmsKey);
    if (raw == null) return false;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final alarms = [
        for (final e in list) Alarm.fromJson((e as Map).cast<String, Object?>()),
      ];
      final target = alarms.where((a) => a.id == alarmId).firstOrNull;
      if (target == null) return false;
      apply(target);
      await prefs.setString(
        _alarmsKey,
        jsonEncode([for (final a in alarms) a.toJson()]),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
