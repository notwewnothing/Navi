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
    _loaded = true;
    notifyListeners();
  }

  void _sort() => _entries.sort((a, b) => b.at.compareTo(a.at));

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
    await _save();
    notifyListeners();
  }

  List<JournalEntry> entriesForDay(DateTime day) {
    final key = dayKeyOf(day);
    return List.unmodifiable(_entries.where((e) => dayKeyOf(e.at) == key));
  }

  bool hasEntryOn(DateTime day) {
    final key = dayKeyOf(day);
    return _entries.any((e) => dayKeyOf(e.at) == key);
  }

  List<JournalEntry> photoEntriesForDay(DateTime day) {
    final key = dayKeyOf(day);
    return List.unmodifiable(
      _entries.where(
        (e) =>
            dayKeyOf(e.at) == key &&
            e.type == JournalType.photo &&
            e.mediaPath != null,
      ),
    );
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
