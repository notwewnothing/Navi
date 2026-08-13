import 'package:flutter/material.dart';

import '../../services/settings_store.dart';
import '../../theme/palette.dart';
import '../../widgets/routes.dart';
import '../blocker/app_block_screen.dart';
import '../stats/screen_time_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = SettingsScope.of(context);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Text('SYSTEM', style: p.h1),
            const SizedBox(height: 20),
            _section(
              p,
              title: 'SOUND & DISPLAY',
              children: [
                _row(
                  p,
                  glyph: '\u{1F50A}',
                  label: 'SFX',
                  trailing: _switch(p, settings.sfxEnabled, (v) {
                    settings.setSfxEnabled(v);
                  }),
                ),
                _divider(p),
                _row(
                  p,
                  glyph: '\u{1F4D6}',
                  label: 'FONT SIZE',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (lbl, scale) in [
                        ('S', 0.85),
                        ('M', 1.0),
                        ('L', 1.15),
                      ]) ...[
                        if (scale > 0.85) const SizedBox(width: 6),
                        _chip(
                          p,
                          label: lbl,
                          selected: (settings.fontScale - scale).abs() < 0.01,
                          onTap: () => settings.setFontScale(scale),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _section(
              p,
              title: 'FOCUS',
              children: [
                _row(
                  p,
                  glyph: '\u{25A0}',
                  label: 'BLOCK RULES',
                  onTap: () => Navigator.of(
                    context,
                  ).push(slideUpRoute(const AppBlockScreen())),
                ),
                _divider(p),
                _row(
                  p,
                  glyph: '\u{25D0}',
                  label: 'SCREEN TIME',
                  onTap: () => Navigator.of(
                    context,
                  ).push(slideUpRoute(const ScreenTimeScreen())),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _section(
              p,
              title: 'ABOUT',
              children: [
                _row(p, glyph: '\u{25C9}', label: 'NAVI v1.0'),
              ],
              footer: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  'Present day. Present time.\nAnd you are still here.',
                  style: p.quote.copyWith(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    NaviPalette p, {
    required String title,
    required List<Widget> children,
    Widget? footer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: p.h2),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: p.border),
            color: p.panel,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) Container(height: 1, color: p.border),
                child,
              ],
            ],
          ),
        ),
        ?footer,
      ],
    );
  }

  Widget _row(
    NaviPalette p, {
    required String glyph,
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Text(glyph, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: kFontPixel,
                fontSize: 8,
                letterSpacing: 1,
                color: p.text,
                height: 1.5,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }

  Widget _divider(NaviPalette p) => Container(height: 1, color: p.border);

  Widget _switch(NaviPalette p, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 44,
        height: 22,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? p.accentGhost : p.panelHi,
          border: Border.all(color: value ? p.accent : p.border, width: 1.5),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(width: 12, height: 12, color: value ? p.accent : p.textGhost),
        ),
      ),
    );
  }

  Widget _chip(NaviPalette p, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? p.accent : Colors.transparent,
          border: Border.all(color: selected ? p.accent : p.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: kFontPixel,
            fontSize: 7,
            letterSpacing: 1,
            color: selected ? Colors.black : p.textDim,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

