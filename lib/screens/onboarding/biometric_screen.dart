// 05 · Enable biometric — fingerprint ring, headline, Enable / Maybe later. Both
// paths advance to the KYC intro; Enable also flips biometricEnabled. Ported from
// screens.jsx Biometric. Mid-flow gated screen, no tab bar.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
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
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: KColor.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: KColor.hairline, width: 1),
                    ),
                    child: const Center(
                      child: KFingerprint(size: 48, stroke: 1.6),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Sign in faster',
                    textAlign: TextAlign.center,
                    style: KType.title(),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      'Use your face or fingerprint to sign in instead of your passcode.',
                      textAlign: TextAlign.center,
                      style: KType.body(color: KColor.ink2),
                    ),
                  ),
                  const Spacer(),
                  KButton(
                    label: 'Enable',
                    // SEAM: real biometric enrolment (local_auth) plugs in here.
                    onPressed: () {
                      AppScope.read(context).setBiometric(true);
                      context.go(Routes.kycIntro);
                    },
                  ),
                  const SizedBox(height: 10),
                  KButton(
                    label: 'Maybe later',
                    variant: KButtonVariant.ghost,
                    onPressed: () => context.go(Routes.kycIntro),
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
