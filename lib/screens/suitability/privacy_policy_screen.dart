// Suitability — privacy policy. New onboarding step (previously the
// Privacy Policy was only listed as a downloadable reference document in
// the Legal screen, never actively presented for acceptance). Content is
// fetched from the backend (GET /legal-documents/content/privacy_policy) —
// see legal_acceptance_screen.dart, the shared widget every one of the
// four onboarding acceptance screens wraps. Second step in the
// legal-acceptance chain: terms of service -> privacy policy ->
// risk disclosure -> client agreement.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/router/routes.dart';
import 'legal_acceptance_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalAcceptanceScreen(
      kind: 'privacy_policy',
      screenTitle: 'Privacy Policy',
      checkboxLabel: 'I agree to the Privacy Policy',
      buttonLabel: 'Agree and continue',
      onAccepted: (context) async => context.go(Routes.riskDisclosure),
    );
  }
}
