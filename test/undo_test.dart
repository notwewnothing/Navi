import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi/models/journal_entry.dart';
import 'package:navi/screens/habits/habits_screen.dart';
import 'package:navi/services/habit_store.dart';
import 'package:navi/services/journal_store.dart';
import 'package:navi/services/settings_store.dart';
import 'package:navi/theme/palette.dart';
import 'package:navi/widgets/nd_widgets.dart';

void main() {
  group('store restore', () {
    test('a removed journal entry comes back in date order', () async {
      final store = JournalStore();
      final older = await store.add(type: JournalType.text, body: 'older');
      final newer = await store.add(type: JournalType.text, body: 'newer');
      expect(store.entries.length, 2);

      await store.remove(newer, keepMedia: true);
      expect(store.entries.length, 1);
      expect(store.entriesForDay(older.at).length, 1);

      await store.restore(newer);
      expect(store.entries.length, 2);
      expect(store.entries.first.id, newer.id);
      expect(store.entriesForDay(newer.at).length, 2);
    });

    test('restore is idempotent', () async {
      final store = JournalStore();
      final entry = await store.add(type: JournalType.text, body: 'one');
      await store.remove(entry, keepMedia: true);
      await store.restore(entry);
      await store.restore(entry);
      expect(store.entries.length, 1);
    });

    test('a removed habit comes back with its check-in history', () async {
      final store = HabitStore();
      final habit = await store.addHabit(name: 'Read');
      await store.checkIn(habit);
      expect(store.isDone(habit, DateTime.now()), isTrue);

      final logs = await store.removeHabit(habit, keepMedia: true);
      expect(store.habits, isEmpty);
      expect(logs.length, 1);

      await store.restoreHabit(habit, logs);
      expect(store.habits.length, 1);
      expect(store.isDone(habit, DateTime.now()), isTrue);
      expect(store.streak(habit), 1);
    });

    test('undoing a check-in clears it', () async {
      final store = HabitStore();
      final habit = await store.addHabit(name: 'Walk');
      await store.checkIn(habit);
      expect(store.isDone(habit, DateTime.now()), isTrue);
      await store.uncheck(habit);
      expect(store.isDone(habit, DateTime.now()), isFalse);
    });
  });

  group('toast', () {
    Widget host(void Function(BuildContext) onReady) => MaterialApp(
      theme: NaviPalette(accents.first).toThemeData(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onReady(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    testWidgets('tapping the action skips onExpire', (tester) async {
      var undone = false;
      var expired = false;
      await tester.pumpWidget(
        host(
          (context) => showNdToast(
            context,
            'Deleted',
            actionLabel: 'Undo',
            onAction: () => undone = true,
            onExpire: () => expired = true,
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.text('Deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(undone, isTrue);
      expect(expired, isFalse);

      await tester.pump(const Duration(seconds: 6));
      expect(expired, isFalse);
    });

    testWidgets('letting it lapse fires onExpire once', (tester) async {
      var undone = false;
      var expires = 0;
      await tester.pumpWidget(
        host(
          (context) => showNdToast(
            context,
            'Deleted',
            actionLabel: 'Undo',
            onAction: () => undone = true,
            onExpire: () => expires++,
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.text('Undo'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      expect(expires, 1);
      expect(undone, isFalse);
      expect(find.text('Deleted'), findsNothing);
    });
  });

  group('habits screen', () {
    testWidgets('swiping a habit away offers undo and restores it', (
      tester,
    ) async {
      final habits = HabitStore();
      final settings = SettingsStore();
      final habit = await habits.addHabit(name: 'Stretch');
      await habits.checkIn(habit);

      tester.view.physicalSize = const Size(360, 800) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        SettingsScope(
          store: settings,
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

      await tester.drag(find.text('Stretch'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(habits.habits, isEmpty);
      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(habits.habits.length, 1);
      expect(habits.isDone(habit, DateTime.now()), isTrue);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
