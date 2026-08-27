// Kudimata Securities — ThemeData built from KPalette (2026-08-22 "Soft
// Landing" redesign; dark added per R-13, docs/redesign/DECISIONS.md — see
// tokens.dart's header and KPalette.dark's doc comment for where its values
// come from). Two faces (Nunito for display, Nunito Sans for body/core);
// warm paper surfaces, plum ink text, grape purple the interactive seed.
// Custom widgets read colours from KColor (the active palette); this theme
// covers the Material defaults and keeps them in sync via the same palette.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'tokens.dart';

class KTheme {
  KTheme._();

  static ThemeData light() => _build(KPalette.light);

  static ThemeData dark() => _build(KPalette.dark);

  static ThemeData _build(KPalette p) {
    final base = ThemeData(useMaterial3: true, brightness: p.brightness);

    // Bundled Nunito Sans (assets/fonts) as the Material default — matches
    // "information" role text (body/data/labels), the vast majority of
    // Material-default text. Display-role text (hero/title/section/card
    // title) explicitly requests KType.fontDisplay per call, same pattern
    // as before.
    final textTheme = base.textTheme.apply(
      fontFamily: KType.fontCore,
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
