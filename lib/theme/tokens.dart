// Kudimata Securities — design tokens, ported 1:1 from the design system
// (_ds/.../tokens/*.css). "Editorial mono": white + ink, colour only where it
// carries meaning. Do not invent values here — every constant traces to a token.
import 'package:flutter/material.dart';

/// The semantic palette. Two instances (light / dark) hold every colour the app
/// uses; [KColor] reads from the active one so screens keep using `KColor.paper`
/// etc. unchanged.
@immutable
class KPalette {
  const KPalette({
    required this.paper,
    required this.bg,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.hairline,
    required this.track,
    required this.feature,
    required this.feature2,
    required this.featureInk,
    required this.featureInk2,
    required this.indicator,
    required this.indicatorPress,
    required this.indicatorTint,
    required this.gain,
    required this.loss,
    required this.gainOnInk,
    required this.lossOnInk,
    required this.brightness,
  });

  final Color paper, bg, ink, ink2, ink3, hairline, track;
  final Color feature, feature2, featureInk, featureInk2;
  final Color indicator, indicatorPress, indicatorTint;
  final Color gain, loss, gainOnInk, lossOnInk;
  final Brightness brightness;

  /// Light — the original 1:1 design tokens (tokens/colors.css).
  static const light = KPalette(
    brightness: Brightness.light,
    paper: Color(0xFFFFFFFF),
    bg: Color(0xFFFAFAFA),
    ink: Color(0xFF0F0F12),
    ink2: Color(0xFF6B6B72),
    ink3: Color(0xFF9A9AA2),
    hairline: Color(0xFFE7E7EA),
    track: Color(0xFFECECEF),
    feature: Color(0xFF0F0F12),
    feature2: Color(0xFF1A1A1F),
    featureInk: Color(0xFFFFFFFF),
    featureInk2: Color(0x9EFFFFFF),
    indicator: Color(0xFF670099),
    indicatorPress: Color(0xFF52007A),
    indicatorTint: Color(0xFFF3E9FB),
    gain: Color(0xFF1F8A5B),
    loss: Color(0xFFC8443D),
    gainOnInk: Color(0xFF86D8AC),
    lossOnInk: Color(0xFFE79A95),
  );

  /// Dark — editorial mono inverted: near-black surfaces, off-white ink, the same
  /// rationed colour (brighter purple + movement tints that hold contrast on dark).
  static const dark = KPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0C0C0F), // app background — near black
    paper: Color(0xFF17171B), // cards / sheets / rows — elevated surface
    ink: Color(0xFFF5F5F7), // primary text + primary action
    ink2: Color(0xFF9C9CA4), // secondary text
    ink3: Color(0xFF6E6E77), // tertiary / labels / placeholders
    hairline: Color(0xFF2A2A31), // rules / dividers / card edges
    track: Color(0xFF1F1F25), // recessed control track
    feature: Color(0xFF211E2C), // the one rich surface — elevated, subtle indigo
    feature2: Color(0xFF2A2736),
    featureInk: Color(0xFFFFFFFF),
    featureInk2: Color(0x9EFFFFFF),
    indicator: Color(0xFFA05CD6), // brighter purple — pops on dark
    indicatorPress: Color(0xFFB98AE6),
    indicatorTint: Color(0xFF2C1B42), // dark purple chip / focus tint
    gain: Color(0xFF43C088), // brightened green
    loss: Color(0xFFE26A63), // brightened red
    gainOnInk: Color(0xFF86D8AC), // on the (dark) feature panel
    lossOnInk: Color(0xFFE79A95),
  );
}

/// Colour accessor — reads from the active [KPalette]. The root widget sets
/// [current] from the resolved brightness before the tree builds, so every
/// `KColor.x` reference returns the themed colour. (No longer `const` — widgets
/// that referenced these inside a `const` constructor must drop the `const`.)
class KColor {
  KColor._();

  /// The active palette. Set by the root before building (see main.dart).
  static KPalette active = KPalette.light;

  static Color get paper => active.paper;
  static Color get bg => active.bg;
  static Color get ink => active.ink;
  static Color get ink2 => active.ink2;
  static Color get ink3 => active.ink3;
  static Color get hairline => active.hairline;
  static Color get track => active.track;
  static Color get feature => active.feature;
  static Color get feature2 => active.feature2;
  static Color get featureInk => active.featureInk;
  static Color get featureInk2 => active.featureInk2;
  static Color get indicator => active.indicator;
  static Color get indicatorPress => active.indicatorPress;
  static Color get indicatorTint => active.indicatorTint;
  static Color get gain => active.gain;
  static Color get loss => active.loss;
  static Color get gainOnInk => active.gainOnInk;
  static Color get lossOnInk => active.lossOnInk;
}

