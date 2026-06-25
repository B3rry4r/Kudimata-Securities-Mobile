// 02 · OTP verify — 6 single-digit cells, a disabled resend countdown, Verify.
// Ported from screens.jsx Otp. Mid-flow gated screen: top bar with back, no tab bar.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'onboarding_scaffold.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // Demo seed: two digits entered, matching the design's filled state.
  final List<String> _digits = ['3', '9', '', '', '', ''];

  int get _focusIndex => _digits.indexWhere((d) => d.isEmpty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KOnboardTopBar(onBack: () => context.go(Routes.signup)),
            Expanded(
              child: KOnboardBody(
                paddingTop: 8,
                children: [
                  const KScreenHead(
                    title: "Verify it's you",
                    body: 'We sent a 6-digit code to chidi@email.com',
                  ),
                  const SizedBox(height: 36),
                  KOtpCells(digits: _digits, focusIndex: _focusIndex),
                  const Spacer(),
                  Column(
                    children: [
                      // SEAM: resend countdown + dispatch wires to the auth provider.
                      const KButton(
                        label: 'Resend in 0:42',
                        variant: KButtonVariant.ghost,
                        onPressed: null,
                      ),
                      const SizedBox(height: 10),
                      KButton(
                        label: 'Verify',
                        // SEAM: real OTP check plugs in here; demo advances to
                        // passcode creation on Verify.
                        onPressed: () => context.go(Routes.createPasscode),
                      ),
                    ],
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
