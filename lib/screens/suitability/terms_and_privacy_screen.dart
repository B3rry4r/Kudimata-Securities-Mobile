// Onboarding — the remaining THREE legal documents (terms of service,
// privacy policy, client agreement) combined into one screen with one
// checkbox (2026-08-20 consolidation; see legal_acceptance_screen.dart for
// the general shape).
//
// R-8a (DECISIONS.md, 2026-08-27) is the current ruling — it amends R-8 and
// settles a three-way conflict with R-1a and the firm's SEC-intake
// instruction: risk disclosure is pulled OUT of this bundle and back into
// its own scroll-gated in-app screen (risk_disclaimer_screen.dart), run
// right after suitability, ahead of this screen. So R-8 now covers three
// documents, not four — this bundle stays the phone's-native-viewer
// pattern for the three that are left (see legal_acceptance_screen.dart's
// header for the acceptance-evidence consequence of that pattern).
//
// The onboarding order (R-8a): signup → OTP → suitability → result → risk
// disclosure → THIS SCREEN → passcode → biometric → KYC. This screen is
// reached from risk_disclaimer_screen.dart's own accept action
// (`context.go(Routes.termsOfService)`), not straight off OTP verification
// any more.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'legal_acceptance_screen.dart';

class TermsAndPrivacyScreen extends StatelessWidget {
  const TermsAndPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalAcceptanceScreen(
      kinds: const [
        'terms_of_service',
        'privacy_policy',
        'client_agreement',
      ],
      screenTitle: 'Terms & agreements',
      screenBody: 'Three documents, one agreement. Open each one, then accept.',
      // Canvas s05's own "Step 2 of 4" — same mid-flow indicator convention
      // otp_screen.dart (Step 1)/create_passcode_screen.dart (Step 3)/
      // biometric_screen.dart (Step 4) already use.
      stepLabel: 'Step 2 of 4',
      checkboxLabel: 'I have read and agree to all three documents',
      checkboxDescription: 'Terms of Service · Privacy Policy · Client Agreement',
      buttonLabel: 'Accept and continue',
      onAccepted: (context) async => context.go(
        Routes.createPasscode,
        // AppState.pendingSignupEmail — set by otp_screen.dart right after
        // verification and carried forward from there (this screen now
        // runs several hops downstream of OTP, past suitability/result/risk
        // disclosure, so the email can no longer ride a single route
        // `extra` the way it used to when this screen followed OTP
        // directly). See AppState's own doc comment on that field.
        extra: AppScope.read(context).pendingSignupEmail,
      ),
    );
  }
}
