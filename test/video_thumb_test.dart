import 'package:flutter_test/flutter_test.dart';
import 'package:navi/models/journal_entry.dart';
import 'package:navi/services/journal_store.dart';

void main() {
  test('entries saved before posters existed still load', () {
    final entry = JournalEntry.fromJson({
      'id': 3,
      'type': 'video',
      'body': 'old clip',
      'mediaPath': 'media/2026-01/1.mp4',
      'durationMs': 4200,
      'at': 1700000000000,
    });
    expect(entry.thumbPath, isNull);
    expect(entry.mediaPath, 'media/2026-01/1.mp4');
  });

  test('thumbPath round-trips through json', () {
    final entry = JournalEntry(
      id: 1,
      type: JournalType.video,
      mediaPath: 'media/2026-01/1.mp4',
      thumbPath: 'media/2026-01/1.jpg',
      at: DateTime(2026, 1, 2),
    );
    final back = JournalEntry.fromJson(entry.toJson());
    expect(back.thumbPath, 'media/2026-01/1.jpg');
  });

  test('archive posters only include videos that have one', () async {
    final store = JournalStore();
    final withThumb = await store.add(
      type: JournalType.video,
      mediaPath: 'media/a.mp4',
      thumbPath: 'media/a.jpg',
    );
    await store.add(type: JournalType.video, mediaPath: 'media/b.mp4');
    await store.add(type: JournalType.photo, mediaPath: 'media/c.jpg');

    final posters = store.videoPostersForDay(withThumb.at);
    expect(posters, ['media/a.jpg']);
  });

  test('a day with no videos yields no posters', () {
    expect(JournalStore().videoPostersForDay(DateTime(2026, 5, 5)), isEmpty);
  });
}