/// Spacing — 8-pt grid. tokens/spacing.css
class KSpace {
  KSpace._();
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;

  static const double gutter = 20; // screen side gutters
  static const double gapGroup = 12; // inside a group
  static const double gapRow = 16; // between rows
  static const double gapSection = 32; // between sections
}

/// Radius — editorial-precise. tokens/spacing.css
class KRadii {
  KRadii._();
  static const double button = 10;
  static const double input = 10;
  static const double card = 16;
  static const double feature = 20;
  static const double sheet = 24;
  static const double pill = 999;
  static const double full = 9999;

  static const cardR = BorderRadius.all(Radius.circular(card));
  static const buttonR = BorderRadius.all(Radius.circular(button));
  static const featureR = BorderRadius.all(Radius.circular(feature));
  static const pillR = BorderRadius.all(Radius.circular(pill));
}

/// Elevation — hairlines on content; soft single-layer shadow on floating chrome.
class KShadow {
  KShadow._();
  // --shadow-float : 0 8px 24px rgba(15,15,18,0.06)
  static const List<BoxShadow> float = [
    BoxShadow(color: Color(0x0F0F0F12), offset: Offset(0, 8), blurRadius: 24),
  ];
  // --shadow-nav : 0 12px 32px rgba(15,15,18,0.10)
  static const List<BoxShadow> nav = [
    BoxShadow(color: Color(0x1A0F0F12), offset: Offset(0, 12), blurRadius: 32),
  ];
  // sheet : 0 -12px 40px rgba(15,15,18,0.14)
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x240F0F12), offset: Offset(0, -12), blurRadius: 40),
  ];
}

/// Motion — single easing, three durations. tokens/spacing.css
class KMotion {
  KMotion._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);
  // --ease-soft : cubic-bezier(0.32, 0.72, 0, 1)
  static const Cubic easeSoft = Cubic(0.32, 0.72, 0, 1);
}

/// Font weights. tokens/typography.css
class KWeight {
  KWeight._();
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

const FontFeature _tnum = FontFeature.tabularFigures();

/// Typography — one face, Space Grotesk. tokens/typography.css
/// CSS em-tracking is converted to logical px (em * size). Line-heights are
/// converted to Flutter `height` multipliers (lh / size).
class KType {
  KType._();

  /// Bundled font family (assets/fonts/SpaceGrotesk-*.ttf, declared in pubspec).
  /// Bundled — NOT fetched at runtime — so it always renders offline / in release.
  static const String fontFamily = 'Space Grotesk';

  static TextStyle _base(double size, FontWeight w, Color color,
      {double? letterSpacing, double? height}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: w,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Colours default to null → resolved at runtime from the active palette, so
  // default-coloured text auto-themes and explicit `color: KColor.x` still works.

  // hero 34/38 −0.02em, Semibold — balance / display
  static TextStyle hero({Color? color}) =>
      _base(34, KWeight.semibold, color ?? KColor.ink, letterSpacing: -0.68, height: 38 / 34);

  // title 24/28 −0.015em, Semibold — screen title
  static TextStyle title({Color? color}) =>
      _base(24, KWeight.semibold, color ?? KColor.ink, letterSpacing: -0.36, height: 28 / 24);

  // section 16/21 −0.01em, Semibold — section head
  static TextStyle section({Color? color}) =>
      _base(16, KWeight.semibold, color ?? KColor.ink, letterSpacing: -0.16, height: 21 / 16);

  // card title 15/20, Medium
  static TextStyle cardTitle({Color? color, FontWeight w = KWeight.medium}) =>
      _base(15, w, color ?? KColor.ink, height: 20 / 15);

  // body 14/21, Regular
  static TextStyle body({Color? color, FontWeight w = KWeight.regular}) =>
      _base(14, w, color ?? KColor.ink2, height: 21 / 14);

  // label 11/14 +0.14em, Medium UPPERCASE — the editorial signature
  static TextStyle label({Color? color, FontWeight w = KWeight.medium}) =>
      _base(11, w, color ?? KColor.ink3, letterSpacing: 1.54, height: 14 / 11);

  // micro 10/13 +0.04em, Medium
  static TextStyle micro({Color? color, FontWeight w = KWeight.medium}) =>
      _base(10, w, color ?? KColor.ink3, letterSpacing: 0.40, height: 13 / 10);
}

/// Tabular figures — applied to every price, balance, percentage.
extension KTnum on TextStyle {
  TextStyle get tnum => copyWith(fontFeatures: const [_tnum]);
}

/// UPPERCASE helper for tracked labels (eyebrows).
extension KUpper on String {
  String get upper => toUpperCase();
}
