enum JournalType { text, photo, video, audio }

extension JournalTypeLabel on JournalType {
  String get label => switch (this) {
    JournalType.text => 'Text',
    JournalType.photo => 'Photo',
    JournalType.video => 'Video',
    JournalType.audio => 'Voice note',
  };
}

class JournalEntry {
  JournalEntry({
    required this.id,
    required this.type,
    this.body = '',
    this.mediaPath,
    this.thumbPath,
    this.waveform,
    this.durationMs,
    required this.at,
  });

  final int id;
  final JournalType type;
  String body;
  String? mediaPath;
  String? thumbPath;
  List<int>? waveform;
  int? durationMs;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'body': body,
    'mediaPath': mediaPath,
    'thumbPath': thumbPath,
    'waveform': waveform,
    'durationMs': durationMs,
    'at': at.millisecondsSinceEpoch,
  };

  static JournalEntry fromJson(Map<String, Object?> json) => JournalEntry(
    id: json['id'] as int,
    type: JournalType.values.asNameMap()[json['type']] ?? JournalType.text,
    body: json['body'] as String? ?? '',
    mediaPath: json['mediaPath'] as String?,
    // absent on entries saved before video posters existed
    thumbPath: json['thumbPath'] as String?,
    // absent on voice notes saved before waveforms were kept
    waveform: (json['waveform'] as List?)?.map((v) => v as int).toList(),
    durationMs: json['durationMs'] as int?,
    at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int? ?? 0),
  );
}

/// Squeezes a recording's amplitudes into a fixed number of buckets so the
/// stored waveform is the same size whatever the clip length.
List<int>? downsampleAmplitudes(List<double> amps, {int buckets = 64}) {
  if (amps.isEmpty) return null;
  final out = <int>[];
  for (var i = 0; i < buckets; i++) {
    final start = (i * amps.length / buckets).floor();
    final end = ((i + 1) * amps.length / buckets).ceil().clamp(
      start + 1,
      amps.length,
    );
    var peak = 0.0;
    for (var j = start; j < end; j++) {
      if (amps[j] > peak) peak = amps[j];
    }
    out.add((peak * 100).round().clamp(0, 100));
  }
  return out;
}
