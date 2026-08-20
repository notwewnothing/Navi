import 'package:flutter/material.dart';

/// Compact per-habit history block: one column per week, one row per weekday.
///
/// Deliberately not [CommitmentBoard] — that one is a full-year scroller with a
/// weekday gutter, month labels and a tap tooltip. This is a static read-only
/// block sized to sit inside a habit card.
class HabitDotGrid extends StatelessWidget {
  const HabitDotGrid({
    super.key,
    required this.color,
    required this.isDone,
    this.isActive,
    this.weeks = 6,
    this.gap = 3,
    this.cell = 11,
    this.endDay,
  });

  /// The habit's own colour, so two cards never read as the same habit.
  final Color color;

  final bool Function(DateTime day) isDone;

  /// Whether the habit was scheduled (and already created) on that day.
  /// Days that fail this render at the faintest tier.
  final bool Function(DateTime day)? isActive;

  final int weeks;
  final double gap;

  /// Fixed rather than derived from the available width: these grids sit
  /// inside IntrinsicHeight rows, which cannot measure a LayoutBuilder.
  final double cell;

  final DateTime? endDay;

  static const _rows = 7;

  @override
  Widget build(BuildContext context) {
    // anchor on the Monday of the current week so columns are whole weeks
    final now = endDay ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastMonday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    final origin = DateTime(
      lastMonday.year,
      lastMonday.month,
      lastMonday.day - 7 * (weeks - 1),
    );

    final width = weeks * cell + (weeks - 1) * gap;
    final height = _rows * cell + (_rows - 1) * gap;

    // the block is narrower than the card, so centre it rather than
    // letting it hug the left edge
    return Center(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(width, height),
          painter: _HabitDotPainter(
            color: color,
            origin: origin,
            today: today,
            weeks: weeks,
            cell: cell,
            gap: gap,
            isDone: isDone,
            isActive: isActive,
          ),
        ),
      ),
    );
  }
}

class _HabitDotPainter extends CustomPainter {
  _HabitDotPainter({
    required this.color,
    required this.origin,
    required this.today,
    required this.weeks,
    required this.cell,
    required this.gap,
    required this.isDone,
    required this.isActive,
  });

  final Color color;
  final DateTime origin;
  final DateTime today;
  final int weeks;
  final double cell;
  final double gap;
  final bool Function(DateTime) isDone;
  final bool Function(DateTime)? isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final radius = Radius.circular(cell * 0.28);

    for (var col = 0; col < weeks; col++) {
      for (var row = 0; row < 7; row++) {
        // calendar arithmetic rather than Duration, so DST can't shift a day
        final day = DateTime(
          origin.year,
          origin.month,
          origin.day + col * 7 + row,
        );
        if (day.isAfter(today)) continue;

        final active = isActive?.call(day) ?? true;
        paint.color = isDone(day)
            ? color
            : active
            ? color.withValues(alpha: 0.22)
            : color.withValues(alpha: 0.07);

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(col * (cell + gap), row * (cell + gap), cell, cell),
            radius,
          ),
          paint,
        );
      }
    }
  }

  // the callbacks are fresh closures every build, so field comparison would
  // never report equal anyway — repainting 42 rounded rects is trivial
  @override
  bool shouldRepaint(covariant _HabitDotPainter old) => true;
}
