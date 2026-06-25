// 04 · Confirm your passcode — re-enter to confirm. Mismatch tints the dots loss
// and shows the error line (the design's seeded state). On match we set
// passcodeSet and advance to biometric. Ported from screens.jsx ConfirmPasscode.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kudimata_securities/app/app_state.dart';
import 'package:kudimata_securities/router/routes.dart';
import 'package:kudimata_securities/theme/tokens.dart';
import 'package:kudimata_securities/widgets/widgets.dart';
import 'onboarding_scaffold.dart';

class ConfirmPasscodeScreen extends StatefulWidget {
  const ConfirmPasscodeScreen({super.key, this.created});

  /// The passcode chosen on the create step (passed via GoRouter `extra`).
  final String? created;

  @override
  State<ConfirmPasscodeScreen> createState() => _ConfirmPasscodeScreenState();
}

class _ConfirmPasscodeScreenState extends State<ConfirmPasscodeScreen> {
  String _code = '';
  bool _error = false;

  void _onKey(String k) {
    setState(() {
      if (k == 'del') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
        _error = false;
      } else if (_code.length < 6) {
        _code += k;
        _error = false;
      }
    });
    if (_code.length == 6) _evaluate();
  }

  void _evaluate() {
    final created = widget.created;
    // No created code available (e.g. deep link): accept as the demo path.
    final matches = created == null || _code == created;
    if (matches) {
      AppScope.read(context).setPasscode(true);
      context.go(Routes.biometric);
    } else {
      setState(() => _error = true);
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
            KOnboardTopBar(onBack: () => context.go(Routes.createPasscode)),
            Expanded(
              child: KOnboardBody(
                paddingTop: 12,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: KScreenHead(title: 'Confirm your passcode'),
                  ),
                  const SizedBox(height: 40),
                  KPasscodeDots(filled: _code.length, error: _error),
                  const SizedBox(height: 18),
                  if (_error)
                    Text(
                      "Passcodes don't match",
                      style: KType.body(color: KColor.loss, w: KWeight.medium),
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
