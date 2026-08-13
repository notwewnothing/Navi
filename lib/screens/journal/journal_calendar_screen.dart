import 'package:flutter/material.dart';

import '../../models/habit.dart';
import '../../models/journal_entry.dart';
import '../../services/habit_store.dart';
import '../../services/journal_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/month_grid.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/routes.dart';
import 'journal_entry_view.dart';

const _monthsFull = [
  'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
  'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
];

class JournalCalendarScreen extends StatefulWidget {
  const JournalCalendarScreen({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  State<JournalCalendarScreen> createState() => _JournalCalendarScreenState();
}

class _JournalCalendarScreenState extends State<JournalCalendarScreen> {
  late DateTime _month = DateTime(
    (widget.initialMonth ?? DateTime.now()).year,
    (widget.initialMonth ?? DateTime.now()).month,
    1,
  );

  List<String> _photosFor(
    JournalStore journal,
    HabitStore habits,
    DateTime day,
  ) => [
    for (final e in journal.photoEntriesForDay(day)) e.mediaPath!,
    for (final log in habits.photoLogsForDay(day)) log.photoPath!,
  ];

  @override
  Widget build(BuildContext context) {
    final journal = JournalScope.of(context);
    final habits = HabitScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PixelHeader(
              title: 'ARCHIVE',
              leading: PixelIconButton(
                glyph: Px.left,
                onTap: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                children: [
                  MonthGrid(
                    month: _month,
                    cellAspect: 0.85,
                    onMonthChanged: (m) => setState(() => _month = m),
                    cellBuilder: (context, day) =>
                        _cell(context, journal, habits, day),
                    onTapDay: _openDay,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    JournalStore journal,
    HabitStore habits,
    DateTime day,
  ) {
    final p = context.palette;
    final photos = _photosFor(journal, habits, day);
    if (photos.isEmpty) {
      final hasAny =
          journal.hasEntryOn(day) || habits.logsForDay(day).isNotEmpty;
      return Container(
        color: p.panelHi,
        child: Stack(
          children: [
            _dayTag(p, day.day, onPhoto: false),
            if (hasAny)
              Positioned(
                right: 3,
                bottom: 3,
                child: Container(width: 4, height: 4, color: p.accentDim),
              ),
          ],
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _collage(p, photos),
        _dayTag(p, day.day, onPhoto: true),
      ],
    );
  }

  Widget _dayTag(NaviPalette p, int day, {required bool onPhoto}) => Positioned(
    top: 0,
    left: 0,
    child: Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 4, 2),
      color: onPhoto ? Colors.black.withValues(alpha: 0.6) : Colors.transparent,
      child: Text(
        '$day',
        style: TextStyle(
          fontFamily: kFontPixel,
          fontSize: 6,
          color: onPhoto ? p.text : p.textGhost,
          height: 1.2,
        ),
      ),
    ),
  );

  Widget _collage(NaviPalette p, List<String> photos) => switch (photos.length) {
    1 => MediaImage(photos[0]),
    2 => Column(
      children: [
        Expanded(child: MediaImage(photos[0])),
        const SizedBox(height: 2),
        Expanded(child: MediaImage(photos[1])),
      ],
    ),
    _ => Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: MediaImage(photos[0])),
              const SizedBox(width: 2),
              Expanded(child: MediaImage(photos[1])),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: MediaImage(photos[2])),
              const SizedBox(width: 2),
              Expanded(
                // a day's collage holds at most 4 photos, extras are dropped
                child: photos.length > 3
                    ? MediaImage(photos[3])
                    : Container(color: p.panelHi),
              ),
            ],
          ),
        ),
      ],
    ),
  };


  void _openDay(DateTime day) {
    final journal = JournalScope.of(context);
    final habits = HabitScope.of(context);
    final navigator = Navigator.of(context);
    showPixelSheet<void>(
      context: context,
      builder: (sheetContext) {
        final p = sheetContext.palette;
        final entries = journal.entriesForDay(day);
        final logs = habits.logsForDay(day).toList()
          ..sort((a, b) => a.at.compareTo(b.at));
        final photos = _photosFor(journal, habits, day);
        final title = '${_monthsFull[day.month - 1]} ${day.day} ${day.year}';
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.85;

        if (entries.isEmpty && logs.isEmpty) {
          return SafeArea(
            top: false,
            child: SizedBox(
              height: 280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Text(title, style: p.h2.copyWith(color: p.text)),
                  ),
                  const Expanded(
                    child: EmptyState(
                      message: 'Nothing was recorded. Did it happen?',
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                Text(title, style: p.h2.copyWith(color: p.text)),
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(height: 260, child: _DayGallery(photos: photos)),
                ],
                if (entries.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('JOURNAL', style: p.h2),
                  const SizedBox(height: 10),
                  for (final entry in entries)
                    _entryRow(sheetContext, navigator, entry),
                ],
                if (logs.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('CHECK-INS', style: p.h2),
                  const SizedBox(height: 10),
                  for (final log in logs) _logRow(sheetContext, habits, log),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _entryRow(
    BuildContext sheetContext,
    NavigatorState navigator,
    JournalEntry entry,
  ) {
    final p = sheetContext.palette;
    final firstLine = entry.body.split('\n').first.trim();
    final preview = firstLine.isNotEmpty
        ? firstLine
        : entry.type == JournalType.audio
        ? journalDuration(entry.durationMs)
        : entry.type.label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PixelCard(
        padding: const EdgeInsets.all(10),
        onTap: () {
          Navigator.pop(sheetContext);
          navigator.push(slideUpRoute(JournalEntryView(entry: entry)));
        },
        child: Row(
          children: [
            PixelIcon(
              journalTypeGlyph(entry.type),
              color: p.accentMid,
              size: 13,
            ),
            const SizedBox(width: 10),
            Text(
              journalHm(entry.at),
              style: TextStyle(
                fontFamily: kFontTerminal,
                fontSize: 18,
                color: p.textDim,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: p.body.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logRow(
    BuildContext sheetContext,
    HabitStore habits,
    HabitLog log,
  ) {
    final p = sheetContext.palette;
    final habit = habits.habitById(log.habitId);
    final dotColor =
        habitDotColors[(habit?.colorIndex ?? 0) % habitDotColors.length];
    final note = log.note ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PixelCard(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PixelIcon(
              Px.habitIcon(habit?.icon ?? 'flame'),
              color: dotColor,
              size: 14,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (habit?.name ?? 'SIGNAL LOST').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: kFontTerminal,
                            fontSize: 19,
                            color: p.text,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        journalHm(log.at),
                        style: TextStyle(
                          fontFamily: kFontTerminal,
                          fontSize: 16,
                          color: p.textDim,
                        ),
                      ),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: p.bodyDim.copyWith(fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
            if (log.photoPath != null) ...[
              const SizedBox(width: 8),
              PixelIcon(Px.camera, color: p.accentMid, size: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayGallery extends StatefulWidget {
  const _DayGallery({required this.photos});

  final List<String> photos;

  @override
  State<_DayGallery> createState() => _DayGalleryState();
}

class _DayGalleryState extends State<_DayGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) {
              Sfx.tick();
              setState(() => _page = i);
            },
            itemBuilder: (context, i) => Container(
              color: Colors.black,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: MediaImage(widget.photos[i], fit: BoxFit.contain),
            ),
          ),
        ),
        if (widget.photos.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.photos.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  color: i == _page ? p.accent : p.border,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
