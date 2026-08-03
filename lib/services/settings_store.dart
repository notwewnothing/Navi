import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/easter_eggs.dart';
import '../theme/palette.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore();

  static const _prefsKey = 'navi.settings.v1';

  SharedPreferences? _prefs;
  bool _loaded = false;

  String _displayName = 'LAIN';
  int _avatarIndex = 0;
  int _defaultReminderMinutes = 9 * 60;
  int _photoQuality = 1;
  int _autoSaveSeconds = 5;
  int _defaultSnoozeMinutes = 10;
  int _accentIndex = 0;
  bool _amoled = false;
  double _fontScale = 1.0;
  bool _scanlinesUnlocked = false;
  bool _scanlinesEnabled = false;
  bool _sfxEnabled = true;
  int _taglineIndex = 0;

  bool get isLoaded => _loaded;
  String get displayName => _displayName;
  int get avatarIndex => _avatarIndex;
  int get defaultReminderMinutes => _defaultReminderMinutes;
  int get photoQuality => _photoQuality;
  int get autoSaveSeconds => _autoSaveSeconds;
  int get defaultSnoozeMinutes => _defaultSnoozeMinutes;
  int get accentIndex => _accentIndex;
  bool get amoled => _amoled;
  double get fontScale => _fontScale;
  bool get scanlinesUnlocked => _scanlinesUnlocked;
  bool get scanlinesEnabled => _scanlinesEnabled && _scanlinesUnlocked;
  bool get sfxEnabled => _sfxEnabled;

  Accent get accent => accents[_accentIndex.clamp(0, accents.length - 1)];
  NaviPalette get palette => NaviPalette(accent, amoled: _amoled);

  int get imageQualityValue => switch (_photoQuality) {
    0 => 40,
    1 => 70,
    _ => 95,
  };

  String get tagline => lainTaglines[_taglineIndex % lainTaglines.length];

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final data = (jsonDecode(raw) as Map).cast<String, Object?>();
        _displayName = data['displayName'] as String? ?? 'LAIN';
        _avatarIndex = data['avatarIndex'] as int? ?? 0;
        _defaultReminderMinutes =
            data['defaultReminderMinutes'] as int? ?? 9 * 60;
        _photoQuality = data['photoQuality'] as int? ?? 1;
        _autoSaveSeconds = data['autoSaveSeconds'] as int? ?? 5;
        _defaultSnoozeMinutes = data['defaultSnoozeMinutes'] as int? ?? 10;
        _accentIndex = data['accentIndex'] as int? ?? 0;
        _amoled = data['amoled'] as bool? ?? false;
        _fontScale = (data['fontScale'] as num?)?.toDouble() ?? 1.0;
        _scanlinesUnlocked = data['scanlinesUnlocked'] as bool? ?? false;
        _scanlinesEnabled = data['scanlinesEnabled'] as bool? ?? false;
        _sfxEnabled = data['sfxEnabled'] as bool? ?? true;
        _taglineIndex = data['taglineIndex'] as int? ?? 0;
      }
    } catch (_) {}
    _taglineIndex = (_taglineIndex + 1) % lainTaglines.length;
    _loaded = true;
    await _save();
    notifyListeners();
  }

  Future<void> setDisplayName(String value) async {
    _displayName = value.trim().isEmpty ? 'LAIN' : value.trim();
    await _save();
    notifyListeners();
  }

  Future<void> setAvatarIndex(int value) async {
    _avatarIndex = value;
    await _save();
    notifyListeners();
  }

  Future<void> setDefaultReminderMinutes(int value) async {
    _defaultReminderMinutes = value;
    await _save();
    notifyListeners();
  }

  Future<void> setPhotoQuality(int value) async {
    _photoQuality = value.clamp(0, 2);
    await _save();
    notifyListeners();
  }

  Future<void> setAutoSaveSeconds(int value) async {
    _autoSaveSeconds = value;
    await _save();
    notifyListeners();
  }

  Future<void> setDefaultSnoozeMinutes(int value) async {
    _defaultSnoozeMinutes = value;
    await _save();
    notifyListeners();
  }

  Future<void> setAccentIndex(int value) async {
    _accentIndex = value.clamp(0, accents.length - 1);
    await _save();
    notifyListeners();
  }

  Future<void> setAmoled(bool value) async {
    _amoled = value;
    await _save();
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    _fontScale = value;
    await _save();
    notifyListeners();
  }

  Future<void> unlockScanlines() async {
    _scanlinesUnlocked = true;
    _scanlinesEnabled = true;
    await _save();
    notifyListeners();
  }

  Future<void> setScanlinesEnabled(bool value) async {
    _scanlinesEnabled = value;
    await _save();
    notifyListeners();
  }

  Future<void> setSfxEnabled(bool value) async {
    _sfxEnabled = value;
    await _save();
    notifyListeners();
  }

  Future<String> exportData(Map<String, String> sections) async {
    final docs = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${docs.path}/navi_export_$stamp.json');
    final payload = <String, Object?>{
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'NAVI v1.0',
    };
    sections.forEach((name, json) {
      try {
        payload[name] = jsonDecode(json);
      } catch (_) {
        payload[name] = json;
      }
    });
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    return file.path;
  }

  Future<void> _save() async {
    try {
      await _prefs?.setString(
        _prefsKey,
        jsonEncode({
          'displayName': _displayName,
          'avatarIndex': _avatarIndex,
          'defaultReminderMinutes': _defaultReminderMinutes,
          'photoQuality': _photoQuality,
          'autoSaveSeconds': _autoSaveSeconds,
          'defaultSnoozeMinutes': _defaultSnoozeMinutes,
          'accentIndex': _accentIndex,
          'amoled': _amoled,
          'fontScale': _fontScale,
          'scanlinesUnlocked': _scanlinesUnlocked,
          'scanlinesEnabled': _scanlinesEnabled,
          'sfxEnabled': _sfxEnabled,
          'taglineIndex': _taglineIndex,
        }),
      );
    } catch (_) {}
  }
}

class SettingsScope extends InheritedNotifier<SettingsStore> {
  const SettingsScope({
    super.key,
    required SettingsStore store,
    required super.child,
  }) : super(notifier: store);

  static SettingsStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope missing from widget tree');
    return scope!.notifier!;
  }
}
