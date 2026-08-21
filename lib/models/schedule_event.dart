enum EventType { focus, sleep, alarm, appBlock, custom }

extension EventTypeLabel on EventType {
  String get label => switch (this) {
    EventType.focus => 'Focus',
    EventType.sleep => 'Sleep',
    EventType.alarm => 'Alarm',
    EventType.appBlock => 'App block',
    EventType.custom => 'Custom',
  };
}

enum EventRepeat { never, daily, weekdays, custom }

extension EventRepeatLabel on EventRepeat {
  String get label => switch (this) {
    EventRepeat.never => 'Once',
    EventRepeat.daily => 'Daily',
    EventRepeat.weekdays => 'Weekdays',
    EventRepeat.custom => 'Custom',
  };
}

class ScheduleEvent {
  ScheduleEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.startMin,
    required this.endMin,
    this.repeat = EventRepeat.never,
    this.dayBits = 0,
    required this.anchorDay,
    this.packages = const [],
    this.snoozeMinutes = 10,
    this.enabled = true,
  });

  final int id;
  String title;
  EventType type;
  int startMin;
  int endMin;
  EventRepeat repeat;
  int dayBits;
  DateTime anchorDay;
  List<String> packages;
  int snoozeMinutes;
  bool enabled;

  bool occursOn(DateTime day) {
    if (!enabled) return false;
    switch (repeat) {
      case EventRepeat.never:
        return day.year == anchorDay.year &&
            day.month == anchorDay.month &&
            day.day == anchorDay.day;
      case EventRepeat.daily:
        return !day.isBefore(_dayOnly(anchorDay));
      case EventRepeat.weekdays:
        return !day.isBefore(_dayOnly(anchorDay)) &&
            day.weekday <= DateTime.friday;
      case EventRepeat.custom:
        return !day.isBefore(_dayOnly(anchorDay)) &&
            (dayBits >> (day.weekday - 1)) & 1 == 1;
    }
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // mask implied by the repeat type daily = all 7 bits, weekdays = Mon-Fri only
  int get effectiveDayBits => switch (repeat) {
    EventRepeat.never => 1 << (anchorDay.weekday - 1),
    EventRepeat.daily => 0x7f,
    EventRepeat.weekdays => 0x1f,
    EventRepeat.custom => dayBits,
  };

  String get timeLabel => '${_fmt(startMin)} — ${_fmt(endMin)}';

  static String _fmt(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'type': type.name,
    'startMin': startMin,
    'endMin': endMin,
    'repeat': repeat.name,
    'dayBits': dayBits,
    'anchorDay': anchorDay.millisecondsSinceEpoch,
    'packages': packages,
    'snoozeMinutes': snoozeMinutes,
    'enabled': enabled,
  };

  static ScheduleEvent fromJson(Map<String, Object?> json) => ScheduleEvent(
    id: json['id'] as int,
    title: json['title'] as String? ?? 'EVENT',
    type: EventType.values.asNameMap()[json['type']] ?? EventType.custom,
    startMin: json['startMin'] as int? ?? 0,
    endMin: json['endMin'] as int? ?? 0,
    repeat: EventRepeat.values.asNameMap()[json['repeat']] ?? EventRepeat.never,
    dayBits: json['dayBits'] as int? ?? 0,
    anchorDay: DateTime.fromMillisecondsSinceEpoch(
      json['anchorDay'] as int? ?? 0,
    ),
    packages: [...(json['packages'] as List? ?? []).cast<String>()],
    snoozeMinutes: json['snoozeMinutes'] as int? ?? 10,
    enabled: json['enabled'] as bool? ?? true,
  );
}
