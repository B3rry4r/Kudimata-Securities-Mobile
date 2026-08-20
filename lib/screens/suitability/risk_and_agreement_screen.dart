// Suitability — risk disclosure + client agreement, combined into one
// screen with one checkbox (2026-08-20 consolidation — previously two
// separate screens/ticks; see legal_acceptance_screen.dart's
// DualLegalAcceptanceScreen for why). Runs right after the suitability
// questionnaire result — these are the investment-specific documents,
// unlike terms of service / privacy policy which are accepted earlier, at
// account creation (see terms_and_privacy_screen.dart).
//
// LAST step of onboarding overall. Accepting posts BOTH acknowledgements
// (risk_disclosure, then client_agreement — see DualLegalAcceptanceScreen's
// sequential-not-parallel note), then — only once both succeed — completes
// suitability and signs the investor in, then routes to the home tab. Those
// AppState flags must never flip on a failed acknowledgement.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'legal_acceptance_screen.dart';

class RiskAndAgreementScreen extends StatelessWidget {
  const RiskAndAgreementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DualLegalAcceptanceScreen(
      firstKind: 'risk_disclosure',
      secondKind: 'client_agreement',
      screenTitle: 'Risk & Agreement',
      checkboxLabel: 'I have read and agree to the Risk Disclosure and Client Agreement',
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
