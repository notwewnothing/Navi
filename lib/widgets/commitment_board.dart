import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sfx.dart';
import '../theme/palette.dart';

class CommitmentBoard extends StatefulWidget {
  const CommitmentBoard({
    super.key,
    required this.levelFor,
    required this.countFor,
    this.weeks = 53,
  });

  final int Function(DateTime day) levelFor;

  final int Function(DateTime day) countFor;

  final int weeks;

  @override
  State<CommitmentBoard> createState() => _CommitmentBoardState();
}

class _CommitmentBoardState extends State<CommitmentBoard>
    with SingleTickerProviderStateMixin {
  static const _cell = 15.0;
  static const _gap = 3.0;
  static const _monthLabelH = 14.0;

  final _scroll = ScrollController();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  DateTime? _selected;

  late final DateTime _origin;
  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    final thisMonday = _today.subtract(Duration(days: _today.weekday - 1));
    // start at the Monday of the first week so columns always align to weeks
    _origin = thisMonday.subtract(Duration(days: 7 * (widget.weeks - 1)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onTapUp(TapUpDetails details) {
    final pos = details.localPosition;
    final col = (pos.dx / (_cell + _gap)).floor();
    final row = ((pos.dy - _monthLabelH) / (_cell + _gap)).floor();
    if (col < 0 || col >= widget.weeks || row < 0 || row > 6) return;
    final day = _origin.add(Duration(days: col * 7 + row));
    if (day.isAfter(_today)) return;
    HapticFeedback.selectionClick();
    Sfx.tick();
    setState(() => _selected = _selected == day ? null : day);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final width = widget.weeks * (_cell + _gap) - _gap;
    const height = _monthLabelH + 7 * (_cell + _gap) - _gap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: _monthLabelH),
              child: SizedBox(
                width: 16,
                height: height - _monthLabelH,
                child: Column(
                  children: [
                    for (var r = 0; r < 7; r++)
                      SizedBox(
                        height: _cell + (r < 6 ? _gap : 0),
                        child: r.isEven
                            ? Text(
                                const ['M', '', 'W', '', 'F', '', 'S'][r],
                                style: TextStyle(
                                  fontFamily: kFontPixel,
                                  fontSize: 6,
                                  color: p.textGhost,
                                ),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: GestureDetector(
                  onTapUp: _onTapUp,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) => CustomPaint(
                        painter: _BoardPainter(
                          palette: p,
                          origin: _origin,
                          today: _today,
                          weeks: widget.weeks,
                          levelFor: widget.levelFor,
                          pulse: _pulse.value,
                          selected: _selected,
                          cell: _cell,
                          gap: _gap,
                          monthLabelH: _monthLabelH,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: _selected == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        color: p.boardLevel(widget.levelFor(_selected!)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _tooltipLabel(_selected!),
                        style: p.label.copyWith(color: p.textDim),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  String _tooltipLabel(DateTime day) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final count = widget.countFor(day);
    final date =
        '${months[day.month - 1]} ${day.day.toString().padLeft(2, '0')} ${day.year}';
    final what = count == 0
        ? 'NO SIGNAL'
        : count == 1
        ? '1 CHECK-IN'
        : '$count CHECK-INS';
    return '$date — $what';
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.palette,
    required this.origin,
    required this.today,
    required this.weeks,
    required this.levelFor,
    required this.pulse,
    required this.selected,
    required this.cell,
    required this.gap,
    required this.monthLabelH,
  });

  final NaviPalette palette;
  final DateTime origin;
  final DateTime today;
  final int weeks;
  final int Function(DateTime) levelFor;
  final double pulse;
  final DateTime? selected;
  final double cell;
  final double gap;
  final double monthLabelH;

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    var lastMonth = -1;

    for (var col = 0; col < weeks; col++) {
      final weekStart = origin.add(Duration(days: col * 7));

      if (weekStart.month != lastMonth) {
        lastMonth = weekStart.month;
        if (col < weeks - 2) {
          final tp = TextPainter(
            text: TextSpan(
              text: _months[weekStart.month - 1],
              style: TextStyle(
                fontFamily: kFontPixel,
                fontSize: 6,
                color: palette.textGhost,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(col * (cell + gap), 0));
        }
      }

      for (var row = 0; row < 7; row++) {
        final day = weekStart.add(Duration(days: row));
        if (day.isAfter(today)) continue;
        final x = col * (cell + gap);
        final y = monthLabelH + row * (cell + gap);
        final rect = Rect.fromLTWH(x, y, cell, cell);
        final level = levelFor(day);
        final isToday = day == today;

        paint.color = palette.boardLevel(level);
        if (isToday && level == 0) {
          paint.color = Color.lerp(
            palette.boardLevel(0),
            palette.accentGhost,
            0.35 + 0.4 * pulse,
          )!;
        }
        canvas.drawRect(rect, paint);

        if (isToday) {
          final halo = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = palette.accent.withValues(alpha: 0.35 + 0.55 * pulse);
          canvas.drawRect(rect.inflate(2.2), halo);
        }

        if (selected == day) {
          final sel = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = palette.text;
          canvas.drawRect(rect.inflate(1.2), sel);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) =>
      old.pulse != pulse ||
      old.selected != selected ||
      old.palette.accentRamp != palette.accentRamp;
}

