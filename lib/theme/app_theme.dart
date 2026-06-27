// Kudimata Securities — ThemeData built from a KPalette. One face (Space Grotesk);
// light = white surfaces / ink text, dark = near-black surfaces / off-white ink;
// purple is the interactive seed in both. Custom widgets read colours from KColor
// (the active palette); this theme covers the Material defaults and keeps them in
// sync via the same palette.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'tokens.dart';

class KTheme {
  KTheme._();

  static ThemeData light() => _build(KPalette.light);
  static ThemeData dark() => _build(KPalette.dark);

  static ThemeData _build(KPalette p) {
    final base = ThemeData(useMaterial3: true, brightness: p.brightness);

    // Bundled Space Grotesk (assets/fonts) — no runtime font fetch.
    final textTheme = base.textTheme.apply(
      fontFamily: KType.fontFamily,
      bodyColor: p.ink,
      displayColor: p.ink,
    );

    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: p.indicator,
        onPrimary: Colors.white,
        secondary: p.ink,
        onSecondary: p.paper,
        surface: p.paper,
        onSurface: p.ink,
        error: p.loss,
        onError: Colors.white,
        outline: p.hairline,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.indicator,
        selectionColor: p.indicatorTint,
        selectionHandleColor: p.indicator,
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
