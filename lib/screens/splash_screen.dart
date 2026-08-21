import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'shell.dart';

/// Nothing-style cold start: the wordmark resolves letter by letter over a
/// hairline progress rule, then hands off to the shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _word = ['N', 'A', 'V', 'I'];

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _exitTimer = Timer(const Duration(milliseconds: 2100), _exit);
  }

  void _exit() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => const NaviShell(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  // each letter gets its own slice of the first 70% of the timeline
  double _letterOpacity(int i, double t) {
    const span = 0.7;
    final slot = span / _word.length;
    return ((t - i * slot) / slot).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, ch) in _word.indexed)
                          Opacity(
                            opacity: _letterOpacity(i, t),
                            child: Text(
                              ch,
                              style: p.dot(
                                52,
                                color: p.text,
                                letterSpacing: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: NdSpace.xl),
                    Opacity(
                      opacity: ((t - 0.6) / 0.3).clamp(0.0, 1.0),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: NdSpace.xxl,
                right: NdSpace.xxl,
                bottom: 64,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        value: t,
                        minHeight: 2,
                        backgroundColor: p.panelHi,
                        valueColor: AlwaysStoppedAnimation(p.accent),
                      ),
                    ),
                    const SizedBox(height: NdSpace.md),
                    Opacity(
                      opacity: ((t - 0.2) / 0.3).clamp(0.0, 1.0),
                      child: Text(
                        'HABITS · JOURNAL · SCHEDULE',
                        style: p.micro.copyWith(color: p.textGhost),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
