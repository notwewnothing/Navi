import 'package:flutter_test/flutter_test.dart';
import 'package:navi/models/journal_entry.dart';

void main() {
  group('downsampleAmplitudes', () {
    test('always returns the requested bucket count', () {
      for (final n in [1, 5, 63, 64, 65, 500]) {
        final amps = List<double>.generate(n, (i) => (i % 10) / 10);
        expect(downsampleAmplitudes(amps)!.length, 64, reason: 'n=$n');
      }
    });

    test('empty input yields null', () {
      expect(downsampleAmplitudes(const []), isNull);
    });

    test('values are clamped to 0-100', () {
      final out = downsampleAmplitudes([0.0, 1.0, 0.5, 2.0, -1.0])!;
      expect(out.every((v) => v >= 0 && v <= 100), isTrue);
    });

    test('keeps peaks rather than averaging them away', () {
      // one loud sample in an otherwise silent clip must survive
      final amps = List<double>.filled(200, 0.0)..[100] = 1.0;
      final out = downsampleAmplitudes(amps)!;
      expect(out.reduce((a, b) => a > b ? a : b), 100);
    });

    test('a flat recording maps to a flat waveform', () {
      final out = downsampleAmplitudes(List<double>.filled(100, 0.4))!;
      expect(out.toSet().length, 1);
      expect(out.first, 40);
    });
  });

  test('voice notes saved before waveforms still load', () {
    final entry = JournalEntry.fromJson({
      'id': 2,
      'type': 'audio',
      'body': '',
      'mediaPath': 'media/2026-09/a.m4a',
      'durationMs': 4000,
      'at': 1700000000000,
    });
    expect(entry.waveform, isNull);
  });

  test('waveform round-trips through json', () {
    final entry = JournalEntry(
      id: 1,
      type: JournalType.audio,
      waveform: const [0, 50, 100, 25],
      at: DateTime(2026, 1, 1),
    );
    expect(JournalEntry.fromJson(entry.toJson()).waveform, [0, 50, 100, 25]);
  });
}
