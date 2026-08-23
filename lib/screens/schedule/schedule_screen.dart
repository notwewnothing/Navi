import 'package:flutter/material.dart';

import '../../models/schedule_event.dart';
import '../../services/journal_store.dart';
import '../../services/schedule_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/month_grid.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_widgets.dart';
import '../../widgets/routes.dart';
import '../shell.dart';
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

  static const _daysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
    // both normalized to midnight first so DST shifts can't skew the day count
    final diff = day.difference(today).inDays;
    return switch (diff) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => '${_daysShort[day.weekday - 1]} ${day.day}',
    };
  }

  Widget _cell(
    BuildContext context,
    DateTime day,
    ScheduleStore schedule,
    JournalStore journal,
  ) {
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
      padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${day.day}', style: p.micro.copyWith(color: p.textDim)),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final color in dots)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
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
          padding: const EdgeInsets.only(bottom: kNavContentInset),
          children: [
            const NdHeader(title: 'Schedule'),
            _Reveal(
              index: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: NdSpace.page),
                child: MonthGrid(
                  month: _month,
                  onMonthChanged: (m) => setState(() => _month = m),
                  cellBuilder: (context, day) =>
                      _cell(context, day, schedule, journal),
                  onTapDay: (day) => Navigator.of(
                    context,
                  ).push(slideUpRoute(DayDetailScreen(day: day))),
                ),
              ),
            ),
            const SizedBox(height: NdSpace.xxl),
            _Reveal(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: NdSpace.page),
                child: Row(
                  children: [
                    Text('UPCOMING', style: p.h2),
                    const Spacer(),
                    Text(
                      'NEXT 7 DAYS',
                      style: p.micro.copyWith(color: p.textGhost),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: NdSpace.md),
            if (upcoming.isEmpty)
              SizedBox(
                height: 180,
                child: EmptyState(
                  glyph: Nd.calendar,
                  message: 'Nothing scheduled this week.',
                  actionLabel: 'Add an event',
                  onAction: () => showEventEditSheet(context),
                ),
              )
            else
              for (final (i, (day, event)) in upcoming.indexed)
                _Reveal(
                  index: 2 + i,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      NdSpace.page,
                      0,
                      NdSpace.page,
                      NdSpace.md,
                    ),
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
    return NdCard(
      onTap: onTap,
      padding: const EdgeInsets.all(NdSpace.lg),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: NdSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.row,
                ),
                const SizedBox(height: 3),
                Text(time, style: p.label),
              ],
            ),
          ),
          const SizedBox(width: NdSpace.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(dayLabel, style: p.micro.copyWith(color: p.accent)),
              if (event.repeat != EventRepeat.never) ...[
                const SizedBox(height: NdSpace.xs),
                Text(
                  event.repeat.label,
                  style: p.micro.copyWith(color: p.textGhost),
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
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
