import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import 'media_store.dart';
import 'notification_service.dart';

class HabitStore extends ChangeNotifier {
  HabitStore({this.notifications, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _prefsKey = 'navi.habits.v1';

  final NotificationService? notifications;
  final DateTime Function() _clock;

  final List<Habit> _habits = [];
  final List<HabitLog> _logs = [];

  final Map<String, Map<int, HabitLog>> _byDay = {};

  SharedPreferences? _prefs;
  int _nextId = 1;
  bool _loaded = false;
  bool _remindersEnabled = true;

  bool get isLoaded => _loaded;
  List<Habit> get habits => List.unmodifiable(_habits);
  List<Habit> get enabledHabits =>
      List.unmodifiable(_habits.where((h) => h.enabled));
  bool get remindersEnabled => _remindersEnabled;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final data = (jsonDecode(raw) as Map).cast<String, Object?>();
        _habits
          ..clear()
          ..addAll(
            (data['habits'] as List? ?? []).map(
              (e) => Habit.fromJson((e as Map).cast<String, Object?>()),
            ),
          );
        _logs
          ..clear()
          ..addAll(
            (data['logs'] as List? ?? []).map(
              (e) => HabitLog.fromJson((e as Map).cast<String, Object?>()),
            ),
          );
        _nextId = data['nextId'] as int? ?? 1;
        _remindersEnabled = data['remindersEnabled'] as bool? ?? true;
      }
    } catch (_) {}
    _reindex();
    _loaded = true;
    await _syncReminders();
    notifyListeners();
  }

  void _reindex() {
    _byDay.clear();
    for (final log in _logs) {
      (_byDay[log.dayKey] ??= {})[log.habitId] = log;
    }
  }


  Future<Habit> addHabit({
    required String name,
    String icon = 'flame',
    bool requirePhoto = false,
    int? reminderMinutes,
    int dayBits = 0x7f,
    int colorIndex = 0,
  }) async {
    final habit = Habit(
      id: _nextId++,
      name: name,
      icon: icon,
      requirePhoto: requirePhoto,
      reminderMinutes: reminderMinutes,
      dayBits: dayBits,
      colorIndex: colorIndex,
      createdAt: _clock(),
    );
    _habits.add(habit);
    await _save();
    await _syncReminders();
    notifyListeners();
    return habit;
  }

  Future<void> updateHabit(Habit habit) async {
    await _save();
    await _syncReminders();
    notifyListeners();
  }

  Future<void> toggleHabit(Habit habit) async {
    habit.enabled = !habit.enabled;
    await _save();
    await _syncReminders();
    notifyListeners();
  }

  Future<void> removeHabit(Habit habit) async {
    _habits.remove(habit);
    final orphaned = _logs.where((l) => l.habitId == habit.id).toList();
    for (final log in orphaned) {
      await MediaStore.delete(log.photoPath);
      _logs.remove(log);
    }
    _reindex();
    await _save();
    await _syncReminders();
    notifyListeners();
  }

  Habit? habitById(int id) {
    for (final h in _habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  Future<void> setRemindersEnabled(bool value) async {
    _remindersEnabled = value;
    await _save();
    await _syncReminders();
    notifyListeners();
  }


  HabitLog? logFor(Habit habit, DateTime day) =>
      _byDay[dayKeyOf(day)]?[habit.id];

  bool isDone(Habit habit, DateTime day) => logFor(habit, day) != null;

  List<HabitLog> logsForDay(DateTime day) =>
      List.unmodifiable(_byDay[dayKeyOf(day)]?.values ?? const <HabitLog>[]);

  Future<bool> checkIn(
    Habit habit, {
    String? photoPath,
    String? note,
    DateTime? day,
  }) async {
    final when = day ?? _clock();
    final key = dayKeyOf(when);
    final existing = _byDay[key]?[habit.id];
    if (existing != null) {
      if (photoPath != null && existing.photoPath != photoPath) {
        await MediaStore.delete(existing.photoPath);
        existing.photoPath = photoPath;
      }
      if (note != null) existing.note = note;
    } else {
      final log = HabitLog(
        id: _nextId++,
        habitId: habit.id,
        dayKey: key,
        photoPath: photoPath,
        note: note,
        at: _clock(),
      );
      _logs.add(log);
      (_byDay[key] ??= {})[habit.id] = log;
    }
    await _save();
    notifyListeners();

    // true when this check-in completes every scheduled habit for the day
    final scheduled = enabledHabits.where((h) => h.scheduledOn(when));
    return scheduled.isNotEmpty && scheduled.every((h) => isDone(h, when));
  }

  Future<void> uncheck(Habit habit, {DateTime? day}) async {
    final key = dayKeyOf(day ?? _clock());
    final log = _byDay[key]?[habit.id];
    if (log == null) return;
    await MediaStore.delete(log.photoPath);
    _logs.remove(log);
    _byDay[key]?.remove(habit.id);
    await _save();
    notifyListeners();
  }


  int streak(Habit habit) {
    var day = DateTime.now();
    var count = 0;
    if (habit.scheduledOn(day) && !isDone(habit, day)) {
      day = day.subtract(const Duration(days: 1));
    }
    for (var i = 0; i < 3660; i++) {
      if (habit.scheduledOn(day)) {
        if (!isDone(habit, day)) break;
        count++;
      }
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  int completionsOn(DateTime day) => _byDay[dayKeyOf(day)]?.length ?? 0;

  int boardLevel(DateTime day) {
    final done = completionsOn(day);
    if (done == 0) return 0;
    final total = enabledHabits.where((h) => h.scheduledOn(day)).length;
    if (total == 0 || done >= total) return 4;
    return (done / total * 4).ceil().clamp(1, 4);
  }

  int todayDone() {
    final now = _clock();
    return enabledHabits
        .where((h) => h.scheduledOn(now) && isDone(h, now))
        .length;
  }

  int todayTotal() {
    final now = _clock();
    return enabledHabits.where((h) => h.scheduledOn(now)).length;
  }

  List<HabitLog> photoLogsForDay(DateTime day) => List.unmodifiable(
    (_byDay[dayKeyOf(day)]?.values ?? const <HabitLog>[])
        .where((l) => l.photoPath != null),
  );

  Future<void> _syncReminders() async {
    await notifications?.syncHabits(
      enabledHabits,
      enabled: _remindersEnabled,
    );
  }

  String exportJson() => jsonEncode({
    'habits': [for (final h in _habits) h.toJson()],
    'logs': [for (final l in _logs) l.toJson()],
  });

  Future<void> _save() async {
    try {
      await _prefs?.setString(
        _prefsKey,
        jsonEncode({
          'habits': [for (final h in _habits) h.toJson()],
          'logs': [for (final l in _logs) l.toJson()],
          'nextId': _nextId,
          'remindersEnabled': _remindersEnabled,
        }),
      );
    } catch (_) {}
  }
}

class HabitScope extends InheritedNotifier<HabitStore> {
  const HabitScope({super.key, required HabitStore store, required super.child})
    : super(notifier: store);

  static HabitStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HabitScope>();
    assert(scope != null, 'HabitScope missing from widget tree');
    return scope!.notifier!;
  }
}
