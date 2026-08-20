// Onboarding — terms of service + privacy policy, combined into one screen
// with one checkbox (2026-08-20 consolidation — previously two separate
// screens/ticks; see legal_acceptance_screen.dart's DualLegalAcceptanceScreen
// for why). Sits right after OTP verification, before passcode/KYC/
// suitability — general platform terms belong at account creation, not
// deep in a KYC flow the investor hasn't started yet. FIRST pairing in the
// legal-acceptance chain: terms+privacy -> (passcode, KYC, suitability) ->
// risk+agreement.
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
    return DualLegalAcceptanceScreen(
      firstKind: 'terms_of_service',
      secondKind: 'privacy_policy',
      screenTitle: 'Terms & Privacy',
      checkboxLabel: 'I agree to the Terms of Service and Privacy Policy',
      buttonLabel: 'Agree and continue',
      onAccepted: (context) async => context.go(Routes.createPasscode, extra: email),
    );
  }
}
