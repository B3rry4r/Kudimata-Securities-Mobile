// Kudimata Securities — ThemeData assembled from the tokens. The whole system is
// one face (Space Grotesk), white surfaces, ink text; purple is the seed for the
// interactive layer. Screens read from the tokens directly; this theme covers the
// Material defaults (text selection, scaffold bg, splash behaviour).
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

class KTheme {
  KTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    final textTheme = GoogleFonts.spaceGroteskTextTheme(base.textTheme).apply(
      bodyColor: KColor.ink,
      displayColor: KColor.ink,
    );

    return base.copyWith(
      scaffoldBackgroundColor: KColor.bg,
      canvasColor: KColor.bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: KColor.indicator,
        onPrimary: KColor.paper,
        secondary: KColor.ink,
        onSecondary: KColor.paper,
        surface: KColor.paper,
        onSurface: KColor.ink,
        error: KColor.loss,
        outline: KColor.hairline,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: KColor.indicator,
        selectionColor: KColor.indicatorTint,
        selectionHandleColor: KColor.indicator,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
