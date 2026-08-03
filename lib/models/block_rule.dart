class BlockRule {
  BlockRule({
    required this.id,
    required this.packages,
    required this.startMin,
    required this.endMin,
    this.dayBits = 0x7f,
    this.enabled = true,
  });

  final int id;
  List<String> packages;
  int startMin;
  int endMin;
  int dayBits;
  bool enabled;

  String get timeLabel => '${_fmt(startMin)} — ${_fmt(endMin)}';

  static String _fmt(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

  String toNative() => '$startMin|$endMin|$dayBits|${packages.join(',')}';

  Map<String, Object?> toJson() => {
    'id': id,
    'packages': packages,
    'startMin': startMin,
    'endMin': endMin,
    'dayBits': dayBits,
    'enabled': enabled,
  };

  static BlockRule fromJson(Map<String, Object?> json) => BlockRule(
    id: json['id'] as int,
    packages: [...(json['packages'] as List? ?? []).cast<String>()],
    startMin: json['startMin'] as int? ?? 0,
    endMin: json['endMin'] as int? ?? 0,
    dayBits: json['dayBits'] as int? ?? 0x7f,
    enabled: json['enabled'] as bool? ?? true,
  );
}
