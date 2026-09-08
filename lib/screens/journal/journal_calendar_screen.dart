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
import '../../widgets/tactile.dart';
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
  bool _yearView = false;

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
    ...journal.videoPostersForDay(day),
    for (final log in habits.photoLogsForDay(day)) log.photoPath!,
  ];

  /// One pass over the month: the grid and the header both read from this
  /// instead of re-querying the stores per cell.
  Map<int, ({int entries, int logs, List<String> photos})> _monthData(
    JournalStore journal,
    HabitStore habits,
  ) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    return {
      for (var d = 1; d <= daysInMonth; d++)
        d: (
          entries: journal
              .entriesForDay(DateTime(_month.year, _month.month, d))
              .length,
          logs: habits
              .logsForDay(DateTime(_month.year, _month.month, d))
              .length,
          photos: _photosFor(
            journal,
            habits,
            DateTime(_month.year, _month.month, d),
          ),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final journal = JournalScope.of(context);
    final habits = HabitScope.of(context);
    final p = context.palette;
    final data = _monthData(journal, habits);
    final totals = (
      entries: data.values.fold(0, (a, d) => a + d.entries),
      photos: data.values.fold(0, (a, d) => a + d.photos.length),
      checkIns: data.values.fold(0, (a, d) => a + d.logs),
      days: data.values.where((d) => d.entries > 0 || d.logs > 0).length,
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NdHeader(
              title: 'Archive',
              subtitle: _yearView
                  ? 'Tap a month to open it'
                  : 'Tap a day to see what you logged',
              leading: NdIconButton(
                glyph: Nd.left,
                onTap: () => Navigator.pop(context),
              ),
              actions: [
                NdIconButton(
                  glyph: _yearView ? Nd.calendar : Nd.grid,
                  tooltip: _yearView ? 'Month view' : 'Year view',
                  onTap: () => setState(() => _yearView = !_yearView),
                ),
              ],
            ),
            Expanded(
              child: _yearView
                  ? _YearGrid(
                      year: _month.year,
                      counts: journal.entryCountsByMonth(_month.year),
                      dayCounts: journal.entryCountsByDay(_month.year),
                      earliestYear: journal.earliestYear,
                      onPickMonth: (m) => setState(() {
                        _month = DateTime(_month.year, m);
                        _yearView = false;
                      }),
                      onYearChanged: (y) =>
                          setState(() => _month = DateTime(y, _month.month)),
                    )
                  : ListView(
                padding: const EdgeInsets.fromLTRB(
                  NdSpace.lg,
                  NdSpace.xs,
                  NdSpace.lg,
                  NdSpace.xl,
                ),
                children: [
                  MonthGrid(
                    month: _month,
                    onMonthChanged: (m) => setState(() => _month = m),
                    cellBuilder: (context, day) => _cell(
                      context,
                      day,
                      data[day.day] ??
                          (entries: 0, logs: 0, photos: const <String>[]),
                    ),
                    onTapDay: _openDay,
                  ),
                  const SizedBox(height: NdSpace.xl),
                  _MonthSummary(totals: totals),
                  const SizedBox(height: NdSpace.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendDot(p.accent),
                      const SizedBox(width: NdSpace.sm),
                      Text('journal', style: p.micro),
                      const SizedBox(width: NdSpace.lg),
                      _legendDot(p.textDim),
                      const SizedBox(width: NdSpace.sm),
                      Text('check-in', style: p.micro),
                      const SizedBox(width: NdSpace.lg),
                      NdIcon(Nd.camera, color: p.textGhost, size: 12),
                      const SizedBox(width: NdSpace.sm),
                      Text('photo', style: p.micro),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _cell(
    BuildContext context,
    DateTime day,
    ({int entries, int logs, List<String> photos}) data,
  ) {
    final p = context.palette;
    final photos = data.photos;
    final now = DateTime.now();
    final isFuture = day.isAfter(DateTime(now.year, now.month, now.day));

    if (photos.isNotEmpty) {
      // one photo reads at this size, a four-way collage does not
      return Stack(
        fit: StackFit.expand,
        children: [
          MediaImage(photos.first),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          _dayTag(p, day.day, onPhoto: true),
          if (photos.length > 1)
            Positioned(
              right: 3,
              bottom: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(NdRadius.small),
                ),
                child: Text(
                  '${photos.length}',
                  style: p.micro.copyWith(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
        ],
      );
    }

    return Container(
      color: isFuture ? Colors.transparent : p.panel,
      child: Stack(
        children: [
          _dayTag(p, day.day, onPhoto: false, dim: isFuture),
          if (data.entries > 0 || data.logs > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // one dot per kind, not per item - the sheet has the detail
                  if (data.entries > 0) _legendDot(p.accent),
                  if (data.entries > 0 && data.logs > 0)
                    const SizedBox(width: 4),
                  if (data.logs > 0) _legendDot(p.textDim),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayTag(
    NaviPalette p,
    int day, {
    required bool onPhoto,
    bool dim = false,
  }) => Positioned(
    top: 0,
    left: 0,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 3),
      child: Text(
        '$day',
        style: p.dot(
          13,
          color: onPhoto
              ? Colors.white
              : dim
              ? p.textGhost
              : p.textDim,
        ),
      ),
    ),
  );

  void _openDay(DateTime day) {
    final journal = JournalScope.of(context);
    final habits = HabitScope.of(context);
    final navigator = Navigator.of(context);
    showNdSheet<void>(
      context: context,
      heightFactor: 0.85,
      builder: (sheetContext) {
        final p = sheetContext.palette;
        final entries = journal.entriesForDay(day);
        final logs = habits.logsForDay(day).toList()
          ..sort((a, b) => a.at.compareTo(b.at));
        final photos = _photosFor(journal, habits, day);
        final title = '${_monthsFull[day.month - 1]} ${day.day} ${day.year}';

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
                      SizedBox(height: 260, child: _DayGallery(photos: photos)),
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

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.totals});

  final ({int entries, int photos, int checkIns, int days}) totals;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return NdCard(
      radius: NdRadius.inner,
      padding: const EdgeInsets.symmetric(vertical: NdSpace.lg),
      child: Row(
        children: [
          _stat(p, '${totals.days}', 'DAYS LOGGED'),
          _divider(p),
          _stat(p, '${totals.entries}', 'ENTRIES'),
          _divider(p),
          _stat(p, '${totals.photos}', 'PHOTOS'),
          _divider(p),
          _stat(p, '${totals.checkIns}', 'CHECK-INS'),
        ],
      ),
    );
  }

  Widget _stat(NaviPalette p, String value, String label) => Expanded(
    child: Column(
      children: [
        Text(value, style: p.dot(26, color: p.text)),
        const SizedBox(height: 3),
        Text(label, style: p.micro, textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _divider(NaviPalette p) =>
      Container(width: 1, height: 30, color: p.border);
}

class _YearGrid extends StatelessWidget {
  const _YearGrid({
    required this.year,
    required this.counts,
    required this.dayCounts,
    required this.earliestYear,
    required this.onPickMonth,
    required this.onYearChanged,
  });

  final int year;
  final Map<int, int> counts;
  final Map<String, int> dayCounts;
  final int earliestYear;
  final ValueChanged<int> onPickMonth;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final busiestDay = dayCounts.values.fold(0, (a, b) => a > b ? a : b);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NdSpace.lg,
        NdSpace.xs,
        NdSpace.lg,
        NdSpace.xl,
      ),
      children: [
        Row(
          children: [
            Opacity(
              opacity: year > earliestYear ? 1 : 0.3,
              child: NdIconButton(
                glyph: Nd.left,
                onTap: () {
                  if (year <= earliestYear) return;
                  Sfx.tick();
                  onYearChanged(year - 1);
                },
              ),
            ),
            Expanded(
              child: Center(
                child: Text('$year', style: p.dot(30, letterSpacing: 3)),
              ),
            ),
            Opacity(
              opacity: year < now.year ? 1 : 0.3,
              child: NdIconButton(
                glyph: Nd.right,
                onTap: () {
                  if (year >= now.year) return;
                  Sfx.tick();
                  onYearChanged(year + 1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: NdSpace.lg),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: NdSpace.md,
          mainAxisSpacing: NdSpace.md,
          childAspectRatio: 0.82,
          children: [
            for (var m = 1; m <= 12; m++)
              _MiniMonth(
                year: year,
                month: m,
                count: counts[m] ?? 0,
                dayCounts: dayCounts,
                busiestDay: busiestDay,
                isCurrent: year == now.year && m == now.month,
                onTap: () {
                  Sfx.tick();
                  onPickMonth(m);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.year,
    required this.month,
    required this.count,
    required this.dayCounts,
    required this.busiestDay,
    required this.isCurrent,
    required this.onTap,
  });

  final int year;
  final int month;
  final int count;
  final Map<String, int> dayCounts;
  final int busiestDay;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final days = DateTime(year, month + 1, 0).day;
    final leading = DateTime(year, month, 1).weekday - 1;

    return Tactile(
      pressedScale: 0.94,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(NdSpace.sm),
          decoration: BoxDecoration(
            color: count > 0 ? p.panelHi : p.panel,
            border: Border.all(
              color: isCurrent ? p.accent : p.border,
              width: isCurrent ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(NdRadius.inner),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _monthsFull[month - 1].substring(0, 3).toUpperCase(),
                style: p.micro.copyWith(
                  color: count > 0 ? p.text : p.textGhost,
                ),
              ),
              const SizedBox(height: NdSpace.xs),
              Expanded(
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 7,
                  crossAxisSpacing: 1.5,
                  mainAxisSpacing: 1.5,
                  children: [
                    for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                    for (var d = 1; d <= days; d++)
                      Builder(
                        builder: (context) {
                          final onDay =
                              dayCounts[dayKeyOf(DateTime(year, month, d))] ??
                              0;
                          final intensity = busiestDay == 0
                              ? 0.0
                              : onDay / busiestDay;
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              color: onDay == 0
                                  ? p.border.withValues(alpha: 0.35)
                                  : p.accent.withValues(
                                      alpha: 0.3 + 0.7 * intensity,
                                    ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: NdSpace.xs),
              Text(
                count == 0 ? '—' : '$count',
                style: p.micro.copyWith(
                  color: count > 0 ? p.accent : p.textGhost,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
