// Onboarding — terms of service + privacy policy + risk disclosure, all
// combined into one screen with one checkbox (2026-08-20 consolidation; see
// legal_acceptance_screen.dart for the general shape). Sits right after OTP
// verification, before passcode/KYC/suitability.
//
// Risk Disclosure moved here from its old post-suitability pairing with
// Client Agreement (2026-08-20, user directive: "the privacy policy, terms
// of service and risk disclosure... stack them in one screen so user just
// scrolls down and accept one time not moving between screens" — Client
// Agreement wasn't named, so it stayed behind on its own screen; see
// client_agreement_screen.dart). Reading general risk information early,
// before KYC/suitability even start, is a defensible ordering on its own —
// it's the CLIENT AGREEMENT (a binding contract to actually become a
// trading client) that stays gated behind a completed suitability
// assessment.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/router/routes.dart';
import 'legal_acceptance_screen.dart';

class TermsAndPrivacyScreen extends StatelessWidget {
  const TermsAndPrivacyScreen({super.key, this.email});

  /// Threaded through from otp_screen.dart's post-verify handoff, same
  /// pattern app_router.dart's createPasscode route already uses — known
  /// with certainty here, so forwarded rather than re-derived later.
  final String? email;

  @override
  Widget build(BuildContext context) {
    return LegalAcceptanceScreen(
      kinds: const ['terms_of_service', 'privacy_policy', 'risk_disclosure'],
      screenTitle: 'Terms & Disclosures',
      checkboxLabel: 'I have read and agree to the Terms of Service, Privacy Policy, and Risk Disclosure',
      buttonLabel: 'Agree and continue',
      onAccepted: (context) async => context.go(Routes.createPasscode, extra: email),
    );
  }
}
