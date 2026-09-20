# NAVI

*An open source, feature rich journaling / habit tracking app with some extra cool features :3*

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
│   ├── alarm.dart            
│   ├── block_rule.dart        
│   ├── day_stats.dart         
│   ├── habit.dart             
│   ├── journal_entry.dart    
│   └── schedule_event.dart    
├── screens/
│   ├── shell.dart             
│   ├── splash_screen.dart     
│   ├── home/
│   │   └── home_screen.dart  
│   ├── habits/
│   │   ├── habits_screen.dart       
│   │   ├── habit_edit_sheet.dart    
│   │   └── habit_checkin_screen.dart 
│   ├── journal
│   │   ├── journal_screen.dart      
│   │   ├── journal_calendar_screen.dart 
│   │   ├── journal_entry_editor.dart 
│   │   └── journal_entry_view.dart    
│   ├── schedule/
│   │   ├── schedule_screen.dart    
│   │   ├── day_detail_screen.dart
│   │   └── event_edit_sheet.dart   
│   ├── blocker/
│   │   ├── app_block_screen.dart    
│   │   └── rule_edit_sheet.dart     
│   ├── timer/
│   │   └── timer_screen.dart       
│   ├── alarm/
│   │   └── alarm_ring_screen.dart  
│   ├── stats/
│   │   └── screen_time_screen.dart  
│   └── settings/
│       └── settings_screen.dart     
├── services/
│   ├── habit_store.dart        
│   ├── journal_store.dart      
│   ├── schedule_store.dart    
│   ├── alarm_store.dart        
│   ├── block_store.dart      
│   ├── session_store.dart       
│   ├── settings_store.dart     
│   ├── backup_service.dart      
│   ├── media_store.dart       
│   ├── notification_service.dart 
│   ├── notification_actions.dart
│   ├── app_blocker.dart        
│   ├── app_icons.dart            
│   ├── device_usage.dart      
│   ├── device_admin_service.dart 
│   ├── alarm_buzz.dart           
│   └── sfx.dart                  
├── theme/
│   └── palette.dart             
└── widgets/
    ├── nd_widgets.dart      
    ├── nd_icons.dart          
    ├── nd_photo_viewer.dart   
    ├── nd_video_player.dart   
    ├── habit_dot_grid.dart   
    ├── commitment_board.dart  
    ├── month_grid.dart        
    ├── app_picker_sheet.dart  
    ├── tactile.dart          
    └── routes.dart       
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

**Status:** v1.0.1 (still WIP)
