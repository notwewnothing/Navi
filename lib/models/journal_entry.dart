enum JournalType { text, photo, video, audio }

extension JournalTypeLabel on JournalType {
  String get label => switch (this) {
    JournalType.text => 'TEXT',
    JournalType.photo => 'PHOTO',
    JournalType.video => 'VIDEO',
    JournalType.audio => 'AUDIO',
  };
}

class JournalEntry {
  JournalEntry({
    required this.id,
    required this.type,
    this.body = '',
    this.mediaPath,
    this.durationMs,
    required this.at,
  });

  final int id;
  final JournalType type;
  String body;
  String? mediaPath;
  int? durationMs;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'body': body,
    'mediaPath': mediaPath,
    'durationMs': durationMs,
    'at': at.millisecondsSinceEpoch,
  };

  static JournalEntry fromJson(Map<String, Object?> json) => JournalEntry(
    id: json['id'] as int,
    type: JournalType.values.asNameMap()[json['type']] ?? JournalType.text,
    body: json['body'] as String? ?? '',
    mediaPath: json['mediaPath'] as String?,
    durationMs: json['durationMs'] as int?,
    at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int? ?? 0),
  );
}
