import 'dart:async';

import 'package:flutter/material.dart';

import '../services/sfx.dart';
import '../theme/palette.dart';
import '../widgets/glitch.dart';
import 'shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _tear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  bool _showSubtitle = false;
  Timer? _subtitleTimer;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _fade.forward();
    _subtitleTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _showSubtitle = true);
    });
    _exitTimer = Timer(const Duration(milliseconds: 2500), _exit);
  }

  Future<void> _exit() async {
    if (!mounted) return;
    Sfx.glitch();
    await _tear.forward();
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
    _subtitleTimer?.cancel();
    _exitTimer?.cancel();
    _fade.dispose();
    _tear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _tear,
        builder: (context, child) => GlitchTear(
          progress: (_tear.value * 0.94).clamp(0.0, 0.999),
          seed: 3,
          child: child!,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _fade,
                  curve: Curves.easeOut,
                ),
                child: const Text(
                  'NAVI',
                  style: TextStyle(
                    fontFamily: kFontPixel,
                    fontSize: 42,
                    color: Colors.white,
                    letterSpacing: 10,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              AnimatedOpacity(
                opacity: _showSubtitle ? 1 : 0,
                duration: const Duration(milliseconds: 700),
                child: const Text(
                  'Present day... present time...',
                  style: TextStyle(
                    fontFamily: kFontTerminal,
                    fontSize: 21,
                    color: Color(0xff8a938a),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
