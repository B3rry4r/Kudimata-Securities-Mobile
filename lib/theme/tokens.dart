// Kudimata Invest — design tokens, ported 1:1 from the design system
// (_ds/kudimata-design-system-.../tokens/*.css). "Soft Landing" (2026-08-22
// redesign, replacing "editorial mono"): warm paper, plum ink, a grape
// accent, and two warm accents (coral/sun) that carry celebration and
// personality without borrowing the gain/loss semantics. Do not invent
// values here — every constant traces to a token.
//
// Light-only: tokens/base.css declares `color-scheme: light` and the design
// system's readme is explicit that dark is an undesigned draft ("no
// surface, illustration plate or contrast pair has been designed against
// it") — see main.dart's header comment for where the app enforces this.
import 'package:flutter/material.dart';

/// The semantic palette. [KColor] reads from [KColor.active] so screens keep
/// using `KColor.paper` etc. unchanged even though there is now only one
/// instance (light).
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
    required this.indicatorSoft,
    required this.warm,
    required this.warmPress,
    required this.warmTint,
    required this.sun,
    required this.sunPress,
    required this.sunTint,
    required this.gain,
    required this.loss,
    required this.gainOnInk,
    required this.lossOnInk,
    required this.ramp1,
    required this.ramp2,
    required this.ramp3,
    required this.ramp4,
    required this.ramp5,
    required this.statusApprovedTint,
    required this.statusRejectedTint,
    required this.statusReviewTint,
    required this.scrim,
    required this.brightness,
  });

  final Color paper, bg, ink, ink2, ink3, hairline, track;
  final Color feature, feature2, featureInk, featureInk2;
  final Color indicator, indicatorPress, indicatorTint, indicatorSoft;
  final Color warm, warmPress, warmTint;
  final Color sun, sunPress, sunTint;
  final Color gain, loss, gainOnInk, lossOnInk;
  final Color ramp1, ramp2, ramp3, ramp4, ramp5;
  final Color statusApprovedTint, statusRejectedTint, statusReviewTint;
  final Color scrim;
  final Brightness brightness;

  /// The only palette — tokens/colors.css, "Soft Landing".
  static const light = KPalette(
    brightness: Brightness.light,
    paper: Color(0xFFFFFFFF),
    bg: Color(0xFFFFFDF9),
    ink: Color(0xFF20201E),
    ink2: Color(0xFF5C564E),
    ink3: Color(0xFF726B62),
    hairline: Color(0xFFEBE6DD),
    track: Color(0xFFEFE9DE),
    feature: Color(0xFF6524A8),
    feature2: Color(0xFF7B3BBE),
    featureInk: Color(0xFFFFFFFF),
    featureInk2: Color(0xB8FFFFFF),
    indicator: Color(0xFF6524A8),
    indicatorPress: Color(0xFF4A1A80),
    indicatorTint: Color(0xFFF0E7FA),
    indicatorSoft: Color(0xFFA16BE0),
    warm: Color(0xFFF07A45),
    warmPress: Color(0xFFA63C13),
    warmTint: Color(0xFFFDEDE3),
    sun: Color(0xFFF5C542),
    sunPress: Color(0xFFC9973F),
    sunTint: Color(0xFFFDF4DC),
    gain: Color(0xFF2AA36B),
    loss: Color(0xFFD0503F),
    // --gain-on-feature / --loss-on-feature in the CSS; --gain-on-ink /
    // --loss-on-ink are that same CSS's own back-compat aliases for these —
    // kept as the Dart names too so every existing call site (KColor.gainOnInk
    // on the feature panel) needs no rename.
    gainOnInk: Color(0xFF9DEBC4),
    lossOnInk: Color(0xFFFFB3A8),
    ramp1: Color(0xFF6524A8),
    ramp2: Color(0xFF8B4FC4),
    ramp3: Color(0xFFA16BE0),
    ramp4: Color(0xFFC9A6EC),
    ramp5: Color(0xFFEDE0FA),
    statusApprovedTint: Color(0x1F2AA36B), // rgba(42,163,107,.12)
    statusRejectedTint: Color(0x1FD0503F), // rgba(208,80,63,.12)
    statusReviewTint: Color(0xFFF0E7FA), // == indicatorTint
    scrim: Color(0x5C2B1A3D), // rgba(43,26,61,.36)
  );
}

