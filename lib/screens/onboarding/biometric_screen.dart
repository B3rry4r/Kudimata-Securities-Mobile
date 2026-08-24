// 05 · Enable biometric — fingerprint ring, headline, Enable / Maybe later. Both
// paths sign the investor in and land straight on Home — Enable also flips
// biometricEnabled. KYC/suitability are no longer forced here — browsing is
// open to everyone, only trading/funding require them (see Home's "Complete
// your KYC" prompt and the KYC-gate checks on Buy/Sell/Add money/Withdraw).
//
// 2026-08-24: used to detour through the onboarding personal-details step
// (personal_details_screen.dart) before Home — direct product feedback: "a
// few more details should be part of the KYC and not a separate step after
// login". That screen's DOB/address/city/state/phone fields are now
// collected as part of STARTING KYC verification instead (see
// kyc_intro.dart's `_start()`), so a fresh signup reaches Home immediately,
// browse-only, same as any other not-yet-verified investor.
//
// Ported from screens.jsx Biometric. Mid-flow gated screen, no tab bar.
import 'package:flutter/material.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'log_in_screen.dart' show hydrateGatingStateAndRoute;
import 'onboarding_scaffold.dart';

class BiometricScreen extends StatelessWidget {
  const BiometricScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Canvas #s09 renders the "Step 4 of 4" label bare, with no back
            // arrow — unlike every other mid-flow screen (04/05/07/08/12).
            // Found in the 2026-08-23 exactness audit.
            const KOnboardTopBar(
              stepLabel: 'Step 4 of 4',
              showBackIcon: false,
            ),
            Expanded(
              child: KOnboardBody(
                paddingTop: 8,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  KStatusView(
                    illustrationName: 'sign-in',
                    tone: KStatusTone.pending,
                    title: 'Unlock with your face',
                    message:
                        'Skip the passcode next time. Your face never leaves your phone — we only ever see a yes or a no.',
                  ),
                  const Spacer(),
                  KButton(
                    label: 'Turn on Face ID',
                    iconLeft: 'fingerprint',
                    // SEAM: real biometric enrolment (local_auth) plugs in here.
                    onPressed: () async {
                      AppScope.read(context).setBiometric(true);
                      await hydrateGatingStateAndRoute(context);
                    },
                  ),
                  const SizedBox(height: 10),
                  KButton(
                    label: 'Not now',
                    variant: KButtonVariant.ghost,
                    onPressed: () async {
                      await hydrateGatingStateAndRoute(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
