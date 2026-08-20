import 'package:flutter/material.dart';

// Ndot-55, the Nothing display face. Dot matrix, so it only reads well large
// or with wide tracking; body copy uses the system grotesque instead.
const kFontDot = 'Ndot';
const kFontUI = 'Roboto';

const kFontPixel = 'PixelDisplay';
const kFontTerminal = 'Terminal';

// Nothing rounds hard. Cards and sheets are near-squircles, controls are pills.
abstract final class NdRadius {
  static const card = 24.0;
  static const inner = 16.0;
  static const small = 12.0;
  static const pill = 999.0;
  static const sheet = 32.0;
}

// 4pt scale. Screens should reach for these instead of ad-hoc numbers.
abstract final class NdSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  // gutter used by every screen's outer padding
  static const page = 20.0;
}

class Accent {
  const Accent({
    required this.name,
    required this.l1,
    required this.l2,
    required this.l3,
    required this.l4,
  });

  final String name;
  // 4-step ramp ghost to dim to mid to bright, l4 is the accent, l1 blends into the background
  final Color l1;
  final Color l2;
  final Color l3;
  final Color l4;

  Color get accent => l4;
  Color get dim => l2;
}

const accents = <Accent>[
  Accent(
    name: 'NOTHING RED',
    l1: Color(0xff2e0508),
    l2: Color(0xff6e0c11),
    l3: Color(0xffa8121a),
    l4: Color(0xffd71921),
  ),
  Accent(
    name: 'MONO WHITE',
    l1: Color(0xff2a2a2a),
    l2: Color(0xff6e6e6e),
    l3: Color(0xffc4c4c4),
    l4: Color(0xffffffff),
  ),
  Accent(
    name: 'GLYPH ORANGE',
    l1: Color(0xff2e1400),
    l2: Color(0xff7a3400),
    l3: Color(0xffc25200),
    l4: Color(0xffff6d00),
  ),
  Accent(
    name: 'SIGNAL BLUE',
    l1: Color(0xff08182e),
    l2: Color(0xff163d7a),
    l3: Color(0xff2260c4),
    l4: Color(0xff2e7dff),
  ),
  Accent(
    name: 'PULSE GREEN',
    l1: Color(0xff032117),
    l2: Color(0xff0a5e3c),
    l3: Color(0xff109660),
    l4: Color(0xff16c47f),
  ),
];

const habitDotColors = <Color>[
  Color(0xffd71921),
  Color(0xffff6d00),
  Color(0xffffc700),
  Color(0xff16c47f),
  Color(0xff2e7dff),
  Color(0xffb06bff),
  Color(0xffffffff),
];

class NaviPalette {
  const NaviPalette(this.accentRamp, {this.amoled = false});

  final Accent accentRamp;

  // Flattens every surface to black and leans on outlines instead of fills.
  final bool amoled;

  Color get bg => const Color(0xff000000);
  Color get panel => amoled ? const Color(0xff000000) : const Color(0xff131313);
  Color get panelHi =>
      amoled ? const Color(0xff0d0d0d) : const Color(0xff1c1c1c);
  Color get border =>
      amoled ? const Color(0xff333333) : const Color(0xff2a2a2a);
  Color get borderHi =>
      amoled ? const Color(0xff4a4a4a) : const Color(0xff3d3d3d);

  Color get text => const Color(0xffffffff);
  Color get textDim => const Color(0xffa0a0a0);
  Color get textGhost => const Color(0xff5a5a5a);

  Color get accent => accentRamp.l4;
  Color get accentMid => accentRamp.l3;
  Color get accentDim => accentRamp.l2;
  Color get accentGhost => accentRamp.l1;

  // Foreground for anything sitting on a filled accent surface.
  Color get onAccent =>
      accentRamp.l4.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  // level 0 = nothing done, 4 = done, anything past 4 stays on l4
  Color boardLevel(int level) => switch (level) {
    <= 0 => const Color(0xff1a1a1a),
    1 => accentRamp.l1,
    2 => accentRamp.l2,
    3 => accentRamp.l3,
    _ => accentRamp.l4,
  };

  Color get focusDot => accent;
  Color get sleepDot => const Color(0xff2e7dff);
  Color get alarmDot => const Color(0xffd71921);
  Color get blockDot => const Color(0xff8a8a8a);
  Color get journalDot => const Color(0xffffffff);

  Color get danger => const Color(0xffd71921);

  // Ndot at an arbitrary size. Used for clocks, counters, anything numeric.
  TextStyle dot(
    double size, {
    Color? color,
    double letterSpacing = 1,
    FontWeight? weight,
  }) => TextStyle(
    fontFamily: kFontDot,
    fontSize: size,
    color: color ?? text,
    letterSpacing: letterSpacing,
    fontWeight: weight,
    height: 1.1,
  );

  TextStyle get logo => TextStyle(
    fontFamily: kFontDot,
    fontSize: 22,
    color: text,
    letterSpacing: 4,
    height: 1.2,
  );

  // Screen titles.
  TextStyle get h1 => TextStyle(
    fontFamily: kFontDot,
    fontSize: 26,
    color: text,
    letterSpacing: 1.5,
    height: 1.2,
  );

  // Section labels above a group of content.
  TextStyle get h2 => TextStyle(
    fontFamily: kFontUI,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: textDim,
    letterSpacing: 1.8,
    height: 1.4,
  );

  // Card and row headings.
  TextStyle get title => TextStyle(
    fontFamily: kFontUI,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: text,
    letterSpacing: -0.1,
    height: 1.3,
  );

  TextStyle get label => TextStyle(
    fontFamily: kFontUI,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textDim,
    letterSpacing: 0.3,
    height: 1.3,
  );

  TextStyle get labelAccent => label.copyWith(color: accent);

  // Micro-label: uppercase, wide tracking, used on chips and meta rows.
  TextStyle get micro => TextStyle(
    fontFamily: kFontUI,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: textDim,
    letterSpacing: 1.4,
    height: 1.3,
  );

  TextStyle get body => TextStyle(
    fontFamily: kFontUI,
    fontSize: 15,
    color: text,
    letterSpacing: -0.1,
    height: 1.45,
  );

  TextStyle get bodyDim => body.copyWith(color: textDim);

  // List rows.
  TextStyle get row => TextStyle(
    fontFamily: kFontUI,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: text,
    letterSpacing: -0.1,
    height: 1.3,
  );

  TextStyle get clock => dot(88, color: text, letterSpacing: 2);

  TextStyle get quote => body.copyWith(color: textDim, fontSize: 15);

  ThemeData toThemeData() {
    final scheme = ColorScheme.dark(
      surface: bg,
      onSurface: text,
      primary: accent,
      onPrimary: onAccent,
      secondary: accentMid,
      onSecondary: onAccent,
      error: danger,
      outline: border,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: kFontUI,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accentDim,
        selectionHandleColor: accent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.circular(NdRadius.card),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(NdRadius.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panelHi,
        contentTextStyle: body,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderHi),
          borderRadius: BorderRadius.circular(NdRadius.inner),
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

class PaletteScope extends InheritedWidget {
  const PaletteScope({super.key, required this.palette, required super.child});

  final NaviPalette palette;

  static NaviPalette of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PaletteScope>();
    return scope?.palette ?? NaviPalette(accents.first);
  }

  @override
  bool updateShouldNotify(PaletteScope oldWidget) =>
      oldWidget.palette.accentRamp != palette.accentRamp ||
      oldWidget.palette.amoled != palette.amoled;
}

extension PaletteX on BuildContext {
  NaviPalette get palette => PaletteScope.of(this);
}
