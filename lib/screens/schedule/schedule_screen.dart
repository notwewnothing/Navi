import 'package:flutter/material.dart';

import '../../models/schedule_event.dart';
import '../../services/journal_store.dart';
import '../../services/schedule_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/month_grid.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/routes.dart';
import 'day_detail_screen.dart';
import 'event_edit_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _month = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }();

  static const _daysShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  List<(DateTime, ScheduleEvent)> _upcoming(ScheduleStore schedule) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final result = <(DateTime, ScheduleEvent)>[];
    for (var i = 0; i < 7 && result.length < 5; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      for (final e in schedule.eventsForDay(day)) {
        if (i == 0 && e.startMin < nowMin) continue;
        result.add((day, e));
        if (result.length >= 5) break;
      }
    }
    return result;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    return switch (diff) {
      0 => 'TODAY',
      1 => 'TOMORROW',
      _ => '${_daysShort[day.weekday - 1]} ${day.day}',
    };
  }

  Widget _cell(BuildContext context, DateTime day, ScheduleStore schedule,
      JournalStore journal) {
    final p = context.palette;
    final types = schedule.typesOn(day);
    final dots = <Color>[
      if (types.contains(EventType.focus)) p.focusDot,
      if (types.contains(EventType.sleep)) p.sleepDot,
      if (types.contains(EventType.alarm)) p.alarmDot,
      if (types.contains(EventType.appBlock)) p.blockDot,
      if (journal.hasEntryOn(day)) p.journalDot,
    ];
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontFamily: kFontPixel,
                fontSize: 6,
                height: 1,
                color: p.textDim,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in dots)
                  Container(
                    width: 3,
                    height: 3,
                    margin: const EdgeInsets.only(right: 2),
                    color: color,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final schedule = ScheduleScope.of(context);
    final journal = JournalScope.of(context);
    final upcoming = _upcoming(schedule);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const PixelHeader(title: 'SCHEDULE'),
            _Reveal(
              index: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: MonthGrid(
                  month: _month,
                  onMonthChanged: (m) => setState(() => _month = m),
                  cellBuilder: (context, day) =>
                      _cell(context, day, schedule, journal),
                  onTapDay: (day) => Navigator.of(context)
                      .push(slideUpRoute(DayDetailScreen(day: day))),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _Reveal(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('UPCOMING', style: p.h2),
                    const Spacer(),
                    Text(
                      'NEXT 7 DAYS',
                      style: p.label.copyWith(color: p.textGhost),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (upcoming.isEmpty)
              const SizedBox(
                height: 140,
                child: EmptyState(
                  glyph: Px.calendar,
                  message: 'Nothing is scheduled.\nThe Wired is quiet.',
                ),
              )
            else
              for (final (i, (day, event)) in upcoming.indexed)
                _Reveal(
                  index: 2 + i,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: _UpcomingCard(
                      event: event,
                      dayLabel: _dayLabel(day),
                      onTap: () {
                        Sfx.tick();
                        showEventEditSheet(context, event: event);
                      },
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.event,
    required this.dayLabel,
    required this.onTap,
  });

  final ScheduleEvent event;
  final String dayLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = eventTypeColor(p, event.type);
    final time = event.type == EventType.alarm
        ? hhmm(event.startMin)
        : event.timeLabel;
    return PixelCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(width: 10, height: 10, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kFontTerminal,
                    fontSize: 21,
                    height: 1.05,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    fontFamily: kFontTerminal,
                    fontSize: 15,
                    height: 1,
                    color: p.textDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(dayLabel, style: p.label.copyWith(color: p.accentMid)),
              if (event.repeat != EventRepeat.never) ...[
                const SizedBox(height: 4),
                Text(
                  event.repeat.label,
                  style: p.label.copyWith(color: p.textGhost),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = index.clamp(0, 8) * 80;
    final total = 320 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
