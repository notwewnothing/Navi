import 'package:flutter/material.dart';

class SessionStore {
  Future<void> init() async {}
  void dispose() {}
}

class SessionScope extends StatelessWidget {
  final SessionStore store;
  final Widget child;
  const SessionScope({super.key, required this.store, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
