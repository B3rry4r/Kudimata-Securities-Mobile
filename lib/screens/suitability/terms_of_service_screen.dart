// Suitability — terms of service. New onboarding step (previously the app
// had no Terms of Service acceptance at all — only Risk Disclosure and
// Client Agreement). Content is fetched from the backend
// (GET /legal-documents/content/terms_of_service) — see
// legal_acceptance_screen.dart, the shared widget every one of the four
// onboarding acceptance screens wraps. FIRST step in the legal-acceptance
// chain: terms of service -> privacy policy -> risk disclosure ->
// client agreement.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/router/routes.dart';
import 'legal_acceptance_screen.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalAcceptanceScreen(
      kind: 'terms_of_service',
      screenTitle: 'Terms of Service',
      checkboxLabel: 'I agree to the Terms of Service',
      buttonLabel: 'Agree and continue',
      onAccepted: (context) async => context.go(Routes.privacyPolicy),
    );
  }
}
