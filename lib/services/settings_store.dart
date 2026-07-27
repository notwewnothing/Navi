import 'package:flutter/material.dart';
import '../theme/palette.dart';

class SettingsStore extends ChangeNotifier {
  bool sfxEnabled = true;
  bool scanlinesEnabled = false;
  double fontScale = 1.0;
  Palette get palette => Palette();
  Future<void> init() async {}
  @override
  void dispose() { super.dispose(); }
}

class SettingsScope extends StatelessWidget {
  final SettingsStore store;
  final Widget child;
  const SettingsScope({super.key, required this.store, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
