import 'package:flutter/material.dart';
import '../models/alarm.dart';
import 'notification_service.dart';

abstract class AlarmScheduler {
  Future<void> syncAll(List<Alarm> alarms);
}

class AlarmStore {
  static const scheduleIdBase = 500000;

  final NotificationService scheduler;
  AlarmStore({required this.scheduler});
  void Function(Alarm)? onRing;
  Future<void> init() async {}
  void dispose() {}
  Alarm? byId(int id) => null;
  Future<void> syncScheduleAlarms(List<Alarm> desired) async {}
}

class AlarmScope extends StatelessWidget {
  final AlarmStore store;
  final Widget child;
  const AlarmScope({super.key, required this.store, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
