import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart' show dayKeyOf;
import '../models/journal_entry.dart';
import 'media_store.dart';

class JournalStore extends ChangeNotifier {
  JournalStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const _prefsKey = 'navi.journal.v1';

  final DateTime Function() _clock;

  final List<JournalEntry> _entries = [];
  final Map<String, List<JournalEntry>> _byDay = {};
  SharedPreferences? _prefs;
  int _nextId = 1;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  List<JournalEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final data = (jsonDecode(raw) as Map).cast<String, Object?>();
        _entries
          ..clear()
          ..addAll(
            (data['entries'] as List? ?? []).map(
              (e) => JournalEntry.fromJson((e as Map).cast<String, Object?>()),
            ),
          );
        _nextId = data['nextId'] as int? ?? 1;
      }
    } catch (_) {}
    _sort();
    _reindex();
    _loaded = true;
    notifyListeners();
    unawaited(backfillVideoThumbs());
  }

  void _sort() => _entries.sort((a, b) => b.at.compareTo(a.at));

  void _reindex() {
    _byDay.clear();
    for (final entry in _entries) {
      (_byDay[dayKeyOf(entry.at)] ??= []).add(entry);
    }
  }

  Future<JournalEntry> add({
    required JournalType type,
    String body = '',
    String? mediaPath,
    String? thumbPath,
    List<int>? waveform,
    int? durationMs,
  }) async {
    final entry = JournalEntry(
      id: _nextId++,
      type: type,
      body: body,
      mediaPath: mediaPath,
      thumbPath: thumbPath,
      waveform: waveform,
      durationMs: durationMs,
      at: _clock(),
    );
    _entries.insert(0, entry);
    _sort();
    _reindex();
    await _save();
    notifyListeners();
    return entry;
  }

  Future<void> update(JournalEntry entry) async {
    await _save();
    notifyListeners();
  }

  Future<void> remove(JournalEntry entry, {bool keepMedia = false}) async {
    if (!keepMedia) {
      await MediaStore.delete(entry.mediaPath);
      await MediaStore.delete(entry.thumbPath);
    }
    _entries.remove(entry);
    _reindex();
    await _save();
    notifyListeners();
  }

  Future<void> restore(JournalEntry entry) async {
    if (_entries.any((e) => e.id == entry.id)) return;
    _entries.add(entry);
    if (entry.id >= _nextId) _nextId = entry.id + 1;
    _sort();
    _reindex();
    await _save();
    notifyListeners();
  }

  Future<void> purgeMedia(JournalEntry entry) async {
    await MediaStore.delete(entry.mediaPath);
    await MediaStore.delete(entry.thumbPath);
  }

  List<JournalEntry> entriesForDay(DateTime day) =>
      List.unmodifiable(_byDay[dayKeyOf(day)] ?? const <JournalEntry>[]);

  bool hasEntryOn(DateTime day) => _byDay.containsKey(dayKeyOf(day));

  List<JournalEntry> photoEntriesForDay(DateTime day) => List.unmodifiable(
    (_byDay[dayKeyOf(day)] ?? const <JournalEntry>[]).where(
      (e) => e.type == JournalType.photo && e.mediaPath != null,
    ),
  );

  Future<void> importJson(String raw) async {
    final data = (jsonDecode(raw) as Map).cast<String, Object?>();
    _entries
      ..clear()
      ..addAll(
        (data['entries'] as List? ?? []).map(
          (e) => JournalEntry.fromJson((e as Map).cast<String, Object?>()),
        ),
      );
    _nextId = 1;
    for (final e in _entries) {
      if (e.id >= _nextId) _nextId = e.id + 1;
    }
    _sort();
    _reindex();
    await _save();
    notifyListeners();
  }

  /// Videos imported before posters existed have no thumb, so make one the
  /// first time we load them.
  Future<void> backfillVideoThumbs() async {
    var changed = false;
    for (final entry in _entries) {
      if (entry.type != JournalType.video) continue;
      if (entry.thumbPath != null || entry.mediaPath == null) continue;
      final made = await MediaStore.makeVideoThumbnail(entry.mediaPath!);
      if (made == null) continue;
      entry.thumbPath = made;
      changed = true;
    }
    if (!changed) return;
    await _save();
    notifyListeners();
  }

  List<String> videoPostersForDay(DateTime day) => List.unmodifiable([
    for (final e in _byDay[dayKeyOf(day)] ?? const <JournalEntry>[])
      if (e.type == JournalType.video && e.thumbPath != null) e.thumbPath!,
  ]);

  List<JournalEntry> search({String query = '', JournalType? type}) {
    final q = query.trim().toLowerCase();
    return List.unmodifiable(
      _entries.where((e) {
        if (type != null && e.type != type) return false;
        if (q.isEmpty) return true;
        return e.body.toLowerCase().contains(q);
      }),
    );
  }

  Map<String, int> entryCountsByDay(int year) {
    final counts = <String, int>{};
    for (final key in _byDay.keys) {
      if (!key.startsWith('$year-')) continue;
      counts[key] = _byDay[key]!.length;
    }
    return counts;
  }

  Map<int, int> entryCountsByMonth(int year) {
    final counts = <int, int>{};
    for (final entry in _entries) {
      if (entry.at.year != year) continue;
      counts[entry.at.month] = (counts[entry.at.month] ?? 0) + 1;
    }
    return counts;
  }

  int get earliestYear => _entries.isEmpty
      ? DateTime.now().year
      : _entries.map((e) => e.at.year).reduce((a, b) => a < b ? a : b);

  String exportJson() => jsonEncode({
    'entries': [for (final e in _entries) e.toJson()],
  });

  Future<void> _save() async {
    try {
      await _prefs?.setString(
        _prefsKey,
        jsonEncode({
          'entries': [for (final e in _entries) e.toJson()],
          'nextId': _nextId,
        }),
      );
    } catch (_) {}
  }
}

class JournalScope extends InheritedNotifier<JournalStore> {
  const JournalScope({
    super.key,
    required JournalStore store,
    required super.child,
  }) : super(notifier: store);

  static JournalStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<JournalScope>();
    assert(scope != null, 'JournalScope missing from widget tree');
    return scope!.notifier!;
  }
}