/// Colour accessor — reads from the active [KPalette] (always [KPalette.light]
/// — see this file's header comment). Kept as a live accessor rather than a
/// bare `const` palette so existing `KColor.x` call sites across ~60 screens
/// needed no rename when the design system moved off the old dual-palette
/// scheme.
class KColor {
  KColor._();

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
  static Color get indicatorSoft => active.indicatorSoft;
  static Color get warm => active.warm;
  static Color get warmPress => active.warmPress;
  static Color get warmTint => active.warmTint;
  static Color get sun => active.sun;
  static Color get sunPress => active.sunPress;
  static Color get sunTint => active.sunTint;
  static Color get gain => active.gain;
  static Color get loss => active.loss;
  static Color get gainOnInk => active.gainOnInk;
  static Color get lossOnInk => active.lossOnInk;
  static Color get ramp1 => active.ramp1;
  static Color get ramp2 => active.ramp2;
  static Color get ramp3 => active.ramp3;
  static Color get ramp4 => active.ramp4;
  static Color get ramp5 => active.ramp5;
  static Color get statusApprovedTint => active.statusApprovedTint;
  static Color get statusRejectedTint => active.statusRejectedTint;
  static Color get statusReviewTint => active.statusReviewTint;
  static Color get statusPendingTint => active.track;
  static Color get scrim => active.scrim;

  /// The allocation-donut ramp, darkest to lightest — tokens/colors.css's
  /// only multi-hue palette; used nowhere else.
  static List<Color> get ramp => [ramp1, ramp2, ramp3, ramp4, ramp5];
}

/// Spacing — 8-pt grid, 4 as the half step. tokens/spacing.css (unchanged by
/// the redesign — the same scale carries forward).
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

/// Radius — rounder than the "editorial mono" system it replaces; roundness
/// is most of what separates calm from strict. tokens/radii.css
class KRadii {
  KRadii._();
  static const double button = 14;
  static const double input = 14;
  static const double card = 20;
  static const double feature = 24;
  static const double sheet = 28;
  static const double pill = 999;
  static const double full = 9999;
  static const double segment = 10;
  static const double chip = 10;
  static const double illo = 18; // the tinted plate an illustration sits on

  static const cardR = BorderRadius.all(Radius.circular(card));
  static const buttonR = BorderRadius.all(Radius.circular(button));
  static const featureR = BorderRadius.all(Radius.circular(feature));
  static const sheetR = BorderRadius.only(
    topLeft: Radius.circular(sheet),
    topRight: Radius.circular(sheet),
  );
  static const pillR = BorderRadius.all(Radius.circular(pill));
  static const chipR = BorderRadius.all(Radius.circular(chip));
  static const illoR = BorderRadius.all(Radius.circular(illo));
}

/// Elevation — hairlines carry content; shadow only floats chrome and the
/// few surfaces that should feel liftable. Shadows are warm-tinted (never
/// grey — rgba(43,26,61,*) is the plum ink, not black). tokens/elevation.css
class KShadow {
  KShadow._();
  static const List<BoxShadow> float = [
    BoxShadow(color: Color(0x122B1A3D), offset: Offset(0, 8), blurRadius: 24),
  ];
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D2B1A3D), offset: Offset(0, 2), blurRadius: 10),
  ];
  static const List<BoxShadow> nav = [
    BoxShadow(color: Color(0x1F2B1A3D), offset: Offset(0, 12), blurRadius: 32),
  ];
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x292B1A3D), offset: Offset(0, -12), blurRadius: 40),
  ];
  static const List<BoxShadow> knob = [
    BoxShadow(color: Color(0x382B1A3D), offset: Offset(0, 2), blurRadius: 6),
  ];
  static const List<BoxShadow> indicator = [
    BoxShadow(color: Color(0x4D6524A8), offset: Offset(0, 8), blurRadius: 18),
  ];
  static const List<BoxShadow> warm = [
    BoxShadow(color: Color(0x42F07A45), offset: Offset(0, 8), blurRadius: 18),
  ];
}

/// Motion — one curve for everything functional, a gentler one for the
/// moments meant to feel like a gift. Nothing bounces, nothing springs.
/// tokens/motion.css
class KMotion {
  KMotion._();
  static const Duration fast = Duration(milliseconds: 120); // press, hover, focus
  static const Duration base = Duration(milliseconds: 220); // toggles, transforms
  static const Duration slow = Duration(milliseconds: 360); // sheets, page transitions
  static const Duration settle = Duration(milliseconds: 640); // milestone reveal
  static const Cubic easeSoft = Cubic(0.32, 0.72, 0, 1);
  static const Cubic easeSettle = Cubic(0.22, 0.68, 0.24, 1);
  static const double pressScale = 0.98;
  static const double pressScaleIcon = 0.96;
}

/// The illustration system — 35 Semcore (MIT) scenes + 9 generated Adventurer
/// (CC BY 4.0) characters, reduced to seven values. tokens/illustration.css.
/// See lib/widgets/illustration.dart for the [KIllustration] widget that
/// renders a scene on its tinted plate using these tokens.
class KIllo {
  KIllo._();

