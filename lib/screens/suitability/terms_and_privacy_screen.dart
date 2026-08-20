// Onboarding — ALL FOUR legal documents (terms of service, privacy policy,
// risk disclosure, client agreement) combined into one screen with one
// checkbox (2026-08-20 consolidation; see legal_acceptance_screen.dart for
// the general shape). Sits right after OTP verification, before
// passcode/KYC/suitability — this is now the ONLY legal-acceptance screen
// in onboarding.
//
// Risk Disclosure and Client Agreement both moved here in two passes the
// same day. First Risk Disclosure joined Terms+Privacy (user directive:
// "the privacy policy, terms of service and risk disclosure... stack them
// in one screen" — Client Agreement wasn't named that time, so it briefly
// stayed on its own post-suitability screen, client_agreement_screen.dart).
// Then Client Agreement joined too (follow-up directive: "move client
// agreement to the beginning, let users accept it all in the terms and
// disclosures") — client_agreement_screen.dart and the post-suitability
// legal step are gone; suitability_result_screen.dart now goes straight
// from the questionnaire result to Home, since every document is already
// accepted by the time KYC even starts.
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
      kinds: const ['terms_of_service', 'privacy_policy', 'risk_disclosure', 'client_agreement'],
      screenTitle: 'Terms & Disclosures',
      checkboxLabel:
          'I have read and agree to the Terms of Service, Privacy Policy, Risk Disclosure, and Client Agreement',
      buttonLabel: 'Agree and continue',
      onAccepted: (context) async => context.go(Routes.createPasscode, extra: email),
    );
  }
}
