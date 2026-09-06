import 'package:flutter_test/flutter_test.dart';
import 'package:navi/models/habit.dart' show dayKeyOf;
import 'package:navi/models/journal_entry.dart';
import 'package:navi/services/journal_store.dart';

void main() {
  Future<JournalStore> seeded() async {
    final store = JournalStore();
    await store.add(type: JournalType.text, body: 'Walked by the river');
    await store.add(type: JournalType.text, body: 'RIVER crossing again');
    await store.add(type: JournalType.photo, body: 'Sunset over the bridge');
    await store.add(type: JournalType.audio, body: 'Voice note about rivers');
    return store;
  }

  test('search matches body text case-insensitively', () async {
    final store = await seeded();
    expect(store.search(query: 'river').length, 3);
    expect(store.search(query: 'RIVER').length, 3);
    expect(store.search(query: '  river  ').length, 3);
  });

  test('empty query returns everything', () async {
    final store = await seeded();
    expect(store.search().length, 4);
    expect(store.search(query: '   ').length, 4);
  });

  test('type filter narrows without a query', () async {
    final store = await seeded();
    expect(store.search(type: JournalType.text).length, 2);
    expect(store.search(type: JournalType.photo).length, 1);
    expect(store.search(type: JournalType.video), isEmpty);
  });

  test('query and type combine', () async {
    final store = await seeded();
    expect(store.search(query: 'river', type: JournalType.text).length, 2);
    expect(store.search(query: 'river', type: JournalType.audio).length, 1);
    expect(store.search(query: 'bridge', type: JournalType.text), isEmpty);
  });

  test('results keep newest-first ordering', () async {
    final store = await seeded();
    final all = store.search();
    for (var i = 1; i < all.length; i++) {
      expect(all[i - 1].at.isAfter(all[i].at) || all[i - 1].at == all[i].at,
          isTrue);
    }
  });

  test('month counts bucket by month and ignore other years', () async {
    final store = JournalStore();
    final entry = await store.add(type: JournalType.text, body: 'now');
    final counts = store.entryCountsByMonth(entry.at.year);
    expect(counts[entry.at.month], 1);
    expect(store.entryCountsByMonth(entry.at.year - 1), isEmpty);
  });

  test('day counts key by day and only cover the asked year', () async {
    final store = JournalStore();
    final a = await store.add(type: JournalType.text, body: 'one');
    await store.add(type: JournalType.text, body: 'two');
    final counts = store.entryCountsByDay(a.at.year);
    expect(counts[dayKeyOf(a.at)], 2);
    expect(store.entryCountsByDay(a.at.year - 1), isEmpty);
  });

  test('earliestYear falls back to this year when empty', () {
    expect(JournalStore().earliestYear, DateTime.now().year);
  });
}
