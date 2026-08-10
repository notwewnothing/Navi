import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit.dart';
import '../../models/journal_entry.dart';
import '../../models/schedule_event.dart';
import '../../services/habit_store.dart';
import '../../services/journal_store.dart';
import '../../services/schedule_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/tactile.dart';
import 'event_edit_sheet.dart';

class DayDetailScreen extends StatefulWidget {
  const DayDetailScreen({super.key, required this.day});

  final DateTime day;

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  static const _pxPerHour = 44.0;
  static const _pxPerMin = _pxPerHour / 60;
  static const _topPad = 10.0;
  static const _totalHeight = 24 * _pxPerHour + 2 * _topPad;
  static const _rulerWidth = 44.0;

  static const _monthsShort = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  late final ScrollController _scroll;
  Timer? _clockTick;

  int? _dragAnchor;
  int? _dragEnd;

  bool get _isToday {
    final now = DateTime.now();
    return now.year == widget.day.year &&
        now.month == widget.day.month &&
        now.day == widget.day.day;
  }

  int get _nowMin {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  double _y(num minutes) => _topPad + minutes * _pxPerMin;

  @override
  void initState() {
    super.initState();
    final target = _isToday
        ? (_y(_nowMin - 120)).clamp(0.0, _totalHeight - 240)
        : (_y(7 * 60)).clamp(0.0, _totalHeight - 240);
    _scroll = ScrollController(initialScrollOffset: target);
    if (_isToday) {
      _clockTick = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _clockTick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  String get _dateLabel =>
      '${_monthsShort[widget.day.month - 1]} ${widget.day.day} ${widget.day.year}';


  int _snap(double dy) =>
      ((((dy - _topPad) / _pxPerMin) / 15).round() * 15).clamp(0, 1440);

  void _createStart(LongPressStartDetails d) {
    HapticFeedback.mediumImpact();
    Sfx.tick();
    final anchor =
        ((((d.localPosition.dy - _topPad) / _pxPerMin) / 15).floor() * 15)
            .clamp(0, 1425);
    setState(() {
      _dragAnchor = anchor;
      _dragEnd = anchor + 15;
    });
  }

  void _createUpdate(LongPressMoveUpdateDetails d) {
    if (_dragAnchor == null) return;
    final m = _snap(d.localPosition.dy);
    if (m != _dragEnd) {
      HapticFeedback.selectionClick();
      Sfx.tick();
      setState(() => _dragEnd = m);
    }
  }

  void _createEnd(LongPressEndDetails _) {
    final a = _dragAnchor;
    final b = _dragEnd;
    setState(() {
      _dragAnchor = null;
      _dragEnd = null;
    });
    if (a == null || b == null) return;
    final lo = min(a, b);
    final hi = max(a, b);
    if (hi - lo < 15) return;
    HapticFeedback.mediumImpact();
    showEventEditSheet(
      context,
      day: widget.day,
      startMin: lo,
      endMin: min(hi, 1439),
    );
  }

  void _createCancel() {
    setState(() {
      _dragAnchor = null;
      _dragEnd = null;
    });
  }


  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final schedule = ScheduleScope.of(context);
    final events = schedule.eventsForDay(widget.day);
    final prevDay =
        DateTime(widget.day.year, widget.day.month, widget.day.day - 1);
    final tails = [
      for (final e in schedule.eventsForDay(prevDay))
        if (e.endMin < e.startMin && e.endMin > 0) e,
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PixelHeader(
              title: _dateLabel,
              leading: PixelIconButton(
                glyph: Px.left,
                onTap: () => Navigator.pop(context),
              ),
              actions: [
                if (_isToday)
                  Text('TODAY', style: p.label.copyWith(color: p.accent)),
              ],
            ),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scroll,
                    child: SizedBox(
                      height: _totalHeight,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPressStart: _createStart,
                              onLongPressMoveUpdate: _createUpdate,
                              onLongPressEnd: _createEnd,
                              onLongPressCancel: _createCancel,
                              child: const SizedBox.expand(),
                            ),
                          ),
                          ..._ruler(p),
                          for (final (i, e) in tails.indexed)
                            _block(context, e, 0, e.endMin, i, tail: true),
                          for (final (i, e) in events.indexed)
                            _eventBlock(context, e, tails.length + i),
                          if (_dragAnchor != null && _dragEnd != null)
                            _ghost(p),
                          if (_isToday) ..._nowLine(p),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 14,
                    child: PixelFab(
                      onTap: () =>
                          showEventEditSheet(context, day: widget.day),
                    ),
                  ),
                ],
              ),
            ),
            _logsSection(context),
          ],
        ),
      ),
    );
  }


  List<Widget> _ruler(NaviPalette p) => [
        for (var h = 0; h <= 24; h++) ...[
          Positioned(
            top: _y(h * 60) - 0.5,
            left: _rulerWidth,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 1,
                color: p.border.withValues(alpha: 0.7),
              ),
            ),
          ),
          if (h < 24) ...[
            Positioned(
              top: _y(h * 60 + 30) - 0.5,
              left: _rulerWidth,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  color: p.border.withValues(alpha: 0.28),
                ),
              ),
            ),
            Positioned(
              top: _y(h * 60) - 7,
              left: 0,
              width: _rulerWidth - 6,
              child: IgnorePointer(
                child: Text(
                  h.toString().padLeft(2, '0'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: kFontTerminal,
                    fontSize: 14,
                    height: 1,
                    color: p.textGhost,
                  ),
                ),
              ),
            ),
          ],
        ],
      ];

  Widget _eventBlock(BuildContext context, ScheduleEvent e, int index) {
    final start = e.startMin;
    var end = e.endMin;
    if (e.type == EventType.alarm || end == start) {
      end = start;
    } else if (end < start) {
      end = 1440;
    }
    return _block(context, e, start, end, index);
  }

  Widget _block(
    BuildContext context,
    ScheduleEvent e,
    int start,
    int end,
    int index, {
    bool tail = false,
  }) {
    final p = context.palette;
    final color = eventTypeColor(p, e.type);
    final rawH = (end - start) * _pxPerMin;
    final h = max(20.0, rawH);
    final compact = h < 40;
    final time = switch ((e.type, tail)) {
      (EventType.alarm, _) => hhmm(e.startMin),
      (_, true) => '— ${hhmm(e.endMin)}',
      _ => e.timeLabel,
    };
    final title = Text(
      e.title.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: kFontPixel,
        fontSize: 7,
        letterSpacing: 1,
        height: 1.4,
        color: color,
      ),
    );
    final timeText = Text(
      time,
      maxLines: 1,
      style: TextStyle(
        fontFamily: kFontTerminal,
        fontSize: 13,
        height: 1,
        color: p.textDim,
      ),
    );
    return Positioned(
      top: _y(start),
      left: _rulerWidth + 8,
      right: 14,
      height: h,
      child: _Reveal(
        index: index,
        child: Tactile(
          pressedScale: 0.98,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Sfx.tick();
              showEventEditSheet(context, event: e);
            },
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                border: Border(left: BorderSide(color: color, width: 3)),
              ),
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
              child: compact
                  ? Row(
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 6),
                        timeText,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, const SizedBox(height: 3), timeText],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ghost(NaviPalette p) {
    final a = _dragAnchor!;
    final b = _dragEnd!;
    final lo = min(a, b);
    final hi = max(max(a, b), lo + 15);
    return Positioned(
      top: _y(lo),
      left: _rulerWidth + 8,
      right: 14,
      height: (hi - lo) * _pxPerMin,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: 0.12),
            border: Border.all(color: p.accent, width: 1.5),
          ),
          padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
          alignment: Alignment.topLeft,
          child: Text(
            '${hhmm(lo)} — ${hhmm(hi)}',
            style: TextStyle(
              fontFamily: kFontTerminal,
              fontSize: 13,
              height: 1,
              color: p.accent,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _nowLine(NaviPalette p) {
    final y = _y(_nowMin);
    return [
      Positioned(
        top: y - 0.75,
        left: _rulerWidth,
        right: 0,
        child: IgnorePointer(
          child: Container(height: 1.5, color: p.accent),
        ),
      ),
      Positioned(
        top: y - 3,
        left: _rulerWidth - 3,
        child: IgnorePointer(
          child: Container(width: 6, height: 6, color: p.accent),
        ),
      ),
    ];
  }


  Widget _logsSection(BuildContext context) {
    final p = context.palette;
    final habits = HabitScope.of(context);
    final journal = JournalScope.of(context);
    final habitLogs = [...habits.logsForDay(widget.day)]
      ..sort((a, b) => a.at.compareTo(b.at));
    final entries = [...journal.entriesForDay(widget.day)]
      ..sort((a, b) => a.at.compareTo(b.at));

    final rows = <Widget>[];
    var i = 0;
    for (final log in habitLogs) {
      final habit = habits.habitById(log.habitId);
      if (habit == null) continue;
      rows.add(_Reveal(index: i++, child: _HabitLogRow(habit: habit, log: log)));
    }
    for (final entry in entries) {
      rows.add(_Reveal(index: i++, child: _JournalRow(entry: entry)));
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.35,
      ),
      decoration: BoxDecoration(
        color: p.panel,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Row(
              children: [
                Text('LOGS', style: p.h2),
                const Spacer(),
                if (rows.isNotEmpty)
                  Text(
                    '${rows.length}',
                    style: p.label.copyWith(color: p.accentMid),
                  ),
              ],
            ),
          ),
          if (rows.isEmpty)
            const SizedBox(
              height: 104,
              child: EmptyState(
                message: 'No records of this day in the Wired.',
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                children: rows,
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitLogRow extends StatelessWidget {
  const _HabitLogRow({required this.habit, required this.log});

  final Habit habit;
  final HabitLog log;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = habitDotColors[habit.colorIndex % habitDotColors.length];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          PixelIcon(Px.habitIcon(habit.icon), color: color, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              habit.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kFontTerminal,
                fontSize: 20,
                height: 1.05,
                color: p.text,
              ),
            ),
          ),
          Text(
            hhmm(log.at.hour * 60 + log.at.minute),
            style: TextStyle(
              fontFamily: kFontTerminal,
              fontSize: 15,
              color: p.textDim,
            ),
          ),
          const SizedBox(width: 10),
          PixelIcon(Px.check, color: p.accent, size: 13),
        ],
      ),
    );
  }
}

class _JournalRow extends StatelessWidget {
  const _JournalRow({required this.entry});

  final JournalEntry entry;

  static PixelGlyph _glyph(JournalType type) => switch (type) {
    JournalType.text => Px.textLines,
    JournalType.photo => Px.photo,
    JournalType.video => Px.video,
    JournalType.audio => Px.mic,
  };

  String get _preview {
    final line = entry.body.trim().split('\n').first.trim();
    return line.isEmpty ? '[${entry.type.label}]' : line;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          PixelIcon(_glyph(entry.type), color: p.journalDot, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kFontTerminal,
                fontSize: 20,
                height: 1.05,
                color: p.textDim,
              ),
            ),
          ),
          Text(
            hhmm(entry.at.hour * 60 + entry.at.minute),
            style: TextStyle(
              fontFamily: kFontTerminal,
              fontSize: 15,
              color: p.textDim,
            ),
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
