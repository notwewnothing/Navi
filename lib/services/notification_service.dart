class NotificationService {
  final void Function(int) onAlarmTap;
  NotificationService({required this.onAlarmTap});
  Future<void> init() async {}
  Future<int?> launchedByAlarm() async => null;
}

