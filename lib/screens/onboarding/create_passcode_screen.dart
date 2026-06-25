// 03 · Create a passcode — 6 dots fill from the keypad; at 6 digits we advance to
// confirm. Ported from screens.jsx CreatePasscode. Mid-flow gated, no tab bar.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'onboarding_scaffold.dart';

class CreatePasscodeScreen extends StatefulWidget {
  const CreatePasscodeScreen({super.key});

  @override
  State<CreatePasscodeScreen> createState() => _CreatePasscodeScreenState();
}

class _CreatePasscodeScreenState extends State<CreatePasscodeScreen> {
  String _code = '';

  void _onKey(String k) {
    setState(() {
      if (k == 'del') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
      } else if (_code.length < 6) {
        _code += k;
      }
    });
    if (_code.length == 6) {
      // Hand the chosen passcode to the confirm step (mismatch checked there).
      context.go(Routes.confirmPasscode, extra: _code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColor.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KOnboardTopBar(onBack: () => context.go(Routes.otp)),
            Expanded(
              child: KOnboardBody(
                paddingTop: 12,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: KScreenHead(title: 'Create a passcode'),
                  ),
                  const SizedBox(height: 40),
                  KPasscodeDots(filled: _code.length),
                  const SizedBox(height: 20),
                  Text(
                    "You'll use this to sign in.",
                    style: KType.body(color: KColor.ink3),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: KKeypad(onKey: _onKey),
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
