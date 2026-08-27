// 02 · Welcome — NOT the illustrated 3-slide carousel this file used to hold,
// and NOT `s02`. Per DECISIONS.md R-14, the welcome screen is the **Landing
// Video Concept**, treatment **V3**:
// docs/design/redesign-2026-08/Landing Video Concept.dc.html, artboards
// `v1`/`v2`/`v3`. The canvas contains no carousel at all (zero occurrences of
// slide/swipe/dots/"1 of 3" anywhere) — the old 3-slide `PageView` here is
// removed outright, not restyled.
//
// V3 is a 6-second muted looping video behind "Dream. Invest. Live." — that
// footage does not exist yet (filed as an asset gap in BACKEND_GAPS.md), so
// this builds V1's illustrated frame in V3's exact layout instead: same
// gradient panel, same headline/CTA/regulatory-line stack, same 430px bottom
// scrim. [_LandingBackground] below is the ONE widget that changes when the
// footage lands — swap its body for a looping video player (first frame as
// the poster image per V3's own rule) and nothing else on this screen moves.
//
// V3's footage brief, for whoever shoots it:
//   - 6 seconds, muted, looping. Handheld, warm daylight, one person. No text
//     in the footage — the headline sits on top. Keep the top third calm so
//     the mark stays legible.
//   - Storyboard: 0.0s hands/phone/Kudimata open (close crop, screen glow on
//     the fingers) → 2.0s face lifts, small smile (eye line off camera, no
//     acting, no thumbs up) → 4.5s walks out of frame, light fills it (ends
//     bright and empty so the loop point is invisible).
//   - Bottom 430px is covered by the scrim, so nothing important below the
//     waist. Under 1.5MB, H.264.
//
// Wired at Routes.welcome (app_router.dart, off-limits — lib/router/**);
// splash_screen.dart routes here for any first-time investor
// (passcodeSet == false) instead of straight to sign-up/log-in.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

class WelcomeSliderScreen extends StatelessWidget {
  const WelcomeSliderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.feature,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // SWAPPABLE background — see the file doc above.
          const _LandingBackground(),
          // Bottom scrim, constant regardless of what sits behind it —
          // v1/v2/v3 all draw the identical gradient over the bottom 430px
          // so the headline stays readable over any frame.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 430,
            child: _LandingScrim(),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 22),
                const Center(child: KMark(size: 30, white: true)),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 0, 26, 38),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dream.\nInvest.\nLive.',
                            style: KType.hero(color: KColor.sun).copyWith(
                              fontSize: 50,
                              height: 54 / 50,
                              fontWeight: KWeight.black,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 290),
                            child: Text(
                              "Own a piece of Nigeria's biggest companies, from ₦5,000.",
                              style: KType.body(color: KColor.featureInk.withValues(alpha: 0.82)).copyWith(
                                fontSize: 16,
                                height: 24 / 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _LandingCta(
                              label: 'Create account',
                              background: KColor.sun,
                              foreground: KColor.ink,
                              onTap: () => context.go(Routes.signup),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LandingCta(
                              label: 'Sign in',
                              background: KColor.featureInk.withValues(alpha: 0.12),
                              foreground: KColor.featureInk,
                              borderColor: KColor.featureInk.withValues(alpha: 0.45),
                              onTap: () => context.go(Routes.login),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Kudimata Securities Ltd · SEC registered'.upper,
                        textAlign: TextAlign.center,
                        style: KType.micro(color: KColor.featureInk.withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one swappable element: V1's illustrated stand-in today, a looping
/// muted video later (V3). Everything else on the screen — scrim, mark,
/// headline, CTAs, regulatory line — stays fixed across that swap.
class _LandingBackground extends StatelessWidget {
  const _LandingBackground();

  @override
  Widget build(BuildContext context) {
    // DECISIONS.md R-26: no dark artboard exists for this screen (Landing
    // Video Concept only has v1/v2/v3), and the ruling's "flattening wins,
    // everywhere" precedent — set on s22d/s23d/s24d and s01d's own splash —
    // says a full-bleed grape treatment does not carry into dark as a vivid
    // gradient. Dark keeps the mark/illustration/rings but flattens the
    // panel itself to the ordinary dark-card `KColor.feature`, same as
    // splash_screen.dart already does for its one full-bleed panel.
    final dark = KColor.active.brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: KColor.feature,
            gradient: dark
                ? null
                : RadialGradient(
                    center: const Alignment(0.56, -0.76),
                    radius: 1.15,
                    colors: [
                      KColor.ramp2,
                      KColor.feature,
                      Color.lerp(KColor.feature, KIllo.line, 0.55)!,
                      KIllo.line,
                    ],
                    stops: const [0.0, 0.42, 0.78, 1.0],
                  ),
          ),
        ),
        Positioned(
          left: -40,
          top: 130,
          child: _Ring(diameter: 300, color: KColor.sun.withValues(alpha: 0.28)),
        ),
        Positioned(
          right: -70,
          top: 310,
          child: _Ring(diameter: 260, color: KColor.featureInk.withValues(alpha: 0.14)),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 180,
          child: Center(
            child: SvgPicture.asset('assets/illustrations/kd-celebrate.svg', width: 290),
          ),
        ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.diameter, required this.color});
  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

class _LandingScrim extends StatelessWidget {
  const _LandingScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.42, 1.0],
            colors: [
              KIllo.line.withValues(alpha: 0),
              KIllo.line.withValues(alpha: 0.55),
              KIllo.line.withValues(alpha: 0.94),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen-local CTA — neither `KButton.primary` (purple fill) nor any other
/// existing variant matches V1's sun-filled "Create account" / translucent-
/// white "Sign in" pair, and this pairing is used nowhere else in the app.
/// A local widget, not a fork of `KButton` (see the brief's rule 5).
class _LandingCta extends StatefulWidget {
  const _LandingCta({
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.borderColor,
  });

  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final Color? borderColor;

  @override
  State<_LandingCta> createState() => _LandingCtaState();
}

class _LandingCtaState extends State<_LandingCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? KMotion.pressScale : 1.0,
        duration: KMotion.fast,
        curve: KMotion.easeSoft,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: KRadii.buttonR,
            border: widget.borderColor == null ? null : Border.all(color: widget.borderColor!, width: 1),
          ),
          child: Text(
            widget.label,
            style: KType.cardTitle(color: widget.foreground, w: KWeight.bold).copyWith(
              fontSize: 16,
              letterSpacing: -0.16,
            ),
          ),
        ),
      ),
    );
  }
}
