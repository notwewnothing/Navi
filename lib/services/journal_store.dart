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
    int? durationMs,
  }) async {
    final entry = JournalEntry(
      id: _nextId++,
      type: type,
      body: body,
      mediaPath: mediaPath,
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

  Future<void> remove(JournalEntry entry) async {
    await MediaStore.delete(entry.mediaPath);
    _entries.remove(entry);
    _reindex();
    await _save();
    notifyListeners();
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
