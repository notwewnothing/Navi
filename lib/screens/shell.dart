import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sfx.dart';
import '../theme/palette.dart';
import '../widgets/pixel_icons.dart';

import 'habits/habits_screen.dart';
import 'home/home_screen.dart';


import 'settings/settings_screen.dart';


class NaviShell extends StatefulWidget {
  const NaviShell({super.key});

  @override
  State<NaviShell> createState() => NaviShellState();
}

class NaviShellState extends State<NaviShell> {
  int _index = 0;

  static const _tabs = [
    (Px.home, 'HOME'),
    (Px.grid, 'HABITS'),
    (Px.gear, 'SYSTEM'),
  ];

  
  void goTo(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          HabitsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: p.bg,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (final (i, tab) in _tabs.indexed)
                  Expanded(
                    child: _NavItem(
                      glyph: tab.$1,
                      label: tab.$2,
                      selected: i == _index,
                      onTap: () {
                        if (i == _index) return;
                        HapticFeedback.selectionClick();
                        Sfx.tick();
                        setState(() => _index = i);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final PixelGlyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.accent : p.textGhost;
    return Tactile(
      pressedScale: 0.9,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 14,
              height: 2,
              color: selected ? p.accent : Colors.transparent,
              margin: const EdgeInsets.only(bottom: 6),
            ),
            PixelIcon(glyph, color: color, size: 18),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: kFontPixel,
                fontSize: 6,
                letterSpacing: 1,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Tactile extends StatelessWidget {
  const Tactile({
    super.key,
    required this.pressedScale,
    required this.child,
  });

  final double pressedScale;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
