// External Kudimata web destinations — DECISIONS.md R-29.
//
// Persona, readiness, the quiz and financial literacy are existing products
// already live on kudimata.app, not features this app builds — Home's
// "Grow with Kudimata"/"While you wait" rails (s22/s23,
// docs/design/redesign-2026-08/03 Home and Markets.dc.html) open them in the
// device browser. Kept in ONE file, per R-29's own instruction, so a moved
// page is a one-line fix rather than a hunt across screens.
//
// The public site is kudimata.app (NOT kudimata.com — that host appears in
// the Kudimata-Web source but the live product site is `.app`; verified
// against the live site per R-29).
import 'package:url_launcher/url_launcher.dart';

class KLinks {
  KLinks._();

  static const String persona = 'https://www.kudimata.app/kudimata-persona';
  static const String readiness = 'https://www.kudimata.app/iri';
  static const String quiz = 'https://www.kudimata.app/quiz';
  static const String financialLiteracy =
      'https://www.kudimata.app/our-app/financial-literacy-quiz';

  // Kudimata Securities' own legal pages (R-51, DECISIONS.md, 2026-08-31 —
  // owner: "remove the assessment and also remove the risk disclosure too...
  // legal on account screen should also open a link"). Replaces the in-app
  // legal-document screens this app used to render itself (legal_screen.dart,
  // legal_preview_screen.dart, the onboarding legal-acceptance chain) —
  // sign-up's account-creation checkbox and Account → Terms and conditions
  // both open this URL now instead.
  //
  // Corrected 2026-09-02 (owner, exact URLs given): the public site is
  // `kudimatasecurities.com`, NOT the `alpha.` API host these first pointed
  // at, and the risk disclosure sits at /legal/risk-disclosure/ rather than
  // /legal/risk. Trailing slashes are the owner's own, kept verbatim.
  // Distinct from the kudimata.app constants above, which are the separate
  // marketing site. Not necessarily live yet; correct in advance of the site
  // shipping, by deliberate instruction — no reachability check, no fallback.
  static const String legal = 'https://kudimatasecurities.com/legal/';

  // Risk disclosure specifically, its own page rather than only a row inside
  // the list above — opened directly from the trade-confirmation risk
  // checkbox (trade_flows.dart) so an investor about to place an order isn't
  // sent to the full document list to find the one that matters mid-order.
  static const String legalRisk = 'https://kudimatasecurities.com/legal/risk-disclosure/';
}

/// Best-effort hand-off to the device browser for a [KLinks] URL — the one
/// place this is implemented, so home_screen.dart's promo rail and
/// learn_screen.dart (Learn's destination) both call this rather than each
/// keeping its own copy. Same seam as help_support_screen.dart's `_launch`:
/// a promo card, not a form, has no in-app surface to report failure on.
Future<void> openExternalLink(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    // Silently stays on the current screen — see doc comment above.
  }
}
