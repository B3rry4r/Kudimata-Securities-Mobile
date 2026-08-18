// Suitability — client agreement. Content is fetched from the backend
// (GET /legal-documents/content/client_agreement), not hardcoded — see
// legal_acceptance_screen.dart, the shared widget every one of the four
// acceptance screens wraps. LAST step of onboarding overall — terms of
// service and privacy policy are accepted earlier at account creation
// (see terms_of_service_screen.dart); this and risk disclosure are the
// investment-specific pair that follow suitability: risk disclosure ->
// client agreement -> home.
//
// Accepting posts a ComplianceAcknowledgement (kind: 'client_agreement'),
// then — only once that succeeds — completes suitability and signs the
// user in, then routes to the home tab. This is the final gated onboarding
// step, so those AppState flags must never flip on a failed acknowledgement.
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
      kind: 'client_agreement',
      screenTitle: 'Client agreement',
      checkboxLabel: 'I agree to the Client Agreement',
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
