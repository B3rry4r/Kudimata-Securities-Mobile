// 07 · Reset your passcode — email entry, Send code. Returns to Log in (a reset
// code is sent out of band). Ported from screens.jsx ResetPasscode. Mid-flow
// gated screen pushed off Log in, no tab bar.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'onboarding_scaffold.dart';

class ResetPasscodeScreen extends StatefulWidget {
  const ResetPasscodeScreen({super.key});

  @override
  State<ResetPasscodeScreen> createState() => _ResetPasscodeScreenState();
}

class _ResetPasscodeScreenState extends State<ResetPasscodeScreen> {
  String _email = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KOnboardTopBar(onBack: () => context.go(Routes.login)),
            Expanded(
              child: KOnboardBody(
                paddingTop: 8,
                children: [
                  const KScreenHead(
                    title: 'Reset your passcode',
                    body: "We'll send a code to your email.",
                  ),
                  const SizedBox(height: 28),
                  KInput(
                    label: 'Email',
                    icon: 'profile',
                    placeholder: 'you@email.com',
                    keyboardType: TextInputType.emailAddress,
                    value: _email,
                    onChanged: (v) => setState(() => _email = v),
                  ),
                  const Spacer(),
                  KButton(
                    label: 'Send code',
                    // SEAM: reset-code dispatch wires to the auth provider; demo
                    // returns to the Log in unlock.
                    onPressed: () => context.go(Routes.login),
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
