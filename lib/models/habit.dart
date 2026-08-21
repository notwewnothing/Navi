class Habit {
  Habit({
    required this.id,
    required this.name,
    this.description = '',
    this.icon = 'flame',
    this.requirePhoto = false,
    this.reminderMinutes,
    this.dayBits = 0x7f,
    this.colorIndex = 0,
    this.enabled = true,
    required this.createdAt,
  });

  final int id;
  String name;
  String description;
  String icon;
  bool requirePhoto;
  int? reminderMinutes;
  int dayBits;
  int colorIndex;
  bool enabled;
  final DateTime createdAt;

  // same bitmask as alarms, bit 0 = Monday
  bool scheduledOn(DateTime day) => (dayBits >> (day.weekday - 1)) & 1 == 1;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'requirePhoto': requirePhoto,
    'reminderMinutes': reminderMinutes,
    'dayBits': dayBits,
    'colorIndex': colorIndex,
    'enabled': enabled,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  static Habit fromJson(Map<String, Object?> json) => Habit(
    id: json['id'] as int,
    name: json['name'] as String? ?? 'HABIT',
    // absent on saves written before descriptions existed, so default to empty
    description: json['description'] as String? ?? '',
    icon: json['icon'] as String? ?? 'flame',
    requirePhoto: json['requirePhoto'] as bool? ?? false,
    reminderMinutes: json['reminderMinutes'] as int?,
    dayBits: json['dayBits'] as int? ?? 0x7f,
    colorIndex: json['colorIndex'] as int? ?? 0,
    enabled: json['enabled'] as bool? ?? true,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      json['createdAt'] as int? ?? 0,
    ),
  );
}

class HabitLog {
  HabitLog({
    required this.id,
    required this.habitId,
    required this.dayKey,
    this.photoPath,
    this.note,
    required this.at,
  });

  final int id;
  final int habitId;
  final String dayKey;
  String? photoPath;
  String? note;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'id': id,
    'habitId': habitId,
    'dayKey': dayKey,
    'photoPath': photoPath,
    'note': note,
    'at': at.millisecondsSinceEpoch,
  };

  static HabitLog fromJson(Map<String, Object?> json) => HabitLog(
    id: json['id'] as int,
    habitId: json['habitId'] as int,
    dayKey: json['dayKey'] as String,
    photoPath: json['photoPath'] as String?,
    note: json['note'] as String?,
    at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int? ?? 0),
  );
}

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Human-readable schedule, e.g. "Every day · 09:00" or "Mon Wed Fri".
/// Doubles as the fallback subtitle for habits with no description.
String habitScheduleLabel(Habit habit, {bool withReminder = true}) {
  final bits = habit.dayBits & 0x7f;
  final schedule = switch (bits) {
    0x7f => 'Every day',
    0x1f => 'Weekdays',
    0x60 => 'Weekends',
    0 => 'Not scheduled',
    _ => [
      for (var i = 0; i < 7; i++)
        if ((bits >> i) & 1 == 1) _dayNames[i],
    ].join(' '),
  };
  final r = habit.reminderMinutes;
  if (!withReminder || r == null) return schedule;
  final hh = (r ~/ 60).toString().padLeft(2, '0');
  final mm = (r % 60).toString().padLeft(2, '0');
  return '$schedule · $hh:$mm';
}

// YYYY-MM-DD keys so logs sort lexicographically, don't change the format or old saves break
String dayKeyOf(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

DateTime dayFromKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
