import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/block_rule.dart';
import '../models/schedule_event.dart';
import 'app_blocker.dart';
import 'schedule_store.dart';

class BlockStore extends ChangeNotifier {
  BlockStore({this.schedule});

  static const _prefsKey = 'navi.blocker.v1';

  final ScheduleStore? schedule;

  final List<BlockRule> _rules = [];
  SharedPreferences? _prefs;
  int _nextId = 1;
  bool _loaded = false;
  bool _sleepBlockEnabled = false;
  List<String> _sleepPackages = [];

  bool get isLoaded => _loaded;
  List<BlockRule> get rules => List.unmodifiable(_rules);
  bool get sleepBlockEnabled => _sleepBlockEnabled;
  List<String> get sleepPackages => List.unmodifiable(_sleepPackages);

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final data = (jsonDecode(raw) as Map).cast<String, Object?>();
        _rules
          ..clear()
          ..addAll(
            (data['rules'] as List? ?? []).map(
              (e) => BlockRule.fromJson((e as Map).cast<String, Object?>()),
            ),
          );
        _nextId = data['nextId'] as int? ?? 1;
        _sleepBlockEnabled = data['sleepBlockEnabled'] as bool? ?? false;
        _sleepPackages = [
          ...(data['sleepPackages'] as List? ?? []).cast<String>(),
        ];
      }
    } catch (_) {}
    _loaded = true;
    schedule?.addListener(_onScheduleChanged);
    await pushToNative();
    notifyListeners();
  }

  void _onScheduleChanged() {
    pushToNative();
  }

  Future<BlockRule> addRule({
    required List<String> packages,
    required int startMin,
    required int endMin,
    int dayBits = 0x7f,
  }) async {
    final rule = BlockRule(
      id: _nextId++,
      packages: packages,
      startMin: startMin,
      endMin: endMin,
      dayBits: dayBits,
    );
    _rules.add(rule);
    await _save();
    await pushToNative();
    notifyListeners();
    return rule;
  }

  Future<void> updateRule(BlockRule rule) async {
    await _save();
    await pushToNative();
    notifyListeners();
  }

  Future<void> toggleRule(BlockRule rule) async {
    rule.enabled = !rule.enabled;
    await _save();
    await pushToNative();
    notifyListeners();
  }

  Future<void> removeRule(BlockRule rule) async {
    _rules.remove(rule);
    await _save();
    await pushToNative();
    notifyListeners();
  }

  Future<void> setSleepBlock({bool? enabled, List<String>? packages}) async {
    if (enabled != null) _sleepBlockEnabled = enabled;
    if (packages != null) _sleepPackages = [...packages];
    await _save();
    await pushToNative();
    notifyListeners();
  }

  // rules, schedule app-block events and sleep blocks all flatten into one native rule list
  Future<void> pushToNative() async {
    final encoded = <String>[
      for (final rule in _rules.where(
        (r) => r.enabled && r.packages.isNotEmpty,
      ))
        rule.toNative(),
      for (final event in schedule?.appBlockEvents ?? const <ScheduleEvent>[])
        BlockRule(
          id: 0,
          packages: event.packages,
          startMin: event.startMin,
          endMin: event.endMin,
          dayBits: event.effectiveDayBits,
        ).toNative(),
      if (_sleepBlockEnabled && _sleepPackages.isNotEmpty)
        for (final sleep in schedule?.sleepEvents ?? const <ScheduleEvent>[])
          BlockRule(
            id: 0,
            packages: _sleepPackages,
            startMin: sleep.startMin,
            endMin: sleep.endMin,
            dayBits: sleep.effectiveDayBits,
          ).toNative(),
    ];
    await AppBlocker.setBlockRules(encoded);
  }

  String exportJson() => jsonEncode({
    'rules': [for (final r in _rules) r.toJson()],
    'sleepBlockEnabled': _sleepBlockEnabled,
    'sleepPackages': _sleepPackages,
  });

  Future<void> _save() async {
    try {
      await _prefs?.setString(
        _prefsKey,
        jsonEncode({
          'rules': [for (final r in _rules) r.toJson()],
          'nextId': _nextId,
          'sleepBlockEnabled': _sleepBlockEnabled,
          'sleepPackages': _sleepPackages,
        }),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    schedule?.removeListener(_onScheduleChanged);
    super.dispose();
  }
}

class BlockScope extends InheritedNotifier<BlockStore> {
  const BlockScope({super.key, required BlockStore store, required super.child})
    : super(notifier: store);

  static BlockStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BlockScope>();
    assert(scope != null, 'BlockScope missing from widget tree');
    return scope!.notifier!;
  }
}
