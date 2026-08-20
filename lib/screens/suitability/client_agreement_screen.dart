// Suitability — client agreement, its own single-document screen
// (2026-08-20). Previously paired with Risk Disclosure on this same screen;
// that pairing broke apart the same day when Risk Disclosure moved up to
// join Terms of Service + Privacy Policy at account-creation time (user
// directive named exactly those three documents, not Client Agreement —
// see terms_and_privacy_screen.dart). Client Agreement stays here,
// gated behind a completed suitability assessment, since it's the actual
// binding contract to become a trading client — unlike the other three,
// which are general platform/risk disclosures appropriate to show before
// KYC even starts.
//
// Runs right after the suitability questionnaire result. LAST step of
// onboarding overall — accepting completes suitability and signs the
// investor in, then routes to the home tab.
//
// Replaces the former RiskAndAgreementScreen (this file used to be
// risk_and_agreement_screen.dart); the route constant it's wired to
// (Routes.riskDisclosure) is unchanged even though it now only shows
// Client Agreement — see routes.dart's own note on that path.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'legal_acceptance_screen.dart';

class ClientAgreementScreen extends StatelessWidget {
  const ClientAgreementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalAcceptanceScreen(
      kinds: const ['client_agreement'],
      screenTitle: 'Client Agreement',
      checkboxLabel: 'I have read and agree to the Client Agreement',
      buttonLabel: 'Accept and continue',
      onAccepted: (context) async {
        final app = AppScope.read(context);
        app.setSuitabilityComplete(true);
        app.setSignedIn(true);
        context.go(Routes.home);
      },
    );
  }
}
