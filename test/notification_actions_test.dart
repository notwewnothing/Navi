import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:navi/models/alarm.dart';
import 'package:navi/models/habit.dart';
import 'package:navi/services/notification_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> seedHabits({int nextId = 5, List<HabitLog> logs = const []}) async {
    SharedPreferences.setMockInitialValues({
      'navi.habits.v1': jsonEncode({
        'habits': [
          Habit(id: 1, name: 'Read', createdAt: DateTime(2026, 1, 1)).toJson(),
        ],
        'logs': [for (final l in logs) l.toJson()],
        'nextId': nextId,
        'remindersEnabled': true,
      }),
    });
  }

  Map<String, Object?> readHabits(SharedPreferences prefs) =>
      (jsonDecode(prefs.getString('navi.habits.v1')!) as Map)
          .cast<String, Object?>();

  test('check-in writes a log for today', () async {
    await seedHabits();
    expect(await NotificationActions.checkInHabit(1), isTrue);

    final prefs = await SharedPreferences.getInstance();
    final data = readHabits(prefs);
    final logs = (data['logs'] as List)
        .map((e) => HabitLog.fromJson((e as Map).cast<String, Object?>()))
        .toList();
    expect(logs.length, 1);
    expect(logs.single.habitId, 1);
    expect(logs.single.dayKey, dayKeyOf(DateTime.now()));
    expect(data['nextId'], 6);
  });

  test('checking in twice on the same day does not duplicate', () async {
    await seedHabits();
    await NotificationActions.checkInHabit(1);
    await NotificationActions.checkInHabit(1);

    final prefs = await SharedPreferences.getInstance();
    final logs = (readHabits(prefs)['logs'] as List);
    expect(logs.length, 1);
  });

  test('check-in leaves yesterday alone', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await seedHabits(
      logs: [
        HabitLog(
          id: 1,
          habitId: 1,
          dayKey: dayKeyOf(yesterday),
          at: yesterday,
        ),
      ],
    );
    await NotificationActions.checkInHabit(1);

    final prefs = await SharedPreferences.getInstance();
    final logs = (readHabits(prefs)['logs'] as List)
        .map((e) => HabitLog.fromJson((e as Map).cast<String, Object?>()))
        .toList();
    expect(logs.length, 2);
    expect(logs.map((l) => l.dayKey), contains(dayKeyOf(yesterday)));
    expect(logs.map((l) => l.dayKey), contains(dayKeyOf(DateTime.now())));
  });

  test('check-in on missing storage fails quietly', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await NotificationActions.checkInHabit(1), isFalse);
  });

  Future<void> seedAlarm(Alarm alarm) async {
    SharedPreferences.setMockInitialValues({
      'navi.alarms.v1': jsonEncode([alarm.toJson()]),
    });
  }

  Future<Alarm> readAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    final list = jsonDecode(prefs.getString('navi.alarms.v1')!) as List;
    return Alarm.fromJson((list.first as Map).cast<String, Object?>());
  }

  test('snooze pushes the alarm out by its snooze length', () async {
    await seedAlarm(
      Alarm(id: 7, hour: 6, minute: 30, snoozeMinutes: 10),
    );
    final before = DateTime.now();
    expect(await NotificationActions.snoozeAlarm(7), isTrue);

    final alarm = await readAlarm();
    expect(alarm.snoozedUntil, isNotNull);
    final delta = alarm.snoozedUntil!.difference(before).inMinutes;
    expect(delta, inInclusiveRange(9, 11));
  });

  test('dismiss disables a one-off alarm and clears snooze', () async {
    await seedAlarm(
      Alarm(
        id: 7,
        hour: 6,
        minute: 30,
        repeat: AlarmRepeat.once,
        snoozedUntil: DateTime.now().add(const Duration(minutes: 5)),
      ),
    );
    expect(await NotificationActions.dismissAlarm(7), isTrue);

    final alarm = await readAlarm();
    expect(alarm.enabled, isFalse);
    expect(alarm.snoozedUntil, isNull);
  });

  test('dismiss keeps a repeating alarm enabled', () async {
    await seedAlarm(
      Alarm(id: 7, hour: 6, minute: 30, repeat: AlarmRepeat.daily),
    );
    await NotificationActions.dismissAlarm(7);

    final alarm = await readAlarm();
    expect(alarm.enabled, isTrue);
  });

  test('an unknown alarm id is a no-op', () async {
    await seedAlarm(Alarm(id: 7, hour: 6, minute: 30));
    expect(await NotificationActions.snoozeAlarm(999), isFalse);
  });
}
