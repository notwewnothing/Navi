import 'package:flutter/material.dart';

class ScanlineOverlay extends StatelessWidget {
  final bool enabled;
  final Widget child;
  const ScanlineOverlay({super.key, required this.enabled, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

