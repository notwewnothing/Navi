import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sfx.dart';
import '../theme/palette.dart';
import 'nd_icons.dart';
import 'nd_widgets.dart';
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
    // pad the first week to Monday and round up so the grid is always full rectangles
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            NdIconButton(
              glyph: Nd.left,
              tooltip: 'Previous month',
              onTap: () => _shift(-1),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${_months[month.month - 1]} ${month.year}',
                  style: p.title,
                ),
              ),
            ),
            NdIconButton(
              glyph: Nd.right,
              tooltip: 'Next month',
              onTap: () => _shift(1),
            ),
          ],
        ),
        const SizedBox(height: NdSpace.md),
        Row(
          children: [
            for (final label in _dayLabels)
              Expanded(
                child: Center(child: Text(label, style: p.micro)),
              ),
          ],
        ),
        const SizedBox(height: NdSpace.sm),
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
                                  borderRadius: BorderRadius.circular(
                                    NdRadius.small,
                                  ),
                                  border: Border.all(
                                    color: isToday ? p.accent : p.border,
                                    width: isToday ? 1.5 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
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
