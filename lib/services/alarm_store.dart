import 'package:flutter/material.dart';
import '../models/alarm.dart';
import 'notification_service.dart';

class AlarmStore {
  final NotificationService scheduler;
  AlarmStore({required this.scheduler});
  void Function(Alarm)? onRing;
  Future<void> init() async {}
  void dispose() {}
  Alarm? byId(int id) => null;
}

class AlarmScope extends StatelessWidget {
  final AlarmStore store;
  final Widget child;
  const AlarmScope({super.key, required this.store, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
