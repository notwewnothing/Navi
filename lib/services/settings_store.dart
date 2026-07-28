import 'package:flutter/material.dart';
import '../theme/palette.dart';

class SettingsStore extends ChangeNotifier {
  bool sfxEnabled = true;
  bool scanlinesEnabled = false;
  double fontScale = 1.0;
  NaviPalette get palette => const NaviPalette(Accent(
    name: 'WIRED GREEN',
    l1: Color(0xff0e4429),
    l2: Color(0xff006d32),
    l3: Color(0xff26a641),
    l4: Color(0xff39d353),
  ));
  Future<void> init() async {}
}

class SettingsScope extends StatelessWidget {
  final SettingsStore store;
  final Widget child;
  const SettingsScope({super.key, required this.store, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
