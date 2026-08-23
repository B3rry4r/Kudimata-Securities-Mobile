// 05 · Enable biometric — fingerprint ring, headline, Enable / Maybe later. Both
// paths sign the investor in, then land on the onboarding personal-details
// step (personal_details_screen.dart) rather than Home directly — Enable
// also flips biometricEnabled. KYC/suitability are no longer forced here —
// browsing is open to everyone, only trading/funding require them (see
// Home's "Complete your KYC" prompt and the KYC-gate checks on Buy/Sell/Add
// money/Withdraw). Ported from screens.jsx Biometric. Mid-flow gated screen,
// no tab bar.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/app/app_state.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
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
            KOnboardTopBar(onBack: () => context.go(Routes.confirmPasscode)),
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
                    onPressed: () {
                      final app = AppScope.read(context);
                      app.setBiometric(true);
                      app.setSignedIn(true);
                      context.go(Routes.onboardingPersonal);
                    },
                  ),
                  const SizedBox(height: 10),
                  KButton(
                    label: 'Not now',
                    variant: KButtonVariant.ghost,
                    onPressed: () {
                      AppScope.read(context).setSignedIn(true);
                      context.go(Routes.onboardingPersonal);
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
