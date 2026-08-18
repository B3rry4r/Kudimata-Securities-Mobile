// Onboarding — privacy policy. New onboarding step (previously the
// Privacy Policy was only listed as a downloadable reference document in
// the Legal screen, never actively presented for acceptance). Content is
// fetched from the backend (GET /legal-documents/content/privacy_policy) —
// see legal_acceptance_screen.dart, the shared widget every one of the
// four acceptance screens wraps.
//
// Second step in the legal-acceptance chain, right after terms of service
// (see terms_of_service_screen.dart for why this pair sits at account
// creation rather than after suitability). Accepting hands off to passcode
// creation — the next step in the original onboarding flow before this
// pair was inserted.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/router/routes.dart';
import 'legal_acceptance_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key, this.email});

  /// Forwarded from terms_of_service_screen.dart — see its own [email] doc.
  final String? email;

  @override
  Widget build(BuildContext context) {
    return LegalAcceptanceScreen(
      kind: 'privacy_policy',
      screenTitle: 'Privacy Policy',
      checkboxLabel: 'I agree to the Privacy Policy',
      buttonLabel: 'Agree and continue',
      onAccepted: (context) async => context.go(Routes.createPasscode, extra: email),
    );
  }
}
