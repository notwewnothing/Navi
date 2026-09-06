import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi/screens/home/home_screen.dart';
import 'package:navi/services/habit_store.dart';
import 'package:navi/services/settings_store.dart';
import 'package:navi/theme/palette.dart';

/// Home is the densest screen in the app, so these guard the layout rather
/// than the logic: a RenderFlex overflow surfaces here as a real failure.
void main() {
  Widget harness(HabitStore habits, SettingsStore settings) => SettingsScope(
    store: settings,
    child: HabitScope(
      store: habits,
      child: MaterialApp(
        theme: NaviPalette(accents.first).toThemeData(),
        home: const HomeScreen(),
      ),
    ),
  );

  Future<void> pumpAt(
    WidgetTester tester,
    Widget widget, {
    Size size = const Size(360, 800),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 500));
  }

  // the greeting owns a periodic timer, so unmount before the test ends
  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('lays out with no habits', (tester) async {
    await pumpAt(tester, harness(HabitStore(), SettingsStore()));
    expect(tester.takeException(), isNull);
    expect(find.text('Add your first habit'), findsOneWidget);
    expect(
      find.textContaining('LOGGED IN', findRichText: true),
      findsOneWidget,
    );
    await teardown(tester);
  });

  testWidgets('lays out an odd number of habits', (tester) async {
    final habits = HabitStore();
    for (var i = 0; i < 3; i++) {
      await habits.addHabit(name: 'Habit $i', description: 'Does a thing');
    }
    await pumpAt(tester, harness(habits, SettingsStore()));
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  testWidgets('caps the card grid at four habits', (tester) async {
    final habits = HabitStore();
    for (var i = 0; i < 8; i++) {
      await habits.addHabit(name: 'Habit $i');
    }
    await pumpAt(tester, harness(habits, SettingsStore()));
    expect(tester.takeException(), isNull);
    // the second card row sits below the fold, so scroll it into the viewport
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(find.text('Habit 3'), findsOneWidget);
    expect(find.text('Habit 4'), findsNothing);
    await teardown(tester);
  });

  testWidgets('survives very long names and descriptions', (tester) async {
    final habits = HabitStore();
    await habits.addHabit(
      name: 'An extraordinarily long habit name that will never fit',
      description:
          'And a description that rambles on well past any reasonable '
          'width for a card that is only about a hundred and fifty '
          'density-independent pixels across',
    );
    await pumpAt(tester, harness(habits, SettingsStore()));
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  testWidgets('caps the today bars and shows the overflow count', (
    tester,
  ) async {
    final habits = HabitStore();
    for (var i = 0; i < 15; i++) {
      await habits.addHabit(name: 'Habit $i');
    }
    await pumpAt(tester, harness(habits, SettingsStore()));
    expect(tester.takeException(), isNull);
    expect(find.text('+3'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('holds up at the largest text scale on a narrow phone', (
    tester,
  ) async {
    final habits = HabitStore();
    for (var i = 0; i < 4; i++) {
      await habits.addHabit(name: 'Habit $i', description: 'Some detail here');
    }
    final settings = SettingsStore();
    await pumpAt(
      tester,
      SettingsScope(
        store: settings,
        child: HabitScope(
          store: habits,
          child: MaterialApp(
            theme: NaviPalette(accents.first).toThemeData(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.15)),
              child: child!,
            ),
            home: const HomeScreen(),
          ),
        ),
      ),
      size: const Size(320, 700),
    );
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });
}
