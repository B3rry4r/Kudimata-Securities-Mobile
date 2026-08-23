// 03 · Create a passcode — 6 dots fill from the keypad; at 6 digits we advance to
// confirm. Ported from screens.jsx CreatePasscode. Mid-flow gated, no tab bar.
//
// Re-entry (reentry): Security's "Change passcode" (security_screen.dart)
// PUSHes here with `extra: true` for an already-signed-in investor, instead
// of the gated onboarding flow reaching it via go(). When reentry is set we
// keep using push() to advance to confirm (so the Security/account stack
// underneath survives) and pop back to Security on the back arrow, instead
// of the onboarding go()/otp-back behaviour.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_invest/router/routes.dart';
import 'package:kudimata_invest/theme/tokens.dart';
import 'package:kudimata_invest/widgets/widgets.dart';
import 'confirm_passcode_screen.dart';
import 'onboarding_scaffold.dart';

class CreatePasscodeScreen extends StatefulWidget {
  const CreatePasscodeScreen({super.key, this.reentry = false, this.email});

  /// True when re-entering this flow from Security's "Change passcode"
  /// rather than first-time onboarding. Defaults to false so the ordinary
  /// signup → passcode → biometric → KYC flow is unaffected when this isn't
  /// explicitly set.
  final bool reentry;

  /// The account this new passcode belongs to — known with certainty at
  /// both call sites that pass it (otp_screen.dart post-signup,
  /// log_in_screen.dart post-login), threaded through to
  /// confirm_passcode_screen.dart so it doesn't need to re-derive this via
  /// an API call. Null for Security's reentry (no fresh login just
  /// happened) — that screen resolves it itself instead.
  final String? email;

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
      final args = ConfirmPasscodeArgs(code: _code, reentry: widget.reentry, email: widget.email);
      if (widget.reentry) {
        // Push (not go) so the Security/account stack below stays intact —
        // confirm's success pops back through both screens to Security.
        context.push(Routes.confirmPasscode, extra: args);
      } else {
        context.go(Routes.confirmPasscode, extra: args);
      }
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
            KOnboardTopBar(
              stepLabel: widget.reentry ? null : 'Step 3 of 4',
              onBack: () =>
                  widget.reentry ? context.pop() : context.go(Routes.otp),
            ),
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
                    "Six digits. You'll use it to open the app and to approve withdrawals.",
                    textAlign: TextAlign.center,
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
