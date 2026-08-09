import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../widgets/glitch.dart';
import 'sfx.dart';

const lainTaglines = <String>[
  'Welcome to the Wired, Lain.',
  'Present day... present time...',
  'No matter where you go, everyone\'s connected.',
  'The Wired might actually be thought of as a highly advanced upper layer of the real world.',
  'If you\'re not remembered, you never existed.',
  'You don\'t seem to understand. There is no "you" without the Wired.',
  'Close the world. Open the nExt.',
  'God is here.',
  'I\'m right here... so come to the Wired as soon as you can.',
  'Everyone is connected.',
];

const lainWakeLines = <String>[
  'Wake up, Lain.',
  'Present day... present time...',
  'The other side is waiting.',
  'You are needed in the real world.',
  'The border between here and there is thin at dawn.',
];

const lainSnoozeTaunt = "You can't escape the Wired.";

const wiredBootLines = <String>[
  'NAVI COPLAND OS ENTERPRISE',
  'BIOS v2.0.1 — TACHIBANA LAB',
  '',
  'MEM CHECK ............... 640K OK',
  'PSYCHE PROCESSOR ........ FOUND',
  'PROTOCOL 7 .............. LOADED',
  'WIRED UPLINK ............ SYNCED',
  'REAL WORLD INTERFACE .... DEGRADED',
  '',
  '> no matter where you go,',
  '> everyone\'s connected.',
  '',
  'PRESENT DAY ... PRESENT TIME ...',
];

abstract final class EasterEggs {
  static final _rng = Random();
  // once per session so typing "lain" in search can't spam the glitch overlay
  static bool _lainTriggeredThisSession = false;

  static String randomWakeLine() =>
      lainWakeLines[_rng.nextInt(lainWakeLines.length)];

  static void watchText(BuildContext context, String text) {
    if (_lainTriggeredThisSession) return;
    if (!RegExp(r'\blain\b', caseSensitive: false).hasMatch(text)) return;
    _lainTriggeredThisSession = true;
    glitchMoment(context, 'Present day, present time...');
  }

  static void glitchMoment(BuildContext context, String message) {
    final overlay = Overlay.of(context, rootOverlay: true);
    Sfx.glitch();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _GlitchMoment(
        message: message,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  static void wiredBoot(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    Sfx.glitch();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => TerminalBootOverlay(
        lines: wiredBootLines,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  static void whisper(BuildContext context, String message) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _Whisper(
        message: message,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _GlitchMoment extends StatefulWidget {
  const _GlitchMoment({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_GlitchMoment> createState() => _GlitchMomentState();
}

class _GlitchMomentState extends State<_GlitchMoment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final tear = t < 0.18 ? t / 0.18 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
        final opacity = t > 0.85 ? (1 - t) / 0.15 : 1.0;
        return IgnorePointer(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: GlitchTear(
              progress: (tear * 0.5).clamp(0.001, 0.999),
              seed: 13,
              child: Material(
                color: Colors.black.withValues(alpha: 0.92),
                child: Center(
                  child: GlitchText(
                    widget.message,
                    intensity: 0.2,
                    interval: const Duration(milliseconds: 500),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kFontTerminal,
                      fontSize: 30,
                      color: p.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Whisper extends StatefulWidget {
  const _Whisper({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_Whisper> createState() => _WhisperState();
}

class _WhisperState extends State<_Whisper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final opacity = t < 0.25
            ? t / 0.25
            : t > 0.7
            ? (1 - t) / 0.3
            : 1.0;
        return IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: (opacity * 0.85).clamp(0.0, 1.0),
              child: Material(
                color: Colors.transparent,
                child: Text(
                  widget.message,
                  style: TextStyle(
                    fontFamily: kFontTerminal,
                    fontSize: 26,
                    color: p.textDim,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
