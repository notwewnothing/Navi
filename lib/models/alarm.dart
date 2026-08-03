enum AlarmRepeat { once, daily, weekdays, custom }

extension AlarmRepeatLabel on AlarmRepeat {
  String get label => switch (this) {
    AlarmRepeat.once => 'ONCE',
    AlarmRepeat.daily => 'DAILY',
    AlarmRepeat.weekdays => 'WEEKDAYS',
    AlarmRepeat.custom => 'CUSTOM',
  };
}

class Alarm {
  Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.label = 'WAKE UP',
    this.snoozeMinutes = 10,
    this.repeat = AlarmRepeat.once,
    this.dayBits = 0,
    this.enabled = true,
    this.snoozedUntil,
    this.fromSchedule = false,
  });

  final int id;
  int hour;
  int minute;
  String label;
  int snoozeMinutes;
  AlarmRepeat repeat;


  int dayBits;
  bool enabled;
  DateTime? snoozedUntil;


  bool fromSchedule;

  DateTime? nextFire(DateTime from) {
    if (!enabled) return null;
    if (repeat == AlarmRepeat.custom && dayBits == 0) return null;

    final snooze = snoozedUntil;
    if (snooze != null && snooze.isAfter(from)) return snooze;

    var candidate = DateTime(from.year, from.month, from.day, hour, minute);
    var guard = 0;
    while (!candidate.isAfter(from) || !_matchesRepeat(candidate)) {
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day + 1,
        hour,
        minute,
      );
      if (++guard > 370) return null;
    }
    return candidate;
  }

  bool _matchesRepeat(DateTime day) => switch (repeat) {
    AlarmRepeat.weekdays => day.weekday <= DateTime.friday,
    AlarmRepeat.custom => (dayBits >> (day.weekday - 1)) & 1 == 1,
    _ => true,
  };

  String get timeLabel24 =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'label': label,
    'snoozeMinutes': snoozeMinutes,
    'repeat': repeat.name,
    'dayBits': dayBits,
    'enabled': enabled,
    'snoozedUntil': snoozedUntil?.millisecondsSinceEpoch,
    'fromSchedule': fromSchedule,
  };

  static Alarm fromJson(Map<String, Object?> json) {
    final snoozeMs = json['snoozedUntil'] as int?;
    return Alarm(
      id: json['id'] as int,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      label: json['label'] as String? ?? 'WAKE UP',
      snoozeMinutes: json['snoozeMinutes'] as int? ?? 10,
      repeat:
          AlarmRepeat.values.asNameMap()[json['repeat']] ?? AlarmRepeat.once,
      dayBits: json['dayBits'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      snoozedUntil: snoozeMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(snoozeMs),
      fromSchedule: json['fromSchedule'] as bool? ?? false,
    );
  }
}
