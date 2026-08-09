import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sfx.dart';
import '../theme/palette.dart';
import 'pixel_icons.dart';
import 'pixel_widgets.dart';
import 'tactile.dart';

class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.onMonthChanged,
    required this.cellBuilder,
    required this.onTapDay,
    this.cellAspect = 1.0,
  });

  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;
  final Widget Function(BuildContext context, DateTime day) cellBuilder;
  final ValueChanged<DateTime> onTapDay;
  final double cellAspect;

  static const _months = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];
  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  void _shift(int delta) {
    Sfx.tick();
    onMonthChanged(DateTime(month.year, month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PixelIconButton(glyph: Px.left, onTap: () => _shift(-1)),
            Expanded(
              child: Center(
                child: Text(
                  '${_months[month.month - 1]} ${month.year}',
                  style: p.h2.copyWith(color: p.text),
                ),
              ),
            ),
            PixelIconButton(glyph: Px.right, onTap: () => _shift(1)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final label in _dayLabels)
              Expanded(
                child: Center(
                  child: Text(label, style: p.label.copyWith(fontSize: 6)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var week = 0; week < totalCells ~/ 7; week++) ...[
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: cellAspect,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Builder(
                        builder: (context) {
                          final index = week * 7 + d - leading;
                          if (index < 0 || index >= daysInMonth) {
                            return const SizedBox.shrink();
                          }
                          final day = DateTime(
                            month.year,
                            month.month,
                            index + 1,
                          );
                          final isToday = day == today;
                          return Tactile(
                            pressedScale: 0.9,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Sfx.tick();
                                onTapDay(day);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  border: isToday
                                      ? Border.all(
                                          color: p.accent,
                                          width: 1.5,
                                        )
                                      : Border.all(
                                          color: p.border.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: cellBuilder(context, day),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
