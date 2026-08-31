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

  // This app's own backend-served legal page (R-51, DECISIONS.md,
  // 2026-08-31 — owner: "remove the assessment and also remove the risk
  // disclosure too... legal on account screen should also open a link...
  // you can just use the domain of the backend with a /legal route") — the
  // `alpha.kudimatasecurities.com` domain above, NOT the kudimata.app
  // marketing site the four constants above point at. Replaces the
  // in-app legal-document screens this app used to render itself
  // (legal_screen.dart, legal_preview_screen.dart, the onboarding legal-
  // acceptance chain) — sign-up's account-creation checkbox and Account →
  // Terms and disclosures both open this URL now instead. Not live yet as
  // of this ruling; the link is correct in advance of the site shipping,
  // by deliberate instruction — no reachability check, no fallback.
  static const String legal = 'https://alpha.kudimatasecurities.com/legal';

  // Risk disclosure specifically, its own URL under the same page rather
  // than only a row inside the list above — opened directly from the
  // trade-confirmation risk checkbox (trade_flows.dart) so an investor
  // about to place an order isn't sent to the full 4-document list to find
  // the one that matters mid-order. Also not live yet; same note as
  // [legal] above.
  static const String legalRisk = 'https://alpha.kudimatasecurities.com/legal/risk';
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