  static const Color line = Color(0xFF2B1A3D);
  static const Color grey = Color(0xFF7C6C86);
  static const Color tint = Color(0xFFE9E0F2);
  static const Color grape = Color(0xFFA16BE0);
  static const Color sun = Color(0xFFF5C542);
  static const Color coral = Color(0xFFF07A45);
  static const Color gain = Color(0xFF6FD3A4);

  /// Plate tints an illustration sits on — never bare paper.
  static Color get platePurple => KColor.indicatorTint; // default, most states
  static Color get plateWarm => KColor.warmTint; // nudges, personal moments
  static Color get plateSun => KColor.sunTint; // milestones

  /// Drawn size per role — the drawing, not the plate.
  static const double hero = 200; // onboarding slide, Explain-this opening
  static const double state = 160; // empty / waiting / outcome states
  static const double small = 120; // statements, inline cards
  static const double banner = 140; // email header (not used in-app)
  static const double platePad = 28;

  /// Character sizes.
  static const double avatarXs = 28; // AI mark inline with copy
  static const double avatarSm = 40; // nudge card, list rows
  static const double avatarMd = 56; // Explain panel
  static const double avatarLg = 88; // profile, milestone
}

/// Font weights. tokens/typography.css
class KWeight {
  KWeight._();
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight black = FontWeight.w800;
}

const FontFeature _tnum = FontFeature.tabularFigures();

/// Typography — two faces. Nunito carries feeling (hero, title, section,
/// card title); Nunito Sans carries information (body, data, label, micro).
/// tokens/typography.css. CSS em-tracking is converted to logical px
/// (em * size). Line-heights are converted to Flutter `height` multipliers
/// (lh / size).
class KType {
  KType._();

  /// Bundled font families (assets/fonts/Nunito-*.ttf, NunitoSans-*.ttf,
  /// declared in pubspec). Bundled — NOT fetched at runtime — so they always
  /// render offline / in release.
  static const String fontDisplay = 'Nunito';
  static const String fontCore = 'Nunito Sans';

  static TextStyle _base(String family, double size, FontWeight w, Color color,
      {double? letterSpacing, double? height}) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: w,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Colours default to null → resolved at runtime from the active palette, so
  // default-coloured text auto-themes and explicit `color: KColor.x` still works.

  // hero 40/44 −0.025em, Black (800) — balance / display. Nunito.
  static TextStyle hero({Color? color}) => _base(
      fontDisplay, 40, KWeight.black, color ?? KColor.ink, letterSpacing: -1.0, height: 44 / 40);

  // title 26/32 −0.02em, Bold — screen title. Nunito.
  static TextStyle title({Color? color}) => _base(
      fontDisplay, 26, KWeight.bold, color ?? KColor.ink, letterSpacing: -0.52, height: 32 / 26);

  // section 19/25 −0.015em, Bold — section head. Nunito.
  static TextStyle section({Color? color}) => _base(fontDisplay, 19, KWeight.bold, color ?? KColor.ink,
      letterSpacing: -0.285, height: 25 / 19);

  // card title 16/22 −0.01em, Bold. Nunito.
  static TextStyle cardTitle({Color? color, FontWeight w = KWeight.bold}) =>
      _base(fontDisplay, 16, w, color ?? KColor.ink, letterSpacing: -0.16, height: 22 / 16);

  // body 15/24, Regular. Nunito Sans.
  static TextStyle body({Color? color, FontWeight w = KWeight.regular}) =>
      _base(fontCore, 15, w, color ?? KColor.ink2, height: 24 / 15);

  // label 11/14 +0.14em, Semibold UPPERCASE — the tracked-caps signature,
  // reserved for Eyebrow/table headers/metadata micro-labels only. Nunito Sans.
  static TextStyle label({Color? color, FontWeight w = KWeight.semibold}) =>
      _base(fontCore, 11, w, color ?? KColor.ink3, letterSpacing: 1.54, height: 14 / 11);

  // micro 10/13 +0.04em, Semibold. Nunito Sans.
  static TextStyle micro({Color? color, FontWeight w = KWeight.semibold}) =>
      _base(fontCore, 10, w, color ?? KColor.ink3, letterSpacing: 0.40, height: 13 / 10);

  // data 14/20 −0.005em, Regular — prices, refs, timestamps outside a hero
  // figure. Nunito Sans, always paired with `.tnum` below.
  static TextStyle data({Color? color, FontWeight w = KWeight.regular}) =>
      _base(fontCore, 14, w, color ?? KColor.ink, letterSpacing: -0.07, height: 20 / 14);
}

/// Tabular figures — applied to every price, balance, percentage.
extension KTnum on TextStyle {
  TextStyle get tnum => copyWith(fontFeatures: const [_tnum]);
}

/// UPPERCASE helper for tracked labels (eyebrows).
extension KUpper on String {
  String get upper => toUpperCase();
}
