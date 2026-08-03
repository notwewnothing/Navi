class DayStats {
  DayStats({this.focusMin = 0, this.distractedMin = 0, this.sleepMin = 0});

  int focusMin;
  int distractedMin;
  int sleepMin;

  Map<String, Object?> toJson() => {
    'focusMin': focusMin,
    'distractedMin': distractedMin,
    'sleepMin': sleepMin,
  };

  static DayStats fromJson(Map<String, Object?> json) => DayStats(
    focusMin: json['focusMin'] as int? ?? 0,
    distractedMin: json['distractedMin'] as int? ?? 0,
    sleepMin: json['sleepMin'] as int? ?? 0,
  );
}

String minutesLabel(int minutes) {
  if (minutes <= 0) return '0M';
  if (minutes < 60) return '${minutes}M';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}H';
  return '${h}H ${m.toString().padLeft(2, '0')}M';
}
