import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../widgets/pixel_icons.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            
            Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, color: p.accent),
                    const SizedBox(width: 10),
                    Text('NAVI', style: p.logo),
                  ],
                ),
                const Spacer(),
                PixelIcon(Px.gear, color: p.textDim, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Present day... present time...",
              style: p.quote,
            ),
            const SizedBox(height: 22),

            
            Text("TODAY'S PROGRESS", style: p.h2),
            const SizedBox(height: 12),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final items = [
                    (Px.flame, 'WORK OUT', 5, true),
                    (Px.book, 'READ', 12, true),
                    (Px.heart, 'MEDITATE', 3, false),
                  ];
                  final (icon, name, streak, done) = items[i];
                  return _HabitCard(
                    icon: icon,
                    name: name,
                    streak: streak,
                    done: done,
                  );
                },
              ),
            ),
            const SizedBox(height: 26),

            
            Text('PROTOCOLS', style: p.h2),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'FOCUS',
                    glyph: Px.eye,
                    color: p.accent,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: 'SLEEP',
                    glyph: Px.moon,
                    color: p.accent,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: 'STATS',
                    glyph: Px.chart,
                    color: p.accent,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.icon,
    required this.name,
    required this.streak,
    required this.done,
  });

  final PixelGlyph icon;
  final String name;
  final int streak;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: done ? p.panelHi : p.panel,
          border: Border.all(color: done ? p.accentDim : p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PixelIcon(icon, color: done ? p.accent : p.textDim, size: 18),
                const Spacer(),
                PixelIcon(
                  done ? Px.check : Px.circle,
                  color: done ? p.accent : p.textGhost,
                  size: 16,
                ),
              ],
            ),
            const Spacer(),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kFontTerminal,
                fontSize: 19,
                height: 1.05,
                color: done ? p.text : p.textDim,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                PixelIcon(
                  Px.flame,
                  color: streak > 0 ? p.accentMid : p.textGhost,
                  size: 11,
                ),
                const SizedBox(width: 5),
                Text(
                  '$streak',
                  style: p.label.copyWith(
                    color: streak > 0 ? p.accentMid : p.textGhost,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.glyph,
    required this.color,
    required this.onTap,
  });

  final String label;
  final PixelGlyph glyph;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PixelIcon(glyph, color: color, size: 14),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: kFontPixel,
                    fontSize: 9,
                    letterSpacing: 1.5,
                    color: color,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
