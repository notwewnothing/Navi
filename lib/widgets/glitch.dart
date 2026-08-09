import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/palette.dart';

final _rng = Random();

// katakana + terminal junk reads as corruption better than random ASCII
const _corruptChars = 'ｱｲｳｴｵｶｷｸｹｺﾀﾁﾂﾃﾄﾅﾆﾇ01_/\\|#*+=<>';

class GlitchText extends StatefulWidget {
  const GlitchText(
    this.text, {
    super.key,
    required this.style,
    this.intensity = 0.12,
    this.interval = const Duration(seconds: 4),
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final double intensity;
  final Duration interval;
  final TextAlign? textAlign;

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText> {
  Timer? _timer;
  Timer? _restore;
  String? _corrupted;
  bool _shift = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _timer = Timer(
      widget.interval + Duration(milliseconds: _rng.nextInt(2500)),
      _burst,
    );
  }

  void _burst() {
    if (!mounted) return;
    final chars = widget.text.characters.toList();
    for (var i = 0; i < chars.length; i++) {
      if (chars[i] != ' ' && _rng.nextDouble() < widget.intensity) {
        chars[i] = _corruptChars[_rng.nextInt(_corruptChars.length)];
      }
    }
    setState(() {
      _corrupted = chars.join();
      _shift = true;
    });
    _restore = Timer(Duration(milliseconds: 80 + _rng.nextInt(90)), () {
      if (!mounted) return;
      setState(() {
        _corrupted = null;
        _shift = false;
      });
      _schedule();
    });
  }

  @override
  void didUpdateWidget(GlitchText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _corrupted = null;
      _shift = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restore?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _corrupted ?? widget.text;
    final base = Text(text, style: widget.style, textAlign: widget.textAlign);
    if (!_shift) return base;
    // classic RGB split, cyan ghost left, red ghost right, base on top
    return Stack(
      children: [
        Transform.translate(
          offset: const Offset(-1.5, 0),
          child: Text(
            text,
            textAlign: widget.textAlign,
            style: widget.style.copyWith(
              color: const Color(0x5500ffcc),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(1.5, 0),
          child: Text(
            text,
            textAlign: widget.textAlign,
            style: widget.style.copyWith(
              color: const Color(0x55ff3366),
            ),
          ),
        ),
        base,
      ],
    );
  }
}

class GlitchTear extends StatelessWidget {
  const GlitchTear({
    super.key,
    required this.progress,
    required this.child,
    this.slices = 14,
    this.seed = 7,
  });

  final double progress;
  final Widget child;
  final int slices;
  final int seed;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return child;
    // sine envelope, mild at start/end of the tear, most violent in the middle
    final amp = sin(progress * pi);
    // seeded by progress so the tear pattern stays stable frame-to-frame
    final rng = Random(seed + (progress * 6).floor());
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, box) {
          final h = box.maxHeight / slices;
          return Stack(
            children: [
              for (var i = 0; i < slices; i++)
                Positioned(
                  top: i * h,
                  left: (rng.nextDouble() * 2 - 1) * 42 * amp *
                      (rng.nextDouble() < 0.4 ? 1 : 0.2),
                  width: box.maxWidth,
                  height: h,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment(0, -1 + 2 * i / (slices - 1)),
                      minWidth: box.maxWidth,
                      maxWidth: box.maxWidth,
                      minHeight: box.maxHeight,
                      maxHeight: box.maxHeight,
                      child: child,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ScanlineOverlay extends StatefulWidget {
  const ScanlineOverlay({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<ScanlineOverlay> createState() => _ScanlineOverlayState();
}

class _ScanlineOverlayState extends State<ScanlineOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll;

  @override
  void initState() {
    super.initState();
    _roll = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    );
    if (widget.enabled) _roll.repeat();
  }

  @override
  void didUpdateWidget(ScanlineOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_roll.isAnimating) _roll.repeat();
    if (!widget.enabled && _roll.isAnimating) _roll.stop();
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _roll,
              builder: (context, _) => CustomPaint(
                painter: _ScanlinePainter(_roll.value),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = const Color(0x14000000);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.2), line);
    }
    final bandY = size.height * t;
    canvas.drawRect(
      Rect.fromLTWH(0, bandY, size.width, 90),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x00ffffff),
            Color(0x08ffffff),
            Color(0x00ffffff),
          ],
        ).createShader(Rect.fromLTWH(0, bandY, size.width, 90)),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: const [Color(0x00000000), Color(0x33000000)],
          stops: const [0.72, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter old) => old.t != t;
}

class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({super.key, this.width = 9, this.height = 18, this.color});

  final double width;
  final double height;
  final Color? color;

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor> {
  Timer? _timer;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (mounted) setState(() => _on = !_on);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _on ? 1 : 0,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: widget.color ?? context.palette.accent,
      ),
    );
  }
}

class TerminalBootOverlay extends StatefulWidget {
  const TerminalBootOverlay({
    super.key,
    required this.lines,
    this.onDone,
    this.charInterval = const Duration(milliseconds: 9),
    this.holdAtEnd = const Duration(milliseconds: 1200),
  });

  final List<String> lines;
  final VoidCallback? onDone;
  final Duration charInterval;
  final Duration holdAtEnd;

  @override
  State<TerminalBootOverlay> createState() => _TerminalBootOverlayState();
}

class _TerminalBootOverlayState extends State<TerminalBootOverlay> {
  final _shown = StringBuffer();
  int _line = 0;
  int _char = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.charInterval, (_) => _step());
  }

  void _step() {
    if (_line >= widget.lines.length) {
      _timer?.cancel();
      Future.delayed(widget.holdAtEnd, () => widget.onDone?.call());
      return;
    }
    final line = widget.lines[_line];
    if (_char < line.length) {
      _shown.write(line[_char]);
      _char++;
    } else {
      _shown.write('\n');
      _line++;
      _char = 0;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    _shown.toString(),
                    style: TextStyle(
                      fontFamily: kFontTerminal,
                      fontSize: 19,
                      height: 1.25,
                      color: p.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                BlinkingCursor(color: p.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
