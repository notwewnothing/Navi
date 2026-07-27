import 'package:flutter/material.dart';

import 'models/alarm.dart';
import 'screens/alarm/alarm_ring_screen.dart';
import 'screens/splash_screen.dart';
import 'services/alarm_buzz.dart';
import 'services/alarm_store.dart';
import 'services/block_store.dart';
import 'services/habit_store.dart';
import 'services/journal_store.dart';
import 'services/notification_service.dart';
import 'services/schedule_store.dart';
import 'services/session_store.dart';
import 'services/settings_store.dart';
import 'services/sfx.dart';
import 'theme/palette.dart';
import 'widgets/glitch.dart';
import 'widgets/routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NaviApp());
}

class NaviApp extends StatefulWidget {
  const NaviApp({super.key});

  @override
  State<NaviApp> createState() => _NaviAppState();
}

class _NaviAppState extends State<NaviApp> {
  final _navigator = GlobalKey<NavigatorState>();

  late final SettingsStore _settings;
  late final NotificationService _notifications;
  late final AlarmStore _alarms;
  late final HabitStore _habits;
  late final JournalStore _journal;
  late final ScheduleStore _schedule;
  late final BlockStore _block;
  late final SessionStore _sessions;

  bool _ringOpen = false;

  @override
  void initState() {
    super.initState();
    _settings = SettingsStore();
    _notifications = NotificationService(onAlarmTap: _openRingById);
    _alarms = AlarmStore(scheduler: _notifications);
    _habits = HabitStore(notifications: _notifications);
    _journal = JournalStore();
    _schedule = ScheduleStore(alarms: _alarms);
    _block = BlockStore(schedule: _schedule);
    _sessions = SessionStore();
    _alarms.onRing = _openRing;
    _settings.addListener(_applySettings);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _settings.init();
    _applySettings();
    await Sfx.init();
    await _notifications.init();
    await _alarms.init();
    await _habits.init();
    await _journal.init();
    await _schedule.init();
    await _block.init();
    await _sessions.init();

    final launchId = await _notifications.launchedByAlarm();
    if (launchId != null) _openRingById(launchId);

    final buzzing = await AlarmBuzz.activeAlarmId();
    if (buzzing != null) _openRingById(buzzing);
  }

  void _applySettings() {
    Sfx.enabled = _settings.sfxEnabled;
  }

  void _openRingById(int id) {
    final alarm = _alarms.byId(id);
    if (alarm != null) _openRing(alarm);
  }

  void _openRing(Alarm alarm) {
    if (_ringOpen) return;
    final nav = _navigator.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openRing(alarm));
      return;
    }
    _ringOpen = true;
    nav
        .push(zoomFadeRoute(AlarmRingScreen(alarm: alarm)))
        .whenComplete(() => _ringOpen = false);
  }

  @override
  void dispose() {
    _alarms.onRing = null;
    _settings.removeListener(_applySettings);
    _alarms.dispose();
    _habits.dispose();
    _journal.dispose();
    _schedule.dispose();
    _block.dispose();
    _sessions.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      store: _settings,
      child: AlarmScope(
        store: _alarms,
        child: HabitScope(
          store: _habits,
          child: JournalScope(
            store: _journal,
            child: ScheduleScope(
              store: _schedule,
              child: BlockScope(
                store: _block,
                child: SessionScope(
                  store: _sessions,
                  child: ListenableBuilder(
                    listenable: _settings,
                    builder: (context, _) {
                      final palette = _settings.palette;
                      return PaletteScope(
                        palette: palette,
                        child: MaterialApp(
                          title: 'NAVI',
                          debugShowCheckedModeBanner: false,
                          navigatorKey: _navigator,
                          theme: palette.toThemeData(),
                          builder: (context, child) => ScanlineOverlay(
                            enabled: _settings.scanlinesEnabled,
                            child: MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                textScaler: TextScaler.linear(
                                  _settings.fontScale,
                                ),
                              ),
                              child: child ?? const SizedBox.shrink(),
                            ),
                          ),
                          home: const SplashScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
