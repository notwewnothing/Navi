import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm.dart';
import '../models/schedule_event.dart';
import 'alarm_store.dart';

class ScheduleStore extends ChangeNotifier {
  ScheduleStore({this.alarms, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _prefsKey = 'navi.schedule.v1';

  final AlarmStore? alarms;
  final DateTime Function() _clock;

  final List<ScheduleEvent> _events = [];
  SharedPreferences? _prefs;
  int _nextId = 1;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<ScheduleEvent> get events => List.unmodifiable(_events);

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final data = (jsonDecode(raw) as Map).cast<String, Object?>();
        _events
          ..clear()
          ..addAll(
            (data['events'] as List? ?? []).map(
              (e) =>
                  ScheduleEvent.fromJson((e as Map).cast<String, Object?>()),
            ),
          );
        _nextId = data['nextId'] as int? ?? 1;
      }
    } catch (_) {}
    _loaded = true;
    await _syncAlarms();
    notifyListeners();
  }

  Future<ScheduleEvent> add({
    required String title,
    required EventType type,
    required int startMin,
    required int endMin,
    EventRepeat repeat = EventRepeat.never,
    int dayBits = 0,
    DateTime? anchorDay,
    List<String> packages = const [],
    int snoozeMinutes = 10,
  }) async {
    final event = ScheduleEvent(
      id: _nextId++,
      title: title,
      type: type,
      startMin: startMin,
      endMin: endMin,
      repeat: repeat,
      dayBits: dayBits,
      anchorDay: anchorDay ?? _clock(),
      packages: packages,
      snoozeMinutes: snoozeMinutes,
    );
    _events.add(event);
    await _save();
    await _syncAlarms();
    notifyListeners();
    return event;
  }

  Future<void> update(ScheduleEvent event) async {
    await _save();
    await _syncAlarms();
    notifyListeners();
  }

  Future<void> toggle(ScheduleEvent event) async {
    event.enabled = !event.enabled;
    await _save();
    await _syncAlarms();
    notifyListeners();
  }

  Future<void> remove(ScheduleEvent event) async {
    _events.remove(event);
    await _save();
    await _syncAlarms();
    notifyListeners();
  }

  ScheduleEvent? byId(int id) {
    for (final e in _events) {
      if (e.id == id) return e;
    }
    return null;
  }

  List<ScheduleEvent> eventsForDay(DateTime day) {
    final result = _events.where((e) => e.occursOn(day)).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    return List.unmodifiable(result);
  }

  Set<EventType> typesOn(DateTime day) =>
      {for (final e in _events.where((e) => e.occursOn(day))) e.type};

  List<ScheduleEvent> get sleepEvents => List.unmodifiable(
    _events.where((e) => e.enabled && e.type == EventType.sleep),
  );

  List<ScheduleEvent> get appBlockEvents => List.unmodifiable(
    _events.where(
      (e) => e.enabled && e.type == EventType.appBlock && e.packages.isNotEmpty,
    ),
  );

  Future<void> _syncAlarms() async {
    final store = alarms;
    if (store == null) return;
    final desired = <Alarm>[
      for (final e in _events.where((e) => e.type == EventType.alarm))
        Alarm(
          id: AlarmStore.scheduleIdBase + e.id,
          hour: e.startMin ~/ 60,
          minute: e.startMin % 60,
          label: e.title.toUpperCase(),
          snoozeMinutes: e.snoozeMinutes,
          repeat: switch (e.repeat) {
            EventRepeat.never => AlarmRepeat.once,
            EventRepeat.daily => AlarmRepeat.daily,
            EventRepeat.weekdays => AlarmRepeat.weekdays,
            EventRepeat.custom => AlarmRepeat.custom,
          },
          dayBits: e.dayBits,
          enabled: e.enabled,
          fromSchedule: true,
        ),
    ];
    await store.syncScheduleAlarms(desired);
  }

  String exportJson() =>
      jsonEncode({'events': [for (final e in _events) e.toJson()]});

  Future<void> _save() async {
    try {
      await _prefs?.setString(
        _prefsKey,
        jsonEncode({
          'events': [for (final e in _events) e.toJson()],
          'nextId': _nextId,
        }),
      );
    } catch (_) {}
  }
}

class ScheduleScope extends InheritedNotifier<ScheduleStore> {
  const ScheduleScope({
    super.key,
    required ScheduleStore store,
    required super.child,
  }) : super(notifier: store);

  static ScheduleStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ScheduleScope>();
    assert(scope != null, 'ScheduleScope missing from widget tree');
    return scope!.notifier!;
  }
}
