// Onboarding — THREE legal documents (terms of service, privacy policy,
// client agreement) combined into one screen with one checkbox (2026-08-20
// consolidation; see legal_acceptance_screen.dart for the general shape).
// Sits right after OTP verification, before passcode/KYC/suitability.
//
// Risk Disclosure moved OUT of this bundle on 2026-08-24 (direct product
// instruction, the firm's real SEC-facing compliance intake — "My
// observations on KSL papers.docx"): the statutory risk disclaimer must
// appear immediately after the suitability questionnaire, scroll-gated,
// with the investor's own computed risk category shown dynamically — see
// risk_disclaimer_screen.dart. It briefly lived here (2026-08-20: "the
// privacy policy, terms of service and risk disclosure... stack them in
// one screen") before Client Agreement joined the same day ("move client
// agreement to the beginning, let users accept it all in the terms and
// disclosures") — that history no longer applies to Risk Disclosure
// specifically, which now runs as its own dedicated post-suitability step
// again (client_agreement_screen.dart, its old pre-consolidation home,
// stays gone — only Risk Disclosure needed its own screen back).
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
      kinds: const ['terms_of_service', 'privacy_policy', 'client_agreement'],
      screenTitle: 'Terms & agreements',
      screenBody: 'Three documents, one agreement. Each one has a plain-English summary.',
      // Canvas s05's own "Step 2 of 4" — same mid-flow indicator convention
      // otp_screen.dart (Step 1)/create_passcode_screen.dart (Step 3)/
      // biometric_screen.dart (Step 4) already use; this screen was
      // missing it entirely.
      stepLabel: 'Step 2 of 4',
      checkboxLabel: 'I have read and agree to all three documents',
      checkboxDescription: 'Terms of Service · Privacy Policy · Client Agreement',
      buttonLabel: 'Accept and continue',
      onAccepted: (context) async => context.go(Routes.createPasscode, extra: email),
    );
  }
}
