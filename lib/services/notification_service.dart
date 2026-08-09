import '../models/habit.dart';

class NotificationService {
  final void Function(int) onAlarmTap;
  NotificationService({required this.onAlarmTap});
  Future<void> init() async {}
  Future<int?> launchedByAlarm() async => null;
  Future<void> syncHabits(List<Habit> habits, {required bool enabled}) async {}
}

