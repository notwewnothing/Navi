import 'package:flutter/material.dart';

const kFontPixel = 'PixelDisplay';
const kFontTerminal = 'Terminal';


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


const habitDotColors = <Color>[
  Color(0xff39d353), 
  Color(0xff3dd6f5), 
  Color(0xfff5b53d), 
  Color(0xffe83fd0), 
  Color(0xfff85149), 
  Color(0xff58a6ff), 
  Color(0xfff0f6fc), 
];

class NaviPalette {
  const NaviPalette(this.accentRamp, {this.amoled = false});

  final Accent accentRamp;

  
  final bool amoled;


  
  Color get bg => amoled ? const Color(0xff000000) : const Color(0xff050705);
  Color get panel =>
      amoled ? const Color(0xff070907) : const Color(0xff0c100c);
  Color get panelHi =>
      amoled ? const Color(0xff0e120e) : const Color(0xff131813);
  Color get border => const Color(0xff1d241d);
  Color get borderHi => const Color(0xff2c352c);

  
  Color get text => const Color(0xffe6ede6);
  Color get textDim => const Color(0xff7d8a7d);
  Color get textGhost => const Color(0xff414b41);

  Color get accent => accentRamp.l4;
  Color get accentMid => accentRamp.l3;
  Color get accentDim => accentRamp.l2;
  Color get accentGhost => accentRamp.l1;
  // level 0 = nothing done, 4 = done, anything past 4 stays on l4
  Color boardLevel(int level) => switch (level) {
    <= 0 => const Color(0xff161b16),
    1 => accentRamp.l1,
    2 => accentRamp.l2,
    3 => accentRamp.l3,
    _ => accentRamp.l4,
  };

  Color get focusDot => accent;
  Color get sleepDot => const Color(0xff58a6ff);
  Color get alarmDot => const Color(0xfff85149);
  Color get blockDot => const Color(0xff6e7681);
  Color get journalDot => const Color(0xfff0f6fc);

  Color get danger => const Color(0xfff85149);

  

  TextStyle get logo => TextStyle(
    fontFamily: kFontPixel,
    fontSize: 18,
    color: text,
    letterSpacing: 2,
    height: 1.4,
  );

  
  TextStyle get h1 => TextStyle(
    fontFamily: kFontPixel,
    fontSize: 14,
    color: text,
    letterSpacing: 2,
    height: 1.6,
  );

  
  TextStyle get h2 => TextStyle(
    fontFamily: kFontPixel,
    fontSize: 9,
    color: textDim,
    letterSpacing: 2,
    height: 1.6,
  );

  
  TextStyle get label => TextStyle(
    fontFamily: kFontPixel,
    fontSize: 7,
    color: textDim,
    letterSpacing: 1,
    height: 1.6,
  );

  TextStyle get labelAccent => label.copyWith(color: accent);

  TextStyle get body => TextStyle(
    fontFamily: kFontTerminal,
    fontSize: 20,
    color: text,
    height: 1.15,
  );

  TextStyle get bodyDim => body.copyWith(color: textDim);

  TextStyle get row => TextStyle(
    fontFamily: kFontTerminal,
    fontSize: 24,
    color: text,
    height: 1.1,
  );

  TextStyle get clock => TextStyle(
    fontFamily: kFontTerminal,
    fontSize: 96,
    color: accent,
    height: 1,
  );

  TextStyle get quote => TextStyle(
    fontFamily: kFontTerminal,
    fontSize: 19,
    color: textDim,
    height: 1.2,
  );

  
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
