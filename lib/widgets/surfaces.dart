// Card + Badge + GrowCard. Ported from components/core/Card.jsx and Badge.jsx.
// Card: the default container — white, 1px hairline, NO shadow, radius 16.
// Badge: movement/status label — colour on numbers only; neutral grey otherwise.
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/tokens.dart';
import 'k_icon.dart';

class KCard extends StatelessWidget {
  const KCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.border = true,
    this.radius = KRadii.card,
    this.onTap,
    this.color, // null → themed paper (resolved at build)
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool border;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? KColor.paper,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: KColor.hairline, width: 1) : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
  }
}

enum KBadgeTone { neutral, gain, loss, indicator }

class KBadge extends StatelessWidget {
  const KBadge({super.key, required this.label, this.tone = KBadgeTone.neutral, this.icon});

  final String label;
  final KBadgeTone tone;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final (Color color, Color? background) = switch (tone) {
      KBadgeTone.neutral => (KColor.ink2, null),
      KBadgeTone.gain => (KColor.gain, null),
      KBadgeTone.loss => (KColor.loss, null),
      KBadgeTone.indicator => (KColor.indicator, KColor.indicatorTint),
    };
    return Container(
      padding: tone == KBadgeTone.indicator
          ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 4)],
          Text(label, style: KType.label(color: color).copyWith(height: 1.0).tnum),
        ],
      ),
    );
  }
}

/// A promo card for an existing Kudimata product — home_screen.dart's
/// "Grow with Kudimata"/"While you wait" rails (s22/s23, DECISIONS.md R-29:
/// existing kudimata.app products, opened externally, never a progress
/// card). Promoted here from a private `_GrowCard` in home_screen.dart so
/// learn_screen.dart (the Learn quick action's destination) can render the
/// exact same card rather than a second copy — "never fork a widget, a
/// variant is a prop" (CLAUDE.md).
///
/// Fixes a pre-existing `RenderFlex` overflow (found live on Home's
/// not-verified body — `test/onboarding_avatar_and_risk_disclosure_test.dart`):
/// the CTA row (`Text(cta)` + a chevron `KIcon`) had `mainAxisSize.min` but
/// no `Flexible`/`Expanded` around the label, so a Row measures a bare Text
/// child at its full unwrapped width regardless of the card's own width —
/// the same defect class `KButton`'s content Row already documents fixing
/// (buttons.dart). "Check your readiness"/"Take the quiz" at bold 13px plus
/// the trailing chevron run a few pixels past the 220px card's padded
/// content width (184px), so the Row overflowed its parent every time it
/// painted. Fixed the same way: the label sits in a [Flexible] with
/// `TextOverflow.ellipsis`, so a CTA that doesn't fit truncates instead of
/// throwing a hazard-striped render error.
class KGrowCard extends StatelessWidget {
  const KGrowCard({
    super.key,
    required this.illustration,
    required this.background,
    required this.titleColor,
    required this.title,
    required this.cta,
    required this.ctaColor,
    required this.onTap,
    this.width = 220,
  });

  final String illustration;
  final Color background;
  final Color titleColor;
  final String title;
  final String cta;
  final Color ctaColor;
  final VoidCallback onTap;

  /// 220 matches Home's own horizontally-scrolling rail. A dedicated
  /// listing screen (learn_screen.dart) passes `double.infinity` to fill
  /// its own full-width column instead.
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: background, borderRadius: KRadii.featureR),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: SvgPicture.asset('assets/illustrations/$illustration.svg', height: 84)),
            const SizedBox(height: 10),
            Text(title,
                style: KType.cardTitle(color: titleColor, w: KWeight.black)
                    .copyWith(fontSize: 17, height: 22 / 17)),
            const SizedBox(height: 10),
            // The bundled Nunito/Nunito Sans faces carry no U+2192 glyph, so
            // the canvas's literal "→" (Check your readiness →, etc.) is a
            // tofu box, not a render — this is a real, offline device
            // constraint (see pubspec.yaml's font-bundling note), not a
            // design opinion. A trailing chevron icon carries the same
            // directional cue with a glyph the app actually ships.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(cta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KType.data(color: ctaColor, w: KWeight.bold).copyWith(fontSize: 13)),
                ),
                const SizedBox(width: 4),
                KIcon('chevronRight', size: 13, color: ctaColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
