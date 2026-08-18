// Onboarding — terms of service. New onboarding step (previously the app
// had no Terms of Service acceptance at all — only Risk Disclosure and
// Client Agreement, both gated behind suitability). Content is fetched
// from the backend (GET /legal-documents/content/terms_of_service) — see
// legal_acceptance_screen.dart, the shared widget every one of the four
// acceptance screens wraps.
//
// Sits right after OTP verification, before passcode/KYC/suitability —
// general platform terms belong at account creation, not four screens
// deep in a KYC flow the investor hasn't started yet. FIRST step in the
// legal-acceptance chain: terms of service -> privacy policy -> (passcode,
// KYC, suitability) -> risk disclosure -> client agreement.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/router/routes.dart';
import 'legal_acceptance_screen.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key, this.email});

  /// Threaded through from otp_screen.dart's post-verify handoff, same
  /// pattern app_router.dart's createPasscode route already uses — known
  /// with certainty here, so forwarded rather than re-derived later.
  final String? email;

  @override
  Widget build(BuildContext context) {
    return LegalAcceptanceScreen(
      kind: 'terms_of_service',
      screenTitle: 'Terms of Service',
      checkboxLabel: 'I agree to the Terms of Service',
      buttonLabel: 'Agree and continue',
      onAccepted: (context) async => context.go(Routes.privacyPolicy, extra: email),
    );
  }
}
