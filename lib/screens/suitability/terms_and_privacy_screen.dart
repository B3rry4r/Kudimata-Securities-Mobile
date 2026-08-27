// Onboarding — the FOUR legal documents (terms of service, privacy policy,
// risk disclosure, client agreement) combined into one screen with one
// checkbox (2026-08-20 consolidation; see legal_acceptance_screen.dart for
// the general shape).
//
// R-8 (DECISIONS.md, 2026-08-26): "Risk disclosure is one of the four,
// presented at the start with the rest, not as its own gated screen (this
// replaces R-1's expectation)." Risk Disclosure had been pulled out into
// its own dedicated post-suitability screen on 2026-08-24
// (risk_disclaimer_screen.dart) to satisfy an earlier reading of the firm's
// SEC intake doc; R-8 supersedes that reading and puts it back here,
// alongside the other three, as a document opened in the phone's native
// viewer rather than scroll-gated in-app text (see
// legal_acceptance_screen.dart's header for the acceptance-evidence
// consequence of that change).
//
// R-1a also moves this screen's place in the flow — suitability now runs
// BEFORE legal documents, not after — but this screen is still wired
// straight off OTP verification in app_router.dart/otp_screen.dart, which
// this directory's owner cannot edit (router is off-limits). Filed as a
// SHARED-CHANGE REQUEST rather than worked around locally; see this
// screen-pass's report.
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
      // biometric_screen.dart (Step 4) already use; this screen was
      // missing it entirely.
      stepLabel: 'Step 2 of 4',
      checkboxLabel: 'I have read and agree to all four documents',
      checkboxDescription:
          'Terms of Service · Privacy Policy · Risk Disclosure · Client Agreement',
      buttonLabel: 'Accept and continue',
      onAccepted: (context) async => context.go(Routes.createPasscode, extra: email),
    );
  }
}
