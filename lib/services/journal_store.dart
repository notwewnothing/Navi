import 'package:flutter/material.dart';

class JournalStore {
  Future<void> init() async {}
  void dispose() {}
}

class JournalScope extends StatelessWidget {
  final JournalStore store;
  final Widget child;
  const JournalScope({super.key, required this.store, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
