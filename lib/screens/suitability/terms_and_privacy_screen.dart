// Onboarding — ALL FOUR legal documents (terms of service, privacy policy,
// risk disclosure, client agreement) combined into one screen with one
// checkbox (2026-08-20 consolidation; see legal_acceptance_screen.dart for
// the general shape).
//
// RISK DISCLOSURE'S PLACE HERE HAS MOVED TWICE. R-8 (DECISIONS.md,
// 2026-08-26) originally put it in this bundle. R-8a (2026-08-27) pulled it
// OUT into its own scroll-gated screen (risk_disclaimer_screen.dart), run
// right after suitability, ahead of this one — settling a three-way
// conflict with R-1a and the firm's SEC-intake instruction. **2026-08-29,
// product owner, verbatim: "risk disclosure should be part of the legal
// docs screen not a standalone before them they should be in on user opens
// and then can click on the checkmark leave the scroll thing please."**
// DECISIONS.md records this as a note superseding R-8a rather than editing
// it away. So risk disclosure is back in this bundle's `kinds` — one row
// among the other three, opened then checked off the same way — but it is
// NOT handed off to the phone's native viewer the way the other three are:
// legal_acceptance_screen.dart special-cases its row to push
// risk_disclaimer_screen.dart's `RiskDisclosureScrollScreen`, an in-app
// scroll-to-bottom-gated view of the real content, exactly preserving "the
// scroll thing" the owner asked to keep. See that file's header for the
// full trace and legal_acceptance_screen.dart's for the mechanics.
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
