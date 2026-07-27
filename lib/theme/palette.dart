import 'package:flutter/material.dart';

class Palette {
  ThemeData toThemeData() => ThemeData.dark();
}

class PaletteScope extends StatelessWidget {
  final Palette palette;
  final Widget child;
  const PaletteScope({super.key, required this.palette, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
