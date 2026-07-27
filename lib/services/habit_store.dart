import 'package:flutter/material.dart';
import 'notification_service.dart';

class HabitStore {
  final NotificationService notifications;
  HabitStore({required this.notifications});
  Future<void> init() async {}
  void dispose() {}
}

class HabitScope extends StatelessWidget {
  final HabitStore store;
  final Widget child;
  const HabitScope({super.key, required this.store, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
