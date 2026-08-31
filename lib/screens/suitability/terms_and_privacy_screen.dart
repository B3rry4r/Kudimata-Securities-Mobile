// Onboarding — ALL FOUR legal documents (terms of service, privacy policy,
// risk disclosure, client agreement) combined into one screen with one
// checkbox (2026-08-20 consolidation; see legal_acceptance_screen.dart for
// the general shape).
//
// RISK DISCLOSURE'S PLACE HERE HAS MOVED THREE TIMES. R-8 (DECISIONS.md,
// 2026-08-26) originally put it in this bundle. R-8a (2026-08-27) pulled it
// OUT into its own scroll-gated screen, run right after suitability, ahead
// of this one — settling a three-way conflict with R-1a and the firm's
// SEC-intake instruction. 2026-08-29, product owner, verbatim: "risk
// disclosure should be part of the legal docs screen not a standalone
// before them they should be in on user opens and then can click on the
// checkmark leave the scroll thing please." — folded back into this
// bundle's `kinds`, one row among the other three, but still special-cased
// to open an in-app hand-authored view of its text rather than a real file.
// 2026-08-31, product owner, verbatim: "the risk disclosure should be a PDF
// too not a screen" — the special case is gone; every document in this
// bundle, risk disclosure included, is now opened the exact same way (the
// phone's native viewer, over a real presigned file). See
// legal_acceptance_screen.dart's own header for the full trace and what
// that trades for the literal scroll gate, and DECISIONS.md's R-8a
// 2026-08-31 addendum for the ruling.
//
// The onboarding order is now: signup → OTP → suitability → result → THIS
// SCREEN → passcode → biometric → (optional avatar picker, R-44) → Home.
// This screen is reached from suitability_result_screen.dart's own Continue
// action (`context.go(Routes.termsOfService)`), not straight off OTP
// verification, and there is no risk-disclaimer hop in between any more.
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
        'risk_disclosure',
        'client_agreement',
      ],
      screenTitle: 'Terms & agreements',
      screenBody: 'Four documents, one agreement. Open each one, then accept.',
      // Canvas s05's own "Step 2 of 4" — same mid-flow indicator convention
      // otp_screen.dart (Step 1)/create_passcode_screen.dart (Step 3)/
      // biometric_screen.dart (Step 4) already use.
      stepLabel: 'Step 2 of 4',
      checkboxLabel: 'I have read and agree to all four documents',
      checkboxDescription:
          'Terms of Service · Privacy Policy · Risk Disclosure · Client Agreement',
      buttonLabel: 'Accept and continue',
      onAccepted: (context) async => context.go(
        Routes.createPasscode,
        // AppState.pendingSignupEmail — set by otp_screen.dart right after
        // verification and carried forward from there (this screen now
        // runs several hops downstream of OTP, past suitability/result, so
        // the email can no longer ride a single route `extra` the way it
        // used to when this screen followed OTP directly). See
        // AppState's own doc comment on that field.
        extra: AppScope.read(context).pendingSignupEmail,
      ),
    );
  }
}
