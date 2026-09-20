# NAVI

*An open source, feature rich journaling / app tracking app with some extra cool features.*

## Features

- **Habit Tracking** — You can check-in and create habits (obviouslyy)
- **Journal** — You can create new text/photo/video/audio entries either taken from the app or uploaded
- **Schedule** — You can add events with different types (Focus/sleep/Alarm/App block) that repeat on user specified days
- **Export/import** — You can export your tracked data and journal entries anytime to a zip file (it's basically a json file and a media folder with all photos / videos / audio) making it portable and recoverable even if the app vanishes
- **Screen Time** — The app provides detailed stats for your daily screentime alongside screentime of the previous days
- **Alarm** — (this feature was partialy stolen from a previous app i worked on :D) it's an alarm , it alarms IG
- **App blocking** — You can create app blocking rules in the Schedule screen allowing you to block specific apps at specific times, and also block apps during sleep "event" time

## Screenshots

![NAVI screenshots](docs/screenshots.png)

## Install

Grab the latest APK from [Releases](https://github.com/notwewnothing/Navi/releases/tag/v1.0.1).

## Packages

| Package | Purpose |
|---------|---------|
| `shared_preferences` | JSON persistence |
| `flutter_local_notifications` | Alarm + reminder scheduling |
| `timezone` / `flutter_timezone` | TZ-aware scheduling |
| `app_usage` | Screen time (Android) |
| `android_intent_plus` | Launch system settings |
| `vibration` | Haptics on alarms and check-ins |
| `image_picker` | Photo / video capture and picking |
| `record` | Voice note recording |
| `audioplayers` | Voice note + alarm playback |
| `video_player` | Journal video playback |
| `path_provider` | Media directory resolution |
| `archive` | Backup zip read / write |
| `file_picker` | Choosing a backup file to import |

## Structure

```
lib/
├── main.dart
├── models/
│   ├── alarm.dart             # Alarm, AlarmRepeat, nextFire()
│   ├── block_rule.dart        # App blocking rule (packages + time window)
│   ├── day_stats.dart         # Per-day usage + distraction totals
│   ├── habit.dart             # Habit, HabitLog, streaks, rest days
│   ├── journal_entry.dart     # JournalEntry, JournalType (text/photo/video/audio)
│   └── schedule_event.dart    # ScheduleEvent, EventType, EventRepeat
├── screens/
│   ├── shell.dart             # Root nav capsule + tab host
│   ├── splash_screen.dart     # Boot animation
│   ├── home/
│   │   └── home_screen.dart   # Dashboard, stats, quick add
│   ├── habits/
│   │   ├── habits_screen.dart       # Habit list + swipe-to-delete w/ undo
│   │   ├── habit_edit_sheet.dart    # Create / edit habit
│   │   └── habit_checkin_screen.dart # Check-in, optional photo proof
│   ├── journal/
│   │   ├── journal_screen.dart        # Entry feed
│   │   ├── journal_calendar_screen.dart # Month grid + per-day gallery
│   │   ├── journal_entry_editor.dart  # Capture sheet (text/photo/video/voice)
│   │   └── journal_entry_view.dart    # Entry reader + media viewer
│   ├── schedule/
│   │   ├── schedule_screen.dart     # Timeline + upcoming
│   │   ├── day_detail_screen.dart   # Single day, drag to draw events
│   │   └── event_edit_sheet.dart    # Create / edit event
│   ├── blocker/
│   │   ├── app_block_screen.dart    # Blocking rules + service status
│   │   └── rule_edit_sheet.dart     # Create / edit a block rule
│   ├── timer/
│   │   └── timer_screen.dart        # Focus / sleep / nap sessions
│   ├── alarm/
│   │   └── alarm_ring_screen.dart   # Full-screen ring (snooze / stop)
│   ├── stats/
│   │   └── screen_time_screen.dart  # 7-day chart + per-app breakdown
│   └── settings/
│       └── settings_screen.dart     # Prefs, permissions, export / import
├── services/
│   ├── habit_store.dart          # Habit CRUD, logs, streaks, persistence
│   ├── journal_store.dart        # Entry CRUD + media links
│   ├── schedule_store.dart       # Event CRUD, repeat expansion
│   ├── alarm_store.dart          # Alarm CRUD, ticker, firing logic
│   ├── block_store.dart          # Block rules + active-window checks
│   ├── session_store.dart        # Focus / sleep session recording
│   ├── settings_store.dart       # App preferences
│   ├── backup_service.dart       # Zip export / import (json + media)
│   ├── media_store.dart          # Photo / video / audio file management
│   ├── notification_service.dart # flutter_local_notifications scheduling
│   ├── notification_actions.dart # Check-in / snooze action handling
│   ├── app_blocker.dart          # MethodChannel → AccessibilityService
│   ├── app_icons.dart            # MethodChannel → app icon PNGs
│   ├── device_usage.dart         # app_usage wrapper
│   ├── device_admin_service.dart # Device admin for strict blocking
│   ├── alarm_buzz.dart           # Alarm sound + haptics foreground service
│   └── sfx.dart                  # UI sound effects
├── theme/
│   └── palette.dart              # Ndot type, colors, radii
└── widgets/
    ├── nd_widgets.dart        # NdButton, NdCard, NdSwitch
    ├── nd_icons.dart          # Dot-matrix glyph set
    ├── nd_photo_viewer.dart   # Full-screen photo viewer
    ├── nd_video_player.dart   # Video player with scrubbable waveform
    ├── habit_dot_grid.dart    # Habit history dot grid
    ├── commitment_board.dart  # Animated commitment board
    ├── month_grid.dart        # Calendar month grid
    ├── app_picker_sheet.dart  # Installed app picker
    ├── tactile.dart           # Press-scale animation
    └── routes.dart            # Page transitions
```

## Permissions

| Permission | Why |
|-----------|-----|
| `POST_NOTIFICATIONS` | Reminders and alarms |
| `SCHEDULE_EXACT_ALARM` | Precise timing |
| `USE_EXACT_ALARM` | Android 14+ exact alarm |
| `USE_FULL_SCREEN_INTENT` | Full-screen alarm ring |
| `WAKE_LOCK` | Wake device on alarm |
| `RECEIVE_BOOT_COMPLETED` | Re-schedule after reboot |
| `VIBRATE` | Haptics |
| `CAMERA` | Photo / video journal entries and habit proof |
| `RECORD_AUDIO` | Voice notes |
| `PACKAGE_USAGE_STATS` | Screen time tracking |
| `BIND_ACCESSIBILITY_SERVICE` | App blocking overlay |
| `FOREGROUND_SERVICE` | Keep alarms ringing in background |

## Build & Test

```bash
git clone https://github.com/notwewnothing/Navi
cd Navi/
flutter pub get
flutter run
flutter build apk --release
flutter test
```

**Status:** v1.0.1
