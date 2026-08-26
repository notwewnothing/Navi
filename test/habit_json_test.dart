import 'package:flutter_test/flutter_test.dart';
import 'package:navi/models/habit.dart';

void main() {
  group('Habit JSON stays backward compatible', () {
    test('a save written before descriptions existed still loads', () {
      final habit = Habit.fromJson({
        'id': 7,
        'name': 'Walk around the block',
        'icon': 'leaf',
        'requirePhoto': false,
        'reminderMinutes': 540,
        'dayBits': 0x7f,
        'colorIndex': 3,
        'enabled': true,
        'createdAt': 1700000000000,
      });
      expect(habit.id, 7);
      expect(habit.name, 'Walk around the block');
      expect(habit.description, '');
      expect(habit.icon, 'leaf');
      expect(habit.reminderMinutes, 540);
      expect(habit.colorIndex, 3);
    });

    test('description round-trips', () {
      final original = Habit(
        id: 1,
        name: 'Learn Norwegian',
        description: 'Three lessons per day',
        createdAt: DateTime(2026, 1, 1),
      );
      final restored = Habit.fromJson(original.toJson());
      expect(restored.description, 'Three lessons per day');
      expect(restored.name, original.name);
    });

    test('an explicit null description degrades to empty', () {
      final habit = Habit.fromJson({
        'id': 2,
        'name': 'X',
        'description': null,
        'createdAt': 0,
      });
      expect(habit.description, '');
    });

    test('unknown future keys are ignored', () {
      final habit = Habit.fromJson({
        'id': 3,
        'name': 'X',
        'createdAt': 0,
        'somethingAddedLater': 42,
      });
      expect(habit.id, 3);
    });
  });

  group('habitScheduleLabel', () {
    Habit withBits(int bits, {int? reminder}) => Habit(
      id: 1,
      name: 'X',
      dayBits: bits,
      reminderMinutes: reminder,
      createdAt: DateTime(2026, 1, 1),
    );

    test('names the common patterns', () {
      expect(habitScheduleLabel(withBits(0x7f)), 'Every day');
      expect(habitScheduleLabel(withBits(0x1f)), 'Weekdays');
      expect(habitScheduleLabel(withBits(0x60)), 'Weekends');
      expect(habitScheduleLabel(withBits(0)), 'Not scheduled');
    });

    test('lists individual days', () {
      // bits 0, 2, 4 = Mon, Wed, Fri
      expect(habitScheduleLabel(withBits(0x15)), 'Mon Wed Fri');
    });

    test('appends the reminder only when asked', () {
      final h = withBits(0x7f, reminder: 9 * 60 + 5);
      expect(habitScheduleLabel(h), 'Every day · 09:05');
      expect(habitScheduleLabel(h, withReminder: false), 'Every day');
    });
  });
}
