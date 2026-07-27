import 'package:flutter/material.dart';
import 'alarm_store.dart';

class ScheduleStore {
  final AlarmStore alarms;
  ScheduleStore({required this.alarms});
  Future<void> init() async {}
  void dispose() {}
}

class ScheduleScope extends StatelessWidget {
  final ScheduleStore store;
  final Widget child;
  const ScheduleScope({super.key, required this.store, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
