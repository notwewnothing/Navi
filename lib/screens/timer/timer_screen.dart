import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/day_stats.dart';
import '../../services/app_blocker.dart';
import '../../services/device_usage.dart';
import '../../services/session_store.dart';
import '../../services/sfx.dart';
import '../../theme/palette.dart';
import '../../widgets/app_picker_sheet.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/routes.dart';
import '../../widgets/tactile.dart';
import '../alarm/alarm_ring_screen.dart';

enum TimerMode { focus, sleep, nap }

enum _FocusPreset { endless, m30, m60, custom }

const _napChoices = [10, 20, 30, 45];

String _two(int v) => v.toString().padLeft(2, '0');

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key, this.initialMode = TimerMode.focus});

  final TimerMode initialMode;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with WidgetsBindingObserver {
  late TimerMode _mode = widget.initialMode;
  _FocusPreset _preset = _FocusPreset.endless;
  int _customMinutes = 90;
  int _napMinutes = 20;
  int _wakeHour = 7;
  int _wakeMinute = 0;

  Timer? _ticker;
  bool _running = false;
  int _phaseSec = 0;
  int _focusSec = 0;
  int _pausedSec = 0;
  int _inAppSec = 0;
  int _remainingSec = 0;
  bool _paused = false;
  bool _completed = false;
  bool _blink = true;
  bool _appInForeground = true;
  bool _stopping = false;
  int? _targetMinutes;
  int? _phoneUsageAtStart;
  SessionStore? _store;

  int? get _focusMinutes => switch (_preset) {
    _FocusPreset.endless => null,
    _FocusPreset.m30 => 30,
    _FocusPreset.m60 => 60,
    _FocusPreset.custom => _customMinutes,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = SessionScope.of(context);
    if (_store == store) return;
    _store?.removeListener(_syncBlocking);
    _store = store;
    store.addListener(_syncBlocking);
    unawaited(_syncBlocking());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _store?.removeListener(_syncBlocking);
    unawaited(_disableBlocking());
    super.dispose();
  }


  Future<void> _syncBlocking() async {
    final store = _store;
    if (store == null) return;
    await AppBlocker.setBlockingState(
      enabled: _running &&
          _mode == TimerMode.focus &&
          !_completed &&
          store.blockApps &&
          store.blockedApps.isNotEmpty,
      strictMode: store.strictMode,
      onBreak: false,
      blockedPackages: store.blockedApps,
    );
  }

  Future<void> _disableBlocking() => AppBlocker.setBlockingState(
    enabled: false,
    strictMode: false,
    onBreak: false,
    blockedPackages: const [],
  );


  void _tick() {
    if (!mounted || _completed) return;
    setState(() {
      _blink = !_blink;
      if (_appInForeground) _inAppSec++;
      if (_paused) {
        _pausedSec++;
        return;
      }

      if (_remainingSec > 0) {
        _remainingSec--;
        _focusSec++;
        if (_remainingSec <= 0) _complete();
        return;
      }

      _phaseSec++;
      _focusSec++;

      switch (_mode) {
        case TimerMode.sleep:
          if (_sleepSecondsRemaining <= 0) _complete();
        case TimerMode.focus || TimerMode.nap:
          final target = _targetMinutes;
          if (target != null && _phaseSec >= target * 60) _complete();
      }
    });
  }

  void _start() {
    HapticFeedback.mediumImpact();
    Sfx.tick();
    final now = DateTime.now();
    _phoneUsageAtStart = null;
    final startOfDay = DateTime(now.year, now.month, now.day);
    unawaited(
      DeviceUsage.totalUsageSeconds(startOfDay, now).then((v) {
        _phoneUsageAtStart = v;
      }),
    );
    setState(() {
      _running = true;
      _stopping = false;
      _phaseSec = 0;
      _focusSec = 0;
      _pausedSec = 0;
      _inAppSec = 0;
      _remainingSec = 0;
      _paused = false;
      _completed = false;
      _blink = true;
      _targetMinutes = switch (_mode) {
        TimerMode.focus => _focusMinutes,
        TimerMode.nap => _napMinutes,
        TimerMode.sleep => null,
      };
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(_syncBlocking());
  }

  void _complete() {
    HapticFeedback.heavyImpact();
    if (_mode != TimerMode.sleep) Sfx.complete();
    _completed = true;
    unawaited(_syncBlocking());
    if (_mode == TimerMode.sleep) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showSleepEndRing());
      });
    }
  }

  Future<void> _showSleepEndRing() async {
    final action = await Navigator.of(context).push<String>(
      zoomFadeRoute(const AlarmRingScreen(sleepEndMode: true)),
    );
    if (!mounted) return;
    if (action == 'stop') {
      await _finishAndRecord();
    } else if (action == 'snooze') {
      setState(() {
        _remainingSec = 600;
        _completed = false;
        _paused = false;
      });
      unawaited(_syncBlocking());
    }
  }


  Future<bool> _strictAllows(SessionStore store) async {
    if (_mode != TimerMode.focus || !store.strictMode || _completed) {
      return true;
    }
    HapticFeedback.heavyImpact();
    final yes = await showPixelDialog<bool>(
      context: context,
      title: 'BREAK STRICT MODE?',
      builder: (context) => Text(
        'THIS SESSION IS LOCKED. LEAVING NOW DEFEATS THE POINT.',
        style: TextStyle(
          fontFamily: kFontTerminal,
          fontSize: 19,
          height: 1.25,
          color: context.palette.textDim,
        ),
      ),
      actions: (context) => [
        DialogAction(
          label: 'STAY',
          onTap: () => Navigator.pop(context, false),
        ),
        DialogAction(
          label: 'BREAK',
          danger: true,
          onTap: () => Navigator.pop(context, true),
        ),
      ],
    );
    return yes == true;
  }

  Future<void> _togglePause() async {
    final store = _store;
    if (store == null || _completed) return;
    if (!_paused && !await _strictAllows(store)) return;
    HapticFeedback.mediumImpact();
    Sfx.tick();
    if (mounted) setState(() => _paused = !_paused);
  }

  Future<void> _stopPressed() async {
    final store = _store;
    if (store == null || _stopping) return;
    if (!_completed && !await _strictAllows(store)) return;
    await _finishAndRecord();
  }

  Future<void> _finishAndRecord() async {
    final store = _store;
    if (store == null || _stopping) return;
    _stopping = true;
    HapticFeedback.heavyImpact();
    _ticker?.cancel();
    _ticker = null;
    final deviceDistracted =
        _mode == TimerMode.focus && _phoneUsageAtStart != null
        ? await _computeDeviceDistracted()
        : 0;
    await store.recordSession(
      _mode == TimerMode.focus ? SessionKind.focus : SessionKind.sleep,
      activeSeconds: _mode == TimerMode.focus
          ? _focusSec - (_pausedSec + deviceDistracted)
          : _focusSec + _pausedSec,
      distractedSeconds: _mode == TimerMode.focus
          ? _pausedSec + deviceDistracted
          : 0,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<int> _computeDeviceDistracted() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final totalNow = await DeviceUsage.totalUsageSeconds(startOfDay, now);
    final increase = totalNow - (_phoneUsageAtStart ?? 0);
    return DeviceUsage.computeDistractedSeconds(
      phoneUsageIncrease: increase,
      inAppSeconds: _inAppSec,
    );
  }


  int get _sleepSecondsRemaining {
    final now = DateTime.now();
    final targetMin = _wakeHour * 60 + _wakeMinute;
    final currentMin = now.hour * 60 + now.minute;
    var diffMin = targetMin - currentMin;
    if (diffMin < 0) diffMin += 1440;
    var diffSec = diffMin * 60 - now.second;
    if (diffSec < 0) diffSec = 0;
    return diffSec.clamp(0, 599940);
  }

  String _fmt(int seconds) {
    final big = seconds >= 6000 ? seconds ~/ 3600 : seconds ~/ 60;
    final small = seconds >= 6000 ? (seconds % 3600) ~/ 60 : seconds % 60;
    return '${_two(big)}:${_two(small)}';
  }

  String get _display {
    if (!_running) {
      return switch (_mode) {
        TimerMode.focus =>
          _focusMinutes == null ? '00:00' : _fmt(_focusMinutes! * 60),
        TimerMode.nap => _fmt(_napMinutes * 60),
        TimerMode.sleep => '${_two(_wakeHour)}:${_two(_wakeMinute)}',
      };
    }
    if (_remainingSec > 0) return _fmt(_remainingSec);
    final seconds = switch (_mode) {
      TimerMode.sleep => _sleepSecondsRemaining,
      TimerMode.focus || TimerMode.nap =>
        _targetMinutes == null
            ? _phaseSec
            : (_targetMinutes! * 60 - _phaseSec).clamp(0, 599940),
    };
    return _fmt(seconds);
  }

  int get _minutesLeft =>
      (((_targetMinutes ?? 0) * 60 - _phaseSec).clamp(0, 599940) / 60).ceil();

  String get _modeLabel {
    if (!_running) {
      return switch (_mode) {
        TimerMode.focus =>
          _focusMinutes == null
              ? 'ENDLESS — RUNS UNTIL YOU STOP'
              : 'FOCUS — ${minutesLabel(_focusMinutes!)}',
        TimerMode.sleep =>
          'SLEEP — ENDS AT ${_two(_wakeHour)}:${_two(_wakeMinute)}',
        TimerMode.nap => 'NAP — ${minutesLabel(_napMinutes)}',
      };
    }
    if (_remainingSec > 0) {
      return 'SNOOZING — ${(_remainingSec / 60).ceil()} MIN LEFT';
    }
    if (_completed) return 'SESSION COMPLETE';
    if (_paused) return 'PAUSED — COUNTS AS DISTRACTED';
    return switch (_mode) {
      TimerMode.sleep =>
        'SLEEP — ENDS AT ${_two(_wakeHour)}:${_two(_wakeMinute)}',
      TimerMode.focus when _targetMinutes == null =>
        'ENDLESS — RUNS UNTIL YOU STOP',
      TimerMode.focus => 'FOCUS — ${_minutesLeft}M LEFT',
      TimerMode.nap => 'NAP — ${_minutesLeft}M LEFT',
    };
  }


  Future<void> _pickCustomMinutes() async {
    var selected = _customMinutes;
    final ok = await showPixelDialog<bool>(
      context: context,
      title: 'CUSTOM DURATION',
      builder: (context) => _MinuteWheel(
        initial: _customMinutes,
        onChanged: (v) => selected = v,
      ),
      actions: (context) => [
        DialogAction(
          label: 'CANCEL',
          onTap: () => Navigator.pop(context, false),
        ),
        DialogAction(
          label: 'SET',
          emphasized: true,
          onTap: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok == true && mounted) {
      setState(() {
        _customMinutes = selected;
        _preset = _FocusPreset.custom;
      });
    }
  }

  Future<bool> _editBlockedList(SessionStore store) async {
    HapticFeedback.selectionClick();
    final result = await showAppPickerSheet(
      context,
      initial: store.blockedApps,
    );
    if (result == null) return false;
    await store.setBlockedApps(result);
    return true;
  }

  Future<void> _toggleBlocking(SessionStore store, bool value) async {
    if (value && store.blockedApps.isEmpty) {
      final saved = await _editBlockedList(store);
      if (!saved || store.blockedApps.isEmpty) return;
    }
    if (value && !await AppBlocker.isAccessibilityEnabled() && mounted) {
      await showPixelDialog<void>(
        context: context,
        title: 'ENABLE APP BLOCKING',
        builder: (context) => Text(
          'TURN ON NAVI APP BLOCKER IN ACCESSIBILITY SETTINGS.',
          style: TextStyle(
            fontFamily: kFontTerminal,
            fontSize: 19,
            height: 1.25,
            color: context.palette.textDim,
          ),
        ),
        actions: (context) => [
          DialogAction(label: 'LATER', onTap: () => Navigator.pop(context)),
          DialogAction(
            label: 'OPEN',
            emphasized: true,
            onTap: () {
              unawaited(AppBlocker.openAccessibilitySettings());
              Navigator.pop(context);
            },
          ),
        ],
      );
    }
    await store.setBlockApps(value);
  }

  void _onBack() {
    if (_running) {
      unawaited(_stopPressed());
    } else {
      Navigator.of(context).pop();
    }
  }


  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = SessionScope.of(context);

    return PopScope(
      canPop: !_running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_stopPressed());
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              PixelHeader(
                title: 'PROTOCOL',
                leading: PixelIconButton(glyph: Px.left, onTap: _onBack),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _running
                      ? _buildRunning(p)
                      : _buildIdle(p, store),
                ),
              ),
              _StatsBar(
                store: store,
                showBlocking: _running &&
                    _mode == TimerMode.focus &&
                    !_completed &&
                    store.blockApps &&
                    store.blockedApps.isNotEmpty,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildIdle(NaviPalette p, SessionStore store) {
    return ListView(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        _reveal(0, _modeToggle()),
        const SizedBox(height: 24),
        _reveal(
          1,
          Column(
            children: [
              _GhostClock(text: _display, showColon: true),
              const SizedBox(height: 8),
              _label(p),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _reveal(
          2,
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              child: KeyedSubtree(
                key: ValueKey(_mode),
                child: switch (_mode) {
                  TimerMode.focus => _focusConfig(p, store),
                  TimerMode.sleep => _sleepConfig(p),
                  TimerMode.nap => _napConfig(p),
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _reveal(
          3,
          PixelButton(
            label: 'START',
            glyph: Px.play,
            filled: true,
            expand: true,
            height: 56,
            onTap: _start,
          ),
        ),
      ],
    );
  }

  Widget _modeToggle() {
    const labels = {
      TimerMode.focus: 'FOCUS',
      TimerMode.sleep: 'SLEEP',
      TimerMode.nap: 'NAP',
    };
    return Row(
      children: [
        for (final (i, mode) in TimerMode.values.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: PixelChip(
              label: labels[mode]!,
              selected: _mode == mode,
              onTap: () => setState(() => _mode = mode),
            ),
          ),
        ],
      ],
    );
  }

  Widget _label(NaviPalette p) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        _modeLabel,
        key: ValueKey(_modeLabel),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kFontTerminal,
          fontSize: 18,
          letterSpacing: 2,
          color: p.textDim,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _focusConfig(NaviPalette p, SessionStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DURATION', style: p.h2),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PixelChip(
                label: 'ENDLESS',
                selected: _preset == _FocusPreset.endless,
                onTap: () => setState(() => _preset = _FocusPreset.endless),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: PixelChip(
                label: '30M',
                selected: _preset == _FocusPreset.m30,
                onTap: () => setState(() => _preset = _FocusPreset.m30),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: PixelChip(
                label: '60M',
                selected: _preset == _FocusPreset.m60,
                onTap: () => setState(() => _preset = _FocusPreset.m60),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: PixelChip(
                label: 'CUSTOM',
                selected: _preset == _FocusPreset.custom,
                onTap: () => unawaited(_pickCustomMinutes()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _blockCard(p, store),
      ],
    );
  }

  Widget _blockCard(NaviPalette p, SessionStore store) {
    return PixelCard(
      child: Column(
        children: [
          Row(
            children: [
              PixelIcon(Px.block, color: p.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Tactile(
                  pressedScale: 0.97,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(_editBlockedList(store)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BLOCK APPS',
                          style: p.label.copyWith(
                            color: p.text,
                            fontSize: 8,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          store.blockedApps.isEmpty
                              ? 'TAP TO EDIT LIST'
                              : 'BLOCKING ${store.blockedApps.length} APPS',
                          style: TextStyle(
                            fontFamily: kFontTerminal,
                            fontSize: 15,
                            color: p.textDim,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PixelSwitch(
                value: store.blockApps,
                onChanged: (value) =>
                    unawaited(_toggleBlocking(store, value)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PixelButton(
            label: store.strictMode ? 'STRICT MODE ON' : 'ACTIVATE STRICT MODE',
            glyph: Px.lock,
            filled: store.strictMode,
            expand: true,
            height: 44,
            onTap: () {
              Sfx.tick();
              unawaited(store.setStrictMode(!store.strictMode));
            },
          ),
        ],
      ),
    );
  }

  Widget _sleepConfig(NaviPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WAKE AT', style: p.h2),
        const SizedBox(height: 4),
        _WakeWheels(
          hour: _wakeHour,
          minute: _wakeMinute,
          onChanged: (hour, minute) => setState(() {
            _wakeHour = hour;
            _wakeMinute = minute;
          }),
        ),
      ],
    );
  }

  Widget _napConfig(NaviPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DURATION', style: p.h2),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (i, minutes) in _napChoices.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: PixelChip(
                  label: '${minutes}M',
                  selected: _napMinutes == minutes,
                  onTap: () => setState(() => _napMinutes = minutes),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _reveal(int index, Widget child) {
    final total = 400 + index * 80;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval((index * 80) / total, 1, curve: Curves.easeOutCubic),
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }


  Widget _buildRunning(NaviPalette p) {
    return Padding(
      key: const ValueKey('running'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _GhostClock(
            text: _display,
            showColon: _blink || _paused || _completed,
            dimmed: _paused,
          ),
          const SizedBox(height: 10),
          _label(p),
          const Spacer(flex: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  border: Border.all(color: p.borderHi, width: 1.5),
                ),
                child: Center(
                  child: PixelIconButton(
                    glyph: _completed ? Px.check : Px.stop,
                    color: p.accent,
                    size: 20,
                    onTap: () => unawaited(_stopPressed()),
                  ),
                ),
              ),
              const SizedBox(width: 22),
              Tactile(
                pressedScale: 0.88,
                child: GestureDetector(
                  onTap: _completed ? null : () => unawaited(_togglePause()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 76,
                    height: 76,
                    color: _completed ? p.accentGhost : p.accent,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: PixelIcon(
                          _paused ? Px.play : Px.pause,
                          key: ValueKey(_paused),
                          color: Colors.black,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _GhostClock extends StatelessWidget {
  const _GhostClock({
    required this.text,
    required this.showColon,
    this.dimmed = false,
  });

  final String text;
  final bool showColon;
  final bool dimmed;

  static const _bg = '88:88';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ghost = p.textGhost.withValues(alpha: 0.15);
    final digitStyle = TextStyle(
      fontFamily: kFontTerminal,
      fontSize: 110,
      height: 1,
      color: p.accent,
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: dimmed ? 0.35 : 1,
      child: SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.fitWidth,
          child: text.length != _bg.length
              ? Text(text, style: digitStyle)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _bg.length; i++)
                      Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          Text(
                            _bg[i],
                            style: digitStyle.copyWith(color: ghost),
                          ),
                          Transform.translate(
                            offset: text[i] == '1'
                                ? const Offset(5, 0)
                                : Offset.zero,
                            child: Text(
                              text[i],
                              style: _bg[i] == ':' && !showColon
                                  ? digitStyle.copyWith(
                                      color: Colors.transparent,
                                    )
                                  : digitStyle,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.store, required this.showBlocking});

  final SessionStore store;
  final bool showBlocking;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: showBlocking
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PixelIcon(Px.block, color: p.accentMid, size: 12),
                        const SizedBox(width: 8),
                        Text(
                          'BLOCKING ${store.blockedApps.length} APPS',
                          style: p.label.copyWith(color: p.accentMid),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Row(
            children: [
              _stat(p, 'STREAK', '${store.focusStreak}D'),
              _stat(p, 'FOCUS TODAY', minutesLabel(store.focusedTodayMin)),
              _stat(p, 'SLEEP LAST', minutesLabel(store.sleepLastMin)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(NaviPalette p, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: p.label),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: kFontTerminal,
              fontSize: 26,
              color: p.text,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _WakeWheels extends StatefulWidget {
  const _WakeWheels({
    required this.hour,
    required this.minute,
    required this.onChanged,
  });

  final int hour;
  final int minute;
  final void Function(int hour, int minute) onChanged;

  @override
  State<_WakeWheels> createState() => _WakeWheelsState();
}

class _WakeWheelsState extends State<_WakeWheels> {
  late final FixedExtentScrollController _hourCtrl =
      FixedExtentScrollController(initialItem: widget.hour);
  late final FixedExtentScrollController _minCtrl =
      FixedExtentScrollController(initialItem: widget.minute);
  late int _hour = widget.hour;
  late int _minute = widget.minute;

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 156,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 58,
            margin: const EdgeInsets.symmetric(horizontal: 56),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: p.border),
                bottom: BorderSide(color: p.border),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PixelWheel(
                itemCount: 24,
                controller: _hourCtrl,
                labelFor: _two,
                width: 86,
                fontSize: 46,
                onChanged: (i) {
                  _hour = i;
                  widget.onChanged(_hour, _minute);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontFamily: kFontTerminal,
                    fontSize: 46,
                    color: p.textDim,
                    height: 1,
                  ),
                ),
              ),
              PixelWheel(
                itemCount: 60,
                controller: _minCtrl,
                labelFor: _two,
                width: 86,
                fontSize: 46,
                onChanged: (i) {
                  _minute = i;
                  widget.onChanged(_hour, _minute);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MinuteWheel extends StatefulWidget {
  const _MinuteWheel({required this.initial, required this.onChanged});

  final int initial;
  final ValueChanged<int> onChanged;

  @override
  State<_MinuteWheel> createState() => _MinuteWheelState();
}

class _MinuteWheelState extends State<_MinuteWheel> {
  late final FixedExtentScrollController _ctrl = FixedExtentScrollController(
    initialItem: ((widget.initial ~/ 5) - 1).clamp(0, 35),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 170,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PixelWheel(
            itemCount: 36,
            controller: _ctrl,
            labelFor: (i) => '${(i + 1) * 5}',
            width: 90,
            fontSize: 44,
            onChanged: (i) => widget.onChanged((i + 1) * 5),
          ),
          const SizedBox(width: 12),
          Text('MIN', style: p.label),
        ],
      ),
    );
  }
}
