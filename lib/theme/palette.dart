import 'package:flutter/material.dart';

/// NAVI design language — Serial Experiments Lain.
/// Monochrome black + GitHub-green dot matrix. Two faces:
/// `PixelDisplay` (Press Start 2P) for chrome — logos, headers, labels —
/// and `Terminal` (VT323) for content — body text, numbers, times.
const kFontPixel = 'PixelDisplay';
const kFontTerminal = 'Terminal';

/// One selectable accent ramp. `l1..l4` is the commitment-board intensity
/// ramp (dim → bright); `accent` == l4 is the primary UI color.
class Accent {
  const Accent({
    required this.name,
    required this.l1,
    required this.l2,
    required this.l3,
    required this.l4,
  });

  final String name;
  final Color l1;
  final Color l2;
  final Color l3;
  final Color l4;

  Color get accent => l4;
  Color get dim => l2;
}

const accents = <Accent>[
  Accent(
    name: 'WIRED GREEN',
    l1: Color(0xff0e4429),
    l2: Color(0xff006d32),
    l3: Color(0xff26a641),
    l4: Color(0xff39d353),
  ),
  Accent(
    name: 'SIGNAL CYAN',
    l1: Color(0xff0a3d4a),
    l2: Color(0xff0d6478),
    l3: Color(0xff1f9eb8),
    l4: Color(0xff3dd6f5),
  ),
  Accent(
    name: 'PHOSPHOR AMBER',
    l1: Color(0xff4a3407),
    l2: Color(0xff7a5410),
    l3: Color(0xffb8831f),
    l4: Color(0xfff5b53d),
  ),
  Accent(
    name: 'PROTOCOL MAGENTA',
    l1: Color(0xff3d0a35),
    l2: Color(0xff6e1260),
    l3: Color(0xffa82596),
    l4: Color(0xffe83fd0),
  ),
  Accent(
    name: 'GHOST WHITE',
    l1: Color(0xff30363d),
    l2: Color(0xff6e7681),
    l3: Color(0xffb1bac4),
    l4: Color(0xfff0f6fc),
  ),
];

/// Habit dot colors, indexed by Habit.colorIndex. Index 0 = "use accent".
const habitDotColors = <Color>[
  Color(0xff39d353), // green (default)
  Color(0xff3dd6f5), // cyan
  Color(0xfff5b53d), // amber
  Color(0xffe83fd0), // magenta
  Color(0xfff85149), // red
  Color(0xff58a6ff), // blue
  Color(0xfff0f6fc), // white
];

class NaviPalette {
  const NaviPalette(this.accentRamp, {this.amoled = false});

  final Accent accentRamp;

  /// AMOLED mode: true black background, panels pulled down to match so the
  /// surface ladder keeps its proportions against it.
  final bool amoled;

  // Surfaces — near-black with a whisper of green so pure blacks (OLED) and
  // panels still separate.
  Color get bg => amoled ? const Color(0xff000000) : const Color(0xff050705);
  Color get panel =>
      amoled ? const Color(0xff070907) : const Color(0xff0c100c);
  Color get panelHi =>
      amoled ? const Color(0xff0e120e) : const Color(0xff131813);
  Color get border => const Color(0xff1d241d);
  Color get borderHi => const Color(0xff2c352c);

  // Ink.
  Color get text => const Color(0xffe6ede6);
  Color get textDim => const Color(0xff7d8a7d);
  Color get textGhost => const Color(0xff414b41);

  // Accent ramp.
  Color get accent => accentRamp.l4;
  Color get accentMid => accentRamp.l3;
  Color get accentDim => accentRamp.l2;
  Color get accentGhost => accentRamp.l1;
  Color boardLevel(int level) => switch (level) {
    <= 0 => const Color(0xff161b16),
    1 => accentRamp.l1,
    2 => accentRamp.l2,
    3 => accentRamp.l3,
    _ => accentRamp.l4,
  };

  // Event-type indicator colors (spec: schedule dots).
  Color get focusDot => accent;
  Color get sleepDot => const Color(0xff58a6ff);
  Color get alarmDot => const Color(0xfff85149);
  Color get blockDot => const Color(0xff6e7681);
  Color get journalDot => const Color(0xfff0f6fc);

  Color get danger => const Color(0xfff85149);

  // ---- Text styles ----

  TextStyle get logo => TextStyle(
    fontFamily: kFontPixel,
    fontSize: 18,
    color: text,
    letterSpacing: 2,
    height: 1.4,
  );

  /// Screen titles: chunky pixel caps.
  TextStyle get h1 => TextStyle(
    fontFamily: kFontPixel,
    fontSize: 14,
    color: text,
    letterSpacing: 2,
    height: 1.6,
  );

  /// Section headers inside a screen.
  TextStyle get h2 => TextStyle(
    fontFamily: kFontPixel,
    fontSize: 9,
    color: textDim,
    letterSpacing: 2,
    height: 1.6,
  );

  /// Tiny pixel labels (nav bar, chips, meta).
  TextStyle get label => TextStyle(
    fontFamily: kFontPixel,
    fontSize: 7,
    color: textDim,
    letterSpacing: 1,
    height: 1.6,
  );

  TextStyle get labelAccent => label.copyWith(color: accent);

  /// Terminal body copy — journal entries, descriptions.
  TextStyle get body => TextStyle(
    fontFamily: kFontTerminal,
    fontSize: 20,
    color: text,
    height: 1.15,
  );

  TextStyle get bodyDim => body.copyWith(color: textDim);

  /// Larger terminal text — habit names, list rows.
  TextStyle get row => TextStyle(
    fontFamily: kFontTerminal,
    fontSize: 24,
    color: text,
    height: 1.1,
  );

  /// Big clock digits.
  TextStyle get clock => TextStyle(
    fontFamily: kFontTerminal,
    fontSize: 96,
    color: accent,
    height: 1,
  );

  /// The cycling Lain taglines.
  TextStyle get quote => TextStyle(
    fontFamily: kFontTerminal,
    fontSize: 19,
    color: textDim,
    height: 1.2,
  );

  /// Material ThemeData so stock widgets (inputs, dialogs, sheets,
  /// pickers) fall in line without per-usage styling.
  ThemeData toThemeData() {
    final scheme = ColorScheme.dark(
      surface: bg,
      onSurface: text,
      primary: accent,
      onPrimary: Colors.black,
      secondary: accentMid,
      onSecondary: Colors.black,
      error: danger,
      outline: border,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: kFontTerminal,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accentGhost,
        selectionHandleColor: accent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panelHi,
        contentTextStyle: body,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderHi),
          borderRadius: BorderRadius.circular(4),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Inherited palette — rebuilt when the accent setting changes.
class PaletteScope extends InheritedWidget {
  const PaletteScope({super.key, required this.palette, required super.child});

  final NaviPalette palette;

  static NaviPalette of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PaletteScope>();
    return scope?.palette ?? const NaviPalette(Accent(
      name: 'WIRED GREEN',
      l1: Color(0xff0e4429),
      l2: Color(0xff006d32),
      l3: Color(0xff26a641),
      l4: Color(0xff39d353),
    ));
  }

  @override
  bool updateShouldNotify(PaletteScope oldWidget) =>
      oldWidget.palette.accentRamp != palette.accentRamp ||
      oldWidget.palette.amoled != palette.amoled;
}

extension PaletteX on BuildContext {
  NaviPalette get palette => PaletteScope.of(this);
}
