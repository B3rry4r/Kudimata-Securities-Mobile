// Kudimata Securities — design tokens, ported 1:1 from the design system
// (_ds/.../tokens/*.css). "Editorial mono": white + ink, colour only where it
// carries meaning. Do not invent values here — every constant traces to a token.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colour — near-monochrome. tokens/colors.css
class KColor {
  KColor._();

  // Paper & ink
  static const paper = Color(0xFFFFFFFF); // --paper : cards, sheets, rows
  static const bg = Color(0xFFFAFAFA); // --bg : app background
  static const ink = Color(0xFF0F0F12); // --ink : primary text + primary action
  static const ink2 = Color(0xFF6B6B72); // --ink-2 : secondary text
  static const ink3 = Color(0xFF9A9AA2); // --ink-3 : tertiary / labels / placeholders
  static const hairline = Color(0xFFE7E7EA); // --hairline : rules, dividers, card edges
  static const track = Color(0xFFECECEF); // --track : recessed control track

  // Feature panel — the one rich surface, solid ink (not a gradient)
  static const feature = Color(0xFF0F0F12); // --feature
  static const feature2 = Color(0xFF1A1A1F); // --feature-2
  static const featureInk = Color(0xFFFFFFFF); // --feature-ink
  static const featureInk2 = Color(0x9EFFFFFF); // --feature-ink-2 : rgba(255,255,255,0.62)

  // Indicator — brand purple, used rarely
  static const indicator = Color(0xFF670099); // --indicator
  static const indicatorPress = Color(0xFF52007A); // --indicator-press
  static const indicatorTint = Color(0xFFF3E9FB); // --indicator-tint

  // Movement — functional only, on numbers
  static const gain = Color(0xFF1F8A5B); // --gain
  static const loss = Color(0xFFC8443D); // --loss

  // On-ink change tints (BalancePanel)
  static const gainOnInk = Color(0xFF86D8AC);
  static const lossOnInk = Color(0xFFE79A95);
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

  static TextStyle _base(double size, FontWeight w, Color color,
      {double? letterSpacing, double? height}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: w,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // hero 34/38 −0.02em, Semibold — balance / display
  static TextStyle hero({Color color = KColor.ink}) =>
      _base(34, KWeight.semibold, color, letterSpacing: -0.68, height: 38 / 34);

  // title 24/28 −0.015em, Semibold — screen title
  static TextStyle title({Color color = KColor.ink}) =>
      _base(24, KWeight.semibold, color, letterSpacing: -0.36, height: 28 / 24);

  // section 16/21 −0.01em, Semibold — section head
  static TextStyle section({Color color = KColor.ink}) =>
      _base(16, KWeight.semibold, color, letterSpacing: -0.16, height: 21 / 16);

  // card title 15/20, Medium
  static TextStyle cardTitle({Color color = KColor.ink, FontWeight w = KWeight.medium}) =>
      _base(15, w, color, height: 20 / 15);

  // body 14/21, Regular
  static TextStyle body({Color color = KColor.ink2, FontWeight w = KWeight.regular}) =>
      _base(14, w, color, height: 21 / 14);

  // label 11/14 +0.14em, Medium UPPERCASE — the editorial signature
  static TextStyle label({Color color = KColor.ink3, FontWeight w = KWeight.medium}) =>
      _base(11, w, color, letterSpacing: 1.54, height: 14 / 11);

  // micro 10/13 +0.04em, Medium
  static TextStyle micro({Color color = KColor.ink3, FontWeight w = KWeight.medium}) =>
      _base(10, w, color, letterSpacing: 0.40, height: 13 / 10);
}

/// Tabular figures — applied to every price, balance, percentage.
extension KTnum on TextStyle {
  TextStyle get tnum => copyWith(fontFeatures: const [_tnum]);
}

/// UPPERCASE helper for tracked labels (eyebrows).
extension KUpper on String {
  String get upper => toUpperCase();
}
