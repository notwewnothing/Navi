import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/alarm.dart';
import '../../services/alarm_buzz.dart';
import '../../services/alarm_store.dart';
import '../../services/easter_eggs.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/glitch.dart';
import '../../widgets/pixel_widgets.dart';

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
  String _wakeLine = EasterEggs.randomWakeLine();

  // app-lifetime state so snooze taunts escalate across all ring instances
  static int _sessionSnoozes = 0;

  // hard cap, the alarm never rings longer than 33 minutes
  static const _sequenceLength = Duration(minutes: 33);

  @override
  void initState() {
    super.initState();

    _buzz.start(alarmId: widget.alarm?.id);

    _flash = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (widget.sleepEndMode) SystemSound.play(SystemSoundType.alert);
      if (mounted) setState(() => _bright = !_bright);
    });

    _lineTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _rotateLine();
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

  void _rotateLine() {
    var next = EasterEggs.randomWakeLine();
    var guard = 0;
    // avoid repeating the same wake line, give up after 8 tries
    while (next == _wakeLine && ++guard < 8) {
      next = EasterEggs.randomWakeLine();
    }
    if (mounted) setState(() => _wakeLine = next);
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
    _sessionSnoozes++;
    if (!mounted) return;
    if (_sessionSnoozes >= 10) {
      EasterEggs.glitchMoment(context, lainSnoozeTaunt);
    }
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
        backgroundColor: Colors.black,
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
                padding: const EdgeInsets.all(24),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  builder: (context, t, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      _reveal(t, 0, _timeBlock(p, displayTime)),
                      const SizedBox(height: 22),
                      _reveal(
                        t,
                        1,
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeOut,
                          child: Text(
                            _wakeLine,
                            key: ValueKey(_wakeLine),
                            textAlign: TextAlign.center,
                            style: p.quote.copyWith(fontSize: 24),
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
                        const SizedBox(height: 16),
                      ],
                      _reveal(t, 2, _snoozeButtons()),
                      const SizedBox(height: 12),
                      _reveal(
                        t,
                        3,
                        PixelButton(
                          label: 'STOP',
                          filled: true,
                          expand: true,
                          height: 68,
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
            style: p.h2.copyWith(color: p.textDim),
          ),
          const SizedBox(height: 14),
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
              child: GlitchText(
                displayTime,
                intensity: 0.06,
                interval: const Duration(seconds: 3),
                style: TextStyle(
                  fontFamily: kFontTerminal,
                  fontSize: 170,
                  color: p.accent,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _snoozeButtons() {
    if (widget.sleepEndMode) {
      return PixelButton(
        label: 'SNOOZE',
        expand: true,
        height: 68,
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
              if (i > 0) const SizedBox(width: 10),
              PixelButton(
                label: 'SNOOZE $minutes',
                height: 68,
                onTap: () => _snooze(minutes),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
