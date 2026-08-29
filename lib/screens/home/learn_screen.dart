// Learn (pushed, from Home's "Learn" quick action) — s22's own markup draws
// no destination for it (no `onClick`, unlike Add/Orders/Markets), and an
// earlier pass sent it to the FAQ as "the closest real match"
// (home_screen.dart's own history). Owner direction (2026-08-29, verbatim):
// "the learn should not be to FAQ but rather open a screen that shows the
// financial literacy, kudimata persona and the other one just as the cards
// are designed on the home."
//
// No artboard anywhere in the redesign-2026-08 canvas covers a Learn
// destination screen — searched every `.dc.html` for "Learn"/"learn": the
// only hits are the Learn quick action itself on s22/s23/Home Variants,
// none carrying a `nav`/`onClick` target the way Markets/Orders do. So this
// screen is built from Home's OWN visual language rather than a new
// invention: the same [KGrowCard] Home's "Grow with Kudimata"/"While you
// wait" rails already use (lib/widgets/surfaces.dart — promoted out of
// home_screen.dart's former private `_GrowCard` for exactly this reuse),
// full-width and stacked instead of Home's horizontal scroller, since this
// screen's whole job is to list them.
//
// Three cards — the three real Kudimata web products (R-29, lib/k_links.
// dart), each opened externally in the device browser via
// [openExternalLink], same as Home. A fourth product, KLinks.quiz, exists
// but is unused on Home too and is NOT added here on this screen's own
// authority — flagged for the owner to decide.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/k_links.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';

const _gut = EdgeInsets.symmetric(horizontal: KSpace.gutter);

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      appBar: const KDetailHeader(title: 'Learn'),
      body: ListView(
        padding: const EdgeInsets.only(top: 18, bottom: 28),
        children: [
          Padding(
            padding: _gut,
            child: KGrowCard(
              illustration: 'kd-readiness',
              background: KColor.feature,
              titleColor: KColor.featureInk,
              title: 'How ready are you to invest?',
              cta: 'Check your readiness',
              ctaColor: KColor.sun,
              width: double.infinity,
              onTap: () => openExternalLink(KLinks.readiness),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: _gut,
            child: KGrowCard(
              illustration: 'kd-persona',
              background: KColor.sunTint,
              titleColor: KColor.ink,
              title: "What's your money persona?",
              cta: 'Take the quiz',
              ctaColor: KColor.indicator,
              width: double.infinity,
              onTap: () => openExternalLink(KLinks.persona),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: _gut,
            child: KGrowCard(
              illustration: 'kd-lesson',
              background: KColor.feature,
              titleColor: KColor.featureInk,
              title: 'How the market works, in 4 minutes',
              cta: 'Start lesson 1',
              ctaColor: KColor.sun,
              width: double.infinity,
              onTap: () => openExternalLink(KLinks.financialLiteracy),
            ),
          ),
        ],
      ),
    );
  }
}
