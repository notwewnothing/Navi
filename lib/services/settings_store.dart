import 'package:flutter/material.dart';
import '../theme/palette.dart';

class SettingsStore extends ChangeNotifier {
  bool sfxEnabled = true;
  bool scanlinesEnabled = false;
  double fontScale = 1.0;
  int sessionCount = 0;

  NaviPalette get palette => const NaviPalette(Accent(
    name: 'WIRED GREEN',
    l1: Color(0xff0e4429),
    l2: Color(0xff006d32),
    l3: Color(0xff26a641),
    l4: Color(0xff39d353),
  ));

  Future<void> init() async {
    sessionCount++;
    notifyListeners();
  }

  void setSfxEnabled(bool v) {
    sfxEnabled = v;
    notifyListeners();
  }

  void setFontScale(double v) {
    fontScale = v;
    notifyListeners();
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
