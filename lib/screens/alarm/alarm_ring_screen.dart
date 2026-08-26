import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/alarm.dart';
import '../../services/alarm_buzz.dart';
import '../../services/alarm_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_widgets.dart';

class AlarmRingScreen extends StatefulWidget {
  const AlarmRingScreen({super.key, this.alarm, this.sleepEndMode = false})
    : assert(alarm != null || sleepEndMode);

  final Alarm? alarm;
  final bool sleepEndMode;

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  final _buzz = AlarmBuzz();
  Timer? _flash;
  Timer? _autoFinish;
  Timer? _lineTimer;
  Timer? _clockTimer;
  bool _bright = true;
  bool _closing = false;
  DateTime _now = DateTime.now();
  int _lineIndex = 0;

  static const _wakeLines = <String>[
    'Time to get up.',
    'Your day is waiting.',
    'Up and at it.',
    'Morning. Let\'s go.',
    'Start the day.',
  ];

  // hard cap, the alarm never rings longer than 30 minutes
  static const _sequenceLength = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();

    _buzz.start(alarmId: widget.alarm?.id);

    _flash = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (widget.sleepEndMode) SystemSound.play(SystemSoundType.alert);
      if (mounted) setState(() => _bright = !_bright);
    });

    _lineTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() => _lineIndex = (_lineIndex + 1) % _wakeLines.length);
      }
    });

    if (widget.sleepEndMode) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else {
      _autoFinish = Timer(_sequenceLength, _finish);
    }
  }

  @override
  void dispose() {
    _flash?.cancel();
    _autoFinish?.cancel();
    _lineTimer?.cancel();
    _clockTimer?.cancel();
    if (widget.sleepEndMode) {
      _buzz.stop();
    } else {
      _buzz.detach();
    }
    super.dispose();
  }

  Future<void> _finish() async {
    if (!mounted || _closing) return;
    _closing = true;
    final store = AlarmScope.of(context);
    await store.stopRinging(widget.alarm!);
    await _buzz.stop();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _snooze(int minutes) async {
    if (_closing) return;
    _closing = true;
    HapticFeedback.mediumImpact();
    Sfx.tick();

    if (widget.sleepEndMode) {
      await _buzz.stop();
      if (mounted) Navigator.of(context).pop('snooze');
      return;
    }

    final alarm = widget.alarm!;
    final store = AlarmScope.of(context);
    alarm.snoozeMinutes = minutes;
    await store.snooze(alarm);
    await _buzz.stop();
    if (!mounted) return;
    showNdToast(context, 'Snoozed for $minutes min', glyph: Nd.alarm);
    Navigator.of(context).pop();
  }

  Future<void> _stop() async {
    if (_closing) return;
    _closing = true;
    HapticFeedback.heavyImpact();
    Sfx.complete();

    if (widget.sleepEndMode) {
      await _buzz.stop();
      if (mounted) Navigator.of(context).pop('stop');
      return;
    }

    final store = AlarmScope.of(context);
    await store.stopRinging(widget.alarm!);
    await _buzz.stop();
    if (mounted) Navigator.of(context).pop();
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _reveal(double t, int index, Widget child) {
    final start = (index * 0.14).clamp(0.0, 0.6);
    final v = Curves.easeOutCubic.transform(
      ((t - start) / (1 - start)).clamp(0.0, 1.0),
    );
    return Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final displayTime = widget.sleepEndMode
        ? _fmt(_now)
        : widget.alarm!.timeLabel24;

    return PopScope(
      canPop: widget.sleepEndMode,
      child: Scaffold(
        backgroundColor: p.bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: [
                        p.accent.withValues(alpha: _bright ? 0.14 : 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(NdSpace.xl),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  builder: (context, t, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      _reveal(t, 0, _timeBlock(p, displayTime)),
                      const SizedBox(height: NdSpace.xl),
                      _reveal(
                        t,
                        1,
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeOut,
                          child: Text(
                            _wakeLines[_lineIndex],
                            key: ValueKey(_lineIndex),
                            textAlign: TextAlign.center,
                            style: p.body.copyWith(
                              fontSize: 18,
                              color: p.textDim,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (widget.sleepEndMode) ...[
                        _reveal(
                          t,
                          2,
                          Text(
                            'SLEEP SESSION COMPLETE',
                            textAlign: TextAlign.center,
                            style: p.h2.copyWith(color: p.accent),
                          ),
                        ),
                        const SizedBox(height: NdSpace.lg),
                      ],
                      _reveal(t, 2, _snoozeButtons()),
                      const SizedBox(height: NdSpace.md),
                      _reveal(
                        t,
                        3,
                        NdButton(
                          label: 'Stop',
                          filled: true,
                          expand: true,
                          height: 64,
                          onTap: _stop,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeBlock(NaviPalette p, String displayTime) {
    return Column(
      children: [
        if (!widget.sleepEndMode) ...[
          Text(
            widget.alarm!.label.toUpperCase(),
            textAlign: TextAlign.center,
            style: p.h2,
          ),
          const SizedBox(height: NdSpace.lg),
        ],
        AnimatedScale(
          scale: _bright ? 1 : 0.96,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: _bright ? 1 : 0.25,
            duration: const Duration(milliseconds: 350),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                displayTime,
                style: p.dot(150, color: p.text, letterSpacing: 4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _snoozeButtons() {
    if (widget.sleepEndMode) {
      return NdButton(
        label: 'Snooze 10 min',
        expand: true,
        height: 64,
        onTap: () => _snooze(10),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, minutes) in const [5, 10, 15].indexed) ...[
              if (i > 0) const SizedBox(width: NdSpace.md),
              NdButton(
                label: 'Snooze $minutes',
                height: 64,
                onTap: () => _snooze(minutes),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
