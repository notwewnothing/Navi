import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi/screens/habits/habits_screen.dart';
import 'package:navi/services/settings_store.dart';
import 'package:navi/theme/palette.dart';
import 'package:navi/models/habit.dart';
import 'package:navi/services/habit_store.dart';

void main() {
  // pin "now" so streaks are deterministic
  final now = DateTime(2026, 6, 15, 12);
  DateTime clock() => now;
  DateTime daysAgo(int n) => now.subtract(Duration(days: n));

  Future<(HabitStore, Habit)> seed() async {
    final store = HabitStore(clock: clock);
    final habit = await store.addHabit(name: 'Run');
    return (store, habit);
  }

  test('a skipped day neither extends nor breaks the streak', () async {
    final (store, habit) = await seed();
    await store.checkIn(habit, day: daysAgo(3));
    await store.checkIn(habit, day: daysAgo(2));
    await store.skipDay(habit, day: daysAgo(1));
    await store.checkIn(habit, day: now);

    expect(store.streak(habit), 3);
    expect(store.isSkipped(habit, daysAgo(1)), isTrue);
    expect(store.isDone(habit, daysAgo(1)), isFalse);
  });

  test('a plain missed day still breaks the streak', () async {
    final (store, habit) = await seed();
    await store.checkIn(habit, day: daysAgo(3));
    await store.checkIn(habit, day: daysAgo(2));
    // nothing on daysAgo(1)
    await store.checkIn(habit, day: now);

    expect(store.streak(habit), 1);
  });

  test('a vacation covers days with no log at all', () async {
    final (store, habit) = await seed();
    await store.checkIn(habit, day: daysAgo(5));
    await store.checkIn(habit, day: daysAgo(4));
    await store.setPausedUntil(habit, daysAgo(1));
    await store.checkIn(habit, day: now);

    expect(store.isPaused(habit, daysAgo(2)), isTrue);
    expect(store.isPaused(habit, now), isFalse);
    expect(store.streak(habit), 3);
  });

  test('vacation ends the day after pausedUntil', () async {
    final (store, habit) = await seed();
    await store.setPausedUntil(habit, daysAgo(1));
    expect(store.isPaused(habit, daysAgo(1)), isTrue);
    expect(store.isRestDay(habit, daysAgo(1)), isTrue);
    expect(store.isPaused(habit, now), isFalse);
  });

  test('skipping clears a previous check-in for that day', () async {
    final (store, habit) = await seed();
    await store.checkIn(habit, day: now);
    expect(store.isDone(habit, now), isTrue);
    await store.skipDay(habit, day: now);
    expect(store.isDone(habit, now), isFalse);
    expect(store.isSkipped(habit, now), isTrue);
  });

  test('skips do not count as completions', () async {
    final (store, habit) = await seed();
    await store.skipDay(habit, day: now);
    expect(store.completionsOn(now), 0);
    expect(store.logsForDay(now), isEmpty);
  });

  test('a rest day drops out of the day total', () async {
    final store = HabitStore(clock: clock);
    final a = await store.addHabit(name: 'A');
    await store.addHabit(name: 'B');
    expect(store.todayTotal(), 2);
    await store.skipDay(a, day: now);
    expect(store.todayTotal(), 1);
  });

  test('skipping today leaves an untouched streak intact', () async {
    final (store, habit) = await seed();
    await store.checkIn(habit, day: daysAgo(2));
    await store.checkIn(habit, day: daysAgo(1));
    await store.skipDay(habit, day: now);
    expect(store.streak(habit), 2);
  });

  test('logs written before rest days existed load as not skipped', () {
    final log = HabitLog.fromJson({
      'id': 1,
      'habitId': 2,
      'dayKey': '2026-01-01',
      'at': 1700000000000,
    });
    expect(log.skipped, isFalse);
  });

  test('pausedUntil round-trips and defaults to null', () {
    final plain = Habit.fromJson({
      'id': 1,
      'name': 'Old',
      'createdAt': 1700000000000,
    });
    expect(plain.pausedUntil, isNull);

    final paused = Habit(
      id: 2,
      name: 'New',
      createdAt: now,
      pausedUntil: DateTime(2026, 7, 1),
    );
    expect(Habit.fromJson(paused.toJson()).pausedUntil, DateTime(2026, 7, 1));
  });

  testWidgets('swiping a habit right marks it a rest day', (tester) async {
    final habits = HabitStore();
    final habit = await habits.addHabit(name: 'Stretch');

    tester.view.physicalSize = const Size(360, 800) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      SettingsScope(
        store: SettingsStore(),
        child: HabitScope(
          store: habits,
          child: MaterialApp(
            theme: NaviPalette(accents.first).toThemeData(),
            home: const HabitsScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Stretch'), findsOneWidget);

    await tester.drag(find.text('Stretch'), const Offset(500, 0));
    await tester.pumpAndSettle();

    // the row stays put, but the day is now a rest day
    expect(habits.habits.length, 1);
    expect(habits.isSkipped(habit, DateTime.now()), isTrue);
    expect(habits.isDone(habit, DateTime.now()), isFalse);
    expect(find.text('Resting today'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
