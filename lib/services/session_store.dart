import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/day_stats.dart';
import '../models/habit.dart' show dayKeyOf;

enum SessionKind { focus, sleep }

class SessionStore extends ChangeNotifier {
  SessionStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const _prefsKey = 'navi.sessions.v1';
  static const focusGoalMin = 120;
  static const sleepGoalMin = 480;

  final DateTime Function() _clock;

  final Map<String, DayStats> _days = {};
  SharedPreferences? _prefs;
  bool _loaded = false;
  bool _blockApps = false;
  bool _strictMode = false;
  List<String> _blockedApps = [];

  bool get isLoaded => _loaded;
  bool get blockApps => _blockApps;
  bool get strictMode => _strictMode;
  List<String> get blockedApps => List.unmodifiable(_blockedApps);

  DayStats _statsFor(DateTime day) =>
      _days.putIfAbsent(dayKeyOf(day), DayStats.new);

  DayStats get _today => _statsFor(_clock());

  DayStats statsOn(DateTime day) => _days[dayKeyOf(day)] ?? DayStats();

  int get focusedTodayMin => _today.focusMin;
  int get distractedTodayMin => _today.distractedMin;

  // sleep is measured overnight, empty today means check yesterday
  int get sleepLastMin {
    final today = _today.sleepMin;
    if (today > 0) return today;
    final yesterday =
        _days[dayKeyOf(_clock().subtract(const Duration(days: 1)))];
    return yesterday?.sleepMin ?? 0;
  }

  int get distractedPct {
    final total = focusedTodayMin + distractedTodayMin;
    if (total == 0) return 0;
    return (distractedTodayMin / total * 100).round();
  }

  // if today has no focus yet, count from yesterday so an early start doesn't reset the streak
  int get focusStreak {
    var day = _clock();
    var count = 0;
    if ((_days[dayKeyOf(day)]?.focusMin ?? 0) == 0) {
      day = day.subtract(const Duration(days: 1));
    }
    for (var i = 0; i < 3660; i++) {
      if ((_days[dayKeyOf(day)]?.focusMin ?? 0) == 0) break;
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final data = (jsonDecode(raw) as Map).cast<String, Object?>();
        _days.clear();
        ((data['days'] as Map? ?? {})).forEach((key, value) {
          _days[key as String] = DayStats.fromJson(
            (value as Map).cast<String, Object?>(),
          );
        });
        _blockApps = data['blockApps'] as bool? ?? false;
        _strictMode = data['strictMode'] as bool? ?? false;
        _blockedApps = [...(data['blockedApps'] as List? ?? []).cast<String>()];
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> recordSession(
    SessionKind kind, {
    required int activeSeconds,
    int distractedSeconds = 0,
  }) async {
    final active = (activeSeconds / 60).round();
    final distracted = (distractedSeconds / 60).round();
    if (active == 0 && distracted == 0) return;
    final stats = _today;
    if (kind == SessionKind.focus) {
      stats.focusMin += active;
      stats.distractedMin += distracted;
    } else {
      stats.sleepMin += active;
    }
    await _save();
    notifyListeners();
  }

  Future<void> setBlockApps(bool value) async {
    _blockApps = value;
    await _save();
    notifyListeners();
  }

  Future<void> setStrictMode(bool value) async {
    _strictMode = value;
    await _save();
    notifyListeners();
  }

  Future<void> setBlockedApps(List<String> apps) async {
    _blockedApps = [...apps];
    await _save();
    notifyListeners();
  }

  String exportJson() => jsonEncode({
    'days': _days.map((key, value) => MapEntry(key, value.toJson())),
  });

  Future<void> _save() async {
    try {
      await _prefs?.setString(
        _prefsKey,
        jsonEncode({
          'days': _days.map((key, value) => MapEntry(key, value.toJson())),
          'blockApps': _blockApps,
          'strictMode': _strictMode,
          'blockedApps': _blockedApps,
        }),
      );
    } catch (_) {}
  }
}

class SessionScope extends InheritedNotifier<SessionStore> {
  const SessionScope({
    super.key,
    required SessionStore store,
    required super.child,
  }) : super(notifier: store);

  static SessionStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope missing from widget tree');
    return scope!.notifier!;
  }
}
