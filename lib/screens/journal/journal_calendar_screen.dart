import 'package:flutter/material.dart';

import '../../models/habit.dart';
import '../../models/journal_entry.dart';
import '../../services/habit_store.dart';
import '../../services/journal_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/month_grid.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_widgets.dart';
import '../../widgets/routes.dart';
import 'journal_entry_view.dart';

const _monthsFull = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
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
            NdHeader(
              title: 'Archive',
              subtitle: 'Tap a day to see what you logged',
              leading: NdIconButton(
                glyph: Nd.left,
                onTap: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  NdSpace.lg,
                  NdSpace.xs,
                  NdSpace.lg,
                  NdSpace.xl,
                ),
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
        color: p.panel,
        child: Stack(
          children: [
            _dayTag(p, day.day, onPhoto: false),
            if (hasAny)
              Positioned(
                right: 5,
                bottom: 5,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: p.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [_collage(p, photos), _dayTag(p, day.day, onPhoto: true)],
    );
  }

  Widget _dayTag(NaviPalette p, int day, {required bool onPhoto}) => Positioned(
    top: 0,
    left: 0,
    child: Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 6, 3),
      decoration: BoxDecoration(
        color: onPhoto
            ? Colors.black.withValues(alpha: 0.6)
            : Colors.transparent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(NdRadius.small),
          bottomRight: Radius.circular(NdRadius.small),
        ),
      ),
      child: Text(
        '$day',
        style: p.micro.copyWith(color: onPhoto ? Colors.white : p.textGhost),
      ),
    ),
  );

  Widget _collage(
    NaviPalette p,
    List<String> photos,
  ) => switch (photos.length) {
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
                    : Container(color: p.panel),
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
    showNdSheet<void>(
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
                  NdSheetHeader(title: title),
                  const Expanded(
                    child: EmptyState(message: 'Nothing logged on this day.'),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NdSheetHeader(title: title),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(
                      NdSpace.page,
                      0,
                      NdSpace.page,
                      NdSpace.xl,
                    ),
                    children: [
                      if (photos.isNotEmpty) ...[
                        SizedBox(
                          height: 260,
                          child: _DayGallery(photos: photos),
                        ),
                        const SizedBox(height: NdSpace.xl),
                      ],
                      if (entries.isNotEmpty) ...[
                        Text('JOURNAL', style: p.h2),
                        const SizedBox(height: NdSpace.md),
                        for (final entry in entries)
                          _entryRow(sheetContext, navigator, entry),
                        const SizedBox(height: NdSpace.sm),
                      ],
                      if (logs.isNotEmpty) ...[
                        Text('CHECK-INS', style: p.h2),
                        const SizedBox(height: NdSpace.md),
                        for (final log in logs)
                          _logRow(sheetContext, habits, log),
                      ],
                    ],
                  ),
                ),
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
      padding: const EdgeInsets.only(bottom: NdSpace.sm),
      child: NdCard(
        radius: NdRadius.inner,
        padding: const EdgeInsets.all(NdSpace.md),
        onTap: () {
          Navigator.pop(sheetContext);
          navigator.push(slideUpRoute(JournalEntryView(entry: entry)));
        },
        child: Row(
          children: [
            NdIcon(journalTypeGlyph(entry.type), color: p.accent, size: 16),
            const SizedBox(width: NdSpace.md),
            Text(journalHm(entry.at), style: p.dot(15, color: p.textDim)),
            const SizedBox(width: NdSpace.md),
            Expanded(
              child: Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: p.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logRow(BuildContext sheetContext, HabitStore habits, HabitLog log) {
    final p = sheetContext.palette;
    final habit = habits.habitById(log.habitId);
    final dotColor =
        habitDotColors[(habit?.colorIndex ?? 0) % habitDotColors.length];
    final note = log.note ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: NdSpace.sm),
      child: NdCard(
        radius: NdRadius.inner,
        padding: const EdgeInsets.all(NdSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NdIcon(
              Nd.habitIcon(habit?.icon ?? 'flame'),
              color: dotColor,
              size: 18,
            ),
            const SizedBox(width: NdSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          habit?.name ?? 'Deleted habit',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: p.row.copyWith(fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: NdSpace.sm),
                      Text(
                        journalHm(log.at),
                        style: p.dot(15, color: p.textDim),
                      ),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: p.bodyDim.copyWith(fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
            if (log.photoPath != null) ...[
              const SizedBox(width: NdSpace.sm),
              NdIcon(Nd.camera, color: p.accent, size: 15),
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
              margin: const EdgeInsets.symmetric(horizontal: NdSpace.xs),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: p.panel,
                borderRadius: BorderRadius.circular(NdRadius.inner),
              ),
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
                  width: i == _page ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _page ? p.accent : p.borderHi,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
