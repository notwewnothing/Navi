
class Habit {
  Habit({
    required this.id,
    required this.name,
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
  String icon;
  bool requirePhoto;
  int? reminderMinutes;
  int dayBits;
  int colorIndex;
  bool enabled;
  final DateTime createdAt;

  bool scheduledOn(DateTime day) => (dayBits >> (day.weekday - 1)) & 1 == 1;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
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
