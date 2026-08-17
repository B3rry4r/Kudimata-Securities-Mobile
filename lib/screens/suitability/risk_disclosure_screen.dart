// Suitability — risk disclosure. Content is fetched from the backend
// (GET /legal-documents/content/risk_disclosure), not hardcoded — see
// legal_acceptance_screen.dart, the shared widget every one of the four
// onboarding acceptance screens wraps. Third step in the legal-acceptance
// chain: terms of service -> privacy policy -> risk disclosure ->
// client agreement.
//
// Tapping "Agree" persists the acknowledgement server-side (POST
// /compliance-acknowledgements) via ComplianceRepository before navigating
// on — see STUB-risk-disclosure-1 in
// Kudimata-Securities-Backend/.pipeline/fragments/risk-disclosure.json,
// which flagged the previous pure-navigation tap as having no durable
// record of consent.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/router/routes.dart';
import 'legal_acceptance_screen.dart';

class RiskDisclosureScreen extends StatelessWidget {
  const RiskDisclosureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalAcceptanceScreen(
      kind: 'risk_disclosure',
      screenTitle: 'Risk disclosure',
      checkboxLabel: 'I have read and understood the risks',
      buttonLabel: 'Agree',
      onAccepted: (context) async => context.go(Routes.clientAgreement),
    );
  }
}
